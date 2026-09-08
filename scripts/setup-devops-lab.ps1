param(
    [Alias("ClusterName")]
    [string]$Profile = "minikube",
    [string]$Driver = "docker",
    [int]$CpuCount = 4,
    [int]$MemorySize = 8192,
    [switch]$SkipIngress,
    [switch]$SkipMonitoring,
    [switch]$SkipIstio
)

$ErrorActionPreference = "Stop"

foreach ($commandName in @("minikube", "kubectl", "helm")) {
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

    # Install the Gateway API CRDs (standard channel) so Gateway/HTTPRoute resources work.
    Write-Host "Installing Gateway API CRDs..." -ForegroundColor Cyan
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] Failed to install Gateway API CRDs." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Gateway API CRDs installed." -ForegroundColor Green
    }

    # Install NGINX Gateway Fabric: the Gateway API controller that creates the
    # 'nginx' GatewayClass and programs routes for Gateway/HTTPRoute resources.
    Write-Host "Installing NGINX Gateway Fabric (Gateway API controller)..." -ForegroundColor Cyan
    kubectl create namespace nginx-gateway --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null
    helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric `
        --namespace nginx-gateway `
        --wait `
        --timeout 5m 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] Failed to install NGINX Gateway Fabric." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] NGINX Gateway Fabric installed." -ForegroundColor Green
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

$ArgoInstallUrl = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
$retryCount = 0
$maxRetries = 3
$installed = $false

while ($retryCount -lt $maxRetries -and -not $installed) {
    Write-Host "Attempting Argo CD installation (attempt $($retryCount + 1) of $maxRetries)..." -ForegroundColor Yellow
    
    try {
        # Use server-side apply to avoid annotation warnings
        kubectl apply -n argocd --server-side --force-conflicts -f $ArgoInstallUrl 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Argo CD manifests applied." -ForegroundColor Green
            $installed = $true
        }
        else {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "Installation attempt failed with exit code $LASTEXITCODE. Retrying in 10 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
            }
        }
    }
    catch {
        $retryCount++
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        if ($retryCount -lt $maxRetries) {
            Write-Host "Retrying in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    }
}

if (-not $installed) {
    throw "Failed to install Argo CD after $maxRetries attempts. Check your internet connection and try again."
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

if (-not $SkipMonitoring) {
    Write-Host "" 
    Write-Host "Installing monitoring stack (Prometheus & Grafana)..." -ForegroundColor Cyan

    # Add Prometheus Helm repo
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] Failed to add Prometheus Helm repo. Monitoring will not be installed." -ForegroundColor Yellow
    } else {
        # Create monitoring namespace
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create monitoring namespace."
        }

        # Install kube-prometheus-stack
        $monitoringValuesPath = Join-Path $PSScriptRoot "monitoring-values.yaml"
        helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
            --namespace monitoring `
            -f $monitoringValuesPath `
            --set prometheus.prometheusSpec.retention=24h `
            --set grafana.adminPassword=admin `
            --wait `
            --timeout 5m 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Monitoring stack installed successfully." -ForegroundColor Green
            
            # Wait for monitoring to be ready
            Write-Host "Waiting for monitoring stack to be ready..." -ForegroundColor Cyan
            kubectl wait `
                --namespace monitoring `
                --for=condition=Available `
                deployment `
                --all `
                --timeout=300s 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Monitoring stack is ready." -ForegroundColor Green
            } else {
                Write-Host "[WARNING] Monitoring stack may not be fully ready yet." -ForegroundColor Yellow
            }
        } else {
            Write-Host "[WARNING] Failed to install monitoring stack." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "" 
    Write-Host "[SKIP] Monitoring stack installation skipped." -ForegroundColor Yellow
}

if (-not $SkipIstio) {
    Write-Host ""
    Write-Host "Installing Istio service mesh..." -ForegroundColor Cyan

    helm repo add istio https://istio-release.storage.googleapis.com/charts 2>&1 | Out-Null
    helm repo update 2>&1 | Out-Null

    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null

    # 1. Istio base: CRDs and cluster-scoped resources.
    Write-Host "Installing Istio base (CRDs)..." -ForegroundColor Cyan
    helm upgrade --install istio-base istio/base `
        --namespace istio-system `
        --wait `
        --timeout 5m 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Istio base."
    }

    # 2. istiod: the control plane.
    Write-Host "Installing istiod (control plane)..." -ForegroundColor Cyan
    helm upgrade --install istiod istio/istiod `
        --namespace istio-system `
        --wait `
        --timeout 5m 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install istiod."
    }

    # 3. Istio ingress gateway: the data-plane entrypoint for mesh traffic.
    Write-Host "Installing Istio ingress gateway..." -ForegroundColor Cyan
    helm upgrade --install istio-ingressgateway istio/gateway `
        --namespace istio-system `
        --wait `
        --timeout 5m 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install the Istio ingress gateway."
    }

    Write-Host "[OK] Istio service mesh installed." -ForegroundColor Green

    # Enable automatic sidecar (Envoy proxy) injection for the app namespace.
    Write-Host "Enabling Istio sidecar injection on the 'fastapi-demo' namespace..." -ForegroundColor Cyan
    kubectl label namespace fastapi-demo istio-injection=enabled --overwrite 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Sidecar injection enabled for 'fastapi-demo'." -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Failed to label 'fastapi-demo' for sidecar injection." -ForegroundColor Yellow
    }

    # 4. Kiali: the service-mesh observability dashboard.
    Write-Host "Installing Kiali (service mesh dashboard)..." -ForegroundColor Cyan
    helm repo add kiali https://kiali.org/helm-charts 2>&1 | Out-Null
    helm repo update 2>&1 | Out-Null

    helm upgrade --install kiali-server kiali/kiali-server `
        --namespace istio-system `
        --set auth.strategy="anonymous" `
        --set external_services.prometheus.url="http://kube-prometheus-stack-prometheus.monitoring:9090" `
        --wait `
        --timeout 5m 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Kiali installed (anonymous auth - local lab only)." -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Failed to install Kiali." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[SKIP] Istio installation skipped." -ForegroundColor Yellow
}

Write-Host "" 
Write-Host "[OK] DevOps lab is ready." -ForegroundColor Green

Write-Host "" 
Write-Host "Run:" 
Write-Host ".\scripts\open-devops-lab.ps1" -ForegroundColor Green
