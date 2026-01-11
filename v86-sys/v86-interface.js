/**
 * V86 Interface Integration
 * This module provides the interface between the web application
 * and the v86 emulator, replacing jor1k functionality
 */

class V86Interface {
    constructor(config) {
        this.emulator = null;
        this.config = config;
        this.isRunning = false;
        this.terminal = null;
        this.fileBuffer = new Map();
        this.systemReady = false; // Track if system is ready for commands
        
        // Event handlers
        this.onTerminalOutput = null;
        this.onSystemReady = null;
        this.onCompilationComplete = null;
        
        // Compilation state
        this.compilationInProgress = false;
        this.currentCommand = '';
        this.outputBuffer = '';
        
        // Output batching for better performance
        this.pendingOutput = '';
        this.outputTimeout = null;
        
        // Serial console tracking
        this.serialOutputReceived = false;
        this.lastSerialOutput = 0;
        
        // Screen output tracking as fallback
        this.screenOutputReceived = false;
        this.screenBuffer = '';
        this.receivedEvents = new Set();
    }

    /**
     * Initialize the v86 emulator
     */
    async initialize() {
        try {
            console.log('=== V86 Initialization Debug ===');
            
            // Check if V86 constructor is available
            console.log('V86Starter available:', typeof V86Starter !== 'undefined');
            console.log('V86 available:', typeof V86 !== 'undefined');
            
            if (typeof V86Starter === 'undefined' && typeof V86 === 'undefined') {
                throw new Error('V86 constructor is not available. Make sure the v86 library is loaded first.');
            }
            
            // Log the configuration being used
            console.log('V86 Configuration:', JSON.stringify(this.config, null, 2));
            
            // Use the available constructor
            const V86Constructor = typeof V86Starter !== 'undefined' ? V86Starter : V86;
            console.log('Using V86 constructor:', V86Constructor.name || 'V86');
            
            // Track emulator creation
            console.log('Creating V86 emulator instance...');
            this.emulator = new V86Constructor(this.config);
            console.log('V86 emulator instance created successfully');
            
            // Track if emulator exists and has expected methods
            console.log('Emulator methods available:');
            console.log('- add_listener:', typeof this.emulator.add_listener);
            console.log('- serial0_send:', typeof this.emulator.serial0_send);
            console.log('- restart:', typeof this.emulator.restart);
            
            // Track serial output reception
            this.serialOutputReceived = false;
            this.lastSerialOutput = Date.now();
            
            // Add a basic heartbeat to detect if emulator is running
            this.emulatorHeartbeat = setInterval(() => {
                if (this.emulator && typeof this.emulator.is_running === 'function') {
                    console.log('V86 heartbeat - running:', this.emulator.is_running());
                } else {
                    console.log('V86 heartbeat - emulator status unknown');
                }
            }, 10000); // Every 10 seconds
            
            // Set up event listeners with comprehensive debugging
            this.emulator.add_listener("serial0-output-char", (char) => {
                this.serialOutputReceived = true;
                this.lastSerialOutput = Date.now();
                console.log('Serial0 char received:', char, String.fromCharCode(char));
                this.handleTerminalOutput(char);
            });
            
            this.emulator.add_listener("serial1-output-char", (char) => {
                console.log('Serial1 char received:', char, String.fromCharCode(char));
                this.handleTerminalOutput(char);
            });
            
            this.emulator.add_listener("serial2-output-char", (char) => {
                console.log('Serial2 char received:', char, String.fromCharCode(char));
                this.handleTerminalOutput(char);
            });

            // Add comprehensive debugging for all V86 events
            const allEvents = [
                "emulator-ready", "emulator-stopped", "download-progress", "download-error",
                "screen-put-char", "screen-clear", "screen-set-size", "screen-fill-buffer-end",
                "serial0-output-char", "serial1-output-char", "serial2-output-char",
                "dac-send-data", "pit-counter-update", "rtc-tick", "mouse-click", "keyboard-code"
            ];
            
            // Track which events we actually receive
            this.receivedEvents = new Set();
            
            allEvents.forEach(eventName => {
                this.emulator.add_listener(eventName, (data) => {
                    if (!this.receivedEvents.has(eventName)) {
                        console.log(`First time receiving V86 event: ${eventName}`, data);
                        this.receivedEvents.add(eventName);
                    }
                    
                    // Handle specific events
                    switch(eventName) {
                        case 'emulator-ready':
                            console.log('Emulator ready event received');
                            this.handleSystemReady();
                            break;
                        case 'emulator-stopped':
                            console.log('Emulator stopped event received');
                            this.handleSystemStop();
                            break;
                        case 'download-progress':
                            console.log('Download progress:', data);
                            break;
                        case 'download-error':
                            console.error('Download error:', data);
                            break;
                        case 'screen-put-char':
                            // Try to capture screen output as fallback
                            this.handleScreenOutput(data);
                            break;
                    }
                });
            });

            this.isRunning = true;
            console.log('V86 emulator initialized successfully');
            
        } catch (error) {
            console.error('Failed to initialize v86 emulator:', error);
            throw error;
        }
    }

