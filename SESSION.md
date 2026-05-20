# Session Notes — 2026-05-11

## Goal

Create a PowerShell-based migration tool for moving from one Windows 11 machine to another.

## Requirements Discussed

- Archive WSL instances (tar export)
- List all installed software with versions
- Retrieve license keys where possible (Windows, Office, registry)
- Include download URLs for reinstallation
- Generate a restore script for the new machine
- Support exporting to an external drive for physical transfer

## What Was Built

### Migrate-Machine.ps1
Main export script. Run as Admin on the source machine. Accepts `-OutputPath` parameter (defaults to Desktop). Produces:
- `license_keys.txt` — product keys from BIOS, Office ospp.vbs, and registry scan
- `installed_software.csv` / `.txt` — full app inventory from registry + Store
- `winget_packages.json` — winget export for bulk reinstall
- `WSL/*.tar` — each WSL distro archived
- `Restore-Machine.ps1` — auto-generated restore script

### Restore-Machine.ps1 (generated)
Uses `$PSScriptRoot` to find sibling data files. Runs `winget import` and `wsl --import` to restore packages and distros.

## Workflow

1. Plug external drive into old machine
2. `.\Migrate-Machine.ps1 -OutputPath "E:\MigrationExport"`
3. Move drive to new machine
4. `E:\MigrationExport\Restore-Machine.ps1`
5. Manual follow-up: set WSL default users, enter license keys, install anything winget missed

## Session 2 — 2026-05-20

### Added
- **MigrationTool-GUI.ps1** — WPF-based GUI with dark theme, Browse button, Export/Restore buttons, live log output, progress bar
- **MigrationTool.cmd** — CMD launcher that starts the GUI without a console flash
- **installer.iss** — Inno Setup 6 script that produces a proper Windows installer with Start Menu and desktop shortcuts

### GUI Details
- Self-elevates to admin on launch
- Runs export/restore in background runspaces so the UI stays responsive
- Calls the existing `Migrate-Machine.ps1` and `Restore-Machine.ps1` scripts (no logic duplication)
- Dark Catppuccin-style color scheme

### Installer
- Compiles with Inno Setup 6 (free)
- Installs to Program Files, creates Start Menu group + optional desktop icon
- Needs an `icon.ico` file in the project root (placeholder reference for now)

## Decisions

- Restore script is generated inside the export folder so everything is self-contained
- Used `$PSScriptRoot` so restore script works from wherever the folder lands
- Registry key scan looks for common key names (Serial, LicenseKey, ProductKey, CDKey, etc.)
- Filtered out framework/runtime packages from Store app list to reduce noise
- GUI calls existing scripts rather than duplicating logic — single source of truth
- CMD launcher hides the PowerShell console window for a clean app experience
