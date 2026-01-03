"""
Enhanced Fraud Detection Service
Detects fraudulent reports using multiple techniques:
1. AI-generated image detection (EXIF, noise patterns, compression)
2. Duplicate image detection (perceptual hashing)
3. Suspicious reporting patterns
4. Location-based anomalies
5. User behavior analysis
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, or_, desc
from sqlalchemy.orm import selectinload
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple
from .. import models
import logging
import cv2
import numpy as np
from PIL import Image
from PIL.ExifTags import TAGS
import io
import imagehash
from pathlib import Path

logger = logging.getLogger(__name__)

# Fraud detection thresholds
FRAUD_THRESHOLDS = {
    'max_reports_per_hour': 5,          # Max reports per user per hour
    'max_reports_per_day': 20,          # Max reports per user per day
    'min_distance_between_reports': 50,  # Minimum meters between reports (same user)
    'max_reports_same_location': 3,     # Max reports from same location (100m radius)
    'suspicious_time_pattern': 10,      # Reports within 10 minutes from same user
    'image_similarity_threshold': 10,   # pHash distance threshold
}

class FraudDetectionResult:
    """Result of fraud detection analysis"""
    
    def __init__(self):
        self.is_suspicious = False
        self.fraud_score = 0.0  # 0-100 scale
        self.reasons = []
        self.action = "allow"  # allow, warn, block
        self.existing_problem_id = None
        self.metadata = {}
    
    def add_suspicion(self, reason: str, score_increase: float, metadata: Dict = None):
        """Add a suspicion reason and increase fraud score"""
        self.reasons.append(reason)
        self.fraud_score += score_increase
        if metadata:
            self.metadata.update(metadata)
        
        # Update action based on score
        if self.fraud_score >= 80:
            self.action = "block"
            self.is_suspicious = True
        elif self.fraud_score >= 50:
            self.action = "warn"
            self.is_suspicious = True
        else:
            self.action = "allow"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging/API response"""
        return {
            "is_suspicious": self.is_suspicious,
            "fraud_score": round(self.fraud_score, 2),
            "reasons": self.reasons,
            "action": self.action,
            "existing_problem_id": self.existing_problem_id,
            "metadata": self.metadata
        }


async def detect_fraud(
    db: AsyncSession,
    user_id: int,
    image_bytes: bytes,
    latitude: float,
    longitude: float,
    problem_type: str,
    title: str,
    description: str = None
) -> FraudDetectionResult:
    """
    Comprehensive fraud detection for new issue reports.
    
    Args:
        db: Database session
        user_id: ID of user reporting the issue
        image_bytes: Raw image bytes
        latitude: Issue location latitude
        longitude: Issue location longitude
        problem_type: Type of problem being reported
        title: Issue title
        description: Issue description
        
    Returns:
        FraudDetectionResult: Detailed fraud analysis
    """
    result = FraudDetectionResult()
    
    try:
        # 1. Duplicate Image Detection (Highest Priority)
        await _check_duplicate_images(db, user_id, image_bytes, result)
        
        # 2. User Reporting Pattern Analysis
        await _check_user_patterns(db, user_id, result)
        
        # 3. Location-based Anomaly Detection
        await _check_location_anomalies(db, user_id, latitude, longitude, result)
        
        # 4. Content Analysis
        await _check_content_anomalies(db, problem_type, title, description, result)
        
        # 5. Time-based Pattern Detection
        await _check_time_patterns(db, user_id, result)
        
        # Log the result
        logger.info(
            f"Fraud detection for user {user_id}: "
            f"score={result.fraud_score:.2f}, action={result.action}, "
            f"reasons={len(result.reasons)}"
        )
        
        if result.is_suspicious:
            logger.warning(f"Suspicious activity detected: {result.reasons}")
        
        return result
        
    except Exception as e:
        logger.error(f"Fraud detection error: {str(e)}")
        # Fail-open: if detection fails, allow the report
        return result


