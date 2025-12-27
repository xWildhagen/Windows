<#
    stuff.ps1
    - Applies Windows Terminal config from OneDrive
    - Replaces Edge local folder by COPYING OneDrive contents
    - Menu-driven: run each section individually, or run all
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "=== stuff.ps1 ===" -ForegroundColor Blue

# ---------------------------
# Helpers
# ---------------------------
function Write-Section($Title) {
    Write-Host ""
    Write-Host "== $Title ==" -ForegroundColor Blue
}

# ---------------------------
# Resolve home folder
# ---------------------------
$homeFolder = [Environment]::GetFolderPath('UserProfile')

# ---------------------------
# Paths
# ---------------------------
# Windows Terminal
$terminalConfigDir        = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\TERMINAL'
$terminalConfigSourceFile = 'TERMINAL.json'
$terminalConfigTargetFile = 'settings.json'
$terminalConfigPath       = Join-Path $terminalConfigDir $terminalConfigSourceFile

# Microsoft Edge
$edgeLocalPath    = Join-Path $homeFolder 'AppData\Local\Microsoft\Edge'
$edgeOneDrivePath = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\EDGE\Edge'

Write-Host "Terminal config:  $terminalConfigPath"
Write-Host "Edge source:      $edgeOneDrivePath"
Write-Host "Edge destination: $edgeLocalPath"

# =====================================================================
# 1) Windows Terminal config
# =====================================================================
function Apply-WindowsTerminalConfig {
    Write-Section "Windows Terminal: apply config"

    if (-not (Test-Path -LiteralPath $script:terminalConfigPath)) {
        Write-Warning "Terminal config not found at: $($script:terminalConfigPath)"
        return
    }

    $packagesRoot = Join-Path $env:LOCALAPPDATA 'Packages'

    $terminalPackages = Get-ChildItem -Path $packagesRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' }

    if (-not $terminalPackages) {
        Write-Warning "No Windows Terminal package folder found"
        return
    }

    foreach ($pkg in $terminalPackages) {
        $localState = Join-Path $pkg.FullName 'LocalState'
        if (-not (Test-Path -LiteralPath $localState)) {
            New-Item -ItemType Directory -Path $localState -Force | Out-Null
        }

        $targetSettings = Join-Path $localState $script:terminalConfigTargetFile
        Copy-Item -LiteralPath $script:terminalConfigPath -Destination $targetSettings -Force

        Write-Host "Applied terminal config" -ForegroundColor Green
    }
}

# =====================================================================
# 2) Edge folder replacement (COPY OneDrive -> Local)
# =====================================================================
function Replace-EdgeLocalFolderFromOneDrive {
    Write-Section "Microsoft Edge: replace local folder via copy"

    # Ensure Edge is not running
    try {
        Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to stop msedge (may not be running): $_"
    }

    if (-not (Test-Path -LiteralPath $script:edgeOneDrivePath)) {
        Write-Warning "OneDrive Edge source not found: $($script:edgeOneDrivePath)"
        return
    }

    # Remove existing local Edge folder completely
    if (Test-Path -LiteralPath $script:edgeLocalPath) {
        try {
            Remove-Item -LiteralPath $script:edgeLocalPath -Recurse -Force
        }
        catch {
            Write-Warning "Failed to remove local Edge folder: $($_). Make sure Edge is closed and try again."
            return
        }
    }

    # Recreate local Edge folder
    New-Item -ItemType Directory -Path $script:edgeLocalPath -Force | Out-Null

    # Copy EVERYTHING from OneDrive to local Edge folder
    Copy-Item `
        -Path (Join-Path $script:edgeOneDrivePath '*') `
        -Destination $script:edgeLocalPath `
        -Recurse `
        -Force

    Write-Host "Edge folder successfully replaced via copy" -ForegroundColor Green
}

# =====================================================================
# Run All
# =====================================================================
function Invoke-All {
    Apply-WindowsTerminalConfig
    Replace-EdgeLocalFolderFromOneDrive
}

# =====================================================================
# MENU
# =====================================================================
function Show-Menu {
    Write-Host ""
    Write-Host "==== STUFF MENU ====" -ForegroundColor Blue
    Write-Host " 1) Apply Windows Terminal config"
    Write-Host " 2) Replace Edge local folder (copy from OneDrive)"
    Write-Host " A) Run ALL" -ForegroundColor Blue
    Write-Host ""
}

while ($true) {
    Show-Menu
    Write-Host "Select an option: " -ForegroundColor Magenta -NoNewLine
    $choice = Read-Host

    switch -Regex ($choice) {
        '^\s*1\s*$'   { Apply-WindowsTerminalConfig }
        '^\s*2\s*$'   { Replace-EdgeLocalFolderFromOneDrive }
        '^\s*[Aa]\s*$'{ Invoke-All }
        default       { Write-Host "Invalid option." -ForegroundColor Red }
    }
}
