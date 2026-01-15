# Quick Start Guide - Arch Linux v86 Image

## Option 1: Use Pre-built Image (Recommended)

If you don't want to build from scratch, you can download a pre-built Arch Linux image:

1. Download from v86 releases: https://github.com/copy/v86/releases
2. Extract `arch.img` to your `images/` directory
3. Follow Step 3 onwards in main README.md

## Option 2: Build Your Own

### Prerequisites Check

**On Windows with WSL:**
```powershell
# Check if WSL is installed
wsl --version

# If not installed:
wsl --install

# Inside WSL, install requirements:
wsl
sudo apt update
sudo apt install -y packer qemu-system-x86 kpartx python3 rsync
```

### Build Steps

1. **Start the Build** (Linux/WSL):
   ```bash
   cd arch-builder
   chmod +x build.sh
   ./build.sh
   ```
   ⏱️ This takes 30-60 minutes

2. **Deploy Files**:
   ```bash
   cp output/images/arch.img ../images/
   cp output/images/arch-fs.json ../images/
   cp -r output/arch/ ../
   ```

3. **First Boot**:
   - Open `headless-v86.html` in browser
   - Wait 2-5 minutes for full boot
   - Click "Save State" button
   - Save `arch-v86state.bin` to `images/` directory

4. **Enable Instant Boot**:
   - Edit `headless-v86.html`
   - Set `USE_STATE = true`
   - Refresh browser - instant load! 🚀

## Troubleshooting

**"packer not found"**
```bash
sudo apt install packer
```

**WSL not working on Windows**
```powershell
# Enable WSL in PowerShell (as Admin):
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
# Restart computer, then:
wsl --install Ubuntu
```

**Build takes too long**
- Use pre-built image instead (Option 1)
- Or enable KVM in QEMU if your system supports it (much faster)

## Next Steps

Once you have instant-boot Arch Linux:
- Customize the installation by modifying `provision.sh`
- Add your own packages
- Pre-configure development environment
- Create specialized snapshots for different uses

See full README.md for detailed documentation.
