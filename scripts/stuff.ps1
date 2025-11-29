Write-Host "=== stuff.ps1 ===" -ForegroundColor Blue

# Resolve current user's home folder (C:\Users\<user>)
$homeFolder = [Environment]::GetFolderPath('UserProfile')

# Base folder in OneDrive where the Terminal config lives
$terminalConfigDir  = Join-Path $homeFolder 'OneDrive - Wildhagen\MAIN\TERMINAL'

# Name of the config file inside that folder
$terminalConfigFile = 'TERMINAL.json'

# Full path to your saved Terminal config in OneDrive
$terminalConfigPath = Join-Path $terminalConfigDir $terminalConfigFile

if (-not (Test-Path $terminalConfigPath)) {
    Write-Warning "Terminal config not found at: $terminalConfigPath"
    return
}

# Windows Terminal package folders (Store / winget install)
$packagesRoot = Join-Path $env:LOCALAPPDATA 'Packages'
$terminalPackages = @()

if (Test-Path $packagesRoot) {
    $terminalPackages = Get-ChildItem -Path $packagesRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' }
}

if (-not $terminalPackages) {
    Write-Warning "No Windows Terminal package folder found under $packagesRoot"
    return
}

foreach ($pkg in $terminalPackages) {
    $localState = Join-Path $pkg.FullName 'LocalState'
    if (-not (Test-Path $localState)) { continue }

    $targetSettings = Join-Path $localState $terminalConfigFile

    # Replace with your OneDrive version
    Copy-Item -Path $terminalConfigPath -Destination $targetSettings -Force
    Write-Host "Applied terminal config to $targetSettings" -ForegroundColor Green
}
