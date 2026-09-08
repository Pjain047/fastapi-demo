from fastapi import APIRouter, HTTPException, Request
from app.models import TaskCreate, TaskResponse, TaskUpdate
from app.logger import get_logger
from app import data

# Client -> router -> in-memory data store -> response to client.

logger = get_logger(__name__)

router = APIRouter(
    prefix="/tasks",
    tags=["Tasks"],
)



@router.post(
    "/",
    response_model=TaskResponse,
    summary="Create a new task",
)
async def create_task(task: TaskCreate) -> TaskResponse:
    logger.info(
        "Creating a new task",
        extra={"task_title": task.title},
    )

    new_task = TaskResponse(
        id=data.task_id_counter,
        title=task.title,
        description=task.description,
        completed=False,
    )
    data.tasks.append(new_task)
    data.task_id_counter += 1
    return new_task

@router.get(
    "/",
    response_model=list[TaskResponse],
    summary="Get all tasks",
)
async def get_tasks() -> list[TaskResponse]:
    logger.info("Fetching all tasks", extra={"task_count": len(data.tasks)})
    return data.tasks

@router.get(
    "/{task_id}",
    response_model=TaskResponse,
    summary="Get a task by ID",
)
async def get_task(request: Request, task_id: int) -> TaskResponse:
    for task in data.tasks:
        if task.id == task_id:
            logger.info("Fetching task", extra={
                "task_id": task_id,
                "correlation_id": request.headers.get("X-Correlation-ID", "N/A"),
            })
            return task
    logger.warning("Task not found", extra={"task_id": task_id})
    raise HTTPException(status_code=404, detail=f"Task with ID {task_id} not found")

@router.put(
    "/{task_id}",
    response_model=TaskResponse,
    summary="Update a task by ID",
)
async def update_task(task_id: int, task_update: TaskUpdate) -> TaskResponse:
    for task in data.tasks:
        if task.id == task_id:
            if task_update.title is not None:
                task.title = task_update.title
            if task_update.description is not None:
                task.description = task_update.description
            if task_update.completed is not None:
                task.completed = task_update.completed
            return task
    logger.warning("Task not found", extra={"task_id": task_id})
    raise HTTPException(status_code=404, detail=f"Task with ID {task_id} not found")

@router.delete(
    "/{task_id}",
    summary="Delete a task by ID",
)
async def delete_task(task_id: int) -> dict[str, str]:
    for task in data.tasks:
        if task.id == task_id:
            data.tasks.remove(task)
            logger.info("Task deleted", extra={"task_id": task_id})
            return {"message": "Task deleted successfully"}
    logger.warning("Task not found", extra={"task_id": task_id})
    raise HTTPException(status_code=404, detail=f"Task with ID {task_id} not found")

