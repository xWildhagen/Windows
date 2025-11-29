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
# Taskbar "End task" option
# ---------------------------

$taskbarDevKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'

# Ensure the key exists
if (-not (Test-Path $taskbarDevKey)) {
    New-Item -Path $taskbarDevKey -Force | Out-Null
}

# Enable the "End task" button on taskbar right-click
New-ItemProperty -Path $taskbarDevKey `
                 -Name 'TaskbarEndTask' `
                 -PropertyType DWord `
                 -Value 1 `
                 -Force | Out-Null

Write-Host 'End task on taskbar enabled.' -ForegroundColor Blue

# ---------------------------
# Clipboard: history + sync
# ---------------------------

# Per-user clipboard settings (current user)
$clipboardKey = 'HKCU:\Software\Microsoft\Clipboard'

if (-not (Test-Path $clipboardKey)) {
    New-Item -Path $clipboardKey -Force | Out-Null
}

# Turn ON Clipboard history
New-ItemProperty -Path $clipboardKey `
                 -Name 'EnableClipboardHistory' `
                 -PropertyType DWord `
                 -Value 1 `
                 -Force | Out-Null

# Turn ON cloud clipboard + auto sync across devices
New-ItemProperty -Path $clipboardKey `
                 -Name 'EnableCloudClipboard' `
                 -PropertyType DWord `
                 -Value 1 `
                 -Force | Out-Null

# 1 = auto sync, 0 = manual sync
New-ItemProperty -Path $clipboardKey `
                 -Name 'CloudClipboardAutomaticUpload' `
                 -PropertyType DWord `
                 -Value 1 `
                 -Force | Out-Null

Write-Host "Clipboard history + cloud clipboard enabled for current user." -ForegroundColor Blue

# If running as admin, make sure no policies are BLOCKING clipboard history/sync
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        $systemPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'

        if (Test-Path $systemPolicyKey) {
            foreach ($name in 'AllowClipboardHistory','AllowCrossDeviceClipboard','EnableCloudClipboard','CloudClipboardAutomaticUpload') {
                try {
                    Remove-ItemProperty -Path $systemPolicyKey -Name $name -ErrorAction SilentlyContinue
                }
                catch {
                    # ignore if value doesn't exist / cannot be removed
                }
            }
        }

        Write-Host "Clipboard policy values reset to default (not blocking clipboard)." -ForegroundColor Blue
    }
}
catch {
    Write-Warning "Failed to adjust clipboard policy keys: $_"
}

# Make sure Clipboard User Service is running so changes actually apply
try {
    Get-Service -Name 'cbdhsvc*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -ne 'Running' } |
        Start-Service
}
catch {
    Write-Warning "Failed to start Clipboard User Service: $_"
}

# ---------------------------
# Windows optional features:
# Hyper-V, VM Platform, WHP,
# Sandbox, WSL
# ---------------------------

$features = @(
    'Microsoft-Hyper-V',                 # Hyper-V
    'VirtualMachinePlatform',            # Virtual Machine Platform
    'HypervisorPlatform',                # Windows Hypervisor Platform
    'Containers-DisposableClientVM',     # Windows Sandbox
    'Microsoft-Windows-Subsystem-Linux'  # Windows Subsystem for Linux (WSL)
)

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Skipping Windows optional features: run settings.ps1 as Administrator to enable Hyper-V, WSL, Sandbox, etc."
}
else {
    foreach ($feature in $features) {
        try {
            $result = Enable-WindowsOptionalFeature `
                -Online `
                -FeatureName $feature `
                -All `
                -NoRestart `
                -ErrorAction Stop

            if ($result.RestartNeeded) {
                Write-Host "$feature enabled (restart required)." -ForegroundColor Blue
            }
            else {
                Write-Host "$feature enabled." -ForegroundColor Blue
            }
        }
        catch {
            Write-Warning "Failed to enable ${feature}: $_ (feature may be unavailable on this edition of Windows)."
        }
    }
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
# Accent colour (#7A6D98)
# ---------------------------

$htmlAccentColor = '#7A6D98'

# Dark mode for system + apps, transparency on
$personalizeKey = 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
New-Item -Path $personalizeKey -Force | Out-Null

Set-ItemProperty -LiteralPath $personalizeKey -Name 'SystemUsesLightTheme' -Type DWord -Value 0 -Force
Set-ItemProperty -LiteralPath $personalizeKey -Name 'AppsUseLightTheme'   -Type DWord -Value 0 -Force
Set-ItemProperty -LiteralPath $personalizeKey -Name 'ColorPrevalence'     -Type DWord -Value 0 -Force
Set-ItemProperty -LiteralPath $personalizeKey -Name 'EnableTransparency'  -Type DWord -Value 1 -Force

Add-Type -AssemblyName 'System.Drawing'

$accentColor = [System.Drawing.ColorTranslator]::FromHtml($htmlAccentColor)

function ConvertTo-DWord {
    param(
        [System.Drawing.Color]$Color
    )

    [byte[]]$bytes = @(
        $Color.R
        $Color.G
        $Color.B
        $Color.A
    )

    [System.BitConverter]::ToUInt32($bytes, 0)
}

$accentKey = 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$dwmKey    = 'Registry::HKCU\Software\Microsoft\Windows\DWM'

New-Item -Path $accentKey -Force | Out-Null
New-Item -Path $dwmKey    -Force | Out-Null

# These are what the "Personalisation > Colours > Accent colour" UI reads
Set-ItemProperty -LiteralPath $accentKey -Name 'StartColorMenu'  -Type DWord -Value (ConvertTo-DWord $accentColor) -Force
Set-ItemProperty -LiteralPath $accentKey -Name 'AccentColorMenu' -Type DWord -Value (ConvertTo-DWord $accentColor) -Force
Set-ItemProperty -LiteralPath $dwmKey    -Name 'AccentColor'     -Type DWord -Value (ConvertTo-DWord $accentColor) -Force

# Optional: update palette so it also shows as the current swatch
try {
    $params = @{
        LiteralPath = $accentKey
        Name        = 'AccentPalette'
    }
    $palette = Get-ItemPropertyValue @params
    $index   = 20
    $palette[$index++] = $accentColor.R
    $palette[$index++] = $accentColor.G
    $palette[$index++] = $accentColor.B
    $palette[$index++] = $accentColor.A
    Set-ItemProperty @params -Value $palette -Type Binary -Force
}
catch {
    # AccentPalette might not exist yet – safe to ignore
}

Write-Host "Accent colour set to #7A6D98" -ForegroundColor Blue

# ---------------------------
# Desktop icon settings – hide Recycle Bin
# ---------------------------

$rbClsid = '{645FF040-5081-101B-9F08-00AA002F954E}'

$hideIconsBase = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons'
$newStartKey   = Join-Path $hideIconsBase 'NewStartPanel'
$classStartKey = Join-Path $hideIconsBase 'ClassicStartMenu'

foreach ($key in @($newStartKey, $classStartKey)) {
    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }

    # 1 = hidden, 0 = visible
    New-ItemProperty -Path $key `
                     -Name $rbClsid `
                     -PropertyType DWord `
                     -Value 1 `
                     -Force | Out-Null
}

Write-Host "Recycle Bin desktop icon disabled." -ForegroundColor Blue

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
