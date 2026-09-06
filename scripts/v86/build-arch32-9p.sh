#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)

V86_REF="d96be774e549a83371b038b86e819804c96b921f"
FS2JSON_SHA256="546b0ce7d0b172fa855587209318a8d473bce6de23fa327ceeb5b6c115fda23f"
COPY_TO_SHA256_SHA256="7bfb94736afbb9753b6deea922184eec2f9b205be0214bc5f9866cf990bfa77c"

ISO_PATH=""
SFS_PATH=""
OUTPUT_DIR="$REPO_ROOT/archlinux32/generated"
WORK_ROOT="$REPO_ROOT/.tmp/arch32-9p-builder"
V86_TOOLS_DIR=""
ARCH32_PACKAGES="base linux gcc make nano"
ARCH32_MIRROR='https://de.mirror.archlinux32.org/$arch/$repo'
INIT_SYSTEM="minimal"
KEEP_MODULES=0
ENABLE_VGA=0
KEEP_WORK=0
KEEP_BOOTSTRAP_IMAGE=0
ALLOW_UNSIGNED_KEYRING_BOOTSTRAP=0

usage() {
  cat <<'EOF'
Build a minimal Arch Linux 32 root filesystem for v86's HTTP-backed 9p server.

Usage:
  build-arch32-9p.sh --iso PATH [options]
  build-arch32-9p.sh --sfs PATH [options]

Input (choose one):
  --iso PATH              Arch Linux 32 installer ISO
  --sfs PATH              Extracted Arch32 airootfs.sfs

Options:
  --output DIR            New output directory
                          (default: archlinux32/generated)
  --work-dir DIR          Cache and temporary build directory
                          (default: .tmp/arch32-9p-builder)
  --packages "LIST"       Packages installed into the new rootfs
                          (default: base linux gcc make nano)
  --mirror URL            Arch32 pacman mirror template; quote $arch and $repo
  --v86-tools DIR         Directory containing fs2json.py and
                          copy-to-sha256.py; otherwise pinned copies are fetched
  --systemd-init          Keep systemd as PID 1 instead of the minimal serial init
  --keep-modules          Retain /usr/lib/modules after creating the initramfs
  --vga                   Include PS/2 keyboard and mouse modules in the initramfs
  --keep-work             Keep the temporary run directory
  --keep-bootstrap-image  Keep the temporary Docker bootstrap image
  --allow-unsigned-keyring-bootstrap
                          If an old ISO cannot authenticate the current keyring,
                          trust that one package from the HTTPS mirror, then
                          restore mandatory signature verification
  -h, --help              Show this help

The output directory must not already exist. Existing VM assets are never
modified by this script.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

absolute_path() {
  realpath -m -- "$1"
}

while (($#)); do
  case "$1" in
    --iso)
      (($# >= 2)) || die "--iso requires a path"
      ISO_PATH=$2
      shift 2
      ;;
    --sfs)
      (($# >= 2)) || die "--sfs requires a path"
      SFS_PATH=$2
      shift 2
      ;;
    --output)
      (($# >= 2)) || die "--output requires a directory"
      OUTPUT_DIR=$2
      shift 2
      ;;
    --work-dir)
      (($# >= 2)) || die "--work-dir requires a directory"
      WORK_ROOT=$2
      shift 2
      ;;
    --packages)
      (($# >= 2)) || die "--packages requires a quoted package list"
      ARCH32_PACKAGES=$2
      shift 2
      ;;
    --mirror)
      (($# >= 2)) || die "--mirror requires a URL"
      ARCH32_MIRROR=$2
      shift 2
      ;;
    --v86-tools)
      (($# >= 2)) || die "--v86-tools requires a directory"
      V86_TOOLS_DIR=$2
      shift 2
      ;;
    --systemd-init)
      INIT_SYSTEM="systemd"
      shift
      ;;
    --keep-modules)
      KEEP_MODULES=1
      shift
      ;;
    --vga)
      ENABLE_VGA=1
      shift
      ;;
    --keep-work)
      KEEP_WORK=1
      shift
      ;;
    --keep-bootstrap-image)
      KEEP_BOOTSTRAP_IMAGE=1
      shift
      ;;
    --allow-unsigned-keyring-bootstrap)
      ALLOW_UNSIGNED_KEYRING_BOOTSTRAP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ -z "$ISO_PATH" || -z "$SFS_PATH" ]] || die "use either --iso or --sfs, not both"

if [[ -z "$ISO_PATH" && -z "$SFS_PATH" ]]; then
  if [[ -f "$REPO_ROOT/.tmp/arch-9p-build/airootfs.sfs" ]]; then
    SFS_PATH="$REPO_ROOT/.tmp/arch-9p-build/airootfs.sfs"
    printf 'Using cached Arch32 bootstrap: %s\n' "$SFS_PATH"
  else
    die "provide an Arch Linux 32 installer with --iso or --sfs"
  fi
fi

require_command docker
require_command bsdtar
require_command curl
require_command python3
require_command realpath
require_command sha256sum

OUTPUT_DIR=$(absolute_path "$OUTPUT_DIR")
WORK_ROOT=$(absolute_path "$WORK_ROOT")
[[ ! -e "$OUTPUT_DIR" ]] || die "output already exists: $OUTPUT_DIR"

if [[ -n "$ISO_PATH" ]]; then
  ISO_PATH=$(absolute_path "$ISO_PATH")
  [[ -f "$ISO_PATH" ]] || die "ISO not found: $ISO_PATH"
else
  SFS_PATH=$(absolute_path "$SFS_PATH")
  [[ -f "$SFS_PATH" ]] || die "SquashFS image not found: $SFS_PATH"
fi

mkdir -p -- "$WORK_ROOT/runs" "$WORK_ROOT/cache/v86-$V86_REF"
RUN_DIR=$(mktemp -d "$WORK_ROOT/runs/run.XXXXXXXX")
RUN_ID=${RUN_DIR##*/}
BOOTSTRAP_IMAGE="v86-arch32-bootstrap:${RUN_ID#run.}"
ROOTFS_VOLUME="v86_arch32_rootfs_${RUN_ID#run.}"
VOLUME_CREATED=0
IMAGE_CREATED=0

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  if ((VOLUME_CREATED)); then
    docker volume rm -f "$ROOTFS_VOLUME" >/dev/null 2>&1 || true
  fi
  if ((IMAGE_CREATED)) && ((!KEEP_BOOTSTRAP_IMAGE)); then
    docker image rm "$BOOTSTRAP_IMAGE" >/dev/null 2>&1 || true
  fi
  if ((!KEEP_WORK)); then
    case "$RUN_DIR" in
      "$WORK_ROOT"/runs/run.*) rm -rf -- "$RUN_DIR" ;;
      *) printf 'warning: refusing to clean unexpected path: %s\n' "$RUN_DIR" >&2 ;;
    esac
  else
    printf 'Kept work directory: %s\n' "$RUN_DIR"
  fi

  exit "$status"
}
trap cleanup EXIT INT TERM

