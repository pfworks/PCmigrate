@echo off
:: Launcher for Windows Migration Tool GUI
:: This re-launches via wscript to hide the console window

:: If already admin, launch hidden
net session >nul 2>&1
if %errorlevel% equ 0 (
    start "" /b powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0PCmigrate-GUI.ps1"
    exit /b
)

:: Not admin - use VBS to elevate without visible console
echo CreateObject("Shell.Application").ShellExecute "powershell.exe", "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""%~dp0PCmigrate-GUI.ps1""", "", "runas", 0 > "%temp%\launch_migration.vbs"
wscript "%temp%\launch_migration.vbs"
del "%temp%\launch_migration.vbs"
