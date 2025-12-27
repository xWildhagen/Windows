<#
    stuff.ps1
    - Applies Windows Terminal config from OneDrive
    - Replaces Edge local folder by COPYING OneDrive contents
    - Copies SSH files from OneDrive to local .ssh
    - Copies .gitconfig from OneDrive to local home
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

# OpenSSH
$sshOneDrivePath = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\SSH'
$sshLocalPath    = Join-Path $homeFolder '.ssh'

# Git
$gitConfigOneDrivePath = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\GIT\.gitconfig'
$gitConfigLocalPath    = Join-Path $homeFolder '.gitconfig'

Write-Host "Terminal config:  $terminalConfigPath"
Write-Host "Edge source:      $edgeOneDrivePath"
Write-Host "Edge destination: $edgeLocalPath"
Write-Host "SSH source:       $sshOneDrivePath"
Write-Host "SSH destination:  $sshLocalPath"
Write-Host "Git config src:   $gitConfigOneDrivePath"
Write-Host "Git config dst:   $gitConfigLocalPath"

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

    if (Test-Path -LiteralPath $script:edgeLocalPath) {
        try {
            Remove-Item -LiteralPath $script:edgeLocalPath -Recurse -Force
        }
        catch {
            Write-Warning "Failed to remove local Edge folder: $($_)"
            return
        }
    }

    New-Item -ItemType Directory -Path $script:edgeLocalPath -Force | Out-Null

    Copy-Item `
        -Path (Join-Path $script:edgeOneDrivePath '*') `
        -Destination $script:edgeLocalPath `
        -Recurse `
        -Force

    Write-Host "Edge folder successfully replaced via copy" -ForegroundColor Green
}

# =====================================================================
# 3) SSH folder copy (OneDrive -> Local .ssh)
# =====================================================================
function Copy-SSHFromOneDrive {
    Write-Section "OpenSSH: copy .ssh from OneDrive"

    if (-not (Test-Path -LiteralPath $script:sshOneDrivePath)) {
        Write-Warning "OneDrive SSH source not found: $($script:sshOneDrivePath)"
        return
    }

    if (-not (Test-Path -LiteralPath $script:sshLocalPath)) {
        New-Item -ItemType Directory -Path $script:sshLocalPath -Force | Out-Null
    }

    Copy-Item `
        -Path (Join-Path $script:sshOneDrivePath '*') `
        -Destination $script:sshLocalPath `
        -Recurse `
        -Force

    try {
        icacls $script:sshLocalPath /inheritance:r | Out-Null
        icacls $script:sshLocalPath /grant:r "$env:USERNAME:(OI)(CI)F" | Out-Null
        icacls $script:sshLocalPath /remove "Users" "Authenticated Users" "Everyone" 2>$null | Out-Null
    }
    catch {
        Write-Warning "Could not adjust .ssh permissions: $_"
    }

    Write-Host ".ssh successfully copied from OneDrive" -ForegroundColor Green
}

# =====================================================================
# 4) Git config copy (OneDrive -> Local .gitconfig)
# =====================================================================
function Copy-GitConfigFromOneDrive {
    Write-Section "Git: copy .gitconfig from OneDrive"

    if (-not (Test-Path -LiteralPath $script:gitConfigOneDrivePath)) {
        Write-Warning "OneDrive .gitconfig not found: $($script:gitConfigOneDrivePath)"
        return
    }

    Copy-Item `
        -LiteralPath $script:gitConfigOneDrivePath `
        -Destination $script:gitConfigLocalPath `
        -Force

    Write-Host ".gitconfig successfully copied from OneDrive" -ForegroundColor Green
}

# =====================================================================
# Run All
# =====================================================================
function Invoke-All {
    Apply-WindowsTerminalConfig
    Replace-EdgeLocalFolderFromOneDrive
    Copy-SSHFromOneDrive
    Copy-GitConfigFromOneDrive
}

# =====================================================================
# MENU
# =====================================================================
function Show-Menu {
    Write-Host ""
    Write-Host "==== STUFF MENU ====" -ForegroundColor Blue
    Write-Host " 1) Apply Windows Terminal config"
    Write-Host " 2) Replace Edge local folder (copy from OneDrive)"
    Write-Host " 3) Copy SSH folder (.ssh) from OneDrive"
    Write-Host " 4) Copy Git config (.gitconfig) from OneDrive"
    Write-Host " A) Run ALL" -ForegroundColor Blue
    Write-Host ""
}

while ($true) {
    Show-Menu
    Write-Host "Select an option: " -ForegroundColor Magenta -NoNewLine
    $choice = Read-Host

    switch -Regex ($choice) {
        '^\s*1\s*$'    { Apply-WindowsTerminalConfig }
        '^\s*2\s*$'    { Replace-EdgeLocalFolderFromOneDrive }
        '^\s*3\s*$'    { Copy-SSHFromOneDrive }
        '^\s*4\s*$'    { Copy-GitConfigFromOneDrive }
        '^\s*[Aa]\s*$' { Invoke-All }
        default        { Write-Host "Invalid option." -ForegroundColor Red }
    }
}
