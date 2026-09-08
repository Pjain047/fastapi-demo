$ErrorActionPreference = "Continue"

$StateDirectory = Join-Path $PSScriptRoot ".state"
$StateFile = Join-Path $StateDirectory "port-forward-processes.json"

Write-Host ""
Write-Host "Stopping DevOps lab port forwards..." `
    -ForegroundColor Cyan

if (-not (Test-Path $StateFile)) {
    Write-Host `
        "[SKIP] No recorded port-forward processes were found." `
        -ForegroundColor Yellow

    exit 0
}

$content = Get-Content `
    -Path $StateFile `
    -Raw

if ([string]::IsNullOrWhiteSpace($content)) {
    Remove-Item $StateFile -Force
    Write-Host "[SKIP] Port-forward state file was empty." `
        -ForegroundColor Yellow

    exit 0
}

$processes = @($content | ConvertFrom-Json)

foreach ($processInformation in $processes) {
    $processId = [int]$processInformation.ProcessId

    $process = Get-Process `
        -Id $processId `
        -ErrorAction SilentlyContinue

    if ($null -eq $process) {
        Write-Host `
            "[SKIP] $($processInformation.Name) process is already stopped." `
            -ForegroundColor Yellow

        continue
    }

    Stop-Process `
        -Id $processId `
        -Force

    Write-Host `
        "[OK] Stopped $($processInformation.Name)." `
        -ForegroundColor Green
}

Remove-Item $StateFile -Force

Write-Host ""
Write-Host "[OK] All recorded port forwards are stopped." `
    -ForegroundColor Green
