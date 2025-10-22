from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from .database import engine, Base
from .routers import auth, users, admin, worker, super_admin, chatbot
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from . import scheduler
from starlette.middleware.base import BaseHTTPMiddleware
import time
from .config import settings

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
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    job_scheduler.add_job(scheduler.reset_daily_task_counts, "cron", hour=0, minute=0)
    job_scheduler.add_job(scheduler.run_auto_assignment_job, "interval", minutes=1)
    job_scheduler.start()

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
