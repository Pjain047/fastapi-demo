param(
    [string]$ClusterName = "minikube",
   [string]$Driver = "docker",
   [int]$CpuCount = 4,
   [int]$MemorySize = 8192,
   [switch]$SkipIngress

)

$ErrorActionPreference = "Stop"

$ArgoNamespace = "argocd"
$AppNamespace = "fastapi-demo"
$ArgoInstallUrl = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

function Write-Step {
    param (
        [string]$Message
    )
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "=== $Message ===" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
}

function Test-CommandExists {
    param (
        [string]$CommandName
    )
    $commandPath = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $commandPath
}


function Assert-CommandExists {
    param (
        [string]$CommandName,
        [string]$InstallationMessage
    )
    if (-not (Test-CommandExists -CommandName $CommandName)) {
        
        throw "Error: '$CommandName' command not found. $InstallationMessage"
    }
    write-Host "[OK] '$CommandName' is installed." -ForegroundColor Green
}

function Test-DockerRunning {
        docker info *> $null
        return $LASTEXITCODE -eq 0
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

function Test-NamespaceExists {
    param (
        [string]$Namespace
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    kubectl get namespace $Namespace 2>$null | Out-Null
    $commandSucceeded = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $previousErrorActionPreference
    return $commandSucceeded
}

function Test-DeploymentExists {
    param (
        [string]$Namespace,
        [string]$DeploymentName
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    kubectl get deployment $DeploymentName -n $Namespace 2>$null | Out-Null
    $commandSucceeded = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $previousErrorActionPreference
    return $commandSucceeded
}


Write-Step "Checking required tools"

Assert-CommandExists  `
      -CommandName "docker" `
      -InstallationMessage "Please install Docker Desktop from https://www.docker.com/products/docker-desktop"


Assert-CommandExists  `
      -CommandName "minikube" `
      -InstallationMessage "Please install Minikube from https://minikube.sigs.k8s.io/docs/start/"

Assert-CommandExists  `
      -CommandName "kubectl" `
      -InstallationMessage "Please install kubectl from https://kubernetes.io/docs/tasks/tools/"

Write-Step "Checking Docker"

if (-not (Test-DockerRunning)) {
    throw "Error: Docker is not running. Please start Docker Desktop."
}
else {
    Write-Host "[OK] Docker is running." -ForegroundColor Green
}

Write-Step "Checking Minikube"

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

    minikube start -p $ClusterName --driver=$Driver --cpus=$CpuCount --memory=$MemorySize

    if ($LASTEXITCODE -ne 0) {
        throw "Error: Failed to start Minikube."
    }
    else {
        Write-Host "[OK] Minikube started successfully." -ForegroundColor Green
    }
}

Write-Step "Selecting the Minikube kube context"

kubectl config use-context $ClusterName

if ($LASTEXITCODE -ne 0) {
    throw "Error: Failed to set the kube context to '$ClusterName'."
}

kubectl wait --for=condition=Ready nodes --all --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "Error: Not all nodes are ready in the Minikube cluster."
}

if (-not $SkipIngress) {
    Write-Step "Checking Minikube Ingress Addon"

    $addonOutput = minikube addons list -p $ClusterName --output json | ConvertFrom-Json
    $ingressEnabled = $null -ne $addonOutput.ingress -and $addonOutput.ingress.Status -eq "enabled"
    if ($ingressEnabled){
        Write-Host "[SKIP] Ingress addon is already Enabled." -ForegroundColor Yellow
    }
    else{
        minikube addons enable ingress --profile $ClusterName

        if ($LASTEXITCODE -ne 0){
            throw "Failed to enable the Minikube ingress addon."
        }

        Write-Host "[OK] Ingress addon enabled." -ForegroundColor Green
    }
}

Write-Step "Checking Kubernetes namespaces"

foreach ($namespace in @($ArgoNamespace, $AppNamespace)){
    if (Test-NamespaceExists -Namespace $namespace){
        Write-Host "[SKIP] NS '$namespace' already exists" -ForegroundColor Yellow
    }
    else{
        kubectl create namespace $namespace

        if ($LASTEXITCODE -ne 0){
            throw "Failed to create NS '$namespace'."
        }

        Write-Host "[OK] NS '$namespace' created." -ForegroundColor Green
    }
}

Write-Step "Checking Argo CD installation"

if (
    Test-DeploymentExists -Namespace $ArgoNamespace -Deployment "argocd-server"
){
    Write-Host "[SKIP] Argo cd is already Installed." -ForegroundColor Yellow
}
else {
    Write-Host "Installing ArgoCD.."
    
    kubectl apply --namespace $ArgoNamespace --server-side --force-conflicts --filename $ArgoInstallUrl

    if ($LASTEXITCODE -ne 0){
        throw "Argo CD installation Failed."
    }

    Write-Host "[OK] Argo CD manifests applied." -ForegroundColor Green
}


Write-Step "Waiting for Argo CD"

kubectl wait --namespace $ArgoNamespace --for=condition=Ready pods --all --timeout=300s

if ($LASTEXITCODE -ne 0){
    Write-Host "[WARNING] Some Argo CD pods are not ready." -ForegroundColor Yellow

    kubectl get pods --namespace $ArgoNamespace
    throw "Argo cd did not become ready within the expected time."
}

Write-Host "[OK] All Argo cd pods are ready." -ForegroundColor Green


Write-Step "Installing Metrics Server"

# Call metrics-server installation script
& "$(Split-Path $PSCommandPath)\install-metrics-server.ps1" -ClusterName $ClusterName

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Metrics server installation encountered issues." -ForegroundColor Yellow
}


Write-Step "DevOps Lab setup completed"

Write-Host "Minikube cluster: $ClusterName"
Write-Host "Argo Namespace" : $ArgoNamespace
Write-Host "App Namespace: $AppNamespace"
Write-Host " " 
Write-Host "Run the following script to access argo cd:" :
Write-Host ".\scripts\open-argocd.ps1" -ForegroundColor Green
