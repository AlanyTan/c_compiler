/**
 * V86 Configuration for C++ Compiler Environment
 * This configuration sets up an x86 Alpine Linux environment
 * with modern GCC toolchain and 128MB RAM
 */

const V86_CONFIG = {
    wasm_path: "v86.wasm",
    memory_size: 128 * 1024 * 1024, // 128MB RAM
    vga_memory_size: 8 * 1024 * 1024, // 8MB VGA memory
    
    screen_container: document.getElementById("screen_container"),
    
    bios: {
        url: "bios/seabios.bin",
    },
    vga_bios: {
        url: "bios/vgabios.bin",
    },
    
    cdrom: {
        url: "v86-sys/alpine-linux.iso",
    },
    
    autostart: true,
    
    // Network configuration for future expansion
    network_relay_url: "wss://relay.widgetry.org/",
    
    // Serial terminal configuration
    serial0: {
        type: "terminal",
        device: "ttyS0"
    },
    
    // Boot configuration
    boot_order: 0x123, // Try floppy, then CD, then HDD
};

/**
 * Extended V86 Configuration with development optimizations
 */
const V86_DEV_CONFIG = {
    ...V86_CONFIG,
    
    // Enable debugging features
    log_level: 1,
    
    // Filesystem optimizations
    filesystem: {
        baseurl: "v86-sys/",
        basefs: {
            url: "alpine-base.json",
        },
    },
    
    // ACPI configuration for better hardware support
    acpi: true,
    
    // Real-time clock
    rtc_time: Date.now(),
    
    // CPU configuration
    cpu_count: 1,
    
    // Performance monitoring
    performance: {
        enable_profiling: false,
        log_performance: false
    }
};

/**
 * Production V86 Configuration
 * Optimized for performance and stability
 */
const V86_PROD_CONFIG = {
    ...V86_CONFIG,
    
    // Disable debug logging
    log_level: 0,
    
    // Memory optimization
    memory_size: 128 * 1024 * 1024,
    vga_memory_size: 4 * 1024 * 1024, // Reduced VGA memory for more RAM
    
    // Disable unnecessary features for production
    performance: {
        enable_profiling: false,
        log_performance: false
    }
};

export { V86_CONFIG, V86_DEV_CONFIG, V86_PROD_CONFIG };