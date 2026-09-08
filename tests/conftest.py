import pytest
from fastapi.testclient import TestClient

from app.data import data
from app.main import app


@pytest.fixture()
def client():
    original_tasks = list(data.tasks)
    original_task_id_counter = data.task_id_counter
    data.tasks.clear()
    data.task_id_counter = 1

    with TestClient(app) as test_client:
        yield test_client

    data.tasks[:] = original_tasks
    data.task_id_counter = original_task_id_counter