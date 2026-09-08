from app.models import TaskResponse


tasks = [
    TaskResponse(
        id=1,
        title="Learn FastAPI",
        description="Build REST API using FastAPI",
        completed=False,
    ),
    TaskResponse(
        id=2,
        title="Learn Docker",
        description="Create Docker images and run containers",
        completed=False,
    ),
    TaskResponse(
        id=3,
        title="Learn Kubernetes",
        description="Deploy applications on Kubernetes cluster",
        completed=False,
    ),
    TaskResponse(
        id=4,
        title="Learn CI/CD",
        description="Implement CI/CD pipelines using GitHub Actions",
        completed=False,
    ),
    TaskResponse(
        id=5,
        title="Learn Terraform",
        description="Provision infrastructure using Terraform",
        completed=False,
    ),
]

task_id_counter = len(tasks) + 1
