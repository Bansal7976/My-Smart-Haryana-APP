from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from .models import RoleEnum, ProblemStatusEnum, MediaTypeEnum
import re

# --- Token Schemas ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- Department Schemas ---
class DepartmentBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    
    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        # Allow only letters, spaces, and hyphens for department names
        if not re.match(r'^[a-zA-Z\s\-]+$', v):
            raise ValueError('Department name can only contain letters, spaces, and hyphens')
        return v.strip()

class DepartmentCreate(DepartmentBase):
    pass
class Department(DepartmentBase):
    id: int
    class Config:
        from_attributes = True

# --- User & Worker Schemas ---
class UserBase(BaseModel):
    full_name: str = Field(..., min_length=3, max_length=100)
    email: EmailStr
    district: str = Field(..., min_length=2, max_length=50)
    pincode: str = Field(..., min_length=6, max_length=6)
    
    @field_validator('full_name')
    @classmethod
    def validate_full_name(cls, v: str) -> str:
        # Allow only letters, spaces, and basic punctuation
        if not re.match(r'^[a-zA-Z\s\.\-]+$', v):
            raise ValueError('Name can only contain letters, spaces, dots, and hyphens')
        return v.strip()
    
    @field_validator('pincode')
    @classmethod
    def validate_pincode(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError('Pincode must contain only digits')
        return v

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class User(UserBase):
    id: int
    role: RoleEnum
    is_active: bool
    civic_points: int = 0
    issues_reported: int = 0
    issues_verified: int = 0
    created_at: datetime
    class Config:
        from_attributes = True

class WorkerProfileCreate(BaseModel):
    user_id: int
    department_id: int

class AdminCreateWorker(UserBase):
    password: str = Field(..., min_length=8)
    department_id: int
    
class SuperAdminCreateAdmin(UserBase):
    password: str = Field(..., min_length=8)

class UserChangePassword(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8)

class WorkerWithProfile(BaseModel):
    id: int  # Worker profile ID
    user: User
    department: Department
    daily_task_count: int = 0
    
    class Config:
        from_attributes = True

# --- Media Schemas ---
class MediaBase(BaseModel):
    file_url: str
    media_type: MediaTypeEnum
class Media(MediaBase):
    id: int
    problem_id: int
    class Config:
        from_attributes = True

# --- Feedback Schemas ---
class FeedbackBase(BaseModel):
    comment: str = Field(..., min_length=1, max_length=1000)
    rating: int = Field(..., ge=1, le=5)
    
    @field_validator('comment')
    @classmethod
    def validate_comment(cls, v: str) -> str:
        v = v.strip()
        # Prevent script injection
        dangerous_patterns = ['<script', 'javascript:', 'onerror=', 'onclick=']
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError('Invalid characters in feedback comment')
        return v
class FeedbackCreate(FeedbackBase):
    pass
class Feedback(FeedbackBase):
    id: int
    problem_id: int
    user_id: int
    sentiment: Optional[str] = None
    sentiment_confidence: Optional[float] = None
    class Config:
        from_attributes = True

# --- Problem Schemas ---
class ProblemBase(BaseModel):
    title: str = Field(..., min_length=5, max_length=200)
    description: Optional[str] = Field(None, max_length=2000)
    problem_type: str = Field(..., min_length=2, max_length=50)
    
    @field_validator('title', 'description')
    @classmethod
    def validate_text_fields(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Remove potentially dangerous characters
        v = v.strip()
        # Prevent script injection
        dangerous_patterns = ['<script', 'javascript:', 'onerror=', 'onclick=']
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError('Invalid characters in text field')
        return v

class ProblemCreate(ProblemBase):
    latitude: float
    longitude: float
    district: str

class UserInProblemResponse(BaseModel):
    id: int
    full_name: str
    class Config:
        from_attributes = True

class WorkerInProblemResponse(BaseModel):
    user: UserInProblemResponse
    department: Department
    class Config:
        from_attributes = True

class Problem(ProblemBase):
    id: int
    status: ProblemStatusEnum
    priority: float
    district: str
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    submitted_by: UserInProblemResponse
    media_files: List[Media] = []
    feedback: List[Feedback] = []
    assigned_to: Optional[WorkerInProblemResponse] = None
    
    @field_validator('location', mode='before')
    @classmethod
    def extract_location(cls, v: Any) -> Optional[str]:
        """Convert PostGIS geometry to string coordinates"""
        if v is None:
            return None
        
        # If it's already a string, return it
        if isinstance(v, str):
            return v
        
        # If it's a PostGIS WKBElement, convert it
        try:
            from geoalchemy2.shape import to_shape
            point = to_shape(v)
            lat = point.y  # latitude
            lng = point.x  # longitude
            return f"{lat:.6f}, {lng:.6f}"
        except Exception:
            return None
    
    @field_validator('latitude', mode='before')
    @classmethod
    def extract_latitude(cls, v: Any, info) -> Optional[float]:
        """Extract latitude from PostGIS geometry if needed"""
        # Check if location field is a geometry object
        location = info.data.get('location') if hasattr(info, 'data') else None
        
        # If latitude is already set, return it
        if v is not None:
            return v
        
        # Try to extract from location geometry
        if location and not isinstance(location, str):
            try:
                from geoalchemy2.shape import to_shape
                point = to_shape(location)
                return point.y
            except Exception:
                pass
        
        return None
    
    @field_validator('longitude', mode='before')
    @classmethod
    def extract_longitude(cls, v: Any, info) -> Optional[float]:
        """Extract longitude from PostGIS geometry if needed"""
        # Check if location field is a geometry object
        location = info.data.get('location') if hasattr(info, 'data') else None
        
        # If longitude is already set, return it
        if v is not None:
            return v
        
        # Try to extract from location geometry
        if location and not isinstance(location, str):
            try:
                from geoalchemy2.shape import to_shape
                point = to_shape(location)
                return point.x
            except Exception:
                pass
        
        return None
    
    class Config:
        from_attributes = True

# --- Dashboard Schemas ---
class UserDashboardStats(BaseModel):
    scope: str
    total_problems_resolved: int
    problems_resolved_last_30_days: int

class ClientDistrictStats(BaseModel):
    district_name: str
    total_problems: int
    status_breakdown: Dict[str, int]
    type_breakdown: Dict[str, int]

class WorkerSelfStats(BaseModel):
    worker_name: str
    tasks_completed: int
    average_rating: Optional[float] = None


class AdminStats(BaseModel):
    total_problems: int
    pending_problems: int
    assigned_problems: int
    completed_problems: int
    verified_problems: int
    average_resolution_time_hours: Optional[float] = None
    total_workers: int = 0

class HeatmapPoint(BaseModel):
    latitude: float
    longitude: float
    intensity: int = 1

class DepartmentActivity(BaseModel):
    department_name: str
    total_assigned: int

class WorkerPerformanceStats(BaseModel):
    worker_id: int
    worker_name: str
    department_name: str
    tasks_assigned: int
    tasks_completed: int
    average_rating: Optional[float] = None

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    session_id: Optional[str] = Field(None, max_length=100)
    preferred_language: Optional[str] = Field(None, description="Preferred language code (en, hi, pa)")
    
    @field_validator('message')
    @classmethod
    def validate_message(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError('Message cannot be empty')
        # Prevent script injection in chat
        dangerous_patterns = ['<script', 'javascript:', 'onerror=', 'onclick=']
        v_lower = v.lower()
        for pattern in dangerous_patterns:
            if pattern in v_lower:
                raise ValueError('Invalid characters in message')
        return v
    
    @field_validator('preferred_language')
    @classmethod
    def validate_language(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        valid_languages = ['en', 'hi', 'pa']
        if v not in valid_languages:
            raise ValueError(f'Language must be one of: {valid_languages}')
        return v

class ChatResponse(BaseModel):
    response: str
    session_id: str
    agent_used: str
    metadata: Optional[Dict[str, Any]] = {}
    
class ChatHistoryItem(BaseModel):
    role: str
    message: str
    agent_type: Optional[str] = None
    timestamp: str
    
class ChatSessionInfo(BaseModel):
    session_id: str
    started_at: str
    last_message_at: str
    message_count: int

# Voice-to-Text Schemas
class VoiceToTextResponse(BaseModel):
    text: str
    language: str
    confidence: float = 1.0
    
class SupportedLanguagesResponse(BaseModel):
    languages: Dict[str, str]

class WorkerWithProfile(BaseModel):
    id: int
    user: User
    department: Department
    daily_task_count: int
    class Config:
        from_attributes = True

class DistrictStats(BaseModel):
    district_name: str
    total_problems: int
    pending_problems: int
    assigned_problems: int
    completed_problems: int
    verified_problems: int
    total_workers: int
    resolution_rate: float

class SuperAdminOverview(BaseModel):
    total_problems: int
    pending_problems: int
    assigned_problems: int
    completed_problems: int
    verified_problems: int
    rejected_problems: int
    active_districts: int
    total_clients: int
    total_workers: int
    total_admins: int
    resolution_rate: float