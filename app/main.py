from fastapi import FastAPI
from app.routes import router as task_router
from app.config import get_settings

# to create Virtual env run in terminal "python -m venv .venv" 
# and then to activate it run "source ..\.venv\Scripts\Activate.ps1" in terminal
# to install packages that are in requirements.txt run "pip install -r requirements.txt" in terminal
# start the server run " python -m uvicorn app.main:app --reload" in terminal


#Load settings from config.py
settings = get_settings()

app = FastAPI(
    title =settings.app_name,
    description =settings.app_description,
    version =settings.app_version,
    debug =settings.debug,
)

# register the router from routes.py
app.include_router(task_router)

@app.get(
  "/",
   tags =["General"],
   summary="Application root endpoint",
)
async def root() -> dict[str,str]:
    return {
        "message": f"Welcome to the {settings.app_name} API",
        "environment": settings.environment,
        "documetation": "/docs",
        "health" : "/health",
    }

@app.get(
    "/health",
    tags = ["Health"],
    summary = "check application health",
)
async def health_check() -> dict[str,str]:
    return{
        "status": "healthy",
        "service" : settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
    }