@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
powershell -Command "Get-ChildItem -Path '%~dp0' -Filter *.ps1 -Recurse | Unblock-File"
powershell -ExecutionPolicy Bypass -File "%~dp0Restore-Machine.ps1"
pause
