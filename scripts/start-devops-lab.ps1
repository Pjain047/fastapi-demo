param(
    [string]$ClusterName = "minikube"
)

$ErrorActionPreference = "Stop"

foreach ($commandName in @("minikube", "kubectl")) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$commandName' was not found in PATH."
    }
}

function Get-MinikubeState {
    param (
        [string]$ClusterName
    )

    $statusJson = minikube status -p $ClusterName --output json 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($statusJson)) {
        return $null
    }

    try {
        $status = $statusJson | ConvertFrom-Json
        return $status
    }
    catch {
        return $null
    }
}

Write-Host "Checking Minikube profile '$ClusterName'..." -ForegroundColor Cyan

$minikubeState = Get-MinikubeState -ClusterName $ClusterName

if (
 $null -ne $minikubeState -and 
 $minikubeState.Host -eq "Running" -and
 $minikubeState.APIServer -eq "Running" -and
 $minikubeState.Kubelet -eq "Running" 
) {
    Write-Host "[SKIP] Minikube is already running." -ForegroundColor Yellow
}

else {
    Write-Host "Starting Minikube... '$ClusterName'..." -ForegroundColor Green

    minikube start -p $ClusterName

    if ($LASTEXITCODE -ne 0) {
        throw "Error: Failed to start Minikube."
    }
    else {
        Write-Host "[OK] Minikube started successfully." -ForegroundColor Green
    }
}

kubectl config use-context $ClusterName

if ($LASTEXITCODE -ne 0) {
    throw "Error: Failed to set the kube context to '$ClusterName'."
}

kubectl wait --for=condition=Ready nodes --all --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "Error: Not all nodes are ready in the Minikube cluster."
}

Write-Host ""
Write-Host "Cluster status:" -ForegroundColor Cyan
kubectl get nodes

Write-Host ""
Write-Host "Argo Cd status:" -ForegroundColor Cyan
kubectl get pods --namespace argocd

Write-Host ""
Write-Host "[OK] DevOps lab is ready" -ForegroundColor Green

