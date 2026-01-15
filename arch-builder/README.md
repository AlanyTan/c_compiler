# Arch Linux Image Builder for v86

This directory contains scripts to build a custom Arch Linux image for the v86 emulator with instant boot capability using saved state.

## Overview

Based on the [official v86 Arch Linux documentation](https://github.com/copy/v86/blob/master/docs/archlinux.md), this build process creates:

1. **arch.img** - A bootable Arch Linux disk image
2. **arch-fs.json** - 9p network filesystem mapping (optional)
3. **arch/** - Complete filesystem contents for 9p serving
4. **arch-v86state.bin** - Saved emulator state for instant boot

## Prerequisites

### Linux/WSL Required
This build process requires a Linux environment with:
- **Packer** - ISO automation tool
- **QEMU** - x86 emulator for building
- **kpartx** - Partition mapping tool
- **Python 3** - For fs2json script
- **rsync** - File synchronization

### Installation on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y packer qemu-system-x86 kpartx python3 rsync
```

### Windows Users
Use WSL 2 (Windows Subsystem for Linux) to run the build scripts.

## Build Process

### Step 1: Build the Image

The automated build process will:
1. Download Arch Linux 32-bit ISO (archlinux32)
2. Boot it in QEMU
3. Automatically install base system with GCC
4. Configure for v86 compatibility (9p, keyboard support)
5. Generate filesystem mappings

**Linux/WSL:**
```bash
cd arch-builder
chmod +x build.sh
./build.sh
```

**Windows (PowerShell):**
```powershell
cd arch-builder
.\build.ps1
```

This will take 30-60 minutes depending on your system.

### Step 2: Deploy to v86

Copy the generated files to your v86 directory:

```bash
# Copy image and filesystem files
cp output/images/arch.img ../images/
cp output/images/arch-fs.json ../images/
cp -r output/arch/ ../
```

### Step 3: First Boot

1. Open `headless-v86.html` in your browser
2. Wait for Arch Linux to fully boot (2-5 minutes)
3. Verify you can run commands in the serial console
4. Once stable, click "Save State" button
5. Download the `arch-v86state.bin` file
6. Copy it to the `images/` directory:
   ```bash
   cp ~/Downloads/arch-v86state.bin images/
   ```

### Step 4: Enable Instant Boot

Edit `headless-v86.html` and change:
```javascript
const USE_STATE = false; // Change to true
const USE_9P_FS = false; // Change to true for 9p filesystem
```

Now when you refresh the page, Arch Linux will load instantly from the saved state!

## Configuration Options

### In headless-v86.html:

```javascript
// Load from saved state for instant boot (after Step 3)
const USE_STATE = true;

// Use 9p network filesystem (optional - saves bandwidth)
const USE_9P_FS = true;
```

### Disk Image vs 9p Filesystem

**Disk Image Mode (USE_9P_FS = false):**
- Loads entire disk image
- Simpler setup
- Larger initial download

**9p Network Mode (USE_9P_FS = true):**
- Loads files on-demand via HTTP
- Faster initial load
- Requires web server with Range header support
- More complex setup

## Customization

### Modify the Installation

Edit `packer/scripts/provision.sh` to customize:
- Additional packages (add to `pacstrap` line)
- System configuration
- Pre-installed tools

### Change Disk Size

Edit `packer/template.json`:
```json
"disk_size": 2048,  // Size in MB
```

Then update `headless-v86.html`:
```javascript
size: 2 * 1024 * 1024 * 1024,  // Must match disk_size
```

## Troubleshooting

### Build fails with "packer not found"
Install packer: `sudo apt install packer`

### Build fails with "kpartx not found"
Install kpartx: `sudo apt install kpartx`

### Boot hangs or loops
- Increase `boot_wait` in template.json
- Check BIOS files are present
- Verify disk image isn't corrupted

### State file doesn't load
- Ensure file is in correct location: `images/arch-v86state.bin`
- Check browser console for errors
- Try regenerating the state file

### 9p filesystem errors
- Verify `arch-fs.json` is properly formatted
- Ensure web server supports Range headers
- Check `arch/` directory has correct permissions

## File Structure

```
arch-builder/
├── packer/
│   ├── template.json           # Packer build configuration
│   └── scripts/
│       └── provision.sh        # Arch Linux installation script
├── build.sh                    # Linux build script
├── build.ps1                   # Windows PowerShell build script
├── fs2json.py                  # Downloaded during build
└── output/                     # Generated files (after build)
    ├── images/
    │   ├── arch.img           # Bootable disk image
    │   └── arch-fs.json       # 9p filesystem mapping
    └── arch/                  # Complete filesystem
```

## Technical Details

### What's Different from Standard Arch?

1. **32-bit Only**: Uses archlinux32 (last 32-bit compatible version)
2. **Kernel Modules**: Includes atkbd, i8042 (keyboard), 9p (network fs)
3. **Auto-login**: Root auto-login on tty1 and ttyS0 (serial)
4. **Fast Boot**: GRUB timeout set to 0 seconds
5. **9p Support**: Can mount root filesystem over network

### v86 Compatibility

- x86 (32-bit) only - v86 doesn't support x86_64
- IDE disk interface (not SATA)
- SeaBIOS for BIOS emulation
- VGA text/graphics support

## References

- [v86 Arch Linux Documentation](https://github.com/copy/v86/blob/master/docs/archlinux.md)
- [v86 GitHub Repository](https://github.com/copy/v86)
- [Arch Linux 32-bit](https://www.archlinux32.org/)
- [Packer QEMU Builder](https://www.packer.io/docs/builders/qemu)

## License

Scripts based on v86 project examples, licensed under BSD 2-Clause.