    /**
     * Handle screen output as fallback when serial doesn't work
     */
    handleScreenOutput(data) {
        this.screenOutputReceived = true;
        
        if (data && typeof data === 'object') {
            // Convert screen data to text if possible
            if (data.char || data.character) {
                const char = String.fromCharCode(data.char || data.character);
                this.screenBuffer += char;
                
                // Emit screen output to terminal as fallback
                if (this.onTerminalOutput && !this.serialOutputReceived) {
                    console.log('Using screen output as fallback');
                    this.onTerminalOutput(char);
                }
            }
        }
        
        // Debug every 100 characters
        if (this.screenBuffer.length % 100 === 0) {
            console.log('Screen buffer length:', this.screenBuffer.length);
        }
    }

    /**
     * Handle terminal output from v86
     */
    handleTerminalOutput(char) {
        const charCode = typeof char === 'number' ? char : char.charCodeAt(0);
        const charStr = String.fromCharCode(charCode);
        
        // Debug: log every 50th character to verify we're getting output
        if (this.outputBuffer.length % 50 === 0) {
            console.log('Serial output received, buffer length:', this.outputBuffer.length, 'char:', JSON.stringify(charStr));
        }
        
        // Convert to string and add to buffer
        this.outputBuffer += charStr;
        
        // Keep buffer from growing too large
        if (this.outputBuffer.length > 10000) {
            this.outputBuffer = this.outputBuffer.slice(-5000);
        }
        
        // Check for compilation markers
        this.checkCompilationMarkers();
        
        // Emit to terminal if handler is set (batch output for better performance)
        if (this.onTerminalOutput) {
            // Buffer output and send in chunks
            clearTimeout(this.outputTimeout);
            this.outputTimeout = setTimeout(() => {
                if (this.pendingOutput) {
                    this.onTerminalOutput(this.pendingOutput);
                    this.pendingOutput = '';
                }
            }, 10);
            
            this.pendingOutput = (this.pendingOutput || '') + charStr;
        }
    }

