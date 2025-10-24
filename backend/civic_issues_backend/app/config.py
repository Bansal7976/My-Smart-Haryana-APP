from pydantic_settings import BaseSettings
from typing import List
from pydantic import field_validator, ValidationError
import sys

class Settings(BaseSettings):
    # Database Configuration
    DATABASE_URL: str
    
    # JWT & Security
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    
    # Worker & Task Settings
    MAX_DAILY_TASKS_PER_WORKER: int = 3
    PRIORITY_DENSITY_WEIGHT: float = 0.6
    PRIORITY_URGENCY_WEIGHT: float = 0.4
    
    # Multi-Agent Chatbot Configuration
    GOOGLE_API_KEY: str = ""  # For Gemini LLM (required for AI features)
    TAVILY_API_KEY: str = ""  # For web search (optional)
    PINECONE_API_KEY: str = ""  # For Pinecone vector database (optional, but recommended for RAG)
    CHATBOT_MODEL: str = "gemini-1.5-flash"  # Updated model (gemini-pro is deprecated)
    CHATBOT_TEMPERATURE: float = 0.7
    MAX_CHAT_HISTORY: int = 10
    
    # RAG Configuration
    EMBEDDING_MODEL: str = "models/embedding-001"  # Gemini embeddings
    PINECONE_INDEX_NAME: str = "smart-haryana"  # Pinecone index name
    CHUNK_SIZE: int = 1000
    CHUNK_OVERLAP: int = 200
    
    # CORS Settings
    ALLOWED_ORIGINS: str = "http://localhost:3000"
    
    # File Upload Settings
    MAX_FILE_SIZE_MB: int = 10
    ALLOWED_FILE_TYPES: str = "image/jpeg,image/png,image/jpg,image/webp"
    
    # GPS Verification Settings
    GPS_VERIFICATION_RADIUS_METERS: int = 100
    
    # Rate Limiting (Voice-to-Text and AI features)
    MAX_VOICE_TO_TEXT_PER_HOUR: int = 20  # Prevent abuse of speech API
    MAX_CHATBOT_MESSAGES_PER_MINUTE: int = 10
    
    # Environment
    ENVIRONMENT: str = "development"

    class Config:
        env_file = ".env"
    
    @field_validator('SECRET_KEY')
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError('SECRET_KEY must be at least 32 characters long for security')
        return v
    
    @field_validator('DATABASE_URL')
    @classmethod
    def validate_database_url(cls, v: str) -> str:
        if not v or not v.startswith('postgresql'):
            raise ValueError('DATABASE_URL must be a valid PostgreSQL connection string')
        return v
    
    @field_validator('GOOGLE_API_KEY')
    @classmethod
    def validate_google_api_key(cls, v: str) -> str:
        if not v or len(v) < 20:
            print("WARNING: GOOGLE_API_KEY not set or invalid. AI features will be disabled.")
        return v
        
    @property
    def allowed_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]
    
    @property
    def allowed_file_types_list(self) -> List[str]:
        return [ft.strip() for ft in self.ALLOWED_FILE_TYPES.split(",")]

# Load and validate settings
try:
    settings = Settings()
except ValidationError as e:
    print("❌ CONFIGURATION ERROR:")
    for error in e.errors():
        field = error['loc'][0]
        message = error['msg']
        print(f"  - {field}: {message}")
    print("\nPlease check your .env file and fix the above errors.")
    sys.exit(1)