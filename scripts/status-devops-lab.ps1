param(
    [string]$ClusterName = "minikube"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Minikube Status" -ForegroundColor Cyan
Write-Host "-----------------"
minikube status --profile $ClusterName

if ($LASTEXITCODE -ne 0){
    Write-Host ""
    Write-Host "minikube is unavailable or the profile does not exist." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "k8s nodes" -ForegroundColor Cyan
Write-Host "-----------------"
kubectl get nodes

Write-Host ""
Write-Host "Argo cd Pods" -ForegroundColor Cyan
Write-Host "-----------------"
kubectl get pods --namespace argocd

Write-Host ""
Write-Host "FastAPI resources" -ForegroundColor Cyan
Write-Host "------------------"
kubectl get all --namespace fastapi-demo

Write-Host ""
Write-Host "Helm Release" -ForegroundColor Cyan
Write-Host "-----------------"
helm list --all-namespaces