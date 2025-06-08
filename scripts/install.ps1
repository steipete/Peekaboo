# Peekaboo Installation Script for Windows
# Requires PowerShell 5.0 or later

param(
    [string]$Version = "latest",
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\Peekaboo",
    [switch]$AddToPath = $true,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Configuration
$Repo = "steipete/Peekaboo"
$BinaryName = "peekaboo.exe"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Show-Help {
    Write-Host "Peekaboo Installation Script for Windows"
    Write-Host ""
    Write-Host "Usage: .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Version <version>     Install specific version (default: latest)"
    Write-Host "  -InstallDir <path>     Installation directory"
    Write-Host "  -AddToPath             Add to PATH environment variable (default: true)"
    Write-Host "  -Help                  Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1                          # Install latest version"
    Write-Host "  .\install.ps1 -Version v1.0.0          # Install specific version"
    Write-Host "  .\install.ps1 -InstallDir C:\Tools     # Custom install directory"
    Write-Host ""
    exit 0
}

function Get-LatestVersion {
    Write-Info "Fetching latest release information..."
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        $latestVersion = $response.tag_name
        Write-Info "Latest version: $latestVersion"
        return $latestVersion
    }
    catch {
        Write-Error "Failed to fetch latest version: $($_.Exception.Message)"
        exit 1
    }
}

function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "arm64" }
        default {
            Write-Error "Unsupported architecture: $arch"
            exit 1
        }
    }
}

function Download-And-Extract {
    param([string]$Version, [string]$Architecture)
    
    $filename = "peekaboo-$Version-windows-$Architecture.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$Version/$filename"
    $tempDir = [System.IO.Path]::GetTempPath()
    $zipPath = Join-Path $tempDir $filename
    $extractPath = Join-Path $tempDir "peekaboo-extract"
    
    Write-Info "Downloading $filename..."
    
    try {
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $zipPath)
        
        Write-Info "Extracting binary..."
        
        # Create extraction directory
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $extractPath | Out-Null
        
        # Extract zip file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath)
        
        $binaryPath = Join-Path $extractPath $BinaryName
        if (-not (Test-Path $binaryPath)) {
            Write-Error "Binary not found in archive"
            exit 1
        }
        
        return $binaryPath
    }
    catch {
        Write-Error "Failed to download or extract: $($_.Exception.Message)"
        exit 1
    }
    finally {
        # Cleanup
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
    }
}

function Install-Binary {
    param([string]$BinaryPath, [string]$InstallDirectory)
    
    Write-Info "Installing $BinaryName to $InstallDirectory..."
    
    try {
        # Create install directory if it doesn't exist
        if (-not (Test-Path $InstallDirectory)) {
            New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
        }
        
        $destinationPath = Join-Path $InstallDirectory $BinaryName
        Copy-Item $BinaryPath $destinationPath -Force
        
        Write-Success "$BinaryName installed successfully!"
        return $destinationPath
    }
    catch {
        Write-Error "Failed to install binary: $($_.Exception.Message)"
        exit 1
    }
}

function Add-ToPath {
    param([string]$Directory)
    
    Write-Info "Adding $Directory to PATH..."
    
    try {
        # Get current user PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Check if directory is already in PATH
        if ($currentPath -split ";" | Where-Object { $_ -eq $Directory }) {
            Write-Info "Directory already in PATH"
            return
        }
        
        # Add to PATH
        $newPath = if ($currentPath) { "$currentPath;$Directory" } else { $Directory }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        
        # Update current session PATH
        $env:PATH = "$env:PATH;$Directory"
        
        Write-Success "Added to PATH successfully!"
        Write-Warning "You may need to restart your terminal for PATH changes to take effect"
    }
    catch {
        Write-Error "Failed to add to PATH: $($_.Exception.Message)"
        Write-Info "You can manually add $Directory to your PATH"
    }
}

function Test-Installation {
    param([string]$InstallDirectory)
    
    $binaryPath = Join-Path $InstallDirectory $BinaryName
    
    if (Test-Path $binaryPath) {
        Write-Info "Testing installation..."
        
        try {
            $versionOutput = & $binaryPath --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Installation verified! Version: $versionOutput"
            } else {
                Write-Success "Binary installed successfully!"
            }
            
            Write-Info "Run 'peekaboo --help' to get started"
        }
        catch {
            Write-Success "Binary installed at $binaryPath"
            Write-Info "Run '$binaryPath --help' to get started"
        }
    } else {
        Write-Error "Installation verification failed"
        exit 1
    }
}

function Check-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.0 or later is required"
        exit 1
    }
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Warning "Windows 10 or later is recommended"
    }
    
    Write-Info "Prerequisites check passed"
}

# Main installation flow
function Main {
    if ($Help) {
        Show-Help
    }
    
    Write-Info "Peekaboo Installation Script for Windows"
    Write-Info "========================================"
    
    Check-Prerequisites
    
    $architecture = Get-Architecture
    Write-Info "Detected architecture: $architecture"
    
    $versionToInstall = if ($Version -eq "latest") {
        Get-LatestVersion
    } else {
        $Version
    }
    
    $binaryPath = Download-And-Extract -Version $versionToInstall -Architecture $architecture
    $installedPath = Install-Binary -BinaryPath $binaryPath -InstallDirectory $InstallDir
    
    if ($AddToPath) {
        Add-ToPath -Directory $InstallDir
    }
    
    Test-Installation -InstallDirectory $InstallDir
    
    Write-Success "Installation complete!"
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Run 'peekaboo --help' to see available commands"
    Write-Host "  2. Try 'peekaboo list-displays' to see available displays"
    Write-Host "  3. Use 'peekaboo capture-screen' to take a screenshot"
    Write-Host ""
    Write-Info "For more information, visit: https://github.com/$Repo"
    
    # Cleanup
    $extractPath = Join-Path ([System.IO.Path]::GetTempPath()) "peekaboo-extract"
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
}

# Run main installation
try {
    Main
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
}

