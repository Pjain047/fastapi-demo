# Local Minikube DevOps Lab

To Run Script on cmd use "powershell -file <filename>"

These PowerShell scripts help run the FastAPI demo with Minikube, Kubernetes,
Helm, and Argo CD on Windows.

Run the commands from the repository root:

```powershell
cd C:\My_learning\github_project\fastapi-demo
```

## Prerequisites

Install and make sure these commands are available in PowerShell:

- Docker Desktop
- Minikube
- kubectl
- Helm
- PowerShell 5.1 or PowerShell 7+

Check the tools:

```powershell
docker --version
minikube version
kubectl version --client
helm version
```

Docker Desktop must be running before starting Minikube with the Docker driver.

## PowerShell execution policy

If PowerShell blocks local scripts, allow scripts only for the current terminal:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

This change disappears when the terminal closes.

## Recommended command order

Use this order for a new local environment:

1. Run `setup-devops-lab.ps1` to start Minikube, select the context, enable Ingress, create namespaces, and install Argo CD.
2. Run the Helm validation commands.
3. Install the FastAPI application with Helm.
4. Run `status-devops-lab.ps1` to inspect the cluster and releases.
5. Run `open-argocd.ps1` when you need the Argo CD UI.
6. Run `stop-devops-lab.ps1` when you are finished for the day.

Stopping Minikube preserves the cluster, namespaces, Helm release, and Argo CD
resources. Start it again later with `start-devops-lab.ps1`.

## 1. Set up Minikube and Argo CD

From the repository root:

```powershell
.\scripts\setup-devops-lab.ps1
```

The setup script:

- Checks Docker, Minikube, and kubectl
- Verifies that Docker Desktop is running
- Starts the `minikube` profile with the Docker driver
- Selects the `minikube` kubectl context
- Waits for Kubernetes nodes to become Ready
- Enables the Minikube Ingress addon
- Creates the `argocd` and `fastapi-demo` namespaces
- Installs Argo CD into the `argocd` namespace
- Waits for Argo CD pods to become Ready

Custom profile and resource settings:

```powershell
.\scripts\setup-devops-lab.ps1 `
  -ClusterName minikube `
  -Driver docker `
  -CpuCount 4 `
  -MemorySize 8192
```

Skip the Ingress addon:

```powershell
.\scripts\setup-devops-lab.ps1 -SkipIngress
```

## 2. Validate the Helm chart

```powershell
Push-Location .\helm_infra\fastapi-demo
helm lint .
helm template fastapi-demo . --namespace fastapi-demo
helm template fastapi-demo . --namespace fastapi-demo |
  kubeconform -strict -summary
Pop-Location
```

These commands check the chart, render the final Kubernetes YAML, and validate
the rendered resources against Kubernetes schemas without installing them.

If `kubeconform` is not installed locally, run the first two commands and use
the GitHub Actions Helm validation job for schema validation.

## 3. Install or upgrade the FastAPI application

The chart creates the namespace before the release when using
`--create-namespace`:

```powershell
helm upgrade --install fastapi-demo .\helm_infra\fastapi-demo `
  --namespace fastapi-demo `
  --create-namespace `
  --wait `
  --timeout 5m
```

This command is safe for both first installation and later upgrades.

For a different image tag:

```powershell
helm upgrade fastapi-demo .\helm_infra\fastapi-demo `
  --namespace fastapi-demo `
  --set image.tag=latest `
  --wait
```

Check the release:

```powershell
helm status fastapi-demo --namespace fastapi-demo
helm history fastapi-demo --namespace fastapi-demo
```

## 4. Check local status

```powershell
.\scripts\status-devops-lab.ps1
```

The status script displays:

- Minikube profile state
- Kubernetes nodes
- Argo CD pods
- FastAPI resources in `fastapi-demo`
- Helm releases across namespaces

Use another profile when needed:

```powershell
.\scripts\status-devops-lab.ps1 -ClusterName minikube
```

For more detailed application information:

```powershell
kubectl get pods -n fastapi-demo -o wide
kubectl get svc -n fastapi-demo
kubectl logs deployment/fastapi-demo -n fastapi-demo --all-containers=true
kubectl get events -n fastapi-demo --sort-by=.lastTimestamp
```

## 5. Access the FastAPI application

For the NodePort Service:

```powershell
minikube service fastapi-demo --namespace fastapi-demo --url
```

Open the returned URL with these paths:

```text
/health
/docs
```

Alternatively, forward the Service port:

```powershell
kubectl port-forward service/fastapi-demo -n fastapi-demo 8000:80
```

Then open `http://127.0.0.1:8000/docs`.

