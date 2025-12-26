<#
    stuff.ps1
    - Applies Windows Terminal config from OneDrive
    - Replaces Edge local folder by COPYING OneDrive contents
#>

Write-Host "=== stuff.ps1 ===" -ForegroundColor Blue

# ============================================================
# Resolve home folder
# ============================================================

$homeFolder = [Environment]::GetFolderPath('UserProfile')

# ============================================================
# Windows Terminal config
# ============================================================

$terminalConfigDir        = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\TERMINAL'
$terminalConfigSourceFile = 'TERMINAL.json'
$terminalConfigTargetFile = 'settings.json'
$terminalConfigPath       = Join-Path $terminalConfigDir $terminalConfigSourceFile

if (-not (Test-Path $terminalConfigPath)) {
    Write-Warning "Terminal config not found at: $terminalConfigPath"
}
else {
    $packagesRoot = Join-Path $env:LOCALAPPDATA 'Packages'

    $terminalPackages = Get-ChildItem -Path $packagesRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' }

    if (-not $terminalPackages) {
        Write-Warning "No Windows Terminal package folder found"
    }
    else {
        foreach ($pkg in $terminalPackages) {
            $localState = Join-Path $pkg.FullName 'LocalState'

            if (-not (Test-Path $localState)) {
                New-Item -ItemType Directory -Path $localState -Force | Out-Null
            }

            $targetSettings = Join-Path $localState $terminalConfigTargetFile
            Copy-Item -Path $terminalConfigPath -Destination $targetSettings -Force

            Write-Host "Applied terminal config to $targetSettings" -ForegroundColor Green
        }
    }
}

# ============================================================
# Microsoft Edge folder COPY (no links, no sync)
# ============================================================

Write-Host "=== Edge folder copy ===" -ForegroundColor Blue

$edgeLocalPath    = Join-Path $homeFolder 'AppData\Local\Microsoft\Edge'
$edgeOneDrivePath = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\EDGE\Edge'

# Ensure Edge is not running
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force

# Verify OneDrive source exists
if (-not (Test-Path $edgeOneDrivePath)) {
    Write-Warning "OneDrive Edge source not found: $edgeOneDrivePath"
    return
}

# Remove existing local Edge folder completely
if (Test-Path $edgeLocalPath) {
    Write-Host "Removing existing Edge local folder" -ForegroundColor Yellow
    Remove-Item -Path $edgeLocalPath -Recurse -Force
}

# Recreate local Edge folder
New-Item -ItemType Directory -Path $edgeLocalPath -Force | Out-Null

# Copy EVERYTHING from OneDrive to local Edge folder
Write-Host "Copying Edge data from OneDrive to local AppData" -ForegroundColor Cyan
Copy-Item `
    -Path (Join-Path $edgeOneDrivePath '*') `
    -Destination $edgeLocalPath `
    -Recurse `
    -Force

Write-Host "Edge folder successfully replaced via copy" -ForegroundColor Green
