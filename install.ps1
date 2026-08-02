# install.ps1 - Install agy-tier-fix to a standalone folder and setup agys alias
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\agy-tier-fix"
)

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Installing agy-tier-fix ===" -ForegroundColor Cyan
Write-Host "Target directory: $InstallDir" -ForegroundColor Yellow

# 1. Create installation directory
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 2. Copy project files
Copy-Item -Path "$SourceDir\tier-fix.py" -Destination "$InstallDir\tier-fix.py" -Force
Copy-Item -Path "$SourceDir\agy-tier.ps1" -Destination "$InstallDir\agy-tier.ps1" -Force
if (Test-Path -Path "$SourceDir\uninstall.ps1") {
    Copy-Item -Path "$SourceDir\uninstall.ps1" -Destination "$InstallDir\uninstall.ps1" -Force
}

# 3. Check / install mitmproxy
if (-not (Get-Command mitmdump -ErrorAction SilentlyContinue)) {
    Write-Host "Installing mitmproxy via pip..." -ForegroundColor Yellow
    pip install mitmproxy
}

# 4. Generate & trust mitmproxy CA certificate
$CertPath = Join-Path $env:USERPROFILE ".mitmproxy\mitmproxy-ca-cert.cer"
if (-not (Test-Path -Path $CertPath)) {
    Write-Host "Generating mitmproxy CA certificate..." -ForegroundColor Yellow
    $job = Start-Process mitmdump -ArgumentList "-q" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    if ($job -and (-not $job.HasExited)) {
        Stop-Process -Id $job.Id -Force -ErrorAction SilentlyContinue
    }
}

$certExists = Get-ChildItem -Path Cert:\CurrentUser\Root -ErrorAction SilentlyContinue | Where-Object { $_.Subject -like "*mitmproxy*" }
if ((-not $certExists) -and (Test-Path -Path $CertPath)) {
    Write-Host "Adding mitmproxy CA to trusted root certificates..." -ForegroundColor Yellow
    certutil -addstore -user Root "$CertPath"
}

# 5. Add agys function to both PowerShell 5.1 and PowerShell Core profiles if available
$TargetProfiles = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

$AliasLine = 'function agys { & "' + $InstallDir + '\agy-tier.ps1" $args }'
$FullAliasBlock = "`n# === agy-tier-fix alias ===`n" + $AliasLine + "`n"

foreach ($Prof in $TargetProfiles) {
    $ProfDir = Split-Path -Parent $Prof
    if (-not (Test-Path -Path $ProfDir)) {
        New-Item -ItemType Directory -Path $ProfDir -Force | Out-Null
    }
    if (-not (Test-Path -Path $Prof)) {
        New-Item -ItemType File -Path $Prof -Force | Out-Null
    }

    $ProfContent = Get-Content -Path $Prof -Raw -ErrorAction SilentlyContinue
    if ((-not $ProfContent) -or ($ProfContent -notmatch "function agys")) {
        Add-Content -Path $Prof -Value $FullAliasBlock
        Write-Host "Alias 'agys' added to $Prof" -ForegroundColor Green
    } else {
        Write-Host "Alias 'agys' is already in $Prof" -ForegroundColor Yellow
    }
}

Write-Host "`nInstallation successfully completed!" -ForegroundColor Green
Write-Host "Restart PowerShell or run: . `$PROFILE" -ForegroundColor Cyan
Write-Host "Usage: agys -p `"your prompt`"" -ForegroundColor Cyan
Write-Host "To uninstall run: powershell -File `"$InstallDir\uninstall.ps1`"" -ForegroundColor Gray