async def _check_duplicate_images(
    db: AsyncSession,
    user_id: int,
    image_bytes: bytes,
    result: FraudDetectionResult
):
    """Check for AI-generated images and duplicate images"""
    try:
        # Step 1: Check if image is AI-generated
        ai_score = _check_ai_generated_image(image_bytes)
        if ai_score >= 4:  # High suspicion of AI generation
            result.add_suspicion(
                "AI-generated image detected - not a real photo",
                score_increase=95,  # Very high score for AI images
                metadata={"ai_detection_score": ai_score}
            )
            return
        elif ai_score >= 2:  # Medium suspicion
            result.add_suspicion(
                "Image may be AI-generated or heavily edited",
                score_increase=30,
                metadata={"ai_detection_score": ai_score}
            )
        
        # Step 2: Check for duplicate images using perceptual hashing
        is_duplicate, existing_problem_id = await _check_duplicate_image_hash(
            db, image_bytes, user_id
        )
        
        if is_duplicate and existing_problem_id:
            result.existing_problem_id = existing_problem_id
            result.add_suspicion(
                "Duplicate image detected - identical to existing report",
                score_increase=90,  # Very high score for exact duplicates
                metadata={"duplicate_problem_id": existing_problem_id}
            )
            
    except Exception as e:
        logger.warning(f"Image analysis failed: {e}")


def _check_ai_generated_image(image_bytes: bytes) -> int:
    """
    Check if image is AI-generated using multiple techniques.
    Returns suspicion score (0-6, higher = more suspicious)
    """
    try:
        # Load image
        image = Image.open(io.BytesIO(image_bytes))
        img_array = np.array(image)
        
        suspicion_score = 0
        
        # Check 1: EXIF Metadata Analysis
        if _check_exif_suspicious(image):
            suspicion_score += 3  # EXIF is most reliable
        
        # Check 2: Noise Pattern Analysis
        if _check_noise_patterns_suspicious(img_array):
            suspicion_score += 2  # Noise patterns are good indicators
        
        # Check 3: Compression Artifacts
        if _check_compression_suspicious(img_array):
            suspicion_score += 1  # Compression is least reliable
        
        return suspicion_score
        
    except Exception as e:
        logger.warning(f"AI image detection error: {e}")
        return 0  # Fail-open


def _check_exif_suspicious(image: Image.Image) -> bool:
    """Check EXIF data for signs of AI generation"""
    try:
        exif_data = image._getexif()
        
        if not exif_data:
            return True  # No EXIF data is suspicious
        
        # Extract EXIF tags
        exif = {
            TAGS.get(tag): value
            for tag, value in exif_data.items()
            if tag in TAGS
        }
        
        # Suspicious software tags
        ai_software_keywords = [
            'stable diffusion', 'midjourney', 'dall-e', 'dalle',
            'generated', 'ai', 'artificial', 'synthetic'
        ]
        
        software = str(exif.get('Software', '')).lower()
        for keyword in ai_software_keywords:
            if keyword in software:
                return True
        
        # Check for camera info (real photos have this)
        has_camera_info = (
            exif.get('Make') or 
            exif.get('Model') or
            exif.get('LensMake')
        )
        
        return not has_camera_info
        
    except Exception:
        return False


def _check_noise_patterns_suspicious(img_array: np.ndarray) -> bool:
    """Analyze noise patterns to detect AI generation"""
    try:
        # Convert to grayscale if needed
        if len(img_array.shape) == 3:
            gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
        else:
            gray = img_array
        
        # Calculate noise level using Laplacian variance
        laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        
        # AI images often have very low or very high variance
        if laplacian_var < 10 or laplacian_var > 1000:
            return True
        
        # Check edge density
        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges > 0) / edges.size
        
        # AI images often have unnatural edge patterns
        if edge_density < 0.01 or edge_density > 0.3:
            return True
        
        return False
        
    except Exception:
        return False


def _check_compression_suspicious(img_array: np.ndarray) -> bool:
    """Check compression artifacts for AI detection"""
    try:
        # Convert to grayscale
        if len(img_array.shape) == 3:
            gray = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)
        else:
            gray = img_array
        
        # Calculate frequency domain characteristics
        dft = cv2.dft(np.float32(gray), flags=cv2.DFT_COMPLEX_OUTPUT)
        dft_shift = np.fft.fftshift(dft)
        magnitude_spectrum = 20 * np.log(cv2.magnitude(dft_shift[:,:,0], dft_shift[:,:,1]) + 1)
        
        # Check for unnatural frequency patterns
        high_freq_ratio = np.mean(magnitude_spectrum > np.median(magnitude_spectrum))
        
        if high_freq_ratio < 0.3 or high_freq_ratio > 0.7:
            return True
        
        return False
        
    except Exception:
        return False


