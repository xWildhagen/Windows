<#
    settings.ps1
    - Applies setting adjustments to Windows
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== settings.ps1 ===" -ForegroundColor Blue

# ---------------------------
# Paths (HOME_FOLDER\windows)
# ---------------------------
$homeFolder   = [Environment]::GetFolderPath('UserProfile')  # "HOME_FOLDER"
$repoRoot     = Join-Path $homeFolder 'windows'
$assetsRoot   = Join-Path $repoRoot 'assets'

$wallpaperPath  = Join-Path $assetsRoot 'aurora.png'       # Desktop wallpaper (source)
$lockScreenPath = Join-Path $assetsRoot 'aurora.png'       # Lock screen image (source, separate var)
$profilePicPath = Join-Path $assetsRoot 'catppuccin.png'   # Account picture

Write-Host "Repo root:        $repoRoot"
Write-Host "Wallpaper image:  $wallpaperPath"
Write-Host "Lock screen:      $lockScreenPath"
Write-Host "Profile picture:  $profilePicPath"

# ---------------------------
# Set 100% display scaling
# ---------------------------

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

Write-Host "DPI scaling set to 100% (LogPixels=$dpiValue)." -ForegroundColor Blue

# ---------------------------
# Power plan: display & sleep
# ---------------------------

# Plugged in (AC)
# - Turn screen off after 30 minutes
# - Sleep after 60 minutes
powercfg /change monitor-timeout-ac 30     # minutes
$acMonitorExitCode = $LASTEXITCODE

powercfg /change standby-timeout-ac 60     # minutes
$acSleepExitCode = $LASTEXITCODE

# On battery (DC)
# - Turn screen off after 15 minutes
# - Sleep after 30 minutes
powercfg /change monitor-timeout-dc 15     # minutes
$dcMonitorExitCode = $LASTEXITCODE

powercfg /change standby-timeout-dc 30     # minutes
$dcSleepExitCode = $LASTEXITCODE

if ($acMonitorExitCode -ne 0 -or
    $acSleepExitCode   -ne 0 -or
    $dcMonitorExitCode -ne 0 -or
    $dcSleepExitCode   -ne 0) {

    Write-Warning "One or more powercfg commands may have failed. Try running this script in an elevated PowerShell session."
}
else {
    Write-Host "Display and sleep timeouts configured." -ForegroundColor Blue
}

# ---------------------------
# Energy Saver: auto threshold
# ---------------------------

Write-Host "Configuring Energy Saver threshold." -ForegroundColor Blue

# On battery: turn Energy Saver on automatically at 20%
powercfg /setdcvalueindex SCHEME_CURRENT SUB_ENERGYSAVER ESBATTTHRESHOLD 20
$esThresholdExitCode = $LASTEXITCODE

if ($esThresholdExitCode -ne 0) {
    Write-Warning "Failed to configure Energy Saver threshold (code $esThresholdExitCode). Try running this script as Administrator."
}
else {
    Write-Host "Energy Saver will turn on automatically at 20% battery." -ForegroundColor Blue
}

# ---------------------------
# Night light schedule (20:00-06:00)
# ---------------------------

