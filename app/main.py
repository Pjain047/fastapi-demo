from fastapi import FastAPI
from app.routes import router as task_router
from app.config import get_settings
from app.logger import configure_logging, get_logger
from app.middleware import request_logging_middleware

# To create a virtual environment, run "python -m venv .venv" in the terminal.
# and then to activate it run "source ..\.venv\Scripts\Activate.ps1" in terminal
# to install packages that are in requirements.txt run "pip install -r requirements.txt" in terminal
# To start the server, run "python -m uvicorn app.main:app --reload" in the terminal.

# Configure logging
configure_logging()
logger = get_logger(__name__)

# Load settings from config.py.
settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    description=settings.app_description,
    version=settings.app_version,
    debug=settings.debug,
)

# Add middleware for request logging
app.middleware("http")(request_logging_middleware)

# Register the router from routes.py.
app.include_router(task_router)


@app.get(
        "/",
        tags=["General"],
        summary="Application root endpoint",
)
async def root() -> dict[str, str]:
    return {
        "message": f"Welcome to the {settings.app_name} API",
        "environment": settings.environment,
        "documentation": "/docs",
        "health" : "/health",
    }

@app.get(
    "/health",
    tags=["Health"],
    summary="Check application health",
)
async def health_check() -> dict[str, str]:
    logger.info("Health check endpoint called")
    return {
        "status": "healthy",
        "service": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
    }