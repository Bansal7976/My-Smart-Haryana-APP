"""
Duplicate Image Detection Service
Detects if an uploaded image is similar to existing issue images
Uses perceptual hashing (pHash) for efficient similarity comparison
"""

from PIL import Image
import io
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from .. import models
import logging
import imagehash

logger = logging.getLogger(__name__)

# Similarity threshold (0-64, lower = more similar)
# pHash distance of 10 means images are ~84% similar
SIMILARITY_THRESHOLD = 10


def calculate_perceptual_hash(image_bytes: bytes) -> str:
    """
    Calculate perceptual hash (pHash) of an image.
    pHash is robust to minor variations (resize, compression, brightness).
    
    Args:
        image_bytes: Raw image bytes
        
    Returns:
        str: Hexadecimal hash string (64 characters)
    """
    try:
        # Open image from bytes
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if necessary
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Calculate perceptual hash
        # pHash is good for detecting similar images even with minor changes
        phash = imagehash.phash(image, hash_size=16)  # 16x16 = 256 bits = 64 hex chars
        
        return str(phash)
    except Exception as e:
        logger.error(f"Error calculating perceptual hash: {str(e)}")
        raise


def calculate_average_hash(image_bytes: bytes) -> str:
    """
    Calculate average hash (aHash) as a fallback.
    Simpler and faster than pHash but less robust.
    
    Args:
        image_bytes: Raw image bytes
        
    Returns:
        str: Hexadecimal hash string
    """
    try:
        image = Image.open(io.BytesIO(image_bytes))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        ahash = imagehash.average_hash(image, hash_size=16)
        return str(ahash)
    except Exception as e:
        logger.error(f"Error calculating average hash: {str(e)}")
        raise


def hash_distance(hash1: str, hash2: str) -> int:
    """
    Calculate Hamming distance between two hash strings.
    Returns the number of different bits.
    
    Args:
        hash1: First hash string
        hash2: Second hash string
        
    Returns:
        int: Hamming distance (0 = identical, higher = more different)
    """
    try:
        h1 = imagehash.hex_to_hash(hash1)
        h2 = imagehash.hex_to_hash(hash2)
        return h1 - h2
    except Exception as e:
        logger.error(f"Error calculating hash distance: {str(e)}")
        return 100  # Return high distance if error


async def check_duplicate_image(
    db: AsyncSession,
    image_bytes: bytes,
    current_user_id: int
) -> tuple[bool, int | None]:
    """
    Check if uploaded image is similar to any existing issue image.
    
    Args:
        db: Database session
        image_bytes: Raw image bytes of new upload
        current_user_id: ID of user uploading the image
        
    Returns:
        tuple: (is_duplicate: bool, existing_problem_id: int | None)
    """
    try:
        # Calculate hash of new image
        new_hash = calculate_perceptual_hash(image_bytes)
        logger.info(f"Calculated perceptual hash for new image: {new_hash[:16]}...")
        
        # Get all existing media files with initial photos, joined with problems to check status
        query = select(models.Media).where(
            models.Media.media_type == models.MediaTypeEnum.PHOTO_INITIAL
        ).options(selectinload(models.Media.problem))
        
        result = await db.execute(query)
        existing_media = result.scalars().all()
        
        if not existing_media:
            logger.debug("No existing images found, no duplicate")
            return False, None
        
        # Load existing images and compare
        from pathlib import Path
        upload_dir = Path("uploads")
        
        for media in existing_media:
            try:
                # Skip if the problem is already completed or verified (same issue can happen again)
                if media.problem and media.problem.status in [
                    models.ProblemStatusEnum.COMPLETED,
                    models.ProblemStatusEnum.VERIFIED
                ]:
                    logger.debug(
                        f"Skipping completed/verified problem #{media.problem_id} - same issue can be reported again"
                    )
                    continue
                
                # Get file path from URL
                file_url = media.file_url.lstrip('/')
                file_path = Path(file_url)
                
                # Handle both relative and absolute paths
                if not file_path.is_absolute():
                    file_path = upload_dir / file_path.name
                
                if not file_path.exists():
                    logger.warning(f"Media file not found: {file_path}")
                    continue
                
                # Read existing image file
                with open(file_path, 'rb') as f:
                    existing_image_bytes = f.read()
                
                # Calculate hash of existing image
                existing_hash = calculate_perceptual_hash(existing_image_bytes)
                
                # Calculate similarity distance
                distance = hash_distance(new_hash, existing_hash)
                
                logger.debug(
                    f"Comparing with problem #{media.problem_id}: "
                    f"distance={distance}, threshold={SIMILARITY_THRESHOLD}"
                )
                
                # If distance is below threshold, images are similar
                if distance <= SIMILARITY_THRESHOLD:
                    logger.warning(
                        f"Duplicate image detected! "
                        f"Similar to problem #{media.problem_id} "
                        f"(similarity distance: {distance})"
                    )
                    return True, media.problem_id
                    
            except Exception as e:
                logger.warning(f"Error comparing with media {media.id}: {str(e)}")
                continue
        
        logger.info("No duplicate images found")
        return False, None
        
    except Exception as e:
        logger.error(f"Error in duplicate detection: {str(e)}")
        # Fail-open: if detection fails, allow upload (don't block users)
        return False, None


async def get_existing_problem_details(
    db: AsyncSession,
    problem_id: int
) -> dict | None:
    """
    Get details of existing problem that matches duplicate image.
    
    Args:
        db: Database session
        problem_id: ID of existing problem
        
    Returns:
        dict: Problem details or None
    """
    try:
        from sqlalchemy.orm import selectinload
        query = select(models.Problem).where(models.Problem.id == problem_id).options(
            selectinload(models.Problem.submitted_by),
            selectinload(models.Problem.media_files)
        )
        result = await db.execute(query)
        problem = result.scalar_one_or_none()
        
        if problem:
            return {
                "id": problem.id,
                "title": problem.title,
                "description": problem.description,
                "status": problem.status.value,
                "created_at": problem.created_at.isoformat() if problem.created_at else None,
                "district": problem.district,
                "submitted_by": problem.submitted_by.full_name if problem.submitted_by else None
            }
        return None
    except Exception as e:
        logger.error(f"Error getting problem details: {str(e)}")
        return None

