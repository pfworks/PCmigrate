@echo off
:: Launcher for PCmigrate - checks style preference
:: Requires: Run as Administrator

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Check style preference
set "GUI=PCmigrate-GUI.ps1"
if exist "%~dp0.pcmigrate-style" (
    set /p STYLE=<"%~dp0.pcmigrate-style"
    if /i "%STYLE%"=="Retro" set "GUI=PCmigrate-Retro.ps1"
)

:: Run the GUI script
start "" /b powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0%GUI%"
