# agy-tier.ps1 - PowerShell script to run Antigravity CLI via mitmproxy on Windows
param(
    [string]$Port = "8085",
    [switch]$KeepMitmRunning,
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$AgyArgs
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MitmDir = Join-Path $env:USERPROFILE ".mitmproxy"
$CertPath = Join-Path $MitmDir "mitmproxy-ca-cert.cer"

# 1. Check for mitmdump
if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host "mitmdump not found. Installing mitmproxy..." -ForegroundColor Yellow
    pip install mitmproxy
    if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
        Write-Error "Could not find mitmdump. Please install mitmproxy manually: pip install mitmproxy"
        return
    }
}

# 2. Generate CA certificate on first run if missing
if (-not (Test-Path -Path $CertPath)) {
    Write-Host "Generating mitmproxy CA certificate..." -ForegroundColor Yellow
    $genJob = Start-Process mitmdump -ArgumentList "-q" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    if ($genJob -and (-not $genJob.HasExited)) {
        Stop-Process -Id $genJob.Id -Force -ErrorAction SilentlyContinue
    }
}

# 3. Add certificate to CurrentUser Root store if not already added
$certExists = Get-ChildItem -Path Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Subject -like "*mitmproxy*" }
if ((-not $certExists) -and (Test-Path -Path $CertPath)) {
    Write-Host "Adding mitmproxy CA to trusted root certificates..." -ForegroundColor Yellow
    certutil -addstore -user Root "$CertPath"
}

# 4. Check if mitmdump is already running on the port
$spawnedMitm = $null
$portOpen = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $portOpen) {
    Write-Host "Starting mitmdump on port $Port..." -ForegroundColor Cyan
    $mitmArgs = "-s `"$ScriptDir\tier-fix.py`" --listen-host 127.0.0.1 --listen-port $Port --allow-hosts `"daily-cloudcode-pa\.googleapis\.com`""
    $spawnedMitm = Start-Process mitmdump -ArgumentList $mitmArgs -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

# 5. Set proxy env vars and run agy
$env:HTTP_PROXY = "http://127.0.0.1:$Port"
$env:HTTPS_PROXY = "http://127.0.0.1:$Port"

try {
    Write-Host "Launching agy with tier fix..." -ForegroundColor Green
    & agy @AgyArgs
} finally {
    # 6. Stop mitmdump after agy completes if spawned by this invocation
    if ($spawnedMitm -and (-not $KeepMitmRunning) -and (-not $spawnedMitm.HasExited)) {
        Write-Host "Stopping mitmdump background process..." -ForegroundColor Cyan
        Stop-Process -Id $spawnedMitm.Id -Force -ErrorAction SilentlyContinue
    }
}
