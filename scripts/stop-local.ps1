# Helper script to stop local microservice background processes
$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$pidFile = "$repoRoot\.local_services.pid"

if (Test-Path $pidFile) {
    $pids = Get-Content $pidFile
    foreach ($p in $pids) {
        try {
            Stop-Process -Id [int]$p -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped process $p" -ForegroundColor Green
        } catch {
            # Ignore if already stopped
        }
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    Write-Host "Local background microservices stopped." -ForegroundColor Green
} else {
    # Fallback: stop any python processes listening on ports 5001, 5002, 5003
    $ports = @(5001, 5002, 5003)
    foreach ($port in $ports) {
        $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        foreach ($conn in $conns) {
            if ($conn.OwningProcess -gt 0) {
                Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
                Write-Host "Stopped process on port $port (PID: $($conn.OwningProcess))" -ForegroundColor Green
            }
        }
    }
}
