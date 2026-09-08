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
.\scripts\open-devops-lab.ps1
```

## Script details

### 1. Setup the lab

```powershell
.\scripts\setup-devops-lab.ps1
```

The setup script now:

- validates Minikube, kubectl, and Helm are available
- starts the target Minikube profile
- configures the kubectl context
- waits for all nodes to become ready
- enables Minikube ingress when not skipped
- creates `argocd` and `fastapi-demo` namespaces
- installs Argo CD into the `argocd` namespace
- installs metrics-server for HPA autoscaling
- installs monitoring stack (Prometheus & Grafana) unless skipped
- waits for all components to become available

Optional settings:

```powershell
.\scripts\setup-devops-lab.ps1 -Profile minikube -Driver docker -CpuCount 4 -MemorySize 8192
.\scripts\setup-devops-lab.ps1 -Profile minikube -SkipIngress
.\scripts\setup-devops-lab.ps1 -SkipMonitoring
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

### 4. Open DevOps Lab Dashboards (Argo CD, Grafana, Prometheus)

```powershell
.\scripts\open-devops-lab.ps1
```

This script sets up port-forwarding for all available dashboards:

- **Argo CD** at https://localhost:8080 (Username: admin, Password: from script output)
- **Grafana** at http://localhost:3000 (Username: admin, Password: admin) - if monitoring is installed
- **Prometheus** at http://localhost:9090 - if monitoring is installed

The script automatically opens your browser to all available services. To skip browser opening:

```powershell
.\scripts\open-devops-lab.ps1 -NoBrowser
```

The port-forward processes run in the background. Close them with:

```powershell
.\scripts\close-devops-lab.ps1
```

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
| `setup-devops-lab.ps1` | Start Minikube, create namespaces, install Argo CD, metrics-server, and monitoring (Prometheus & Grafana) |
| `start-devops-lab.ps1` | Start an existing cluster profile |
| `status-devops-lab.ps1` | Show cluster and application health |
| `open-devops-lab.ps1` | Open all DevOps dashboards (Argo CD, Grafana, Prometheus) and read admin secrets |

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
kubectl get pods -n monitoring
```

If Argo CD is not ready:

```powershell
kubectl get pods -n argocd
kubectl describe pods -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
```

### Monitoring (Prometheus & Grafana)

The monitoring stack is installed by default. To skip monitoring during setup:

```powershell
.\scripts\setup-devops-lab.ps1 -SkipMonitoring
```

Check monitoring installation:

```powershell
kubectl get namespace monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Access monitoring dashboards:

```powershell
.\scripts\open-devops-lab.ps1
```

This will open:
- **Grafana** at http://localhost:3000 (default username/password: admin/admin)
- **Prometheus** at http://localhost:9090

If monitoring pods are not ready, check the logs:

```powershell
kubectl logs -f deployment/kube-prometheus-stack-grafana -n monitoring
kubectl logs -f statefulset/prometheus-kube-prometheus-prometheus -n monitoring
```

Reinstall monitoring stack if needed:

```powershell
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete namespace monitoring
.\scripts\setup-devops-lab.ps1  # Run setup again
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
