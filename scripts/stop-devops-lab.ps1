param(
    [Alias("ClusterName")]
    [string]$Profile = "minikube"
)

$ErrorActionPreference = "Stop"

$closeScript = Join-Path `
    $PSScriptRoot `
    "close-devops-lab.ps1"

if (Test-Path $closeScript) {
    & $closeScript
}

# Stop any running minikube tunnel before stopping the cluster so no
# orphaned tunnel window/process is left behind.
Write-Host ""
Write-Host "Stopping minikube tunnel (if running)..." -ForegroundColor Cyan

$tunnel = Get-CimInstance Win32_Process `
    -Filter "Name = 'minikube.exe'" `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match '\btunnel\b' }

if ($tunnel) {
    $tunnel | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] minikube tunnel stopped." -ForegroundColor Green
}
else {
    Write-Host "[SKIP] No minikube tunnel running." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Stopping Minikube profile '$Profile'..." `
    -ForegroundColor Cyan

$statusOutput = minikube status `
    --profile $Profile `
    --output json 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($statusOutput)) {
    Write-Host `
        "[SKIP] Minikube profile '$Profile' does not exist." `
        -ForegroundColor Yellow

    exit 0
}

$state = $statusOutput | ConvertFrom-Json

if ($state.Host -ne "Running") {
    Write-Host "[SKIP] Minikube is already stopped." `
        -ForegroundColor Yellow

    exit 0
}

minikube stop --profile $Profile

if ($LASTEXITCODE -ne 0) {
    throw "Minikube failed to stop."
}

Write-Host ""
Write-Host "[OK] Minikube stopped safely." `
    -ForegroundColor Green

Write-Host "No Kubernetes or Helm resources were deleted."
