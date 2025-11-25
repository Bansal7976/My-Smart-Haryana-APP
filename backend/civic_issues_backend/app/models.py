# in app/models.py
import enum
from sqlalchemy import (
    Column, Integer, String, Boolean, ForeignKey, DateTime, Enum, Float
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from geoalchemy2 import Geometry
from .database import Base

# --- Enums ---
class RoleEnum(str, enum.Enum):
    CLIENT = "client"
    ADMIN = "admin"
    WORKER = "worker"
    SUPER_ADMIN = "super_admin"

class ProblemStatusEnum(str, enum.Enum):
    PENDING = "pending"
    ASSIGNED = "assigned"
    COMPLETED = "completed"
    VERIFIED = "verified"

class MediaTypeEnum(str, enum.Enum):
    PHOTO_INITIAL = "photo_initial"
    PHOTO_PROOF = "photo_proof"
    AUDIO = "audio"
    SIGNATURE = "signature"

# --- Tables ---
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(Enum(RoleEnum), default=RoleEnum.CLIENT, nullable=False)
    district = Column(String, nullable=True)
    pincode = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=True)
    fcm_token = Column(String, nullable=True)  # Firebase Cloud Messaging token for push notifications
    
    problems_submitted = relationship("Problem", back_populates="submitted_by")
    worker_profile = relationship("WorkerProfile", uselist=False, back_populates="user")
    feedback_given = relationship("Feedback", back_populates="user")

class Department(Base):
    __tablename__ = "departments"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    workers = relationship("WorkerProfile", back_populates="department")

class WorkerProfile(Base):
    __tablename__ = "worker_profiles"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=False)
    daily_task_count = Column(Integer, default=0)
    
    user = relationship("User", back_populates="worker_profile")
    department = relationship("Department", back_populates="workers")
    assigned_problems = relationship("Problem", back_populates="assigned_to")

class Problem(Base):
    __tablename__ = "problems"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    problem_type = Column(String, nullable=False)
    district = Column(String, nullable=False, index=True)
    location = Column(Geometry(geometry_type='POINT', srid=4326), nullable=False)
    priority = Column(Float, default=0.0)
    status = Column(Enum(ProblemStatusEnum), default=ProblemStatusEnum.PENDING)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    assigned_worker_id = Column(Integer, ForeignKey("worker_profiles.id"), nullable=True)
    
    submitted_by = relationship("User", back_populates="problems_submitted")
    assigned_to = relationship("WorkerProfile", back_populates="assigned_problems")
    media_files = relationship("Media", back_populates="problem")
    feedback = relationship("Feedback", back_populates="problem")

class Media(Base):
    __tablename__ = "media"
    id = Column(Integer, primary_key=True, index=True)
    problem_id = Column(Integer, ForeignKey("problems.id"))
    file_url = Column(String, nullable=False)
    media_type = Column(Enum(MediaTypeEnum), nullable=False)
    
    problem = relationship("Problem", back_populates="media_files")

class Feedback(Base):
    __tablename__ = "feedback"
    id = Column(Integer, primary_key=True, index=True)
    problem_id = Column(Integer, ForeignKey("problems.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    comment = Column(String, nullable=False)
    rating = Column(Integer)
    sentiment = Column(String, nullable=True)
    
    problem = relationship("Problem", back_populates="feedback")
    user = relationship("User", back_populates="feedback_given")

class ChatHistory(Base):
    __tablename__ = "chat_history"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String, nullable=False, index=True)
    role = Column(String, nullable=False)  # 'user' or 'assistant'
    message = Column(String, nullable=False)
    agent_type = Column(String, nullable=True)  # 'coordinator', 'db_agent', 'web_search', 'analytics'
    metadata_json = Column(String, nullable=True)  # JSON string for additional data
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    user = relationship("User")