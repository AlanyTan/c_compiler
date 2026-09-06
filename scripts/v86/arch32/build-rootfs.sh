#!/usr/bin/bash
set -Eeuo pipefail

: "${ARCH32_PACKAGES:=base linux gcc make nano}"
: "${ARCH32_MIRROR:=https://de.mirror.archlinux32.org/\$arch/\$repo}"
: "${V86_INIT_SYSTEM:=minimal}"
: "${V86_KEEP_MODULES:=0}"
: "${V86_ENABLE_VGA:=0}"
: "${ALLOW_UNSIGNED_KEYRING_BOOTSTRAP:=0}"

[[ $(uname -m) == i686 ]] || {
  printf 'expected the i686 personality, got %s\n' "$(uname -m)" >&2
  exit 1
}

sed -Ei 's/^[#[:space:]]*Architecture[[:space:]]*=.*/Architecture = i686/' /etc/pacman.conf
printf 'Server = %s\n' "$ARCH32_MIRROR" >/etc/pacman.d/mirrorlist

printf 'Refreshing the Arch32 signing keys ...\n'
pacman-key --init
keyrings=()
for keyring_file in /usr/share/pacman/keyrings/*.gpg; do
  [[ -e "$keyring_file" ]] || continue
  keyrings+=("$(basename "$keyring_file" .gpg)")
done
((${#keyrings[@]})) || {
  printf 'the Arch32 bootstrap contains no pacman keyrings\n' >&2
  exit 1
}
pacman-key --populate "${keyrings[@]}"
if ! pacman -Sy --needed --noconfirm archlinux32-keyring; then
  if [[ "$ALLOW_UNSIGNED_KEYRING_BOOTSTRAP" != 1 ]]; then
    cat >&2 <<'EOF'
The installer keyring cannot authenticate the current Arch32 keyring.
Use a newer ISO, or review the security note in scripts/v86/README.md and rerun
with --allow-unsigned-keyring-bootstrap.
EOF
    exit 1
  fi

  printf 'Bootstrapping only archlinux32-keyring through the HTTPS mirror ...\n' >&2
  rm -f -- /var/cache/pacman/pkg/archlinux32-keyring-*.pkg.tar.*
  cp /etc/pacman.conf /tmp/pacman-keyring-bootstrap.conf
  sed -Ei 's/^[#[:space:]]*SigLevel[[:space:]]*=.*/SigLevel = Never/' \
    /tmp/pacman-keyring-bootstrap.conf
  pacman -Sy --noconfirm \
    --config /tmp/pacman-keyring-bootstrap.conf archlinux32-keyring

  rm -rf -- /etc/pacman.d/gnupg
  pacman-key --init
  pacman-key --populate archlinux32
fi

read -r -a packages <<<"$ARCH32_PACKAGES"
((${#packages[@]})) || {
  printf 'ARCH32_PACKAGES is empty\n' >&2
  exit 1
}

printf 'Installing: %s\n' "${packages[*]}"
pacstrap -C /etc/pacman.conf /target "${packages[@]}"

cp -a /v86-config/rootfs-overlay/. /target/
printf 'Server = %s\n' "$ARCH32_MIRROR" >/target/etc/pacman.d/mirrorlist
printf 'Architecture = i686\n' >/target/etc/v86-image-build
printf 'Packages = %s\n' "$ARCH32_PACKAGES" >>/target/etc/v86-image-build

modules=(virtio_pci virtio_pci_modern_dev 9p 9pnet 9pnet_virtio)
if [[ "$V86_ENABLE_VGA" == 1 ]]; then
  modules+=(atkbd i8042 libps2 serio serio_raw psmouse)
fi
printf -v module_line '%s ' "${modules[@]}"
module_line=${module_line% }

sed -Ei "s|^[#[:space:]]*MODULES=.*|MODULES=($module_line)|" /target/etc/mkinitcpio.conf
sed -Ei 's|^[#[:space:]]*HOOKS=.*|HOOKS=(base udev modconf block filesystems 9p_root)|' /target/etc/mkinitcpio.conf
sed -Ei 's|^[#[:space:]]*COMPRESSION=.*|COMPRESSION="zstd"|' /target/etc/mkinitcpio.conf

mkdir -p /target/home/student/src /target/root
chmod 0755 /target/home /target/home/student /target/home/student/src
arch-chroot /target /usr/bin/passwd -d root

case "$V86_INIT_SYSTEM" in
  minimal)
    ln -sfn /usr/local/sbin/v86-init /target/usr/bin/init
    ;;
  systemd)
    ;;
  *)
    printf 'unsupported init system: %s\n' "$V86_INIT_SYSTEM" >&2
    exit 1
    ;;
esac

printf 'Generating the v86-specific initramfs ...\n'
arch-chroot /target /usr/bin/mkinitcpio -p linux
[[ -s /target/boot/vmlinuz-linux ]]
[[ -s /target/boot/initramfs-linux.img ]]

printf 'Removing build and package-manager residue ...\n'
rm -rf -- \
  /target/var/cache/pacman/pkg/* \
  /target/var/lib/pacman/sync/* \
  /target/usr/share/doc \
  /target/usr/share/gtk-doc \
  /target/usr/share/info \
  /target/usr/share/man \
  /target/usr/share/locale \
  /target/usr/share/i18n \
  /target/usr/lib/firmware

find /target/var/log -xdev -type f -delete
find /target -xdev -type f \( -name '*.pacnew' -o -name '*.pacsave' \) -delete
rm -f -- /target/var/lib/systemd/random-seed
: >/target/etc/machine-id

if [[ "$V86_KEEP_MODULES" != 1 ]]; then
  rm -rf -- /target/usr/lib/modules
fi

printf 'Creating the flattened rootfs tar ...\n'
(
  cd /target
  find . -mindepth 1 -maxdepth 1 -printf '%P\0' \
    | LC_ALL=C sort -z \
    | tar --null --files-from=- --numeric-owner --xattrs --acls -cpf /work/rootfs.tar
)
chmod 0644 /work/rootfs.tar
