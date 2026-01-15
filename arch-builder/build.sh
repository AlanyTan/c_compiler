#!/bin/sh
# Build script for Arch Linux v86 image
# This script builds the image, creates 9p filesystem, and prepares artifacts

set -e

echo "========================================="
echo "Arch Linux v86 Builder"
echo "========================================="

# Check prerequisites
echo "Checking prerequisites..."
command -v packer >/dev/null 2>&1 || { echo "Error: packer is required but not installed." >&2; exit 1; }
command -v qemu-img >/dev/null 2>&1 || { echo "Error: qemu-img is required but not installed." >&2; exit 1; }
command -v kpartx >/dev/null 2>&1 || { echo "Error: kpartx is required but not installed." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required but not installed." >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "Error: rsync is required but not installed." >&2; exit 1; }
echo "All prerequisites satisfied!"

# Get fs2json script if not present
if [ ! -f "fs2json.py" ]; then
    echo "Downloading fs2json.py..."
    curl -o fs2json.py https://raw.githubusercontent.com/copy/fs2json/master/fs2json.py
    chmod +x fs2json.py
fi

# Build the image from the ISO
echo "Building image with packer (this will take a while)..."
echo "Initializing packer plugins..."
(cd packer && packer init template.pkr.hcl)
echo "Starting build with detailed logging..."
(cd packer && PACKER_LOG=1 packer build -force template.pkr.hcl)

# Check if the build succeeded
if [ ! -f "packer/output-qemu/Archlinux-v86" ]; then
    echo "Error: Build failed. Image file not found."
    exit 1
fi

echo "Build successful! Image created."

# Clean up any previous loops and mounts
echo "Cleaning up any previous mounts..."
sudo umount diskmount -f 2>/dev/null || true
sudo kpartx -d /dev/loop0 2>/dev/null || true
sudo losetup -d /dev/loop0 2>/dev/null || true

# Mount the generated raw image
mkdir -p diskmount
echo "Mounting the created image..."
sudo losetup /dev/loop0 packer/output-qemu/Archlinux-v86
sudo kpartx -a /dev/loop0
sudo mount /dev/mapper/loop0p1 diskmount

# Create output directory
mkdir -p output/images

# Map the filesystem to json with fs2json
echo "Creating filesystem JSON mapping..."
PYTHON_CMD=$(command -v python3 2>/dev/null || command -v python)
sudo $PYTHON_CMD fs2json.py --exclude /boot/ --out output/images/arch-fs.json diskmount

# Copy the filesystem 
echo "Copying filesystem to output/arch..."
mkdir -p output/arch
sudo rsync -q -av diskmount/ output/arch
sudo chown -R $(whoami):$(whoami) output/arch 2>/dev/null || sudo chown -R $(whoami) output/arch

# Clean up mount
echo "Cleaning up mounts..."
sudo umount diskmount -f
sudo kpartx -d /dev/loop0
sudo losetup -d /dev/loop0

# Move the image to the images directory
echo "Moving image to output directory..."
mv packer/output-qemu/Archlinux-v86 output/images/arch.img

echo "========================================="
echo "Build complete!"
echo "========================================="
echo ""
echo "Generated files:"
echo "  - output/images/arch.img (bootable disk image)"
echo "  - output/images/arch-fs.json (9p filesystem mapping)"
echo "  - output/arch/ (filesystem contents)"
echo ""
echo "Next steps:"
echo "1. Copy output/images/* to your v86 images/ directory"
echo "2. Copy output/arch/ to your v86 root directory"
echo "3. Update your HTML file to use the new image"
echo "4. Boot the system and save state for instant loading"
echo ""