if [[ -n "$ISO_PATH" ]]; then
  mapfile -t SFS_ENTRIES < <(bsdtar -tf "$ISO_PATH" | grep -E '(^|/)airootfs\.sfs$' || true)
  ((${#SFS_ENTRIES[@]})) || die "the ISO does not contain airootfs.sfs"

  SFS_ENTRY=${SFS_ENTRIES[0]}
  for candidate in "${SFS_ENTRIES[@]}"; do
    if [[ "$candidate" == *i686* ]]; then
      SFS_ENTRY=$candidate
      break
    fi
  done

  SFS_PATH="$RUN_DIR/airootfs.sfs"
  printf 'Extracting %s from %s ...\n' "$SFS_ENTRY" "$ISO_PATH"
  bsdtar -xOf "$ISO_PATH" "$SFS_ENTRY" >"$SFS_PATH"
fi

printf 'Creating the Arch32 bootstrap image ...\n'
docker run --rm \
  --mount "type=bind,src=$SFS_PATH,dst=/input/airootfs.sfs,readonly" \
  --mount "type=bind,src=$RUN_DIR,dst=/output" \
  alpine:3.22 \
  /bin/sh -euxc '
    apk add --no-cache squashfs-tools tar
    mkdir /tmp/arch32-bootstrap
    unsquashfs -no-progress -d /tmp/arch32-bootstrap /input/airootfs.sfs
    tar --numeric-owner -C /tmp/arch32-bootstrap -cpf /output/bootstrap-rootfs.tar .
  '

docker import --platform linux/386 "$RUN_DIR/bootstrap-rootfs.tar" "$BOOTSTRAP_IMAGE" >/dev/null
IMAGE_CREATED=1
docker volume create "$ROOTFS_VOLUME" >/dev/null
VOLUME_CREATED=1

printf 'Installing the minimal i686 root filesystem ...\n'
docker run --rm --privileged --platform linux/386 \
  --volume "$ROOTFS_VOLUME:/target" \
  --mount "type=bind,src=$RUN_DIR,dst=/work" \
  --mount "type=bind,src=$SCRIPT_DIR/arch32,dst=/v86-config,readonly" \
  --env "ARCH32_PACKAGES=$ARCH32_PACKAGES" \
  --env "ARCH32_MIRROR=$ARCH32_MIRROR" \
  --env "V86_INIT_SYSTEM=$INIT_SYSTEM" \
  --env "V86_KEEP_MODULES=$KEEP_MODULES" \
  --env "V86_ENABLE_VGA=$ENABLE_VGA" \
  --env "ALLOW_UNSIGNED_KEYRING_BOOTSTRAP=$ALLOW_UNSIGNED_KEYRING_BOOTSTRAP" \
  "$BOOTSTRAP_IMAGE" \
  /usr/bin/setarch i686 /usr/bin/bash /v86-config/build-rootfs.sh

[[ -s "$RUN_DIR/rootfs.tar" ]] || die "rootfs builder did not create rootfs.tar"

if [[ -n "$V86_TOOLS_DIR" ]]; then
  V86_TOOLS_DIR=$(absolute_path "$V86_TOOLS_DIR")
  FS2JSON="$V86_TOOLS_DIR/fs2json.py"
  COPY_TO_SHA256="$V86_TOOLS_DIR/copy-to-sha256.py"
else
  TOOLS_CACHE="$WORK_ROOT/cache/v86-$V86_REF"
  FS2JSON="$TOOLS_CACHE/fs2json.py"
  COPY_TO_SHA256="$TOOLS_CACHE/copy-to-sha256.py"

  fetch_tool() {
    local name=$1
    local expected_hash=$2
    local destination=$3
    local url="https://raw.githubusercontent.com/copy/v86/$V86_REF/tools/$name"

    if [[ -f "$destination" ]] && \
       [[ "$(sha256sum "$destination" | cut -d ' ' -f 1)" == "$expected_hash" ]]; then
      return
    fi

    printf 'Fetching pinned v86 tool %s ...\n' "$name"
    curl --fail --location --retry 3 --output "$destination.tmp" "$url"
    [[ "$(sha256sum "$destination.tmp" | cut -d ' ' -f 1)" == "$expected_hash" ]] || \
      die "checksum verification failed for $name"
    mv -- "$destination.tmp" "$destination"
  }

  fetch_tool fs2json.py "$FS2JSON_SHA256" "$FS2JSON"
  fetch_tool copy-to-sha256.py "$COPY_TO_SHA256_SHA256" "$COPY_TO_SHA256"
fi

[[ -f "$FS2JSON" ]] || die "fs2json.py not found: $FS2JSON"
[[ -f "$COPY_TO_SHA256" ]] || die "copy-to-sha256.py not found: $COPY_TO_SHA256"

python3 - <<'PY' || die "zstd support is required (Python 3.14+, or install the zstandard module)"
try:
    from compression import zstd
except ImportError:
    import zstandard
PY

PUBLISH_DIR="$RUN_DIR/publish"
mkdir -p -- "$PUBLISH_DIR/arch" "$PUBLISH_DIR/boot"

printf 'Creating compressed v86 9p artifacts ...\n'
python3 "$FS2JSON" --zstd --out "$PUBLISH_DIR/fs.json" "$RUN_DIR/rootfs.tar" \
  2>"$RUN_DIR/fs2json.log"
python3 "$COPY_TO_SHA256" --zstd "$RUN_DIR/rootfs.tar" "$PUBLISH_DIR/arch" \
  >"$RUN_DIR/copy-to-sha256.log" 2>&1

bsdtar -xOf "$RUN_DIR/rootfs.tar" boot/vmlinuz-linux >"$PUBLISH_DIR/boot/vmlinuz-arch"
bsdtar -xOf "$RUN_DIR/rootfs.tar" boot/initramfs-linux.img >"$PUBLISH_DIR/boot/initramfs-arch.img"

python3 - "$PUBLISH_DIR/fs.json" "$PUBLISH_DIR/arch" <<'PY'
import json
import pathlib
import re
import sys

manifest_path = pathlib.Path(sys.argv[1])
blob_dir = pathlib.Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text())
blob_name = re.compile(r"^[0-9a-f]{10}\.bin\.zst$")
referenced = set()

def visit(nodes):
    for node in nodes:
        if len(node) < 7:
            continue
        target = node[6]
        if isinstance(target, list):
            visit(target)
        elif isinstance(target, str) and blob_name.fullmatch(target):
            referenced.add(target)

visit(manifest["fsroot"])
missing = sorted(name for name in referenced if not (blob_dir / name).is_file())
if missing:
    print(f"missing {len(missing)} content blobs; first: {missing[0]}", file=sys.stderr)
    raise SystemExit(1)
if not referenced:
    print("manifest does not reference any compressed content blobs", file=sys.stderr)
    raise SystemExit(1)
print(f"Validated {len(referenced)} content-addressed blobs")
PY

cat >"$PUBLISH_DIR/build-info.txt" <<EOF
architecture=i686
packages=$ARCH32_PACKAGES
mirror=$ARCH32_MIRROR
init=$INIT_SYSTEM
kernel_modules_retained=$KEEP_MODULES
vga_modules=$ENABLE_VGA
v86_tools_commit=$V86_REF
EOF

mkdir -p -- "$(dirname -- "$OUTPUT_DIR")"
mv -- "$PUBLISH_DIR" "$OUTPUT_DIR"

printf '\nArch32 9p image created successfully:\n'
printf '  output:   %s\n' "$OUTPUT_DIR"
printf '  manifest: %s\n' "$OUTPUT_DIR/fs.json"
printf '  blobs:    %s\n' "$OUTPUT_DIR/arch"
printf '  kernel:   %s\n' "$OUTPUT_DIR/boot/vmlinuz-arch"
printf '  initramfs:%s\n' " $OUTPUT_DIR/boot/initramfs-arch.img"
printf '\nThe current archlinux32 assets were not modified. See scripts/v86/README.md\n'
printf 'for installation and snapshot instructions.\n'
