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
$homeFolder  = [Environment]::GetFolderPath('UserProfile')  # "HOME_FOLDER"
$repoRoot    = Join-Path $homeFolder 'windows'
$assetsRoot  = Join-Path $repoRoot 'assets'

$wallpaperPath   = Join-Path $assetsRoot 'aurora.png'
$profilePicPath  = Join-Path $assetsRoot 'catppuccin.png'

Write-Host "Repo root:        $repoRoot"
Write-Host "Wallpaper image:  $wallpaperPath"
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
    Write-Host "Wallpaper set." -ForegroundColor Green
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
    Add-Type -AssemblyName System.Drawing

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

    Write-Host "Profile picture set for SID $userSid." -ForegroundColor Green
}

# ---------------------------
# Apply wallpaper + profile
# ---------------------------

try {
    Set-CustomWallpaper -Path $wallpaperPath
}
catch {
    Write-Warning "Failed to set wallpaper: $_"
}

try {
    Set-CustomAccountPicture -Path $profilePicPath
}
catch {
    Write-Warning "Failed to set profile picture: $_"
}

Write-Host "Done. Please sign out and back in (or reboot) to fully apply changes." -ForegroundColor Green

Write-Host "Log off now to apply changes (Y/N)? " -ForegroundColor Magenta -NoNewLine
$confirmLogoff = Read-Host

if ($confirmLogoff -match '^[Yy]$') {
    Write-Host "Logging off..." -ForegroundColor Blue
    Start-Process -FilePath "logoff.exe" -WindowStyle Hidden
}
else {
    Write-Host "Logoff skipped. You can log off later to apply scaling and profile changes fully." -ForegroundColor Blue
}
