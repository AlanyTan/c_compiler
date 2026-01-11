#!/bin/sh
# Alpine Linux setup script for C++ compiler environment
# This script configures Alpine Linux for use with v86 emulator

echo "Setting up Alpine Linux for C++ development..."

# Update package manager
apk update

# Install essential development tools
apk add --no-cache \
    gcc \
    g++ \
    make \
    cmake \
    gdb \
    binutils \
    libc-dev \
    linux-headers \
    musl-dev

# Install additional useful tools
apk add --no-cache \
    nano \
    vim \
    wget \
    curl \
    tar \
    gzip \
    unzip \
    git

# Install Python and Node.js for future expansion
apk add --no-cache \
    python3 \
    python3-dev \
    py3-pip \
    nodejs \
    npm

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