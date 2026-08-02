# agy-tier.ps1 - PowerShell script to run Antigravity CLI via mitmproxy on Windows

# AGY_MITM_PORT is the *starting* port; if it is taken by a foreign process the
# next free one is used.
$Port = if ($env:AGY_MITM_PORT) { [int]$env:AGY_MITM_PORT } else { 8085 }
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

# 4. Pick a port. A busy port must not be reused blindly: if a foreign process
# holds it, agy would be proxied through something unknown. Our own mitmdump
# (running tier-fix.py) is reused; anything else makes us move to the next port.
function Test-PortBusy([int]$p) {
    [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)
}

function Test-PortIsOurs([int]$p) {
    $conns = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $($c.OwningProcess)" -ErrorAction SilentlyContinue
        if ($proc -and $proc.CommandLine -match 'tier-fix\.py') { return $true }
    }
    return $false
}

$StartPort = $Port
$reuse = $false
$portFound = $false
for ($i = 0; $i -lt 50; $i++) {
    if (-not (Test-PortBusy $Port)) { $portFound = $true; break }
    if (Test-PortIsOurs $Port) { $portFound = $true; $reuse = $true; break }
    $Port++
}
if (-not $portFound) {
    Write-Error "No free port found in range $StartPort-$($StartPort + 49)"
    return
}
if ($Port -ne $StartPort) {
    Write-Host "Port $StartPort is taken by another process, using $Port" -ForegroundColor Yellow
}

# 5. Start mitmdump unless an existing one is being reused
$spawnedMitm = $null
if (-not $reuse) {
    Write-Host "Starting mitmdump on port $Port..." -ForegroundColor Cyan
    $mitmArgs = "-s `"$ScriptDir\tier-fix.py`" --listen-host 127.0.0.1 --listen-port $Port --allow-hosts `"daily-cloudcode-pa\.googleapis\.com`""
    $spawnedMitm = Start-Process mitmdump -ArgumentList $mitmArgs -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

# 6. Set proxy env vars and run agy
$env:HTTP_PROXY = "http://127.0.0.1:$Port"
$env:HTTPS_PROXY = "http://127.0.0.1:$Port"

try {
    Write-Host "Launching agy with tier fix..." -ForegroundColor Green
    & agy @args
} finally {
    # Clean up proxy environment variables from current session
    Remove-Item Env:\HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:\HTTPS_PROXY -ErrorAction SilentlyContinue

    # 7. Stop mitmdump after agy completes if spawned by this invocation
    if ($spawnedMitm -and (-not $spawnedMitm.HasExited)) {
        Write-Host "Stopping mitmdump background process..." -ForegroundColor Cyan
        Stop-Process -Id $spawnedMitm.Id -Force -ErrorAction SilentlyContinue
    }
}
