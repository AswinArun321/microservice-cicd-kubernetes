# Helper script to launch all 3 microservices locally in background processes (No Docker required)
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName

Write-Host "Starting Auth Service on port 5001..." -ForegroundColor Cyan
$authProc = Start-Process python -ArgumentList "-m uvicorn app.main:app --port 5001" -WorkingDirectory "$repoRoot\auth" -PassThru -WindowStyle Hidden

Write-Host "Starting API Service on port 5002..." -ForegroundColor Cyan
$apiProc = Start-Process python -ArgumentList "-m uvicorn app.main:app --port 5002" -WorkingDirectory "$repoRoot\api" -PassThru -WindowStyle Hidden

Write-Host "Starting Worker Service on port 5003..." -ForegroundColor Cyan
$workerProc = Start-Process python -ArgumentList "-m uvicorn app.main:app --port 5003" -WorkingDirectory "$repoRoot\worker" -PassThru -WindowStyle Hidden

# Store process IDs in a temporary file for easy teardown
$pids = @($authProc.Id, $apiProc.Id, $workerProc.Id)
$pids | Out-File "$repoRoot\.local_services.pid"

Write-Host "Waiting 3 seconds for services to bind ports..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Write-Host "All 3 microservices started in background! (PIDs: $($pids -join ', '))" -ForegroundColor Green
Write-Host "Run '.\scripts\smoke-test.ps1' to test, and '.\scripts\stop-local.ps1' to stop them." -ForegroundColor Yellow

