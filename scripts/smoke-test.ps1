# Smoke test PowerShell script for microservice-cicd-kubernetes
param (
    [string]$BaseUrl = ""
)

$ErrorActionPreference = "Stop"

if ($BaseUrl -ne "") {
    $AuthUrl = "$BaseUrl/auth"
    $ApiUrl = "$BaseUrl/api"
    $WorkerUrl = "$BaseUrl/worker"
} else {
    $AuthUrl = "http://localhost:5001"
    $ApiUrl = "http://localhost:5002"
    $WorkerUrl = "http://localhost:5003"
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Starting Microservices Smoke Test" -ForegroundColor Cyan
Write-Host " Auth Endpoint:   $AuthUrl"
Write-Host " API Endpoint:    $ApiUrl"
Write-Host " Worker Endpoint: $WorkerUrl"
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Health Checks
Write-Host -NoNewline "[1/5] Checking Auth Service Health... "
$authHealth = Invoke-RestMethod -Uri "$AuthUrl/health" -Method Get
if ($authHealth.status -eq "healthy") { Write-Host "PASSED" -ForegroundColor Green } else { throw "Auth health check failed" }

Write-Host -NoNewline "[2/5] Checking API Service Health... "
$apiHealth = Invoke-RestMethod -Uri "$ApiUrl/health" -Method Get
if ($apiHealth.status -eq "healthy") { Write-Host "PASSED" -ForegroundColor Green } else { throw "API health check failed" }

Write-Host -NoNewline "[3/5] Checking Worker Service Health... "
$workerHealth = Invoke-RestMethod -Uri "$WorkerUrl/health" -Method Get
if ($workerHealth.status -eq "healthy") { Write-Host "PASSED" -ForegroundColor Green } else { throw "Worker health check failed" }

# 2. Authentication & JWT Verification
Write-Host -NoNewline "[4/5] Testing User Authentication & Token Issuance... "
$loginBody = @{
    username = "admin"
    password = "admin123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "$AuthUrl/login" -Method Post -Body $loginBody -ContentType "application/json"
$token = $loginResponse.access_token

if (-not [string]::IsNullOrEmpty($token)) {
    Write-Host "PASSED (Token generated)" -ForegroundColor Green
} else {
    throw "Authentication failed: No access token returned"
}

Write-Host -NoNewline "      Verifying JWT Token... "
$verifyBody = @{
    token = $token
} | ConvertTo-Json

$verifyResponse = Invoke-RestMethod -Uri "$AuthUrl/verify" -Method Post -Body $verifyBody -ContentType "application/json"
if ($verifyResponse.valid -eq $true) {
    Write-Host "PASSED" -ForegroundColor Green
} else {
    throw "JWT verification failed"
}

# 3. Data Service & Worker Job Dispatch
Write-Host -NoNewline "[5/5] Testing API Data & Worker Queue... "
try {
    $apiData = Invoke-RestMethod -Uri "$ApiUrl/data" -Method Get
} catch {
    $apiData = Invoke-RestMethod -Uri "$ApiUrl/api/data" -Method Get
}

$jobBody = @{
    task_type = "smoke_test_verification"
    payload = @{ source = "e2e-powershell-smoke-test" }
} | ConvertTo-Json

$jobResponse = Invoke-RestMethod -Uri "$WorkerUrl/jobs" -Method Post -Body $jobBody -ContentType "application/json"
if ($jobResponse.message -match "accepted") {
    Write-Host "PASSED" -ForegroundColor Green
} else {
    throw "Worker job dispatch failed"
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " ALL SMOKE TESTS PASSED SUCCESSFULLY! " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

