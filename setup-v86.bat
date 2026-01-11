@echo off
echo Setting up V86 C++ Compiler Environment...
echo.

REM Create required directories
if not exist "bios" mkdir bios
if not exist "v86-lib" mkdir v86-lib
if not exist "v86-sys" mkdir v86-sys

echo Created directories: bios, v86-lib, v86-sys
echo.

echo ================================================
echo Required Downloads (Manual Steps):
echo ================================================
echo.

echo 1. V86 Library Files:
echo    Download from: https://github.com/copy/v86/releases/latest
echo    - libv86.js ^(save to v86-lib/libv86.js^)
echo    - v86.wasm ^(save to v86-lib/v86.wasm^)
echo.

echo 2. BIOS Files:
echo    - SeaBIOS: https://github.com/copy/v86/raw/master/bios/seabios.bin
echo      ^(save to bios/seabios.bin^)
echo    - VGA BIOS: https://github.com/copy/v86/raw/master/bios/vgabios.bin  
echo      ^(save to bios/vgabios.bin^)
echo.

echo 3. Alpine Linux ISO ^(~130MB^):
echo    Download: https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-standard-3.18.4-x86_64.iso
echo    Save as: v86-sys/alpine-linux.iso
echo.

echo ================================================
echo Quick Download Commands ^(if you have wget^):
echo ================================================
echo.

echo wget https://github.com/copy/v86/raw/master/bios/seabios.bin -O bios/seabios.bin
echo wget https://github.com/copy/v86/raw/master/bios/vgabios.bin -O bios/vgabios.bin
echo wget https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-standard-3.18.4-x86_64.iso -O v86-sys/alpine-linux.iso
echo.

echo ================================================
echo Alternative: PowerShell Download Commands
echo ================================================
echo.

echo powershell -Command "Invoke-WebRequest -Uri 'https://github.com/copy/v86/raw/master/bios/seabios.bin' -OutFile 'bios/seabios.bin'"
echo powershell -Command "Invoke-WebRequest -Uri 'https://github.com/copy/v86/raw/master/bios/vgabios.bin' -OutFile 'bios/vgabios.bin'"
echo.

echo Note: Alpine Linux ISO is large ^(~130MB^), download manually from the URL above
echo.

echo After downloading all files, open test-v86.html in your browser!
pause