async def _check_duplicate_image_hash(
    db: AsyncSession,
    image_bytes: bytes,
    current_user_id: int
) -> tuple[bool, int | None]:
    """
    Check if uploaded image is similar to any existing issue image using perceptual hashing.
    """
    try:
        # Calculate hash of new image
        new_hash = _calculate_perceptual_hash(image_bytes)
        
        # Get all existing media files with initial photos
        query = select(models.Media).where(
            models.Media.media_type == models.MediaTypeEnum.PHOTO_INITIAL
        ).options(selectinload(models.Media.problem))
        
        result = await db.execute(query)
        existing_media = result.scalars().all()
        
        if not existing_media:
            return False, None
        
        # Load existing images and compare
        upload_dir = Path("uploads")
        
        for media in existing_media:
            try:
                # Skip completed/verified problems (same issue can happen again)
                if media.problem and media.problem.status in [
                    models.ProblemStatusEnum.COMPLETED,
                    models.ProblemStatusEnum.VERIFIED
                ]:
                    continue
                
                # Get file path
                file_url = media.file_url.lstrip('/')
                file_path = Path(file_url)
                
                if not file_path.is_absolute():
                    file_path = upload_dir / file_path.name
                
                if not file_path.exists():
                    continue
                
                # Read and compare
                with open(file_path, 'rb') as f:
                    existing_image_bytes = f.read()
                
                existing_hash = _calculate_perceptual_hash(existing_image_bytes)
                distance = _hash_distance(new_hash, existing_hash)
                
                # If distance is below threshold, images are similar
                if distance <= FRAUD_THRESHOLDS['image_similarity_threshold']:
                    return True, media.problem_id
                    
            except Exception as e:
                logger.warning(f"Error comparing with media {media.id}: {e}")
                continue
        
        return False, None
        
    except Exception as e:
        logger.error(f"Duplicate image detection error: {e}")
        return False, None


def _calculate_perceptual_hash(image_bytes: bytes) -> str:
    """Calculate perceptual hash (pHash) of an image"""
    try:
        image = Image.open(io.BytesIO(image_bytes))
        if image.mode != 'RGB':
            image = image.convert('RGB')
        phash = imagehash.phash(image, hash_size=16)
        return str(phash)
    except Exception as e:
        logger.error(f"Error calculating perceptual hash: {e}")
        raise


def _hash_distance(hash1: str, hash2: str) -> int:
    """Calculate Hamming distance between two hash strings"""
    try:
        h1 = imagehash.hex_to_hash(hash1)
        h2 = imagehash.hex_to_hash(hash2)
        return h1 - h2
    except Exception as e:
        logger.error(f"Error calculating hash distance: {e}")
        return 100  # Return high distance if error


