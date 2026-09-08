# Local Minikube DevOps Lab

This folder contains the PowerShell helpers used to create, start, inspect, and stop the local Minikube + Argo CD lab for the FastAPI demo.

Run the scripts from the repository root with a PowerShell session:

```powershell
cd C:\python_projects\fastapi-demo\fastapi-demo
```

## Prerequisites

Make sure the following tools are installed and available in PATH:

- Docker Desktop
- Minikube
- kubectl
- Helm
- PowerShell 5.1 or PowerShell 7+

Check them before starting the lab:

```powershell
docker --version
minikube version
kubectl version --client
helm version
```

Docker Desktop must be running before Minikube starts with the Docker driver.

## PowerShell execution policy

If execution is blocked, allow scripts only for the current shell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

## Quick start

```powershell
.\scripts\setup-devops-lab.ps1
.\scripts\status-devops-lab.ps1
.\scripts\open-argocd.ps1
```

## Script details

### 1. Setup the lab

```powershell
.\scripts\setup-devops-lab.ps1
```

The setup script now:

- validates Minikube and kubectl are available
- starts the target Minikube profile
- configures the kubectl context
- waits for all nodes to become ready
- enables Minikube ingress when not skipped
- creates `argocd` and `fastapi-demo` namespaces
- installs Argo CD into the `argocd` namespace
- waits for Argo CD and metrics-server to become available

Optional settings:

```powershell
.\scripts\setup-devops-lab.ps1 -Profile minikube -Driver docker -CpuCount 4 -MemorySize 8192
.\scripts\setup-devops-lab.ps1 -Profile minikube -SkipIngress
```

The `-ClusterName` alias is also accepted for compatibility with the older README examples.

### 2. Start an existing profile

```powershell
.\scripts\start-devops-lab.ps1
.\scripts\start-devops-lab.ps1 -Profile minikube
```

This script starts the existing Minikube instance if needed, sets the kube context, and waits for cluster readiness.

### 3. View lab status

```powershell
.\scripts\status-devops-lab.ps1
.\scripts\status-devops-lab.ps1 -Profile minikube
```

This script prints:

- Minikube state
- cluster nodes
- Argo CD pods
- FastAPI workloads
- Helm releases in `monitoring`
- HPA state

### 4. Open Argo CD

```powershell
.\scripts\open-argocd.ps1
.\scripts\open-argocd.ps1 -LocalPort 9090
```

The script validates that the Argo CD service is available, reads the admin password, and creates a local `kubectl port-forward` to `https://localhost:<port>`.

### 5. Stop the lab

```powershell
.\scripts\stop-devops-lab.ps1
```

This stops Minikube without deleting the cluster data, namespaces, or Helm releases.

### 6. Close forwarded ports

```powershell
.\scripts\close-devops-lab.ps1
```

This shuts down any recorded `kubectl port-forward` processes created by `open-devops-lab.ps1`.

### 7. Install or repair metrics-server

```powershell
.\scripts\install-metrics-server.ps1
.\scripts\install-metrics-server.ps1 -ClusterName minikube
```

This script enables the Minikube metrics-server addon when possible and verifies the `metrics-server` deployment in `kube-system`.

## Script summary

| Script | Purpose |
| --- | --- |
| `setup-devops-lab.ps1` | Start Minikube, create namespaces, install Argo CD, and verify the lab is ready |
| `start-devops-lab.ps1` | Start an existing cluster profile |
| `status-devops-lab.ps1` | Show cluster and application health |
| `open-devops-lab.ps1` | Open the local DevOps dashboards and read admin secrets |
| `open-argocd.ps1` | Open the Argo CD UI directly |
| `close-devops-lab.ps1` | Stop any recorded port-forward processes |
| `stop-devops-lab.ps1` | Stop Minikube without deleting state |
| `install-metrics-server.ps1` | Install or verify metrics-server |
| `generate_ci_report.py` | Generate CI status report data for the devops flow |

## Common troubleshooting

Check the current cluster context:

```powershell
kubectl config current-context
kubectl config get-contexts
```

If the lab is not ready:

```powershell
kubectl get nodes
kubectl get pods -n argocd
kubectl get pods -n fastapi-demo
kubectl get deployment metrics-server -n kube-system
```

If Argo CD is not ready:

```powershell
kubectl get pods -n argocd
kubectl describe pods -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
```

If metrics are not available:

```powershell
kubectl logs -f deployment/metrics-server -n kube-system
.\scripts\install-metrics-server.ps1
```

## Notes

- The script folder was updated to remove invalid PowerShell null-check syntax that caused parser errors.
- Most scripts accept either `-Profile` or the historical `-ClusterName` alias for compatibility.
- Keep the Argo CD password private and rotate it after first login.
