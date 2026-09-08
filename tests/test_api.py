def test_root_endpoint(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["documentation"] == "/docs"


def test_health_endpoint(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_task_crud_flow(client):
    create_response = client.post(
        "/tasks/",
        json={"title": "Write tests", "description": "Cover the API"},
    )
    task_id = create_response.json()["id"]

    assert create_response.status_code == 200
    assert create_response.json()["completed"] is False

    get_response = client.get(f"/tasks/{task_id}")
    assert get_response.status_code == 200
    assert get_response.json()["title"] == "Write tests"

    list_response = client.get("/tasks/")
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1

    update_response = client.put(
        f"/tasks/{task_id}",
        json={
            "title": "Write better tests",
            "description": "Cover every CRUD operation",
            "completed": True,
        },
    )
    assert update_response.status_code == 200
    assert update_response.json()["title"] == "Write better tests"
    assert update_response.json()["description"] == "Cover every CRUD operation"
    assert update_response.json()["completed"] is True

    delete_response = client.delete(f"/tasks/{task_id}")
    assert delete_response.status_code == 200
    assert client.get(f"/tasks/{task_id}").status_code == 404


def test_task_validation(client):
    response = client.post("/tasks/", json={"title": "x"})

    assert response.status_code == 422


def test_missing_task_returns_not_found(client):
    response = client.get("/tasks/999")

    assert response.status_code == 404
    assert response.json()["detail"] == "Task with ID 999 not found"

    update_response = client.put("/tasks/999", json={"completed": True})
    delete_response = client.delete("/tasks/999")
    assert update_response.status_code == 404
    assert delete_response.status_code == 404


def test_middleware_adds_response_headers(client):
    response = client.get("/health", headers={"X-Correlation-ID": "test-correlation"})

    assert response.headers["X-Correlation-ID"] == "test-correlation"
    assert "X-Processing-Time" in response.headers