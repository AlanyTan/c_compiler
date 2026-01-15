# Build script for Arch Linux v86 image (Windows PowerShell)
# This script is a simplified version for Windows - the full build requires Linux/WSL

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Arch Linux v86 Builder (Windows)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL is available
$wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue

if (-not $wslAvailable) {
    Write-Host "ERROR: WSL (Windows Subsystem for Linux) is required for this build." -ForegroundColor Red
    Write-Host ""
    Write-Host "This build process requires:" -ForegroundColor Yellow
    Write-Host "  - WSL 2 with Ubuntu or Debian" -ForegroundColor Yellow
    Write-Host "  - packer" -ForegroundColor Yellow
    Write-Host "  - qemu" -ForegroundColor Yellow
    Write-Host "  - kpartx" -ForegroundColor Yellow
    Write-Host "  - python3" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use a pre-built Arch Linux image" -ForegroundColor Green
    Write-Host "See: https://github.com/copy/v86/releases" -ForegroundColor Green
    exit 1
}

Write-Host "WSL detected. Checking WSL environment..." -ForegroundColor Green

# Check if build.sh exists in WSL
$buildScriptExists = wsl test -f arch-builder/build.sh
if ($LASTEXITCODE -eq 0) {
    Write-Host "Build script found. Running in WSL..." -ForegroundColor Green
    Write-Host ""
    
    # Make the script executable
    wsl chmod +x arch-builder/build.sh
    
    # Run the build script in WSL
    wsl bash arch-builder/build.sh
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "Build completed successfully!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Build failed. Check the output above for errors." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Build script not found in WSL path." -ForegroundColor Red
    Write-Host "Make sure you're running this from the compiler directory." -ForegroundColor Yellow
    exit 1
}
