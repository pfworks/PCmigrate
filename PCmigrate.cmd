@echo off
:: Launcher for PCmigrate
:: Requires: Run as Administrator

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the GUI script (unblock first in case extracted from zip)
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "Get-ChildItem -Path '%~dp0' -Filter '*.ps1' | Unblock-File -ErrorAction SilentlyContinue"
start "" /b powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0PCmigrate-GUI.ps1"
