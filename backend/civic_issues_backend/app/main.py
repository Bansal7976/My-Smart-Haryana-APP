from fastapi import FastAPI, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from .database import engine, Base, get_db
from .routers import auth, users, admin, worker, super_admin, chatbot, notifications, analytics
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from . import scheduler
from .seed_admins import seed_admins
from .seed_departments import seed_departments
from starlette.middleware.base import BaseHTTPMiddleware
import time
import logging
from .config import settings

logger = logging.getLogger(__name__)

job_scheduler = AsyncIOScheduler()

app = FastAPI(
    title="Smart Haryana API",
    version="2.0.0",
    description="Backend for the Smart Haryana Civic Issues Reporting Platform with AI-Powered Multi-Agent System.",
    lifespan=None,  # We will manage startup/shutdown manually
    docs_url="/docs" if __import__('os').getenv("ENVIRONMENT", "development") == "development" else None,
    redoc_url="/redoc" if __import__('os').getenv("ENVIRONMENT", "development") == "development" else None
)

# Serve static files (uploaded images) from the 'uploads' directory
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# --- 🔒 SECURE CORS MIDDLEWARE (Must be BEFORE other middlewares) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods including OPTIONS for CORS
    allow_headers=["*"],  # Allow all headers
    max_age=600,
)

# --- 🔒 SECURITY HEADERS MIDDLEWARE ---
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        # Security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(self), camera=(self)"
        # Remove server header
        if "server" in response.headers:
            del response.headers["server"]
        return response

app.add_middleware(SecurityHeadersMiddleware)

# --- ⚙️ STARTUP EVENTS ---
@app.on_event("startup")
async def on_startup():
    """
    Runs when the application starts up.
    """
    # Create database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Seed departments and admin accounts (only inserts if they don't exist)
    try:
        async for db in get_db():
            await seed_departments(db)
            await seed_admins(db)
            break
    except Exception as e:
        logger.warning(f"Seeding skipped: {str(e)}")
    
    # Initialize Firebase for push notifications (optional)
    try:
        from .services.push_notifications import initialize_firebase
        initialize_firebase()
    except Exception as e:
        logger.warning(f"Firebase initialization skipped: {str(e)}")
    
    # Start scheduled jobs
    job_scheduler.add_job(scheduler.reset_daily_task_counts, "cron", hour=0, minute=0)
    job_scheduler.add_job(scheduler.run_auto_assignment_job, "interval", minutes=1)
    job_scheduler.start()
    
    logger.info("🚀 Smart Haryana API started successfully!")

# --- ⚙️ SHUTDOWN EVENTS ---
@app.on_event("shutdown")
async def on_shutdown():
    """
    Runs when the application shuts down.
    """
    job_scheduler.shutdown()

# --- 🧩 ROUTERS ---
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(worker.router)
app.include_router(admin.router)
app.include_router(super_admin.router)
app.include_router(chatbot.router)
app.include_router(notifications.router)
app.include_router(analytics.router)

# --- 🌐 ROOT ROUTE ---
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Welcome to Smart Haryana API!",
        "version": "2.0.0",
        "features": [
            "AI-Powered Multi-Agent Chatbot",
            "Real-time Issue Tracking",
            "Geospatial Analytics",
            "Auto-Assignment System"
        ]
    }

# --- 🏥 HEALTH CHECK ENDPOINT ---
@app.get("/health", tags=["Health"])
async def health_check(db: AsyncSession = Depends(get_db)):
    """
    Health check endpoint for monitoring and load balancers.
    Checks database connectivity and returns system status.
    """
    try:
        # Test database connection
        from sqlalchemy import text
        await db.execute(text("SELECT 1"))
        
        return {
            "status": "healthy",
            "version": "2.0.0",
            "database": "connected",
            "services": {
                "auto_assignment": "active",
                "chatbot": "active",
                "voice_to_text": "active",
                "ai_image_detection": "active"
            }
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        from fastapi import status as http_status
        return JSONResponse(
            status_code=http_status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "error": "Database connection failed"
            }
        )
