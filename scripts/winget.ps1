<#
    winget.ps1
    - Reads package IDs from .\conf\winget.txt
    - Skips comments (# ...) and empty lines
    - Installs each ID via winget with silent / accept flags
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot\conf\winget.txt"
)

$ErrorActionPreference = 'Stop'

# ---------------------------
# Header
# ---------------------------
Write-Host "=== winget.ps1 ===" -ForegroundColor Blue
Write-Host "Config : $ConfigPath"
Write-Host ""

# ---------------------------
# Basic validation
# ---------------------------
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

if (-not (Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue)) {
    Write-Error "winget.exe not found on this system. Install App Installer from the Microsoft Store or via offline package."
    exit 1
}

# ---------------------------
# Optional: refresh sources
# ---------------------------
try {
    Write-Host "Updating winget sources..."
    winget source update | Out-Null
}
catch {
    Write-Warning "Failed to update winget sources: $($_.Exception.Message)"
}

# ---------------------------
# Read package IDs
# ---------------------------
$ids = Get-Content -LiteralPath $ConfigPath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }

if (-not $ids) {
    Write-Warning "No package IDs found in $ConfigPath (after skipping comments/empty lines)."
    exit 0
}

# ---------------------------
# Install each package
# ---------------------------
foreach ($id in $ids) {
    Write-Host "=== Installing winget package: $id ===" -ForegroundColor Blue

    try {
        # Use --id for exact ID; --silent to avoid UI
        $args = @(
            'install'
            '--id', $id
            '--exact'
            '--silent'
            '--accept-package-agreements'
            '--accept-source-agreements'
            '--source', 'winget'
        )

        Write-Host "Command: winget $($args -join ' ')"

        $process = Start-Process -FilePath 'winget.exe' -ArgumentList $args -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Successfully installed: $id" -ForegroundColor Green
        }
        else {
            Write-Warning "winget install for ${id} exited with code $($process.ExitCode)."
        }
    }
    catch {
        Write-Warning "Failed to install ${id}: $($_.Exception.Message)"
        continue
    }
}

Write-Host ""
Write-Host "All entries from winget.txt processed." -ForegroundColor Green
