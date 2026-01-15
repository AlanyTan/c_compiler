#!/bin/bash
set -e

echo "========================================="
echo "Arch Linux Installation Script for v86"
echo "========================================="

echo "Creating a GPT partition on /dev/sda1"
echo -e "g\nn\n\n\n\nw" | fdisk /dev/sda

echo "Formatting /dev/sda1 to ext4"
mkfs -t ext4 /dev/sda1

echo "Mounting new filesystem"
mount -t ext4 /dev/sda1 /mnt

echo "Create pacman package cache dir"
mkdir -p /mnt/var/cache/pacman/pkg

# We don't want the pacman cache to fill up the image
echo "Mount the package cache dir in memory so it doesn't fill up the image"
mount -t tmpfs none /mnt/var/cache/pacman/pkg

# Install the Archlinux base system with GCC for compilation
echo "Performing pacstrap (this will take a while...)"
pacstrap -i /mnt base base-devel gcc --noconfirm

echo "Writing fstab"
genfstab -p /mnt >> /mnt/etc/fstab

# Automatic root login on tty1
echo "Ensuring root autologin on tty1"
mkdir -p /mnt/etc/systemd/system/getty@tty1.service.d
cat << 'EOF' > /mnt/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM
EOF

# Configure 9p root remount hooks
echo "Ensuring root is remounted using 9p after reboot"
mkdir -p /mnt/etc/initcpio/hooks
cat << 'EOF' > /mnt/etc/initcpio/hooks/9p_root
run_hook() {
    mount_handler="mount_9p_root"
}

mount_9p_root() {
    msg ":: mounting '$root' on real root (9p)"
    if ! mount -t 9p host9p "$1"; then
        echo "You are now being dropped into an emergency shell."
        launch_interactive_shell
        msg "Trying to continue (this will most likely fail) ..."
    fi
}
EOF

echo "Adding initcpio build hook for 9p root remount"
mkdir -p /mnt/etc/initcpio/install
cat << 'EOF' > /mnt/etc/initcpio/install/9p_root
#!/bin/bash
build() {
	add_runscript
}
EOF

# Configure kernel modules for v86
echo "Configure mkinitcpio for 9p and keyboard support"
sed -i 's/MODULES=""/MODULES="atkbd i8042 virtio_pci 9p 9pnet 9pnet_virtio"/g' /mnt/etc/mkinitcpio.conf

# Add 9p_root hook to initcpio
sed -i 's/fsck"/fsck 9p_root"/g' /mnt/etc/mkinitcpio.conf

echo "Writing the chroot installation script"
cat << 'EOF' > /mnt/bootstrap.sh
#!/usr/bin/bash
echo "Re-generate initial ramdisk environment"
mkinitcpio -p linux

echo "Installing the grub package"
pacman -S os-prober grub --noconfirm

echo "Setting grub timeout to 0 seconds"
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub

echo "Installing bootloader"
grub-install --target=i386-pc --recheck /dev/sda --force

echo "Writing grub config"
grub-mkconfig -o /boot/grub/grub.cfg

echo "Setting hostname"
echo "archlinux-v86" > /etc/hostname

echo "Enabling auto-login on serial console ttyS0"
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
cat << 'SERIAL_EOF' > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root -s %I 115200,38400,9600 vt102
SERIAL_EOF

systemctl enable serial-getty@ttyS0.service

sync
EOF

echo "Chrooting and bootstrapping the installation"
arch-chroot /mnt bash bootstrap.sh

echo "Cleaning up"
rm /mnt/bootstrap.sh
umount -R /mnt

echo "========================================="
echo "Installation complete!"
echo "========================================="
