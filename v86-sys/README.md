# V86 Configuration and Resources

This directory contains the configuration and resources needed for the v86 emulator implementation.

## File Structure

- `alpine-linux.iso` - Alpine Linux disk image with C++ development tools
- `v86-config.js` - v86 emulator configuration
- `v86-interface.js` - JavaScript interface for v86 integration
- `alpine-setup.sh` - Setup script for Alpine Linux environment

## Alpine Linux Configuration

The Alpine Linux environment includes:
- GCC 11+ with C++17/20 support
- Development tools: make, cmake, gdb, binutils
- Text editors: nano, vim
- Utility tools: wget, curl, tar, git
- Python 3 and Node.js for extensibility

## V86 Setup Process

1. Download v86 library from: https://github.com/copy/v86
2. Create Alpine Linux disk image
2.1. V86 libraries:
   - libv86.js: https://github.com/copy/v86/releases
   - v86.wasm: https://github.com/copy/v86/releases
   - libv86.js ^(save to build/libv86.js^)
   - v86.wasm ^(save to build/v86.wasm^)   

2.2. BIOS image:
   - SeaBIOS: https://github.com/copy/v86/raw/master/bios/seabios.bin
      ^(save to bios/seabios.bin^)
   - VGA BIOS: https://github.com/copy/v86/raw/master/bios/vgabios.bin
      ^(save to bios/vgabios.bin^)   

2.3. Alpine Linux ISO:
   - alpine Linux iso: https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-standard-3.23.2-x86_64.iso
   - ^(save to v86-sys/alpine-linux.iso)

3. Configure v86 with the provided configuration
4. Integrate with ACE editor and terminal interface


## Memory Configuration

- RAM: 128MB (4x improvement over jor1k's 32MB)
- VGA Memory: 8MB
- Screen Resolution: 80x25 terminal mode

## Performance Improvements

- x86 architecture with modern toolchain
- WebAssembly optimization
- Faster compilation times
- Support for modern C++ standards
- Better debugging capabilities

## Usage

The v86 implementation provides:
- Drop-in replacement for jor1k interface
- Enhanced compilation workflow
- Improved error handling
- Multi-language support preparation
- Better performance monitoring