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

# Start a minikube tunnel so LoadBalancer services (the Gateway's data-plane)
# get an external IP on 127.0.0.1 and the nip.io hostname becomes reachable.
Write-Host ""
Write-Host "Starting minikube tunnel for LoadBalancer/Gateway access..." -ForegroundColor Cyan

# A tunnel is needed only if the Gateway LB has no external IP assigned yet.
$gatewayIp = kubectl get svc fastapi-demo-nginx -n fastapi-demo `
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

if (-not [string]::IsNullOrWhiteSpace($gatewayIp)) {
    Write-Host "[SKIP] Gateway already has external IP ($gatewayIp) - tunnel likely running." -ForegroundColor Yellow
}
else {
    Start-Process -FilePath "minikube" `
        -ArgumentList "tunnel", "-p", $ClusterName `
        -WindowStyle Minimized

    # Give the tunnel a moment to assign external IPs.
    Start-Sleep -Seconds 5

    $gatewayIp = kubectl get svc fastapi-demo-nginx -n fastapi-demo `
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

    if (-not [string]::IsNullOrWhiteSpace($gatewayIp)) {
        Write-Host "[OK] Tunnel started. Gateway external IP: $gatewayIp" -ForegroundColor Green
    }
    else {
        Write-Host "[WARNING] Tunnel started but Gateway has no external IP yet." -ForegroundColor Yellow
        Write-Host "          If port 80 fails, run 'minikube tunnel' from an elevated terminal." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "App URL (via Gateway): http://fastapi-demo.127.0.0.1.nip.io/docs" -ForegroundColor Green
Write-Host "[OK] DevOps lab is ready" -ForegroundColor Green

