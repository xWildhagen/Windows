<#
    settings.ps1
    - Forces Windows display scaling to 100% (96 DPI) for the current user
    - Uses the documented LogPixels / Win8DpiScaling registry values
    - Sign-out / reboot is required for the change to fully apply
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== settings.ps1 ===" -ForegroundColor Blue
Write-Host "Setting display scaling to 100% for the current user..."

# 100% scaling corresponds to 96 DPI
$dpiValue   = 96
$desktopKey = 'HKCU:\Control Panel\Desktop'

# Ensure the key exists
if (-not (Test-Path $desktopKey)) {
    Write-Host "Creating missing key: $desktopKey"
    New-Item -Path $desktopKey -Force | Out-Null
}

# Enable custom DPI scaling and set it to 100%
# Win8DpiScaling = 1 → use custom DPI
# LogPixels      = 96 (decimal) → 100% scaling
New-ItemProperty -Path $desktopKey -Name 'Win8DpiScaling' -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path $desktopKey -Name 'LogPixels'      -PropertyType DWord -Value $dpiValue -Force | Out-Null

Write-Host "Registry updated:"
Write-Host "  HKCU\Control Panel\Desktop\Win8DpiScaling = 1"
Write-Host "  HKCU\Control Panel\Desktop\LogPixels      = $dpiValue (100% scale)" -ForegroundColor Green

# Try to nudge Windows to reload some settings (full effect still requires sign-out)
try {
    Write-Host "Triggering per-user system parameter update..."
    & rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True
}
catch {
    Write-Warning "Could not run UpdatePerUserSystemParameters: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Done. Please sign out and back in (or reboot) to fully apply 100% scaling." -ForegroundColor Yellow
