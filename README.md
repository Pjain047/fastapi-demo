# FastAPI Demo

A small task-management API for practicing FastAPI, testing, Docker, and CI/CD.

## Run locally

```powershell
python -m venv .venv
..\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt -r requirements-dev.txt
python -m uvicorn app.main:app --reload
```

The API is available at `http://127.0.0.1:8000`, with interactive documentation at
`http://127.0.0.1:8000/docs`.

## Test and coverage

```powershell
python -m pytest --cov=app --cov-report=term-missing --cov-report=xml:coverage.xml
```

The generated `coverage.xml` is consumed by SonarQube in CI and is ignored by Git.

## Docker

```powershell
docker build -t fastapi-demo .
docker run --publish 8000:8000 fastapi-demo
```

The image runs as a non-root user and includes a container health check.

## GitHub Actions

The workflow in `.github/workflows/ci.yml` installs dependencies, runs tests with
coverage, uploads the coverage artifact, conditionally runs SonarQube when
coverage, runs SonarCloud analysis, and publishes the Docker image to Docker Hub
on pushes to `main`.

Each workflow run also publishes a GitHub Actions summary and a downloadable
`ci-report` HTML artifact containing test totals, coverage, SonarCloud status,
Docker push status, image link, and workflow details.

Branch behavior:

- `main` pushes run tests, coverage, SonarCloud, reporting, and Docker Hub publishing.
- `bugfix/**` pushes run tests, coverage, SonarCloud, reporting, and Docker Hub publishing.
- `feature/**` pushes and pull requests run validation, coverage, SonarCloud, and reporting without Docker publishing.
- Merging a pull request into `main` creates a `main` push and runs the full pipeline, including Docker publishing.

Required GitHub repository secrets:

```text
DOCKER_USERNAME
DOCKER_TOKEN
SONAR_TOKEN
```

SonarCloud organization: `pjain047`