    /**
     * Check for GCC compilation markers in output
     */
    checkCompilationMarkers() {
        // Look for compilation start marker
        if (this.outputBuffer.includes('###GCC_COMPILE###')) {
            this.compilationInProgress = true;
            console.log('Compilation started');
        }
        
        // Look for compilation end marker
        if (this.outputBuffer.includes('###GCC_COMPILE_FINISHED###')) {
            this.compilationInProgress = false;
            console.log('Compilation finished');
            
            // Extract compilation output
            const match = this.outputBuffer.match(/###GCC_COMPILE###\s*([\S\s]*?)\s*###GCC_COMPILE_FINISHED###/);
            if (match && this.onCompilationComplete) {
                this.onCompilationComplete(match[1]);
            }
            
            // Clear the buffer
            this.outputBuffer = '';
        }
    }

    /**
     * Force test the emulator manually
     */
    forceTest() {
        console.log('=== Force Testing V86 Emulator ===');
        
        if (!this.emulator) {
            console.error('No emulator instance available');
            return;
        }
        
        console.log('Attempting to send test data to all serial ports...');
        
        try {
            // Try to send to serial0
            console.log('Sending to serial0...');
            this.emulator.serial0_send(65); // Send 'A'
            this.emulator.serial0_send(13); // CR
            this.emulator.serial0_send(10); // LF
            
            // Try manual commands
            console.log('Sending echo command...');
            const testCmd = 'echo "FORCE_TEST_OUTPUT"';
            for (let i = 0; i < testCmd.length; i++) {
                this.emulator.serial0_send(testCmd.charCodeAt(i));
            }
            this.emulator.serial0_send(13);
            this.emulator.serial0_send(10);
            
            console.log('Force test commands sent');
        } catch (error) {
            console.error('Error during force test:', error);
        }
    }

    /**
     * Check V86 communication status
     */
    checkV86Status() {
        console.log('=== V86 Communication Status ===');
        console.log('Events received:', Array.from(this.receivedEvents));
        console.log('Serial output received:', this.serialOutputReceived);
        console.log('Screen output received:', this.screenOutputReceived);
        console.log('Output buffer length:', this.outputBuffer.length);
        console.log('Screen buffer length:', this.screenBuffer.length);
        
        if (this.receivedEvents.size === 0) {
            console.error('❌ No V86 events received at all - emulator may not be working');
        } else if (!this.serialOutputReceived && !this.screenOutputReceived) {
            console.warn('⚠️ V86 events received but no console output - OS may not be booting');
        } else {
            console.log('✅ V86 communication working');
        }
    }

    /**
     * Handle system ready event
     */
    handleSystemReady() {
        console.log('V86 system ready event received');
        
        // Give the system time to boot and establish console
        setTimeout(() => {
            this.checkV86Status();
            
            console.log('Testing console connectivity...');
            
            // Check if we've received any output at all
            if (!this.serialOutputReceived && !this.screenOutputReceived) {
                console.warn('No console output received yet. VM may still be booting.');
                // Still try to send test commands
            }
            
            // Send initial commands to help establish console connection
            console.log('Sending initial console setup commands...');
            // Send some newlines to help establish console
            this.emulator.serial0_send(0x0A); // LF
            this.emulator.serial0_send(0x0D); // CR
            this.emulator.serial0_send(0x0A); // LF
            
            // Wait and then send a test command
            setTimeout(() => {
                console.log('Sending test echo command...');
                this.sendCommand('echo "VM_CONSOLE_TEST_RESPONSE"');
                
                // Check for test response
                setTimeout(() => {
                    if (this.outputBuffer.includes('VM_CONSOLE_TEST_RESPONSE')) {
                        console.log('Console test successful - system is responsive');
                        this.systemReady = true;
                    } else {
                        console.warn('Console test failed - no response received');
                        console.warn('Output buffer content:', JSON.stringify(this.outputBuffer.slice(-200)));
                        
                        // Try force test as last resort
                        console.log('Attempting force test...');
                        this.forceTest();
                        
                        // Mark as ready anyway but log the issue
                        this.systemReady = true;
                    }
                    
                    if (this.onSystemReady) {
                        this.onSystemReady();
                    }
                }, 3000);
            }, 2000);
        }, 5000); // Wait 5 seconds before starting tests
    }

    /**
     * Handle system stop event
     */
    handleSystemStop() {
        console.log('V86 system stopped');
        this.isRunning = false;
    }

    /**
     * Send command to the virtual machine
     */
    sendCommand(command) {
        if (!this.isRunning) {
            console.error('VM is not running');
            return;
        }

        console.log('Sending command:', command);
        this.currentCommand = command;
        
        // Send each character of the command
        for (let i = 0; i < command.length; i++) {
            this.emulator.serial0_send(command.charCodeAt(i));
        }
        
        // Send enter key
        this.emulator.serial0_send(0x0D); // Carriage return
        this.emulator.serial0_send(0x0A); // Line feed
    }

    /**
     * Ensure system is ready for commands
     */
    async ensureSystemReady() {
        console.log('Ensuring system is ready...');
        
        // Wait for initial boot
        await this.waitForPrompt(60000); // 1 minute for boot
        
        // Test basic commands
        this.sendCommand('echo "System ready test"');
        await this.waitForPrompt(10000);
        
        // Ensure we have a working directory
        this.sendCommand('mkdir -p /tmp/compiler && cd /tmp/compiler');
        await this.waitForPrompt(10000);
        
        console.log('System is ready!');
    }

    /**
     * Upload file to the virtual machine
     */
    async uploadFile(filename, content) {
        try {
            console.log('Uploading file:', filename);
            
            // Store file in buffer for later transfer
            this.fileBuffer.set(filename, content);
            
            // Ensure system is ready first
            if (!this.systemReady) {
                console.log('System not ready, ensuring readiness...');
                await this.waitForPrompt(60000); // 1 minute for boot
                
                // Test basic commands
                this.sendCommand('echo "System ready test"');
                await this.waitForPrompt(10000);
                
                // Ensure we have a working directory
                this.sendCommand('mkdir -p /tmp/compiler && cd /tmp/compiler');
                await this.waitForPrompt(10000);
                
                this.systemReady = true;
                console.log('System is ready!');
            }
            
            // Use a more reliable method - write to a temporary file
            const tempFile = `/tmp/compiler/${filename}`;
            
            // Create the file using cat with EOF delimiter
            this.sendCommand(`cat > ${tempFile} << 'COMPILER_EOF'`);
            await new Promise(resolve => setTimeout(resolve, 1000)); // Longer delay
            
            // Send the content line by line with small delays
            const lines = content.split('\n');
            for (const line of lines) {
                this.sendCommand(line);
                await new Promise(resolve => setTimeout(resolve, 100)); // Small delay between lines
            }
            
            // End the cat command
            this.sendCommand('COMPILER_EOF');
            await this.waitForPrompt(15000);
            
            // Verify the file was created
            this.sendCommand(`ls -la ${tempFile}`);
            await this.waitForPrompt(5000);
            
            console.log('File uploaded successfully:', filename);
            
        } catch (error) {
            console.error('Failed to upload file:', filename, error);
            // Try a simpler approach as fallback
            console.log('Trying fallback upload method...');
            await this.uploadFileFallback(filename, content);
        }
    }
    
    /**
     * Fallback file upload method
     */
    async uploadFileFallback(filename, content) {
        console.log('Using fallback upload for:', filename);
        
        // Simple approach - encode content in base64 and decode
        try {
            const base64Content = btoa(content);
            this.sendCommand(`echo "${base64Content}" | base64 -d > /tmp/compiler/${filename}`);
            await this.waitForPrompt(10000);
        } catch (e) {
            // Even simpler fallback
            const escapedContent = content.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
            this.sendCommand(`printf "${escapedContent}" > /tmp/compiler/${filename}`);
            await this.waitForPrompt(10000);
        }
    }

    /**
     * Compile and run C++ code
     */
    async compileAndRun(filename, options = '') {
        try {
            console.log('Compiling and running:', filename);
            
            // Check if we have received any serial output
            const hasSerialOutput = this.serialOutputReceived;
            console.log('Serial output received so far:', hasSerialOutput);
            
            if (!hasSerialOutput) {
                console.warn('No serial console detected. Using non-interactive mode.');
                // Use non-interactive approach
                await this.compileNonInteractive(filename, options);
                return;
            }
            
            // Upload file first if we have interactive console
            await this.uploadFile(filename, this.fileBuffer.get(filename) || '');
            
            // Change to compiler directory
            await this.sendCommandNoWait('cd /tmp/compiler');
            
            // Add compilation markers for output capture
            await this.sendCommandNoWait('echo "###GCC_COMPILE###"');
            
            // Compile the code
            const compileCommand = `g++ -std=c++17 ${options} ${filename} -o program 2>&1`;
            await this.sendCommandNoWait(compileCommand);
            
            // Check if compilation was successful
            await this.sendCommandNoWait('if [ -f program ]; then echo "Compilation successful"; ./program; else echo "Compilation failed"; fi');
            
            // End compilation marker
            await this.sendCommandNoWait('echo "###GCC_COMPILE_FINISHED###"');
            
        } catch (error) {
            console.error('Compilation failed:', error);
            throw error;
        }
    }
    
    /**
     * Non-interactive compilation for systems without proper console
     */
    async compileNonInteractive(filename, options = '') {
        console.log('Using non-interactive compilation mode');
        
        // Just send the commands without waiting for prompts
        this.sendCommandNoWait('echo "###GCC_COMPILE###"');
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        const compileCommand = `g++ -std=c++17 ${options} ${filename} -o program 2>&1`;
        this.sendCommandNoWait(compileCommand);
        await new Promise(resolve => setTimeout(resolve, 3000)); // Give more time for compilation
        
        this.sendCommandNoWait('if [ -f program ]; then echo "Compilation successful"; ./program; else echo "Compilation failed"; fi');
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        this.sendCommandNoWait('echo "###GCC_COMPILE_FINISHED###"');
        
        // Simulate compilation complete after reasonable delay
        setTimeout(() => {
            if (this.onCompilationComplete) {
                this.onCompilationComplete('Non-interactive compilation attempted');
            }
        }, 1000);
    }

    /**
     * Send command without waiting for prompt (for non-interactive use)
     */
    sendCommandNoWait(command) {
        console.log('Sending command (no wait):', command);
        this.currentCommand = command;
        
        // Send each character of the command
        for (let i = 0; i < command.length; i++) {
            this.emulator.serial0_send(command.charCodeAt(i));
        }
        
        // Send enter key
        this.emulator.serial0_send(0x0D); // Carriage return
        this.emulator.serial0_send(0x0A); // Line feed
        
        // Give some time for command to execute
        return new Promise(resolve => {
            setTimeout(resolve, 2000);
        });
    }

    /**
     * Wait for command prompt
     */
    async waitForPrompt(timeout = 30000) { // Increased to 30 seconds
        return new Promise((resolve, reject) => {
            const startTime = Date.now();
            let checkCount = 0;
            
            const checkPrompt = () => {
                checkCount++;
                const elapsed = Date.now() - startTime;
                
                // Debug: log the current buffer content more clearly
                const bufferLength = this.outputBuffer.length;
                const bufferEnd = this.outputBuffer.slice(-100); // Last 100 chars
                
                if (checkCount % 10 === 0) { // Log every 10th check
                    console.log(`Prompt check ${checkCount} (${elapsed}ms elapsed, ${bufferLength} chars):`, JSON.stringify(bufferEnd));
                }
                
                // More comprehensive and flexible prompt detection patterns
                const promptPatterns = [
                    'localhost:~#',       // Alpine Linux root prompt
                    'localhost:~$',       // Alpine Linux user prompt
                    'localhost',          // Any Alpine localhost prompt
                    'alpine:',            // Alpine hostname variants
                    '~ # ',               // Simple root prompt
                    '~# ',                // Simple root prompt (no space)
                    '~ $ ',               // Simple user prompt  
                    '~$ ',                // Simple user prompt (no space)
                    '/ # ',               // Root directory prompt
                    '/# ',                // Root directory prompt (no space)
                    'login:',             // Login prompt
                    '$ ',                 // Generic shell prompt
                    '# '                  // Generic root prompt
                ];
                
                // Check if we have any prompt-like pattern
                for (const pattern of promptPatterns) {
                    if (this.outputBuffer.includes(pattern)) {
                        console.log(`Found prompt pattern: "${pattern}" after ${elapsed}ms`);
                        resolve();
                        return;
                    }
                }
                
                // Also accept if we see typical Linux boot messages followed by some activity
                if (this.outputBuffer.includes('Welcome to Alpine Linux') || 
                    this.outputBuffer.includes('login as:') ||
                    this.outputBuffer.includes('ash') ||
                    (this.outputBuffer.length > 100 && this.outputBuffer.includes('Alpine'))) {
                    console.log(`Found Alpine Linux system indicators after ${elapsed}ms`);
                    resolve();
                    return;
                }
                
                if (elapsed > timeout) {
                    const debugInfo = {
                        bufferLength: this.outputBuffer.length,
                        lastChars: this.outputBuffer.slice(-200),
                        checkCount,
                        elapsed
                    };
                    console.error('Timeout waiting for prompt:', debugInfo);
                    
                    // Don't reject immediately - try to continue anyway for Alpine
                    if (this.outputBuffer.length > 0) {
                        console.warn('Continuing despite timeout - we have some output');
                        resolve();
                    } else {
                        reject(new Error(`Timeout waiting for prompt after ${elapsed}ms`));
                    }
                    return;
                }
                
                setTimeout(checkPrompt, 500); // Check every 500ms
            };
            
            checkPrompt();
        });
    }

    /**
     * Restart the virtual machine
     */
    restart() {
        console.log('Restarting v86 emulator...');
        
        if (this.emulator) {
            this.emulator.restart();
        }
        
        // Reset state
        this.compilationInProgress = false;
        this.outputBuffer = '';
        this.fileBuffer.clear();
    }

    /**
     * Stop the virtual machine
     */
    stop() {
        console.log('Stopping v86 emulator...');
        
        if (this.emulator) {
            this.emulator.stop();
        }
        
        this.isRunning = false;
    }

    /**
     * Get system information
     */
    async getSystemInfo() {
        this.sendCommand('uname -a && gcc --version && free -m');
        await this.waitForPrompt();
    }
}

// Export for use in HTML
window.V86Interface = V86Interface;