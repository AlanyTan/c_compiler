@echo off
echo Starting local web server for V86 C++ Compiler...
echo.
echo Server will be available at: http://localhost:8000
echo.
echo Available pages:
echo - http://localhost:8000/v86-test-simple.html (Diagnostic tool)
echo - http://localhost:8000/test-v86.html (Full C++ compiler)
echo - http://localhost:8000/index.html (Original jor1k version)
echo.
echo Press Ctrl+C to stop the server
echo.

python -m http.server 8000