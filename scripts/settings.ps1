<#
    settings.ps1
    - Applies setting adjustments to Windows
    - Menu-driven: run each section individually, or run all
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== settings.ps1 ===" -ForegroundColor Blue

# ---------------------------
# Helpers
# ---------------------------
function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$IsAdmin = Test-IsAdmin

function Write-Section($Title) {
    Write-Host ""
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

# ---------------------------
# Paths (HOME_FOLDER\Windows)
# ---------------------------
$homeFolder   = [Environment]::GetFolderPath('UserProfile')  # "HOME_FOLDER"
$repoRoot     = Join-Path $homeFolder 'Windows'
$assetsRoot   = Join-Path $repoRoot 'assets'

$wallpaperPath  = Join-Path $assetsRoot 'aurora.png'       # Desktop wallpaper (source)
$lockScreenPath = Join-Path $assetsRoot 'aurora.png'       # Lock screen image (source)
$profilePicPath = Join-Path $assetsRoot 'catppuccin.png'   # Account picture

Write-Host "Repo root:        $repoRoot"
Write-Host "Wallpaper image:  $wallpaperPath"
Write-Host "Lock screen:      $lockScreenPath"
Write-Host "Profile picture:  $profilePicPath"
Write-Host "Admin:            $IsAdmin"
Write-Host ""

# =====================================================================
# 1) DISPLAY: 100% scaling
# =====================================================================
function Set-DisplayScaling100 {
    Write-Section "Display: 100% scaling"

    $dpiValue   = 96
    $desktopKey = 'HKCU:\Control Panel\Desktop'

    if (-not (Test-Path $desktopKey)) {
        Write-Host "Creating missing key: $desktopKey" -ForegroundColor Blue
        New-Item -Path $desktopKey -Force | Out-Null
    }

    New-ItemProperty -Path $desktopKey -Name 'Win8DpiScaling' -PropertyType DWord -Value 1         -Force | Out-Null
    New-ItemProperty -Path $desktopKey -Name 'LogPixels'      -PropertyType DWord -Value $dpiValue -Force | Out-Null

    Write-Host "System > Display > Scale set." -ForegroundColor Blue
}

# =====================================================================
# 2) POWER: screen off & sleep time-outs
# =====================================================================
function Set-PowerTimeouts {
    Write-Section "Power: time-outs"

    powercfg /change monitor-timeout-ac 30
    $acMonitorExitCode = $LASTEXITCODE

    powercfg /change standby-timeout-ac 60
    $acSleepExitCode = $LASTEXITCODE

    powercfg /change monitor-timeout-dc 15
    $dcMonitorExitCode = $LASTEXITCODE

    powercfg /change standby-timeout-dc 30
    $dcSleepExitCode = $LASTEXITCODE

    if (    $acMonitorExitCode -ne 0 `
         -or $acSleepExitCode   -ne 0 `
         -or $dcMonitorExitCode -ne 0 `
         -or $dcSleepExitCode   -ne 0) {

        Write-Warning "One or more powercfg commands may have failed. Try running this script in an elevated PowerShell session."
    }
    else {
        Write-Host "System > Power & battery > Screen, sleep & hibernate time-outs set." -ForegroundColor Blue
    }
}

# =====================================================================
# 3) ENERGY SAVER: automatic threshold
# =====================================================================
function Set-EnergySaverThreshold {
    Write-Section "Energy Saver: threshold"

    powercfg /setdcvalueindex SCHEME_CURRENT SUB_ENERGYSAVER ESBATTTHRESHOLD 20
    $esThresholdExitCode = $LASTEXITCODE

    if ($esThresholdExitCode -ne 0) {
        Write-Warning "Failed to configure Energy Saver threshold (code $esThresholdExitCode). Try running this script as Administrator."
    }
    else {
        Write-Host "System > Power & battery > Energy saver set." -ForegroundColor Blue
    }
}

# =====================================================================
# 4) CLIPBOARD: history + cloud sync
# =====================================================================
function Set-ClipboardSettings {
    Write-Section "Clipboard: history + cloud sync"

    $clipboardKey = 'HKCU:\Software\Microsoft\Clipboard'

    if (-not (Test-Path $clipboardKey)) {
        New-Item -Path $clipboardKey -Force | Out-Null
    }

    New-ItemProperty -Path $clipboardKey -Name 'EnableClipboardHistory'            -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $clipboardKey -Name 'EnableCloudClipboard'              -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $clipboardKey -Name 'CloudClipboardAutomaticUpload'     -PropertyType DWord -Value 1 -Force | Out-Null

    Write-Host "System > Clipboard set." -ForegroundColor Blue

    # If admin, remove policies that might block it
    if ($script:IsAdmin) {
        try {
            $systemPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
            if (Test-Path $systemPolicyKey) {
                foreach ($name in 'AllowClipboardHistory','AllowCrossDeviceClipboard','EnableCloudClipboard','CloudClipboardAutomaticUpload') {
                    Remove-ItemProperty -Path $systemPolicyKey -Name $name -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Warning "Failed to adjust clipboard policy keys: $_"
        }
    }

    # Make sure Clipboard User Service is running
    try {
        Get-Service -Name 'cbdhsvc*' -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -ne 'Running' } |
            Start-Service
    }
    catch {
        Write-Warning "Failed to start Clipboard User Service: $_"
    }
}

# =====================================================================
# 5) WINDOWS OPTIONAL FEATURES
# =====================================================================
function Enable-WindowsFeatures {
    Write-Section "Windows Optional Features: Hyper-V, WSL, Sandbox"

    $features = @(
        'Microsoft-Hyper-V',
        'VirtualMachinePlatform',
        'HypervisorPlatform',
        'Containers-DisposableClientVM',
        'Microsoft-Windows-Subsystem-Linux'
    )

    if (-not $script:IsAdmin) {
        Write-Warning "Skipping Windows optional features: run settings.ps1 as Administrator to enable Hyper-V, WSL, Sandbox, etc."
        return
    }

    foreach ($feature in $features) {
        try {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
            if ($result.RestartNeeded) {
                Write-Host "$feature enabled (restart required)." -ForegroundColor Blue
            } else {
                Write-Host "$feature enabled." -ForegroundColor Blue
            }
        }
        catch {
            Write-Warning "Failed to enable ${feature}: $_ (feature may be unavailable on this edition of Windows)."
        }
    }
}

# =====================================================================
# 6) WALLPAPER (current user)
# =====================================================================
function Set-CustomWallpaper {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Wallpaper file not found: $Path"
        return
    }

    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'Wallpaper' -Value $Path

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
    Write-Host "Personalisation > Background set." -ForegroundColor Blue
}

function Apply-Wallpaper {
    Write-Section "Wallpaper"
    try { Set-CustomWallpaper -Path $script:wallpaperPath }
    catch { Write-Warning "Failed to set wallpaper: $_" }
}

# =====================================================================
# 7) LOCK SCREEN (policy + CSP, all users)
# =====================================================================
function Set-LockScreenImage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Lock screen image file not found: $Path"
        return
    }

    if (-not $script:IsAdmin) {
        Write-Warning "Skipping lock screen: settings.ps1 must be run as Administrator to change it."
        return
    }

    $lockDestRoot = Join-Path $env:ProgramData 'WindowsLockScreen'
    if (-not (Test-Path $lockDestRoot)) {
        New-Item -Path $lockDestRoot -ItemType Directory -Force | Out-Null
    }

    $lockDestFile = Join-Path $lockDestRoot 'LockScreen.jpg'

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        $srcImage = [System.Drawing.Image]::FromFile($Path)
        try { $srcImage.Save($lockDestFile, [System.Drawing.Imaging.ImageFormat]::Jpeg) }
        finally { $srcImage.Dispose() }
    }
    catch {
        Copy-Item -LiteralPath $Path -Destination $lockDestFile -Force
    }

    $targetPath = $lockDestFile

    $personalizationKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
    if (-not (Test-Path $personalizationKey)) { New-Item -Path $personalizationKey -Force | Out-Null }

    New-ItemProperty -Path $personalizationKey -Name 'LockScreenImage'            -PropertyType String -Value $targetPath -Force | Out-Null
    New-ItemProperty -Path $personalizationKey -Name 'NoLockScreenSlideshow'      -PropertyType DWord  -Value 1          -Force | Out-Null
    New-ItemProperty -Path $personalizationKey -Name 'NoChangingLockScreen'       -PropertyType DWord  -Value 1          -Force | Out-Null
    New-ItemProperty -Path $personalizationKey -Name 'LockScreenOverlaysDisabled' -PropertyType DWord  -Value 1          -Force | Out-Null

    $cspKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
    if (-not (Test-Path $cspKey)) { New-Item -Path $cspKey -Force | Out-Null }

    New-ItemProperty -Path $cspKey -Name 'LockScreenImageStatus' -PropertyType DWord  -Value 1           -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name 'LockScreenImagePath'   -PropertyType String -Value $targetPath -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name 'LockScreenImageUrl'    -PropertyType String -Value $targetPath -Force | Out-Null

    Write-Host "Personalisation > Lock screen set." -ForegroundColor Blue
}

function Apply-LockScreen {
    Write-Section "Lock screen"
    try { Set-LockScreenImage -Path $script:lockScreenPath }
    catch { Write-Warning "Failed to set lock screen image: $_" }
}

# =====================================================================
# 8) START MENU: layout & toggles
# =====================================================================
function Set-StartMenuSettings {
    Write-Section "Start menu"

    $explorerAdvancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $startKey            = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'

    if (-not (Test-Path $startKey)) { New-Item -Path $startKey -Force | Out-Null }

    New-ItemProperty -Path $explorerAdvancedKey -Name 'Start_Layout'              -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $explorerAdvancedKey -Name 'Start_TrackDocs'           -PropertyType DWord -Value 0 -Force | Out-Null
    New-ItemProperty -Path $explorerAdvancedKey -Name 'Start_IrisRecommendations' -PropertyType DWord -Value 0 -Force | Out-Null
    New-ItemProperty -Path $explorerAdvancedKey -Name 'Start_AccountNotifications'-PropertyType DWord -Value 0 -Force | Out-Null

    Write-Host "Personalisation > Start set." -ForegroundColor Blue
}

# =====================================================================
# 9) ACCOUNT PICTURE (profile)
# =====================================================================
function Set-CustomAccountPicture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Profile picture file not found: $Path"
        return
    }

    if (-not $script:IsAdmin) {
        Write-Warning "Skipping profile picture: settings.ps1 must be run as Administrator to change it."
        return
    }

    $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

    $accountPicturesRoot = Join-Path $env:PUBLIC 'AccountPictures'
    $userPicturesDir     = Join-Path $accountPicturesRoot $userSid

    if (Test-Path $userPicturesDir) {
        Remove-Item $userPicturesDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $userPicturesDir -ItemType Directory -Force | Out-Null

    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

    $sizes       = @(32, 40, 48, 96, 192, 240, 448)
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
            finally { $graphics.Dispose() }

            $bmp.Save($destFile, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
        }
    }
    finally { $sourceImage.Dispose() }

    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$userSid"
    if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

    foreach ($size in $sizes) {
        $valueName = "Image{0}" -f $size
        $valuePath = Join-Path $userPicturesDir ("Image{0}.png" -f $size)
        New-ItemProperty -Path $regKey -Name $valueName -PropertyType String -Value $valuePath -Force | Out-Null
    }

    Write-Host "Accounts > Your info set." -ForegroundColor Blue
}

function Apply-AccountPicture {
    Write-Section "Account picture"
    try { Set-CustomAccountPicture -Path $script:profilePicPath }
    catch { Write-Warning "Failed to set profile picture: $_" }
}

# =====================================================================
# 10) DATE & TIME: time zone & formats
# =====================================================================
function Set-DateTimeSettings {
    Write-Section "Date & time"

    try {
        $tzId = 'W. Europe Standard Time'
        if ($script:IsAdmin) {
            if (Get-Command Set-TimeZone -ErrorAction SilentlyContinue) {
                Set-TimeZone -Id $tzId
            } else {
                & tzutil.exe /s $tzId
            }
        }
        else {
            Write-Warning "Skipping time zone change: run settings.ps1 as Administrator to change the system time zone."
        }
    }
    catch {
        Write-Warning "Failed to set time zone: $_"
    }

    $intlKey = 'HKCU:\Control Panel\International'
    if (-not (Test-Path $intlKey)) { New-Item -Path $intlKey -Force | Out-Null }

    New-ItemProperty -Path $intlKey -Name 'sShortDate' -PropertyType String -Value 'yyyy-MM-dd'        -Force | Out-Null
    New-ItemProperty -Path $intlKey -Name 'sLongDate'  -PropertyType String -Value 'dddd, dd MMMM yyyy' -Force | Out-Null

    $clockAdvancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (-not (Test-Path $clockAdvancedKey)) { New-Item -Path $clockAdvancedKey -Force | Out-Null }

    New-ItemProperty -Path $clockAdvancedKey -Name 'ShowSecondsInSystemClock' -PropertyType DWord -Value 1 -Force | Out-Null

    Write-Host "Time & language > Date & time set." -ForegroundColor Blue
}

# =====================================================================
# 11) TYPING: text suggestions
# =====================================================================
function Set-TypingSettings {
    Write-Section "Typing: text suggestions"

    $inputSettingsKey = 'HKCU:\Software\Microsoft\Input\Settings'
    if (-not (Test-Path $inputSettingsKey)) { New-Item -Path $inputSettingsKey -Force | Out-Null }

    New-ItemProperty -Path $inputSettingsKey -Name 'EnableHwkbTextPrediction' -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $inputSettingsKey -Name 'MultilingualEnabled'      -PropertyType DWord -Value 1 -Force | Out-Null

    Write-Host "Time & language > Typing set." -ForegroundColor Blue
}

# =====================================================================
# Run All
# =====================================================================
function Invoke-All {
    Set-DisplayScaling100
    Set-PowerTimeouts
    Set-EnergySaverThreshold
    Set-ClipboardSettings
    Enable-WindowsFeatures
    Apply-Wallpaper
    Apply-LockScreen
    Set-StartMenuSettings
    Apply-AccountPicture
    Set-DateTimeSettings
    Set-TypingSettings
}

# =====================================================================
# Final prompt: log off / reboot
# =====================================================================
function Prompt-RebootOrLogoff {
    Write-Host ""
    Write-Host "Done. Please sign out and back in (or reboot) to fully apply changes." -ForegroundColor Green
    Write-Host ""
    Write-Host "[L] Log off"    -ForegroundColor Magenta
    Write-Host "[R] Reboot"     -ForegroundColor Magenta
    Write-Host "[N] Do nothing" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "Choose an option [L/R/N]: " -ForegroundColor Magenta -NoNewLine
    $action = Read-Host
    Write-Host ""

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
}

# =====================================================================
# MENU
# =====================================================================
function Show-Menu {
    Write-Host ""
    Write-Host "==== SETTINGS MENU ====" -ForegroundColor Cyan
    Write-Host " 1) Display: 100% scaling"
    Write-Host " 2) Power: screen off & sleep"
    Write-Host " 3) Energy saver: threshold"
    Write-Host " 4) Clipboard: history + cloud sync"
    Write-Host " 5) Optional features: Hyper-V / WSL / Sandbox (Admin)"
    Write-Host " 6) Wallpaper"
    Write-Host " 7) Lock screen (Admin)"
    Write-Host " 8) Start menu tweaks"
    Write-Host " 9) Account picture (Admin)"
    Write-Host "10) Date & time (TZ Admin, formats user)"
    Write-Host "11) Typing suggestions"
    Write-Host ""
    Write-Host " A) Run ALL"
    Write-Host " R) Prompt reboot/logoff"
    Write-Host " Q) Quit"
    Write-Host ""
}

while ($true) {
    Show-Menu
    Write-Host "Select an option: " -ForegroundColor Magenta -NoNewLine
    $choice = Read-Host

    switch -Regex ($choice) {
        '^\s*1\s*$'  { Set-DisplayScaling100 }
        '^\s*2\s*$'  { Set-PowerTimeouts }
        '^\s*3\s*$'  { Set-EnergySaverThreshold }
        '^\s*4\s*$'  { Set-ClipboardSettings }
        '^\s*5\s*$'  { Enable-WindowsFeatures }
        '^\s*6\s*$'  { Apply-Wallpaper }
        '^\s*7\s*$'  { Apply-LockScreen }
        '^\s*8\s*$'  { Set-StartMenuSettings }
        '^\s*9\s*$'  { Apply-AccountPicture }
        '^\s*10\s*$' { Set-DateTimeSettings }
        '^\s*11\s*$' { Set-TypingSettings }
        '^\s*[Aa]\s*$' {
            Invoke-All
            Prompt-RebootOrLogoff
        }
        '^\s*[Rr]\s*$' { Prompt-RebootOrLogoff }
        '^\s*[Qq]\s*$' { break }
        default { Write-Host "Invalid option." -ForegroundColor Red }
    }
}
