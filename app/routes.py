from fastapi import APIRouter, HTTPException
from app.models import TaskCreate, TaskUpdate, TaskResponse

# client => router => In memory data store => response to client

router = APIRouter(
    prefix="/tasks",
    tags=["Tasks"],
)

tasks = []
task_id_counter = 1

@router.post(
    "/",
    response_model=TaskResponse,
    summary="Create a new task",
)
async def create_task(task: TaskCreate) -> TaskResponse:
    global task_id_counter
    new_task = TaskResponse(
        id=task_id_counter,
        title=task.title,
        description=task.description,
        completed=False,
    )
    tasks.append(new_task)
    task_id_counter += 1
    return new_task

@router.get(
    "/",
    response_model=list[TaskResponse],
    summary="Get all tasks",
)
async def get_tasks() -> list[TaskResponse]:
    return tasks

@router.get(
    "/{task_id}",
    response_model=TaskResponse,
    summary="Get a task by ID",
)
async def get_task(task_id: int) -> TaskResponse:
    for task in tasks:
        if task.id == task_id:
            return task
    raise HttpException(status_code=404, detail=f"Task with ID {task_id} not found")

@router.put(
    "/{task_id}",
    response_model=TaskResponse,
    summary="Update a task by ID",
)
async def update_task(task_id: int, task_update: TaskUpdate) -> TaskResponse:
    for task in tasks:
        if task.id == task_id:
            if task_update.title is not None:
                task.title = task_update.title
            if task_update.description is not None:
                task.description = task_update.description
            if task_update.completed is not None:
                task.completed = task_update.completed
            return task
    raise HttpException(status_code=404, detail=f"Task with ID {task_id} not found")

@router.delete(
    "/{task_id}",
    summary="Delete a task by ID",
)
async def delete_task(task_id: int) -> dict[str, str]:
    for task in tasks:
        if task.id == task_id:
            tasks.remove(task)
            return {"message": "Task deleted successfully"}
    raise HttpException(status_code=404, detail=f"Task with ID {task_id} not found")

