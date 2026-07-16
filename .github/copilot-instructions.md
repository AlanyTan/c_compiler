# AI Coding Agent Instructions for Browser-Based C/C++ Compiler

## Project Overview
This is a web-based C/C++ compiler environment with dual implementations:
1. **Legacy (jor1k)**: OpenRISC-based system with GCC 4.9.1, 32MB memory
2. **Modern (v86)**: x86-based system with GCC 11+, 128MB memory, C++20/23 support

The project is currently migrating from jor1k to v86 for significantly better performance and modern language features.

## Core Architecture

### Dual Implementation System

#### Legacy Stack (jor1k)
1. **Web Interface Layer** (`index.html`): ACE editor integration, file management, UI controls
2. **Virtual Machine Layer** (`jor1k-*-min.js`): OpenRISC CPU emulation with Linux kernel
3. **Filesystem Layer** (`openrisc-sys/`): Complete Linux environment with GCC 4.9.1 toolchain

#### Modern Stack (v86) 
1. **Web Interface Layer** (`index_v86.html`): Enhanced ACE editor with modern UI
2. **Virtual Machine Layer** (v86): x86 CPU emulation with WebAssembly optimization  
3. **Operating System**: Alpine Linux with GCC 11+ and modern development tools

### Key Components

- **jor1kGUI**: Main VM controller initialized in `Start()` function
- **LinuxTerm**: Terminal emulator that communicates with VM via `tty0`/`tty1`
- **ACE Editor**: Code editor with C/C++ syntax highlighting and error annotations
- **File Transfer**: Bidirectional file operations between browser and VM filesystem

## Critical Integration Points

### Compilation Workflow
The compilation process uses regex-based output capture:
```javascript
// Compilation markers used to capture GCC output
var gcc_output_capture_re = /###GCC_COMPILE###\s*([\S\s]*?)\s*###GCC_COMPILE_FINISHED###/;
```

When editing compilation flow:
- Use `SendKeysToJor1k()` to send commands to VM
- Monitor `term_output` for compilation markers
- Parse GCC output with `getErrorAnnotations()` for editor integration
- Handle async compilation with `waitForGccCompletion()` polling

### VM Communication Protocol
```javascript
// Send files to VM filesystem
jor1kgui.message.Send("MergeFile", {name: "home/user/"+filename, data: bufView});

// Send terminal commands
SendKeysToJor1k("gcc " + gccoptions + " " + filename + " -o run\n");
```

### Error Handling Patterns
Error parsing follows this pattern:
```javascript
// GCC error format: "filename:line:col: type: message"
var gcc_output_parse_re = /(?:prog\.c|gcc|collect2):\s*(.+)\s*:\s*(.+)\s*/;
var gcc_row_col_type_parse_re = /(\d+):(\d+):\s*(.+)/;
```

## Development Workflows

### Testing Changes
1. Modify code in ACE editor or upload files
2. Use "编译 运行" (Compile & Run) button
3. Check terminal output and error annotations
4. Use "重启虚拟机" (Reset VM) to clean state

### Adding Language Support
- Update `setFileExtension()` function for new file types
- Modify ACE editor mode in `CreateEditor()`
- Extend compilation logic in `RunCode()` function

### VM Filesystem Access
- Upload files: Use file input with `OnUploadFiles()`
- Download: Use TAR export functionality
- Direct manipulation: Send Linux commands via `SendKeysToJor1k()`

## File Structure Conventions

- **Static Assets**: `css/`, `images/`, `bootstrap/` for UI resources
- **Editor Components**: `ace-editor-src-min-noconflict/` for code editor
- **VM System**: `openrisc-sys/` contains complete Linux environment
  - `basefs-compile.json`: VM filesystem configuration for compiler environment
  - `kernel/vmlinux.bin.bz2`: Linux kernel image
  - `archlinux32/`: Complete filesystem tree with GCC toolchain

## Performance Considerations

- VM uses 32MB memory limit (power of two requirement)
- Files are loaded on-demand via `earlyload` configuration
- Large operations should use background processing with `isBackground` parameter
- Terminal output is buffered and parsed asynchronously

## Chinese Language Context
UI elements use Chinese text reflecting the educational context (C++ textbook companion):
- "编译 运行" = Compile & Run
- "重启虚拟机" = Reset VM  
- "打开..." / "保存..." = Open/Save file operations

When modifying UI text, maintain consistency with the educational Chinese interface while keeping function names and technical terms in English.

## Key Integration Files
- `index.html`: Main application entry point and UI logic
- `jor1k-master-min.js`: VM emulator core
- `openrisc-sys/basefs-compile.json`: VM filesystem configuration
- `ace-editor-src-min-noconflict/ace.js`: Code editor engine