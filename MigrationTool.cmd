@echo off
:: Launcher for Windows 11 Migration Tool GUI
:: Runs the PowerShell GUI script with bypass execution policy and admin elevation
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0MigrationTool-GUI.ps1"
