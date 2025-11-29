<#
    apps.ps1
    - Reads apps from .\conf\apps.txt
    - Format: Name|URL|Type|SilentArgs
    - Downloads installers to the user's Downloads folder
    - Installs them silently (exe/msi supported)
#>

[CmdletBinding()]
param(
    [string]$ConfigPath     = "$PSScriptRoot\conf\apps.txt",
    [string]$DownloadFolder = [Environment]::GetFolderPath('UserProfile') + '\Downloads'
)

$ErrorActionPreference = 'Stop'

# ---------------------------
# Header
# ---------------------------
Write-Host "=== apps.ps1 ===" -ForegroundColor Blue
Write-Host "Config : $ConfigPath"
Write-Host "Target : $DownloadFolder"
Write-Host ""

# ---------------------------
# Basic validation
# ---------------------------
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $DownloadFolder)) {
    Write-Host "Download folder does not exist. Creating: $DownloadFolder" -ForegroundColor Blue
    New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
}

# ---------------------------
# Helper functions
# ---------------------------
function Get-UniquePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Path
    }

    $directory = Split-Path -Path $Path -Parent
    $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $ext       = [System.IO.Path]::GetExtension($Path)

    $i = 1
    while ($true) {
        $candidate = Join-Path $directory ("{0} ({1}){2}" -f $baseName, $i, $ext)
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
        $i++
    }
}

function Get-InstallerPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$DownloadFolder
    )

    # Decide extension based on "Type"
    $ext = switch ($Type.ToLower()) {
        'exe' { '.exe' }
        'msi' { '.msi' }
        default { ".$Type" }
    }

    $safeName = ($Name -replace '[^\w\.-]', '_')
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = 'installer'
    }

    $rawPath = Join-Path $DownloadFolder ($safeName + $ext)
    Get-UniquePath -Path $rawPath
}

# ---------------------------
# Read config
# ---------------------------
$lines = Get-Content -LiteralPath $ConfigPath | Where-Object {
    $_.Trim() -ne '' -and -not $_.Trim().StartsWith('#')
}

if (-not $lines) {
    Write-Warning "No valid lines found in config file: $ConfigPath"
}

# ---------------------------
# Process each app
# ---------------------------
foreach ($line in $lines) {
    $parts = $line.Split('|')

    if ($parts.Count -lt 3) {
        Write-Warning "Skipping malformed line (needs at least 3 fields): $line"
        continue
    }

    $name       = $parts[0].Trim()
    $url        = $parts[1].Trim()
    $type       = $parts[2].Trim()
    $silentArgs = if ($parts.Count -ge 4) { $parts[3].Trim() } else { '' }

    if (-not $name -or -not $url -or -not $type) {
        Write-Warning "Skipping entry with missing required fields: $line"
        continue
    }

    Write-Host ""
    Write-Host "=== Processing: $name ===" -ForegroundColor Blue
    Write-Host "URL   : $url"
    Write-Host "Type  : $type"
    Write-Host "Args  : $silentArgs"

    $installerPath = Get-InstallerPath -Name $name -Type $type -DownloadFolder $DownloadFolder
    Write-Host "File  : $installerPath"

    # ---------------------------
    # DOWNLOAD (with User-Agent)
    # ---------------------------
    try {
        Write-Host "Downloading..." -ForegroundColor Blue

        # Browser-like headers so sites like dl.dell.com don't return 403
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

        Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing -Headers $headers

        Write-Host "Download complete." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to download '${name}': $($_.Exception.Message)"
        continue
    }

    # ---------------------------
    # Install
    # ---------------------------
    try {
        switch ($type.ToLower()) {
            'exe' {
                $filePath  = $installerPath
                $arguments = $silentArgs
            }

            'msi' {
                $filePath  = 'msiexec.exe'
                $arguments = "/i `"$installerPath`" $silentArgs"
            }

            default {
                Write-Warning "Unknown installer type '$type' for '${name}'. Skipping installation."
                continue
            }
        }

        Write-Host "Installing..." -ForegroundColor Blue
        Write-Host "Command: $filePath $arguments" -ForegroundColor Blue

        $process = Start-Process -FilePath $filePath -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Installation of '${name}' completed successfully." -ForegroundColor Green
        }
        else {
            Write-Warning "Installation of '${name}' exited with code $($process.ExitCode)."
        }
    }
    catch {
        Write-Warning "Installation failed for '${name}': $($_.Exception.Message)"
        continue
    }
}

Write-Host ""
Write-Host "All entries from apps.txt processed." -ForegroundColor Green
