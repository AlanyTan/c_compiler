#!/bin/sh
# Alpine Linux setup script for C++ compiler environment
# This script configures Alpine Linux for use with v86 emulator

echo "Setting up Alpine Linux for C++ development..."

# Increase tmpfs size before package installation
mount -o remount,size=400M /tmp 2>/dev/null || true

# up ip link
modprobe ne2k-pci
ip link set eth0 up
udhcpc -i eth0

# Update package manager
echo "http://dl-cdn.alpinelinux.org/alpine/v3.23/main" > /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.23/community" >> /etc/apk/repositories

apk update

# Install ONLY essential development tools (core compiler)
# Using build-base package which includes gcc, g++, make, libc-dev, etc.
apk add --no-cache build-base

# Install minimal additional tools
apk add --no-cache \
    nano \
    gdb

# Optional: Uncomment if you need these (requires more memory)
# apk add --no-cache cmake git python3 nodejs

# Create user directories
mkdir -p /home/user
mkdir -p /tmp/compiler

# Set up permissions
chmod 755 /home/user
chmod 777 /tmp/compiler

# Create a welcome script
cat > /home/user/.profile << 'EOF'
export PATH="/usr/local/bin:/usr/bin:/bin"
export PS1="user@alpine:~$ "
cd /home/user
echo "Alpine Linux C++ Development Environment"
echo "GCC Version: $(gcc --version | head -n1)"
echo "G++ Version: $(g++ --version | head -n1)"
echo "Available compilers: gcc, g++, make, cmake, gdb"
echo ""
EOF

# Create compilation helper script
cat > /usr/local/bin/compile-cpp << 'EOF'
#!/bin/sh
# Helper script for C++ compilation
if [ $# -eq 0 ]; then
    echo "Usage: compile-cpp <source_file> [output_name] [additional_flags]"
    exit 1
fi

SOURCE="$1"
OUTPUT="${2:-program}"
FLAGS="$3"

echo "Compiling $SOURCE..."
g++ -std=c++17 $FLAGS "$SOURCE" -o "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "Compilation successful. Output: $OUTPUT"
    echo "Run with: ./$OUTPUT"
else
    echo "Compilation failed."
fi
EOF

chmod +x /usr/local/bin/compile-cpp

echo "Alpine Linux setup complete!"
echo "GCC version: $(gcc --version | head -n1)"
echo "System ready for C++ development."