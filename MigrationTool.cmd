@echo off
:: Launcher for Windows 11 Migration Tool GUI
:: Requires: Run as Administrator

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the GUI script
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0MigrationTool-GUI.ps1"
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to launch the Migration Tool GUI.
    echo Make sure PowerShell is available on this system.
    pause
)
