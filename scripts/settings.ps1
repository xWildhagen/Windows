<#
    settings.ps1
    - Applies setting adjustments to windows
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== settings.ps1 ===" -ForegroundColor Blue

# 100% scaling corresponds to 96 DPI
$dpiValue   = 96
$desktopKey = 'HKCU:\Control Panel\Desktop'

# Ensure the key exists
if (-not (Test-Path $desktopKey)) {
    Write-Host "Creating missing key: $desktopKey" -ForegroundColor Blue
    New-Item -Path $desktopKey -Force | Out-Null
}

# Enable custom DPI scaling and set it to 100%
# Win8DpiScaling = 1 → use custom DPI
# LogPixels      = 96 (decimal) → 100% scaling
New-ItemProperty -Path $desktopKey -Name 'Win8DpiScaling' -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path $desktopKey -Name 'LogPixels'      -PropertyType DWord -Value $dpiValue -Force | Out-Null

Write-Host "Registry updated:" -ForegroundColor Blue
Write-Host "  HKCU\Control Panel\Desktop\Win8DpiScaling = 1"
Write-Host "  HKCU\Control Panel\Desktop\LogPixels      = $dpiValue (100% scale)"

# Try to nudge Windows to reload some settings (full effect still requires sign-out)
try {
    Write-Host "Triggering per-user system parameter update..." -ForegroundColor Blue
    & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
}
catch {
    Write-Warning "Could not run UpdatePerUserSystemParameters: $($_.Exception.Message)"
}

Write-Host "Done. Please sign out and back in (or reboot) to fully apply 100% scaling." -ForegroundColor Green

Write-Host "Log off now to apply changes (Y/N)? " -ForegroundColor Magenta -NoNewLine
$confirmLogoff = Read-Host

if ($confirmLogoff -match '^[Yy]$') {
    Write-Host "Logging off..." -ForegroundColor Blue
    Start-Process -FilePath "logoff.exe" -WindowStyle Hidden
}
else {
    Write-Host "Logoff skipped. You can log off later to apply scaling fully." -ForegroundColor Blue
}