## 6. Open Argo CD

Run this in a separate PowerShell window:

```powershell
.\scripts\open-argocd.ps1
```

The script checks that the Argo CD server is ready, reads the initial admin
password, and forwards the Argo CD server to `https://localhost:8080`.

Keep that terminal open while using the UI. Stop port forwarding with `Ctrl+C`.

Use a different local port if 8080 is busy:

```powershell
.\scripts\open-argocd.ps1 -LocalPort 9090
```

Login values:

```text
Username: admin
URL: https://localhost:8080
```

The script prints the generated initial password. Treat it as sensitive and
change it after the first login.

## 7. Stop Minikube safely

```powershell
.\scripts\stop-devops-lab.ps1
```

This stops the Minikube VM/container but does not delete:

- Kubernetes namespaces
- FastAPI resources
- Helm releases
- Argo CD resources

Start the existing profile again with:

```powershell
.\scripts\start-devops-lab.ps1
```

## 8. Start an existing profile

```powershell
.\scripts\start-devops-lab.ps1
```

The start script:

- Starts the existing `minikube` profile if needed
- Selects the matching kubectl context
- Waits for nodes to become Ready
- Displays node and Argo CD pod status

Use a custom profile:

```powershell
.\scripts\start-devops-lab.ps1 -ClusterName minikube
```

## 9. Install Kubernetes Metrics Server

The Horizontal Pod Autoscaler (HPA) requires the metrics-server to collect CPU and memory metrics. This is now automatically installed during `setup-devops-lab.ps1`, but you can run it separately if needed:

```powershell
.\scripts\install-metrics-server.ps1
```

The metrics server installation:

- Checks if Minikube is running
- Enables the metrics-server addon (on Minikube)
- Verifies the deployment is ready
- Waits for metrics to be collected

Use a custom cluster name:

```powershell
.\scripts\install-metrics-server.ps1 -ClusterName my-cluster
```

Verify metrics are working:

```powershell
kubectl top nodes
kubectl top pods -n fastapi-demo
```

If HPA shows "unable to get metrics" errors, wait a few minutes for metrics collection to initialize, then check the metrics-server logs:

```powershell
kubectl logs -f deployment/metrics-server -n kube-system
```

## 10. Roll back a Helm release

List revisions:

```powershell
helm history fastapi-demo --namespace fastapi-demo
```

Rollback to a revision:

```powershell
helm rollback fastapi-demo <REVISION> `
  --namespace fastapi-demo `
  --wait `
  --timeout 5m
```

## 11. Remove the application

Remove only the Helm-managed FastAPI resources:

```powershell
helm uninstall fastapi-demo --namespace fastapi-demo
```

The namespace remains. Remove it separately only when required:

```powershell
kubectl delete namespace fastapi-demo
```

## 12. Remove the complete local lab

To remove the application, Argo CD, namespaces, and Minikube profile:

```powershell
helm uninstall fastapi-demo --namespace fastapi-demo
kubectl delete namespace fastapi-demo
kubectl delete namespace argocd
minikube delete --profile minikube
```

Use `minikube delete` only when you want to remove the entire local cluster.
`stop-devops-lab.ps1` is safer for normal day-to-day shutdown.

## Script summary

| Script | Purpose |
| --- | --- |
| `setup-devops-lab.ps1` | First-time setup of Minikube, namespaces, Ingress, Argo CD, and metrics-server |
| `start-devops-lab.ps1` | Start an existing Minikube profile |
| `status-devops-lab.ps1` | Display cluster, Argo CD, application, and Helm status |
| `open-argocd.ps1` | Read the Argo CD password and start local port forwarding |
| `stop-devops-lab.ps1` | Stop Minikube without deleting resources |
| `install-metrics-server.ps1` | Install or verify Kubernetes metrics-server for HPA |

## Troubleshooting

Check the current context:

```powershell
kubectl config current-context
kubectl config get-contexts
```

If the application is not ready:

```powershell
kubectl get pods -n fastapi-demo
kubectl describe pods -n fastapi-demo
kubectl logs deployment/fastapi-demo -n fastapi-demo --all-containers=true
kubectl rollout status deployment/fastapi-demo -n fastapi-demo --timeout=5m
```

If Argo CD is not ready:

```powershell
kubectl get pods -n argocd
kubectl describe pods -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
```
