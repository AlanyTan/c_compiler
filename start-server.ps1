# PowerShell Web Server for V86 C++ Compiler
Write-Host "🚀 Starting local web server..." -ForegroundColor Green
Write-Host ""
Write-Host "📡 Server will be available at: http://localhost:8000" -ForegroundColor Yellow
Write-Host ""
Write-Host "📝 Available pages:" -ForegroundColor Cyan
Write-Host "   - http://localhost:8000/v86-test-simple.html (Diagnostic tool)" -ForegroundColor White
Write-Host "   - http://localhost:8000/test-v86.html (Full V86 compiler)" -ForegroundColor White  
Write-Host "   - http://localhost:8000/index.html (Original jor1k compiler)" -ForegroundColor White
Write-Host ""
Write-Host "⏹️  Press Ctrl+C to stop the server" -ForegroundColor Red
Write-Host ""

# Start Python HTTP server
python -m http.server 8000