function Set-BlueLightReductionSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateRange(0, 23)][int]$StartHour,
        [Parameter(Mandatory = $true)][ValidateSet(0, 15, 30, 45)][int]$StartMinutes,
        [Parameter(Mandatory = $true)][ValidateRange(0, 23)][int]$EndHour,
        [Parameter(Mandatory = $true)][ValidateSet(0, 15, 30, 45)][int]$EndMinutes,
        [Parameter(Mandatory = $true)][bool]$Enabled,
        [Parameter(Mandatory = $true)][ValidateRange(1200, 6500)][int]$NightColorTemperature
    )

    # Build Night light settings blob (CloudStore format for 20H2+/11)
    $data = (0x43, 0x42, 0x01, 0x00, 0x0A, 0x02, 0x01, 0x00, 0x2A, 0x06)

    $epochTime = [System.DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
    $data += $epochTime -band 0x7F -bor 0x80
    $data += ($epochTime -shr 7)  -band 0x7F -bor 0x80
    $data += ($epochTime -shr 14) -band 0x7F -bor 0x80
    $data += ($epochTime -shr 21) -band 0x7F -bor 0x80
    $data +=  $epochTime -shr 28

    $data += (0x2A, 0x2B, 0x0E, 0x1D, 0x43, 0x42, 0x01, 0x00)

    if ($Enabled) {
        $data += (0x02, 0x01)
    }

    $data += (0xCA, 0x14, 0x0E)
    $data += $StartHour
    $data += 0x2E
    $data += $StartMinutes
    $data += (0x00, 0xCA, 0x1E, 0x0E)
    $data += $EndHour
    $data += 0x2E
    $data += $EndMinutes
    $data += (0x00, 0xCF, 0x28)

    $data += ($NightColorTemperature -band 0x3F) * 2 + 0x80
    $data += ($NightColorTemperature -shr 6)

    $data += (0xCA, 0x32, 0x00, 0xCA, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00)

    # Ensure registry path exists:
    $cloudStoreBase    = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore'
    if (-not (Test-Path $cloudStoreBase)) {
        New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion' -Name 'CloudStore' -Force | Out-Null
    }

    $storeKey          = Join-Path $cloudStoreBase 'Store'
    if (-not (Test-Path $storeKey)) {
        New-Item -Path $cloudStoreBase -Name 'Store' -Force | Out-Null
    }

    $defaultAccountKey = Join-Path $storeKey 'DefaultAccount'
    if (-not (Test-Path $defaultAccountKey)) {
        New-Item -Path $storeKey -Name 'DefaultAccount' -Force | Out-Null
    }

    $blueLightKeyRoot  = Join-Path $defaultAccountKey 'Current'
    if (-not (Test-Path $blueLightKeyRoot)) {
        New-Item -Path $defaultAccountKey -Name 'Current' -Force | Out-Null
    }

    $blueLightOuter    = Join-Path $blueLightKeyRoot 'default$windows.data.bluelightreduction.settings'
    if (-not (Test-Path $blueLightOuter)) {
        New-Item -Path $blueLightKeyRoot -Name 'default$windows.data.bluelightreduction.settings' -Force | Out-Null
    }

    $blueLightKey      = Join-Path $blueLightOuter 'windows.data.bluelightreduction.settings'
    if (-not (Test-Path $blueLightKey)) {
        New-Item -Path $blueLightOuter -Name 'windows.data.bluelightreduction.settings' -Force | Out-Null
    }

    Set-ItemProperty -Path $blueLightKey -Name 'Data' -Value ([byte[]]$data) -Type Binary
}

try {
    # 20:00 → 06:00, enabled, moderate colour temperature
    Set-BlueLightReductionSettings -StartHour 20 -StartMinutes 0 -EndHour 6 -EndMinutes 0 -Enabled $true -NightColorTemperature 4500
    Write-Host "Night light schedule set to 20:00–06:00." -ForegroundColor Blue
}
catch {
    Write-Warning "Failed to configure Night light schedule: $_"
}

# ---------------------------
# Wallpaper (current user)
# ---------------------------

function Set-CustomWallpaper {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Wallpaper file not found: $Path"
        return
    }

    # Update registry so Windows knows about the image
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'Wallpaper' -Value $Path

    # Use user32.dll SystemParametersInfo to apply it immediately
    $src = @'
using System;
using System.Runtime.InteropServices;

public class WallpaperHelper
{
    public const int SetDesktopWallpaper = 20;
    public const int UpdateIniFile       = 0x01;
    public const int SendWinIniChange    = 0x02;

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(
        int uAction, int uParam, string lpvParam, int fuWinIni);

    public static void SetWallpaper(string path)
    {
        SystemParametersInfo(SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange);
    }
}
'@

    if (-not ("WallpaperHelper" -as [Type])) {
        Add-Type -TypeDefinition $src -ErrorAction Stop
    }

    [WallpaperHelper]::SetWallpaper($Path)
    Write-Host "Wallpaper set." -ForegroundColor Blue
}

# ---------------------------
# Lock screen (policy + CSP, all users)
# ---------------------------

function Set-LockScreenImage {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Lock screen image file not found: $Path"
        return
    }

    # This writes to HKLM, so it must be run elevated.
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Warning "Skipping lock screen: settings.ps1 must be run as Administrator to change it."
        return
    }

    # Convert/copy the source image to a machine-wide JPG so system can always read it
    $lockDestRoot = Join-Path $env:ProgramData 'WindowsLockScreen'
    if (-not (Test-Path $lockDestRoot)) {
        New-Item -Path $lockDestRoot -ItemType Directory -Force | Out-Null
    }

    $lockDestFile = Join-Path $lockDestRoot 'LockScreen.jpg'

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

        $srcImage = [System.Drawing.Image]::FromFile($Path)
        try {
            $srcImage.Save($lockDestFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        }
        finally {
            $srcImage.Dispose()
        }
    }
    catch {
        # If conversion fails for some reason, fall back to just copying the file
        Copy-Item -LiteralPath $Path -Destination $lockDestFile -Force
    }

    $targetPath = $lockDestFile

    # 1) Group Policy-style key
    $personalizationKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
    if (-not (Test-Path $personalizationKey)) {
        New-Item -Path $personalizationKey -Force | Out-Null
    }

    New-ItemProperty -Path $personalizationKey -Name 'LockScreenImage'            -PropertyType String -Value $targetPath -Force | Out-Null
    New-ItemProperty -Path $personalizationKey -Name 'NoLockScreenSlideshow'      -PropertyType DWord  -Value 1          -Force | Out-Null
    New-ItemProperty -Path $personalizationKey -Name 'NoChangingLockScreen'       -PropertyType DWord  -Value 1          -Force | Out-Null
    New-ItemProperty -Path $personalizationKey -Name 'LockScreenOverlaysDisabled' -PropertyType DWord  -Value 1          -Force | Out-Null

    # 2) PersonalizationCSP keys (used by newer builds / MDM)
    $cspKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
    if (-not (Test-Path $cspKey)) {
        New-Item -Path $cspKey -Force | Out-Null
    }

    New-ItemProperty -Path $cspKey -Name 'LockScreenImageStatus' -PropertyType DWord  -Value 1          -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name 'LockScreenImagePath'   -PropertyType String -Value $targetPath -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name 'LockScreenImageUrl'    -PropertyType String -Value $targetPath -Force | Out-Null

    Write-Host "Lock screen image set to $targetPath." -ForegroundColor Blue
}

