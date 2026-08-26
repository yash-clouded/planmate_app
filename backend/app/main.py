"""
PlanMate Backend — FastAPI application entry point.

Run with: uvicorn app.main:app --reload --port 8000
"""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers.webhooks import router as webhook_router
from app.services.redis_store import get_redis
from app.services.stream_service import create_bot_user

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Ensure uploads directory exists
UPLOADS_DIR = Path("uploads")
UPLOADS_DIR.mkdir(exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown lifecycle."""
    logger.info("PlanMate backend starting up...")
    try:
        r = await get_redis()
        await r.ping()
        logger.info("Redis connected")
    except Exception as e:
        logger.error(f"Redis connection failed: {e}")

    try:
        await create_bot_user()
        logger.info("Stream bot user ensured")
    except Exception as e:
        logger.warning(f"Stream bot user creation failed: {e}")

    logger.info("PlanMate backend ready ✓")
    yield
    logger.info("PlanMate backend shutting down...")


app = FastAPI(
    title="PlanMate Backend",
    description="AI agent backend for group chat planning",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount uploads directory for serving uploaded images
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(webhook_router)


@app.get("/")
async def root():
    return {
        "app": "PlanMate Backend",
        "version": "0.1.0",
        "status": "running",
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    redis_ok = False
    try:
        r = await get_redis()
        await r.ping()
        redis_ok = True
    except Exception:
        pass

    return {
        "status": "healthy" if redis_ok else "degraded",
        "redis": "connected" if redis_ok else "disconnected",
        "stream_api_key_set": bool(settings.stream_api_key),
        "nvidia_api_key_set": bool(settings.nvidia_api_key),
    }
