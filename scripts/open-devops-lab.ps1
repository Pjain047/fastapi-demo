param(
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

$StateDirectory = Join-Path $PSScriptRoot ".state"
$LogDirectory = Join-Path $StateDirectory "logs"
$StateFile = Join-Path $StateDirectory "port-forward-processes.json"

$endpoints = @(
    @{
        Name = "Argo CD"
        Namespace = "argocd"
        Service = "argocd-server"
        LocalPort = 8080
        RemotePort = 443
        Url = "https://localhost:8080"
    },
    @{
        Name = "Grafana"
        Namespace = "monitoring"
        Service = "kube-prometheus-stack-grafana"
        LocalPort = 3000
        RemotePort = 80
        Url = "http://localhost:3000"
    },
    @{
        Name = "Prometheus"
        Namespace = "monitoring"
        Service = "kube-prometheus-stack-prometheus"
        LocalPort = 9090
        RemotePort = 9090
        Url = "http://localhost:9090"
    }
)


function Test-PortInUse {
    param([int]$Port)

    $connection = Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue

    return $null -ne $connection
}


function Wait-ForPort {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        if (Test-PortInUse -Port $Port) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}


function Test-NamespaceExists {
    param(
        [string]$Namespace
    )
    
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    kubectl get namespace $Namespace 2>$null | Out-Null
    $namespaceExists = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $previousErrorActionPreference
    return $namespaceExists
}


function Convert-SecretValue {
    param(
        [string]$SecretName,
        [string]$Namespace,
        [string]$Key
    )

    $encodedValue = kubectl get secret $SecretName `
        --namespace $Namespace `
        --output "jsonpath={.data.$Key}"

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($encodedValue)
    ) {
        return "Unavailable"
    }

    return [System.Text.Encoding]::UTF8.GetString(
        [System.Convert]::FromBase64String($encodedValue)
    )
}


function Start-PortForward {
    param(
        [hashtable]$Endpoint
    )

    kubectl get service $Endpoint.Service `
        --namespace $Endpoint.Namespace *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[SKIP] Service '$($Endpoint.Service)' not found in namespace '$($Endpoint.Namespace)'. ($($Endpoint.Name) will not be available)" -ForegroundColor Yellow
        return $null
    }

    if (Test-PortInUse -Port $Endpoint.LocalPort) {
        Write-Host `
            "[SKIP] Port $($Endpoint.LocalPort) is already in use for $($Endpoint.Name)." `
            -ForegroundColor Yellow

        return $null
    }

    $safeName = $Endpoint.Name.Replace(" ", "-").ToLower()
    $outputLog = Join-Path $LogDirectory "$safeName-output.log"
    $errorLog = Join-Path $LogDirectory "$safeName-error.log"

    $arguments = @(
        "port-forward",
        "service/$($Endpoint.Service)",
        "--namespace",
        $Endpoint.Namespace,
        "$($Endpoint.LocalPort):$($Endpoint.RemotePort)",
        "--address",
        "127.0.0.1"
    )

    $process = Start-Process `
        -FilePath "kubectl.exe" `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -RedirectStandardOutput $outputLog `
        -RedirectStandardError $errorLog `
        -PassThru

    if (
        -not (
            Wait-ForPort `
                -Port $Endpoint.LocalPort `
                -TimeoutSeconds 30
        )
    ) {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
        }

        throw @"
Port forwarding failed for $($Endpoint.Name).
Check the log:
$errorLog
"@
    }

    Write-Host `
        "[OK] $($Endpoint.Name) available at $($Endpoint.Url)" `
        -ForegroundColor Green

    return @{
        Name = $Endpoint.Name
        ProcessId = $process.Id
        LocalPort = $Endpoint.LocalPort
        Url = $Endpoint.Url
        StartedAt = (Get-Date).ToString("o")
    }
}


if ($null -eq (Get-Command "kubectl" -ErrorAction SilentlyContinue)) {
    throw "kubectl is not installed or is not in PATH."
}

kubectl cluster-info *> $null

if ($LASTEXITCODE -ne 0) {
    throw @"
The Kubernetes cluster is not reachable.
Run .\scripts\start-devops-lab.ps1 first.
"@
}

New-Item `
    -ItemType Directory `
    -Path $StateDirectory `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $LogDirectory `
    -Force | Out-Null


Write-Host ""
Write-Host "Starting DevOps lab dashboards..." `
    -ForegroundColor Cyan
Write-Host ""

$processes = @()

foreach ($endpoint in $endpoints) {
    # Skip endpoints in namespaces that don't exist
    if (-not (Test-NamespaceExists -Namespace $endpoint.Namespace)) {
        Write-Host "[SKIP] Namespace '$($endpoint.Namespace)' not found. Skipping $($endpoint.Name)." -ForegroundColor Yellow
        continue
    }
    
    $processInformation = Start-PortForward `
        -Endpoint $endpoint

    if ($null -ne $processInformation) {
        $processes += $processInformation
    }
}

if ($processes.Count -gt 0) {
    $processes |
        ConvertTo-Json -Depth 5 |
        Set-Content -Path $StateFile -Encoding UTF8
}


$argoPassword = Convert-SecretValue `
    -SecretName "argocd-initial-admin-secret" `
    -Namespace "argocd" `
    -Key "password"

# Only fetch monitoring credentials if the namespace exists
$monitoringEnabled = Test-NamespaceExists -Namespace "monitoring"
if ($monitoringEnabled) {
    $grafanaUsername = Convert-SecretValue `
        -SecretName "kube-prometheus-stack-grafana" `
        -Namespace "monitoring" `
        -Key "admin-user"

    $grafanaPassword = Convert-SecretValue `
        -SecretName "kube-prometheus-stack-grafana" `
        -Namespace "monitoring" `
        -Key "admin-password"
    
    # If secrets are not found, use defaults (as set during helm installation)
    if ($grafanaUsername -eq "Unavailable") {
        $grafanaUsername = "admin"
    }
    if ($grafanaPassword -eq "Unavailable") {
        $grafanaPassword = "admin"
    }
}


Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Cyan
Write-Host "DevOps Lab Access Information" `
    -ForegroundColor Cyan
Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Argo CD" -ForegroundColor Green
Write-Host "URL      : https://localhost:8080"
Write-Host "Username : admin"
Write-Host "Password : $argoPassword"

if ($monitoringEnabled) {
    Write-Host ""
    Write-Host "Grafana" -ForegroundColor Green
    Write-Host "URL      : http://localhost:3000"
    Write-Host "Username : $grafanaUsername"
    Write-Host "Password : $grafanaPassword"

    Write-Host ""
    Write-Host "Prometheus" -ForegroundColor Green
    Write-Host "URL            : http://localhost:9090"
    Write-Host "Authentication : Not enabled for this local lab"
} else {
    Write-Host ""
    Write-Host "Monitoring (Grafana/Prometheus)" -ForegroundColor Yellow
    Write-Host "[SKIP] monitoring namespace not found - not configured"
}

Write-Host ""
Write-Host "The port-forward processes are running in the background."
Write-Host "You can close this PowerShell window."
Write-Host ""
Write-Host "To close the dashboards, run:" `
    -ForegroundColor Yellow
Write-Host ".\scripts\close-devops-lab.ps1"


if (-not $NoBrowser) {
    foreach ($endpoint in $endpoints) {
        # Only open browser for endpoints in existing namespaces
        if (Test-NamespaceExists -Namespace $endpoint.Namespace) {
            Start-Process $endpoint.Url
        }
    }
}

#.\scripts\open-devops-lab.ps1 -NoBrowser