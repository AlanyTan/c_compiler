# how to set up alpine linux with gcc

## V86 Disk Configuration

The VM now includes a 512MB RAM disk (hda) for installing packages. To use it:

### Format and mount the disk (first time only):
```bash
# Format the disk as ext4
mkfs.ext4 /dev/sda

# Create mount point and mount
mkdir -p /mnt/disk
mount /dev/sda /mnt/disk

# Create directories for packages
mkdir -p /mnt/disk/tmp
mkdir -p /mnt/disk/cache

# Configure APK to use the disk for cache
echo "/mnt/disk/cache" > /etc/apk/cache

# Set temporary directory to disk
export TMPDIR=/mnt/disk/tmp
```

### Alternative: Use the disk as root overlay
```bash
# Setup Alpine to use the disk for persistence
setup-alpine
# Follow prompts, select /dev/sda as disk, sys installation mode
```

## setup network in the alpine VM
modprobe ne2k-pci
ip link set eth0 up
udhcpc -i eth0
ping 1.1.1.1

## set up apk repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.23/main" > /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.23/community" >> /etc/apk/repositories

## install build-base 
apk update
apk add build-base

## or install gcc only
apk update
apk add gcc musl-dev