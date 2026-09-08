param(
    [int]$LocalPort = 8080
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "Required command 'kubectl' was not found in PATH."
}

$ArgoNamespace = "argocd"

Write-Host "Checking Argo CD Server..." -ForegroundColor Cyan

kubectl get service argocd-server --namespace $ArgoNamespace *> $null

if ($LASTEXITCODE -ne 0){
    throw "Argo cd is not installed or the argocd-sever services is unavailable."
}

$readyReplicas = kubectl get deployment argocd-server --namespace $ArgoNamespace --output jsonpath="{.status.readyReplicas}"

if ([string]::IsNullOrWhiteSpace($readyReplicas) -or [int]$readyReplicas -lt 1) {
    throw "The Argo CD server is not ready. Run setup-devops-lab.ps1 or check its pods."
}

$encodedPassword = kubectl get secret argocd-initial-admin-secret --namespace $ArgoNamespace --output jsonpath="{.data.password}"

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($encodedPassword)) {
    throw "The Argo CD admin password secret is unavailable. Run setup-devops-lab.ps1 first."
}

$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedPassword))

Write-Host ""
Write-Host "Argo CD URL : https://localhost:$LocalPort" -ForegroundColor Green
Write-Host "Username    : admin"
Write-Host "Password    : $password" -ForegroundColor Red
Write-Host ""
Write-Host "Keep this PowerShell window open while using the UI."
Write-Host "Press Ctrl+C to stop port forwarding."
Write-Host ""


kubectl port-forward service/argocd-server --namespace $ArgoNamespace "${LocalPort}:443"