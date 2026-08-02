# uninstall.ps1 - Uninstall agy-tier-fix from Windows
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\agy-tier-fix"
)

Write-Host "=== Uninstalling agy-tier-fix ===" -ForegroundColor Yellow

# 1. Stop mitmdump processes if running
$mitmProcs = Get-Process mitmdump -ErrorAction SilentlyContinue
if ($mitmProcs) {
    Write-Host "Stopping mitmdump background process..." -ForegroundColor Cyan
    $mitmProcs | Stop-Process -Force -ErrorAction SilentlyContinue
}

# 2. Remove alias from PowerShell Profiles
$TargetProfiles = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

foreach ($Prof in $TargetProfiles) {
    if (Test-Path -Path $Prof) {
        $ProfileContent = Get-Content -Path $Prof -Raw -ErrorAction SilentlyContinue
        if ($ProfileContent -and ($ProfileContent -match "function agys")) {
            Write-Host "Removing 'agys' alias from $Prof..." -ForegroundColor Cyan
            $NewContent = $ProfileContent -replace "(?s)# === agy-tier-fix alias ===.*?function agys \{.*?\}\r?\n?", ""
            Set-Content -Path $Prof -Value $NewContent -Force
        }
    }
}

# 3. Delete installation folder
if (Test-Path -Path $InstallDir) {
    Write-Host "Removing installation folder $InstallDir..." -ForegroundColor Cyan
    Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nagy-tier-fix successfully uninstalled!" -ForegroundColor Green
Write-Host "Restart PowerShell for profile changes to take effect." -ForegroundColor Gray
