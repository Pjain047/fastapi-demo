from fastapi import FastAPI
# to create Virtual env run in terminal "python -m venv .venv" 
# and then to activate it run "source ..\.venv\Scripts\Activate.ps1" in terminal
# to install packages that are in requirements.txt run "pip install -r requirements.txt" in terminal
# start the server run " python -m uvicorn app.main:app --reload" in terminal

app = FastAPI(
    title ="Task Management API",
    description ="A Task managment api build to learn DevOps",
    version ="1.0.0",
)

@app.get(
  "/",
   tags =["General"],
   summary="Application root endpoint",
)
async def root() -> dict[str,str]:
    return {
        "message": "Welcome to the Task Managemnt API",
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
        "service" : "task-api",
        "version": "1.0.0",
    }