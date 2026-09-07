from pydantic import BaseModel, Field
from typing import Optional

# create models with uts fields and validation using pydantic

class TaskCreate(BaseModel):
    title: str = Field(
        min_length=3,
        max_length=200,
        description="The title of the task",
    )

    description: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="The description of the task",
    )

class TaskUpdate(BaseModel):
    title: Optional[str] = Field(
        default=None,
        min_length=3,
        max_length=200,
        description="The title of the task",
    )

    description: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="The description of the task",
    )
    completed: Optional[bool] = None

class TaskResponse(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    completed: bool
