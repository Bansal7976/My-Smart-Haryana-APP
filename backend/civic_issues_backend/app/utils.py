# in app/utils.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
import re

from . import models
from .config import settings
from .database import get_db

# --- Password Hashing ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def validate_password_strength(password: str) -> None:
    """
    Validate password meets security requirements:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    """
    if len(password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters long"
        )
    
    if not re.search(r'[A-Z]', password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain at least one uppercase letter"
        )
    
    if not re.search(r'[a-z]', password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain at least one lowercase letter"
        )
    
    if not re.search(r'[0-9]', password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain at least one digit"
        )
    
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must contain at least one special character (!@#$%^&*(),.?\":{}|<>)"
        )

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    validate_password_strength(password)
    return pwd_context.hash(password)

# --- JWT Token & Authentication ---
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> dict:
    """
    Decode and verify JWT token.
    Returns payload if valid, raises JWTError if invalid.
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError as e:
        raise JWTError(f"Invalid token: {str(e)}")

async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    query = select(models.User).where(models.User.email == email)
    user = (await db.execute(query)).scalar_one_or_none()
    
    if user is None or not user.is_active:
        raise credentials_exception
    return user

# --- Location Processing Helpers ---
from typing import List
from . import schemas
import logging

logger = logging.getLogger(__name__)

def process_problems_location(problems: List[models.Problem]) -> List[schemas.Problem]:
    """
    Helper function to process a list of problems and ensure location is properly formatted.
    Converts PostGIS geometry to coordinate string format.
    """
    processed_problems = []
    for problem in problems:
        if problem.location and hasattr(problem.location, 'data'):
            try:
                from geoalchemy2.shape import to_shape
                point = to_shape(problem.location)
                # Create a temporary dict to pass to Pydantic
                problem_dict = {
                    **{c.name: getattr(problem, c.name) for c in problem.__table__.columns},
                    'location': f"{point.y:.6f}, {point.x:.6f}",
                    'latitude': point.y,
                    'longitude': point.x,
                    'submitted_by': problem.submitted_by,
                    'media_files': problem.media_files,
                    'feedback': problem.feedback,
                    'assigned_to': problem.assigned_to
                }
                processed_problems.append(schemas.Problem(**problem_dict))
            except Exception as e:
                logger.warning(f"Failed to extract coordinates from geometry for problem {problem.id}: {e}")
                processed_problems.append(problem)
        else:
            processed_problems.append(problem)
    
    return processed_problems

def process_single_problem_location(problem: models.Problem) -> schemas.Problem:
    """
    Helper function to process a single problem and ensure location is properly formatted.
    Converts PostGIS geometry to coordinate string format.
    """
    if problem.location and hasattr(problem.location, 'data'):
        try:
            from geoalchemy2.shape import to_shape
            point = to_shape(problem.location)
            # Create a temporary dict to pass to Pydantic
            problem_dict = {
                **{c.name: getattr(problem, c.name) for c in problem.__table__.columns},
                'location': f"{point.y:.6f}, {point.x:.6f}",
                'latitude': point.y,
                'longitude': point.x,
                'submitted_by': problem.submitted_by,
                'media_files': problem.media_files,
                'feedback': problem.feedback,
                'assigned_to': problem.assigned_to
            }
            return schemas.Problem(**problem_dict)
        except Exception as e:
            logger.warning(f"Failed to extract coordinates from geometry for problem {problem.id}: {e}")
            return problem
    else:
        return problem