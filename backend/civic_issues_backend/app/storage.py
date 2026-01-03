# in app/storage.py
import aiofiles
from fastapi import UploadFile, HTTPException, status
from uuid import uuid4
import os
import re
from pathlib import Path
from .config import settings
import logging

logger = logging.getLogger(__name__)

UPLOAD_DIR = "uploads"

def sanitize_filename(filename: str) -> str:
    """
    Sanitize filename to prevent path traversal attacks.
    """
    # Remove any path components
    filename = os.path.basename(filename)
    # Remove any non-alphanumeric characters except dots and dashes
    filename = re.sub(r'[^\w\.\-]', '', filename)
    # Ensure filename is not empty
    if not filename:
        return "file"
    return filename

async def save_file(file: UploadFile) -> str:
    """
    Save uploaded file with comprehensive security validations.
    Mobile-friendly validation that prioritizes file extension over content_type.
    """
    # Create upload directory securely
    upload_path = Path(UPLOAD_DIR)
    upload_path.mkdir(exist_ok=True)
    
    # Validate filename is provided
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Filename is required"
        )
    
    # Sanitize and validate file extension FIRST (mobile-friendly)
    sanitized_original = sanitize_filename(file.filename)
    ext = sanitized_original.split(".")[-1].lower() if "." in sanitized_original else ""
    
    # Whitelist of allowed extensions
    ALLOWED_EXTENSIONS = ["jpg", "jpeg", "png", "webp"]
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file extension. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Validate content_type ONLY if provided (mobile devices may not send it)
    # Accept files with valid extensions even if content_type is missing/wrong
    if file.content_type:
        # Map extensions to acceptable content types (more flexible for mobile)
        ACCEPTABLE_CONTENT_TYPES = [
            "image/jpeg", "image/jpg", "image/png", "image/webp",
            "application/octet-stream",  # Generic binary - common on mobile
        ]
        if file.content_type not in ACCEPTABLE_CONTENT_TYPES:
            print(f"Warning: Unexpected content_type '{file.content_type}' for extension '{ext}'")
            # Don't reject - extension check is more reliable on mobile
    
    # Validate file size
    file.file.seek(0, 2)  # Seek to end
    file_size = file.file.tell()  # Get position (file size)
    file.file.seek(0)  # Reset to start
    
    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is empty"
        )
    
    max_size = settings.MAX_FILE_SIZE_MB * 1024 * 1024  # Convert MB to bytes
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {settings.MAX_FILE_SIZE_MB}MB"
        )
    
    # Note: Comprehensive fraud detection (including AI detection) is now handled
    # in the issue creation endpoint using the consolidated fraud_detection service
    
    # Generate secure random filename
    filename = f"{uuid4()}.{ext}"
    file_path = upload_path / filename
    
    # Ensure file path is within upload directory (prevent path traversal)
    try:
        file_path = file_path.resolve()
        upload_path = upload_path.resolve()
        if not str(file_path).startswith(str(upload_path)):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file path"
            )
    except (ValueError, OSError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file path"
        )

    try:
        async with aiofiles.open(str(file_path), "wb") as f:
            while content := await file.read(1024 * 1024):  # Read 1MB chunks
                await f.write(content)
    except Exception as e:
        # Clean up partial file if exists
        if file_path.exists():
            file_path.unlink()
        print(f"File save error: {str(e)}")  # Log for debugging
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save file"
        )
    
    return f"/{UPLOAD_DIR}/{filename}"