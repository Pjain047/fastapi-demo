param(
    [string]$ClusterName = "minikube"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
    throw "Required command 'minikube' was not found in PATH."
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

Write-Host "Checking minikube profile '$ClusterName'...." -ForegroundColor Cyan

$minikubeState = Get-MinikubeState -ClusterName $ClusterName

if ($null -eq $minikubeState) {
    Write-Host "[SKIP] Minikube profile '$ClusterName' does not exist." -ForegroundColor Yellow
    exit 0
}

if ($minikubeState.Host -ne "Running") {
    Write-Host "[SKIP] Minikube is already stopped." -ForegroundColor Yellow
    exit 0
}

Write-Host "Stopping minikube..."

minikube stop --profile $ClusterName

if ($LASTEXITCODE -ne 0){
    throw "minikube failed to stop."
}

Write-Host ""
Write-Host "[OK] Minikube stopped safely." -ForegroundColor Green
Write-Host "No namespace, application, Helm release, or Argo CD resources were deleted."
Write-Host "Run .\scripts\start-devops-lab.ps1 to start it again."