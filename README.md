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
Docker push status, Helm validation status, image link, and workflow details.

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

## Helm deployment

The full Helm runbook is in [helm_infra/README.md](helm_infra/README.md).
The chart is in `helm_infra/fastapi-demo`. Install it into the `fastapi-demo`
namespace with Helm creating the namespace before the release:

```powershell
helm upgrade --install fastapi-demo .\helm_infra\fastapi-demo `
	--namespace fastapi-demo `
	--create-namespace `
	--wait
```

For a local Minikube deployment, the chart defaults to the values in
`helm_infra/fastapi-demo/values.yaml`. Override values without editing the
chart, for example:

```powershell
helm upgrade --install fastapi-demo .\helm_infra\fastapi-demo `
	--namespace fastapi-demo `
	--create-namespace `
	--set image.tag=latest
```

The namespace template is optional and disabled by default. `--create-namespace`
creates the namespace before Helm installs the namespaced resources. Use
`--wait` to wait for workloads to become ready.

## DevOps Lab Setup with Kubernetes & ArgoCD

This project includes a complete DevOps lab setup for deploying on Kubernetes with ArgoCD (GitOps).

### Quick Start - Setup DevOps Lab

Run the automated setup script to initialize everything:

```powershell
.\scripts\setup-devops-lab.ps1
```

This script will:
- ✅ Verify Docker, kubectl, and Minikube are installed
- ✅ Start Minikube cluster
- ✅ Create required namespaces (`argocd` and `fastapi-demo`)
- ✅ Install ArgoCD
- ✅ Install Kubernetes metrics-server (required for HPA autoscaling)
- ✅ Wait for all components to be ready

**Optional parameters:**

```powershell
# Custom cluster name, driver, CPU, and memory
.\scripts\setup-devops-lab.ps1 -ClusterName my-cluster -Driver docker -CpuCount 6 -MemorySize 16384

# Skip Ingress addon setup
.\scripts\setup-devops-lab.ps1 -SkipIngress
```

### Individual Setup Scripts

If you need to run components separately:

```powershell
# Start Minikube and install ArgoCD
.\scripts\setup-devops-lab.ps1 -SkipIngress

# Install or verify metrics-server (for Horizontal Pod Autoscaler)
.\scripts\install-metrics-server.ps1

# Access all dashboards (Argo CD, Grafana, Prometheus)
.\scripts\open-devops-lab.ps1

# Check cluster status
.\scripts\status-devops-lab.ps1

# Stop the cluster
.\scripts\stop-devops-lab.ps1

# Start the cluster again
.\scripts\start-devops-lab.ps1
```

### Deploying with ArgoCD (GitOps)

Once the DevOps lab is set up, the application is deployed via ArgoCD from the `fastapi-demo-gitops` repository:

1. Navigate to the GitOps repository:
   ```powershell
   cd ../fastapi-demo-gitops
   ```

2. Apply the ArgoCD Application:
   ```powershell
   kubectl apply -f argocd/application.yaml
   ```

3. Verify deployment:
   ```powershell
   kubectl get application -n argocd
   kubectl get pods -n fastapi-demo
   ```

4. Access the application:
   ```powershell
   # Get the service details
   kubectl get svc -n fastapi-demo
   
   # Access via NodePort (e.g., http://<node-ip>:30000)
   ```

See [../fastapi-demo-gitops/README.md](../fastapi-demo-gitops/README.md) for complete ArgoCD and GitOps documentation.

### Monitoring and Debugging

```powershell
# View cluster nodes and resource usage
kubectl top nodes
kubectl top pods -n fastapi-demo

# Check HPA status
kubectl get hpa -n fastapi-demo
kubectl describe hpa fastapi-demo -n fastapi-demo

# View application logs
kubectl logs -f deployment/fastapi-demo -n fastapi-demo

# Check ArgoCD application status
argocd app list
argocd app describe fastapi-demo

# Access ArgoCD UI (opens browser automatically)
.\scripts\open-argocd.ps1
```

### Troubleshooting

**Metrics Server Not Ready:**
If HPA shows "unable to get metrics" errors, the metrics-server may still be initializing. Wait a few minutes for metrics to be collected:

```powershell
# Check metrics-server logs
kubectl logs -f deployment/metrics-server -n kube-system

# Re-run the metrics server installation
.\scripts\install-metrics-server.ps1
```

**Application Not Syncing:**
ArgoCD syncs every 3 minutes by default. To force an immediate sync:

```powershell
argocd app sync fastapi-demo
```

**Cluster Resources Low:**
Increase Minikube resources:

```powershell
minikube stop
minikube start --cpus=6 --memory=16384
```