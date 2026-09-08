param(
    [Alias("ClusterName")]
    [string]$Profile = "minikube",
    [string]$Driver = "docker",
    [int]$CpuCount = 4,
    [int]$MemorySize = 8192,
    [switch]$SkipIngress
)

$ErrorActionPreference = "Stop"

foreach ($commandName in @("minikube", "kubectl")) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$commandName' was not found in PATH."
    }
}

function Get-MinikubeState {
    param([string]$ProfileName)

    $statusJson = minikube status `
        --profile $ProfileName `
        --output json 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($statusJson)) {
        return $null
    }

    try {
        return $statusJson | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

$state = Get-MinikubeState -ProfileName $Profile

if (
    $null -ne $state -and
    $state.Host -eq "Running" -and
    $state.APIServer -eq "Running"
) {
    Write-Host "[SKIP] Minikube is already running." -ForegroundColor Yellow
}
else {
    Write-Host "Starting Minikube..." -ForegroundColor Cyan

    $startArgs = @(
        "start",
        "--profile", $Profile,
        "--driver", $Driver,
        "--cpus", $CpuCount,
        "--memory", "${MemorySize}m"
    )

    minikube @startArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Minikube failed to start."
    }
}

kubectl config use-context $Profile

if ($LASTEXITCODE -ne 0) {
    throw "Failed to set kubectl context to '$Profile'."
}

kubectl wait `
    --for=condition=Ready `
    node `
    --all `
    --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "The Minikube node did not become ready."
}

if (-not $SkipIngress) {
    Write-Host "" 
    Write-Host "Enabling Minikube ingress addon..." -ForegroundColor Cyan
    minikube addons enable ingress --profile $Profile

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enable the Minikube ingress addon."
    }
}

foreach ($namespace in @("argocd", "fastapi-demo")) {
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to ensure namespace '$namespace' exists."
    }
}

Write-Host "" 
Write-Host "Installing Argo CD..." -ForegroundColor Cyan
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install Argo CD."
}

Write-Host "" 
Write-Host "Waiting for Argo CD to become ready..." -ForegroundColor Cyan
kubectl wait `
    --namespace argocd `
    --for=condition=Available `
    deployment `
    --all `
    --timeout=600s

if ($LASTEXITCODE -ne 0) {
    throw "Argo CD did not become ready in time."
}

Write-Host "" 
Write-Host "Enabling metrics-server..." -ForegroundColor Cyan
minikube addons enable metrics-server --profile $Profile

if ($LASTEXITCODE -ne 0) {
    throw "Failed to enable the Minikube metrics-server addon."
}

Write-Host "" 
Write-Host "Waiting for metrics-server..." -ForegroundColor Cyan
kubectl wait `
    --namespace kube-system `
    --for=condition=Available `
    deployment/metrics-server `
    --timeout=300s

if ($LASTEXITCODE -ne 0) {
    throw "metrics-server did not become ready in time."
}

Write-Host "" 
Write-Host "[OK] DevOps lab is ready." -ForegroundColor Green

Write-Host "" 
Write-Host "Run:" 
Write-Host ".\scripts\open-devops-lab.ps1" -ForegroundColor Green
