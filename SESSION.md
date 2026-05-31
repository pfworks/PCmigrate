# Session Notes — 2026-05-11

## Goal

Create a PowerShell-based migration tool for moving from one Windows 10/11 machine to another.

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
- **PCmigrate-GUI.ps1** — WPF-based GUI with dark theme, Browse button, Export/Restore buttons, live log output, progress bar
- **PCmigrate.cmd** — CMD launcher that starts the GUI without a console flash
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

## Session 3 — 2026-05-27

### Added
- **`.github/workflows/build-installer.yml`** — GitHub Actions workflow that builds the Inno Setup installer on every push/PR to `main`. Uploads `PCmigrate_Setup.exe` as a workflow artifact.
- **`.github/workflows/release.yml`** — GitHub Actions workflow triggered by version tags (`v*`). Builds the installer, packages a portable zip, and publishes both as GitHub Release assets.

### Release Workflow
- Push a tag like `v1.0.0` to trigger a release
- Produces two assets:
  - `PCmigrate_Setup.exe` — full installer
  - `PCmigrate_Portable.zip` — scripts only, no install needed
- Uses `softprops/action-gh-release@v2` for release creation

### README Updated
- Added "Download from GitHub Releases" as the primary installation option
- Documented installer and portable zip availability from releases page
- Updated requirements to support Windows 10 (1709+) as source machine
- Added winget install instructions for Windows 10 users

### Script Updated
- `Migrate-Machine.ps1` now warns early if winget is not found, with install links
- Updated synopsis to reflect Win10 support

## Session 4 — 2026-05-29

### Fixed
- **`PCmigrate.cmd`** — Rewrote launcher to self-elevate via UAC prompt and show errors instead of silently failing. Removed `-WindowStyle Hidden` so users can see what's happening.
- **PowerShell 5.1 compatibility** — Replaced all `??` (null-coalescing) operators in `Migrate-Machine.ps1` with `if/elseif/else` blocks. Script now works on stock Windows 10 without PowerShell 7.
- **Registry scan timeout** — Wrapped the recursive registry key search in a background job with a 120-second timeout to prevent hangs on machines with large registries (or CI runners).
- **CI workflow branch trigger** — Fixed workflows to trigger on `master` (actual default branch) instead of `main`.

### Updated
- **README.md** — Title changed to "Windows Migration Tool" (not Win11-only). Added SmartScreen bypass note for unsigned installer.
- **CI test job** — Runs under PowerShell 5.1 (`powershell` shell) to catch compatibility issues early.

### Decisions
- CMD launcher handles UAC elevation itself (no more reliance on GUI self-elevation alone)
- PowerShell 5.1 is the minimum supported version (matches README requirements)
- Registry scan is non-blocking — if it times out, export continues without those keys

## Session 5 — 2026-05-30

### GUI Improvements
- **Prominent path label** — Yellow "📁 Backup / Restore Location:" header with helper text explaining what the field is for
- **Cancel button** — Appears during operations, kills the running task immediately via `$ps.Stop()`
- **Export split button** — Main button does "Export Only"; dropdown arrow (▼) opens a menu with "Export Only" and "Export + Create Restore Bundle"
- **Restore Bundle** — Zips the entire export folder into a single self-contained `.zip` that can be transferred and restored without the tool installed
- Removed pause/resume (not reliably implementable in PS 5.1 runspaces)
- Refactored background task logic into shared `Start-BackgroundTask` helper

### License Key Detection Improvements
- Added `HKCU:\SOFTWARE` to registry search (catches per-user license keys)
- Added more key names: `Key`, `DigitalProductId`, `LicenseCode`, `ActivationCode`
- Relaxed regex filter to catch mixed-case and non-standard key formats
- Added Microsoft 365 / Click-to-Run Office detection
- Added Office 2013 (`Office15`) path support

### CLI Addition
- `Migrate-Machine.ps1 -Bundle` flag creates a restore zip automatically after export

### Rebranding
- All files updated from "Windows 11 Migration Tool" to "Windows Migration Tool"
- GUI window title, installer app name, script headers, and User Manual all updated

## Session 6 — 2026-05-31

### Added
- **Web search for download URLs** — During software discovery, searches Google for download links for apps that don't have a URL in the registry. Filters out sponsored/ad results (googleadservices, doubleclick). Rate-limited to avoid blocking.
- **Interactive HTML checklist** (`installed_software.html`) — Dark-themed page with:
  - Checkboxes to mark apps as reinstalled (row grays out)
  - "Download" links for apps with known URLs
  - "Search" fallback link for apps without URLs
  - License keys section (hidden by default, "Show Keys" toggle, "Copy" button)
- **CLI `-Bundle` flag** creates a self-contained restore zip after export

### Fixed
- **Restore bundle 0 MB** — Wildcard glob `"$path\*"` didn't expand in runspaces; switched to `Get-ChildItem -LiteralPath` + explicit paths
- **Size reporting** — Shows KB for files under 1 MB instead of rounding to "0 MB"
- **Cancel button** — Used shared hashtable for state (reference type visible across closures); `BeginStop()` for non-blocking cancel; dispose on threadpool to avoid UI deadlock; kills child processes (wsl, winget, cscript)
