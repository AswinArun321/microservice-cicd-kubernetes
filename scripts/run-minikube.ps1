# Connects to the local Minikube Ingress Controller and exposes the microservices on port 8080
$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Starting Minikube Ingress Port-Forwarding (Port 8080)..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Check if minikube is running
$status = minikube status --format "{{.Host}}"
if ($status -ne "Running") {
    Write-Host "Minikube is not running. Starting minikube..." -ForegroundColor Yellow
    minikube start --driver=docker
}

# Ensure ingress-nginx is available
$ingressPod = kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath="{.items[0].metadata.name}" 2>$null
if (-not $ingressPod) {
    Write-Host "Enabling Minikube Ingress addon..." -ForegroundColor Yellow
    minikube addons enable ingress
    Start-Sleep -Seconds 10
}

# Start port-forwarding in background
Write-Host "Forwarding Ingress traffic to http://localhost:8080..." -ForegroundColor Green
$proc = Start-Process kubectl -ArgumentList "port-forward svc/ingress-nginx-controller -n ingress-nginx 8080:80" -PassThru -WindowStyle Hidden

try {
    # Wait for port to become active
    $maxRetries = 15
    $ready = $false
    for ($i = 1; $i -le $maxRetries; $i++) {
        Start-Sleep -Seconds 1
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:8080/auth/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($resp.status -eq "healthy") {
                $ready = $true
                break
            }
        } catch {}
    }

    if (-not $ready) {
        throw "Ingress port-forward did not become ready in time."
    }

    Write-Host "Microservices Ingress is LIVE on http://localhost:8080!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Available Endpoints:" -ForegroundColor Cyan
    Write-Host "  - Auth Health:   http://localhost:8080/auth/health"
    Write-Host "  - API Health:    http://localhost:8080/api/health"
    Write-Host "  - API Data:      http://localhost:8080/api/data"
    Write-Host "  - API Stats:     http://localhost:8080/api/stats"
    Write-Host "  - Worker Health: http://localhost:8080/worker/health"
    Write-Host "  - Worker Status: http://localhost:8080/worker/status"
    Write-Host ""

    # Run the smoke test automatically
    $repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
    & "$repoRoot\scripts\smoke-test.ps1" -BaseUrl "http://localhost:8080"

    Write-Host ""
    Write-Host "Press Ctrl+C to stop port-forwarding when finished..." -ForegroundColor Yellow
    while ($true) {
        Start-Sleep -Seconds 5
    }
} finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Write-Host "Port-forward stopped." -ForegroundColor Yellow
    }
}
