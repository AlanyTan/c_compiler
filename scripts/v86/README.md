# Arch Linux 32 image builder for v86

`build-arch32-9p.sh` creates an i686 Arch root filesystem without installing
Arch into a QEMU disk. An Arch32 installer ISO is used only as the trusted
bootstrap environment for `pacstrap`.

The build has four stages:

1. Extract the ISO's `airootfs.sfs` and import it as a temporary `linux/386`
   Docker image.
2. Run `pacstrap` under an i686 personality into a fresh Docker volume.
3. Add the v86 9p initramfs hook, create an optional minimal PID 1, and remove
   package caches, logs, documentation, locales, firmware, and the post-build
   module tree.
4. Export a tar with the pinned v86 `fs2json.py` and `copy-to-sha256.py` tools.
   Every content blob is compressed independently with zstd.

## Requirements

- Docker with permission to run privileged build containers
- `bsdtar`, `curl`, Python 3, `realpath`, and `sha256sum`
- Python 3.14 or the Python `zstandard` package
- An Arch Linux 32 installer ISO or its extracted `airootfs.sfs`

Docker privilege is needed only while `pacstrap` creates and enters the target
chroot. The resulting browser VM remains entirely client-side.

## Build

From the repository root:

```bash
./scripts/v86/build-arch32-9p.sh --iso /path/to/archlinux32-i686.iso
```

If `airootfs.sfs` is already available:

```bash
./scripts/v86/build-arch32-9p.sh \
  --sfs .tmp/arch-9p-build/airootfs.sfs
```

An older installer may not know a newly added Arch32 package-signing key. The
builder stops rather than silently disabling verification. Prefer a newer ISO.
If that is unavailable, inspect and trust the configured HTTPS mirror, then use:

```bash
./scripts/v86/build-arch32-9p.sh \
  --sfs .tmp/arch-9p-build/airootfs.sfs \
  --allow-unsigned-keyring-bootstrap
```

This disables signature verification only while upgrading
`archlinux32-keyring`. The new keyring is then populated and normal mandatory
package-signature verification is used for the complete target installation.

The default package set is deliberately smaller than `base-devel`:

```text
base linux gcc make nano
```

Override it when the application needs more tools:

```bash
./scripts/v86/build-arch32-9p.sh \
  --sfs .tmp/arch-9p-build/airootfs.sfs \
  --packages "base linux gcc make gdb nano"
```

The default mirror can be changed. Keep the template quoted so the host shell
does not expand `$arch` and `$repo`:

```bash
./scripts/v86/build-arch32-9p.sh \
  --iso /path/to/archlinux32-i686.iso \
  --mirror 'https://mirror.example/arch32/$arch/$repo'
```

By default the image uses a small serial-only init instead of systemd and
removes `/usr/lib/modules` after the required modules have been packed into the
initramfs. Use `--systemd-init`, `--keep-modules`, or `--vga` when those
tradeoffs are not appropriate.

## Output and installation

The builder refuses to overwrite an existing directory. Its default output is:

```text
archlinux32/generated/
├── arch/                       # content-addressed .bin.zst files
├── boot/
│   ├── initramfs-arch.img
│   └── vmlinuz-arch
├── build-info.txt
└── fs.json
```

Inspect and test that directory before replacing the current assets. To make it
the app's live image, back up the current `archlinux32/arch`, `fs.json`, and
`boot` entries, then move the generated entries into their places. The existing
saved state is tied to the old filesystem and VM configuration; remove it from
the boot candidates or create a new state after the first successful cold boot.

For the new snapshot, use 512 MB RAM and the same device settings that will be
used in production. Wait until the serial prompt appears, run a small GCC
compile, then save the state. Keeping GCC's working pages warm makes the state
larger but improves the first compilation after restore.

## Reproducibility notes

The two v86 export tools are pinned to commit
`d96be774e549a83371b038b86e819804c96b921f` and verified by SHA-256. The Arch32
mirror is rolling, however. For byte-for-byte repeatability, point `--mirror`
at an Arch32 archive date and retain `build-info.txt` with the output.