async def _check_user_patterns(
    db: AsyncSession,
    user_id: int,
    result: FraudDetectionResult
):
    """Analyze user reporting patterns for suspicious behavior"""
    try:
        now = datetime.utcnow()
        
        # Check reports in last hour
        hour_ago = now - timedelta(hours=1)
        hour_query = select(func.count(models.Problem.id)).where(
            and_(
                models.Problem.user_id == user_id,
                models.Problem.created_at >= hour_ago
            )
        )
        reports_last_hour = (await db.execute(hour_query)).scalar()
        
        if reports_last_hour >= FRAUD_THRESHOLDS['max_reports_per_hour']:
            result.add_suspicion(
                f"Too many reports in last hour ({reports_last_hour})",
                score_increase=30,
                metadata={"reports_last_hour": reports_last_hour}
            )
        
        # Check reports in last day
        day_ago = now - timedelta(days=1)
        day_query = select(func.count(models.Problem.id)).where(
            and_(
                models.Problem.user_id == user_id,
                models.Problem.created_at >= day_ago
            )
        )
        reports_last_day = (await db.execute(day_query)).scalar()
        
        if reports_last_day >= FRAUD_THRESHOLDS['max_reports_per_day']:
            result.add_suspicion(
                f"Too many reports in last day ({reports_last_day})",
                score_increase=25,
                metadata={"reports_last_day": reports_last_day}
            )
        
        # Check for rapid-fire reporting (multiple reports within minutes)
        minutes_ago = now - timedelta(minutes=FRAUD_THRESHOLDS['suspicious_time_pattern'])
        rapid_query = select(func.count(models.Problem.id)).where(
            and_(
                models.Problem.user_id == user_id,
                models.Problem.created_at >= minutes_ago
            )
        )
        rapid_reports = (await db.execute(rapid_query)).scalar()
        
        if rapid_reports >= 3:
            result.add_suspicion(
                f"Rapid-fire reporting detected ({rapid_reports} reports in {FRAUD_THRESHOLDS['suspicious_time_pattern']} minutes)",
                score_increase=40,
                metadata={"rapid_reports": rapid_reports}
            )
            
    except Exception as e:
        logger.warning(f"User pattern check failed: {e}")


async def _check_location_anomalies(
    db: AsyncSession,
    user_id: int,
    latitude: float,
    longitude: float,
    result: FraudDetectionResult
):
    """Check for location-based suspicious patterns"""
    try:
        # Check for multiple reports from same location (within 100m)
        location_query = select(func.count(models.Problem.id)).where(
            and_(
                models.Problem.user_id != user_id,  # Different users
                func.ST_DWithin(
                    models.Problem.location,
                    func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326),
                    100  # 100 meter radius
                )
            )
        )
        nearby_reports = (await db.execute(location_query)).scalar()
        
        if nearby_reports >= FRAUD_THRESHOLDS['max_reports_same_location']:
            result.add_suspicion(
                f"Multiple reports from same location ({nearby_reports} reports within 100m)",
                score_increase=20,
                metadata={"nearby_reports": nearby_reports}
            )
        
        # Check if user is reporting from very different locations rapidly
        recent_query = select(models.Problem).where(
            and_(
                models.Problem.user_id == user_id,
                models.Problem.created_at >= datetime.utcnow() - timedelta(hours=1)
            )
        ).order_by(desc(models.Problem.created_at)).limit(3)
        
        recent_problems = (await db.execute(recent_query)).scalars().all()
        
        if len(recent_problems) >= 2:
            # Calculate distances between recent reports
            from geoalchemy2.shape import to_shape
            distances = []
            
            for problem in recent_problems:
                if problem.location:
                    try:
                        point = to_shape(problem.location)
                        # Simple distance calculation (not exact but good enough for fraud detection)
                        lat_diff = abs(point.y - latitude)
                        lng_diff = abs(point.x - longitude)
                        distance_km = ((lat_diff ** 2 + lng_diff ** 2) ** 0.5) * 111  # Rough km conversion
                        distances.append(distance_km)
                    except Exception:
                        continue
            
            # If user is reporting from locations > 50km apart within an hour
            max_distance = max(distances) if distances else 0
            if max_distance > 50:
                result.add_suspicion(
                    f"Reports from distant locations ({max_distance:.1f}km apart within 1 hour)",
                    score_increase=35,
                    metadata={"max_distance_km": max_distance}
                )
                
    except Exception as e:
        logger.warning(f"Location anomaly check failed: {e}")


