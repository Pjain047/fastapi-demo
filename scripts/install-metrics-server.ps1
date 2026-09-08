# Script to install metrics-server on Minikube or any Kubernetes cluster
# metrics-server is required for HPA (Horizontal Pod Autoscaler) to work

param(
    [string]$ClusterName = "minikube"
)

Write-Host "Installing metrics-server for Kubernetes metrics collection..." -ForegroundColor Green

# Check if Minikube is running
Write-Host "Checking if Minikube is running..." -ForegroundColor Yellow
$minikubeStatus = & minikube status -p $ClusterName 2>&1 | Select-String "host: Running"
if ($minikubeStatus) {
    Write-Host "Minikube is running. Enabling metrics-server addon..." -ForegroundColor Green
    & minikube addons enable metrics-server -p $ClusterName
    Write-Host "Waiting for metrics-server to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
} else {
    Write-Host "Minikube not running or metrics-server addon not available. Installing metrics-server via kubectl..." -ForegroundColor Yellow
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
}

# Verify installation
Write-Host "Verifying metrics-server installation..." -ForegroundColor Yellow
$attempts = 0
$maxAttempts = 60

while ($attempts -lt $maxAttempts) {
    $deployment = kubectl get deployment metrics-server -n kube-system --no-headers 2>&1
    if ($deployment -like "*1/1*") {
        Write-Host "metrics-server is running and ready!" -ForegroundColor Green
        kubectl get deployment metrics-server -n kube-system
        break
    }
    $waitMsg = "Waiting for metrics-server to be ready... (attempt $($attempts + 1) of $maxAttempts)"
    Write-Host $waitMsg -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    $attempts++
}

if ($attempts -eq $maxAttempts) {
    Write-Host "metrics-server installation timed out. Metrics may not be available immediately." -ForegroundColor Yellow
    Write-Host "Check logs with:" -ForegroundColor Yellow
    Write-Host "  kubectl logs -f deployment/metrics-server -n kube-system"
}

# Wait a bit for metrics to be collected
Write-Host "Waiting for metrics to be collected..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Try to get metrics
kubectl top nodes 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Metrics collection is working!" -ForegroundColor Green
} else {
    Write-Host "Metrics are still being collected. This may take a minute..." -ForegroundColor Yellow
}

Write-Host "`nmetrics-server installation complete!" -ForegroundColor Green
Write-Host "`nTest metrics with these commands:" -ForegroundColor Cyan
Write-Host "  kubectl top nodes"
Write-Host "  kubectl top pods -n fastapi-demo"