# ---------------------------
# Account picture (profile)
# ---------------------------

function Set-CustomAccountPicture {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Profile picture file not found: $Path"
        return
    }

    # This part writes to HKLM, so it needs an elevated session.
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Warning "Skipping profile picture: settings.ps1 must be run as Administrator to change it."
        return
    }

    # Current user SID
    $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

    # Folder used by Windows for account pictures: %PUBLIC%\AccountPictures\<SID>
    $accountPicturesRoot = Join-Path $env:PUBLIC 'AccountPictures'
    $userPicturesDir     = Join-Path $accountPicturesRoot $userSid

    if (Test-Path $userPicturesDir) {
        Remove-Item $userPicturesDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $userPicturesDir -ItemType Directory -Force | Out-Null

    # Create multiple sizes from the source PNG – Windows expects several ImageXX entries.
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

    $sizes = @(32, 40, 48, 96, 192, 240, 448)
    $sourceImage = [System.Drawing.Image]::FromFile($Path)

    try {
        foreach ($size in $sizes) {
            $destFile = Join-Path $userPicturesDir ("Image{0}.png" -f $size)

            $bmp      = New-Object System.Drawing.Bitmap ($size, $size)
            $graphics = [System.Drawing.Graphics]::FromImage($bmp)

            try {
                $graphics.InterpolationMode  = 'HighQualityBicubic'
                $graphics.SmoothingMode      = 'HighQuality'
                $graphics.PixelOffsetMode    = 'HighQuality'
                $graphics.CompositingQuality = 'HighQuality'

                $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
            }
            finally {
                $graphics.Dispose()
            }

            $bmp.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
        }
    }
    finally {
        $sourceImage.Dispose()
    }

    # Point registry to the generated images:
    # HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\<SID>\ImageXX
    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$userSid"
    if (-not (Test-Path $regKey)) {
        New-Item -Path $regKey -Force | Out-Null
    }

    foreach ($size in $sizes) {
        $valueName = "Image{0}" -f $size
        $valuePath = Join-Path $userPicturesDir ("Image{0}.png" -f $size)

        New-ItemProperty -Path $regKey -Name $valueName -PropertyType String -Value $valuePath -Force | Out-Null
    }

    Write-Host "Profile picture set for SID $userSid." -ForegroundColor Blue
}

# ---------------------------
# Apply wallpaper + lock screen + profile
# ---------------------------

try {
    Set-CustomWallpaper -Path $wallpaperPath
}
catch {
    Write-Warning "Failed to set wallpaper: $_"
}

try {
    Set-LockScreenImage -Path $lockScreenPath
}
catch {
    Write-Warning "Failed to set lock screen image: $_"
}

try {
    Set-CustomAccountPicture -Path $profilePicPath
}
catch {
    Write-Warning "Failed to set profile picture: $_"
}

Write-Host "Done. Please sign out and back in (or reboot) to fully apply changes." -ForegroundColor Green

Write-Host "  [L] Log off"    -ForegroundColor Blue
Write-Host "  [R] Reboot"     -ForegroundColor Blue
Write-Host "  [N] Do nothing" -ForegroundColor Blue

Write-Host "Choose an option (L/R/N): " -ForegroundColor Magenta -NoNewLine
$action = Read-Host

switch -Regex ($action) {
    '^[Ll]$' {
        Write-Host "Logging off..." -ForegroundColor Blue
        Start-Process -FilePath "logoff.exe" -WindowStyle Hidden
    }
    '^[Rr]$' {
        Write-Host "Rebooting..." -ForegroundColor Blue
        Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 0" -WindowStyle Hidden
    }
    default {
        Write-Host "No action selected. You can log off or reboot later to apply all changes fully." -ForegroundColor Blue
    }
}