async def _check_content_anomalies(
    db: AsyncSession,
    problem_type: str,
    title: str,
    description: str,
    result: FraudDetectionResult
):
    """Check for suspicious content patterns"""
    try:
        # Check for very short or generic titles
        if len(title.strip()) < 5:
            result.add_suspicion(
                "Very short title (possible low-effort spam)",
                score_increase=10,
                metadata={"title_length": len(title)}
            )
        
        # Check for repeated words (spam indicator)
        words = title.lower().split()
        if len(words) > 1 and len(set(words)) < len(words) * 0.5:
            result.add_suspicion(
                "Repetitive title content (possible spam)",
                score_increase=15,
                metadata={"unique_word_ratio": len(set(words)) / len(words)}
            )
        
        # Check for common spam phrases
        spam_phrases = [
            "test", "testing", "fake", "spam", "dummy", "sample",
            "टेस्ट", "फेक", "नकली", "परीक्षण"
        ]
        
        title_lower = title.lower()
        description_lower = (description or "").lower()
        
        for phrase in spam_phrases:
            if phrase in title_lower or phrase in description_lower:
                result.add_suspicion(
                    f"Suspicious content detected: '{phrase}'",
                    score_increase=20,
                    metadata={"spam_phrase": phrase}
                )
                break
                
    except Exception as e:
        logger.warning(f"Content anomaly check failed: {e}")


async def _check_time_patterns(
    db: AsyncSession,
    user_id: int,
    result: FraudDetectionResult
):
    """Check for suspicious time-based patterns"""
    try:
        # Check if user only reports at unusual hours (possible bot)
        hour_query = select(
            func.extract('hour', models.Problem.created_at).label('hour'),
            func.count(models.Problem.id).label('count')
        ).where(
            models.Problem.user_id == user_id
        ).group_by(
            func.extract('hour', models.Problem.created_at)
        )
        
        hour_stats = (await db.execute(hour_query)).all()
        
        if len(hour_stats) >= 5:  # Only check if user has enough reports
            # Check if all reports are during unusual hours (2 AM - 5 AM)
            unusual_hours = [2, 3, 4, 5]
            total_reports = sum(stat.count for stat in hour_stats)
            unusual_reports = sum(stat.count for stat in hour_stats if stat.hour in unusual_hours)
            
            if unusual_reports / total_reports > 0.8:  # 80% of reports during unusual hours
                result.add_suspicion(
                    "Unusual reporting hours (possible automated behavior)",
                    score_increase=25,
                    metadata={"unusual_hour_ratio": unusual_reports / total_reports}
                )
                
    except Exception as e:
        logger.warning(f"Time pattern check failed: {e}")


async def log_fraud_attempt(
    db: AsyncSession,
    user_id: int,
    fraud_result: FraudDetectionResult,
    additional_data: Dict = None
):
    """Log fraud detection results for analysis and monitoring"""
    try:
        # You could create a FraudLog table to store these
        # For now, just log to application logs
        log_data = {
            "user_id": user_id,
            "timestamp": datetime.utcnow().isoformat(),
            "fraud_score": fraud_result.fraud_score,
            "action": fraud_result.action,
            "reasons": fraud_result.reasons,
            "metadata": fraud_result.metadata
        }
        
        if additional_data:
            log_data.update(additional_data)
        
        if fraud_result.is_suspicious:
            logger.warning(f"FRAUD DETECTED: {log_data}")
        else:
            logger.info(f"Fraud check passed: User {user_id}, Score: {fraud_result.fraud_score}")
            
    except Exception as e:
        logger.error(f"Failed to log fraud attempt: {e}")


# Utility functions for admin monitoring
async def get_fraud_statistics(db: AsyncSession, days: int = 7) -> Dict[str, Any]:
    """Get fraud detection statistics for monitoring"""
    try:
        # This would require a fraud_logs table in a real implementation
        # For now, return basic stats
        return {
            "period_days": days,
            "total_checks": 0,  # Would come from fraud_logs table
            "suspicious_reports": 0,
            "blocked_reports": 0,
            "top_fraud_reasons": [],
            "fraud_score_distribution": {}
        }
    except Exception as e:
        logger.error(f"Failed to get fraud statistics: {e}")
        return {}


async def get_user_fraud_history(db: AsyncSession, user_id: int) -> List[Dict[str, Any]]:
    """Get fraud detection history for a specific user"""
    try:
        # This would query a fraud_logs table in a real implementation
        # For now, return empty list
        return []
    except Exception as e:
        logger.error(f"Failed to get user fraud history: {e}")
        return []

async def get_existing_problem_details(
    db: AsyncSession,
    problem_id: int
) -> dict | None:
    """
    Get details of existing problem that matches duplicate image.
    """
    try:
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
        logger.error(f"Error getting problem details: {e}")
        return None