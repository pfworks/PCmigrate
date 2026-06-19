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
2. `.\Migrate-Machine.ps1 -OutputPath "E:\PCmigrate"`
3. Move drive to new machine
4. `E:\PCmigrate\Restore-Machine.ps1`
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

## Session 7 — 2026-05-31 (continued)

### Added
- **WSL-only mode** — CLI: `-WslOnly` flag; GUI: "WSL Only" in export dropdown. Skips license keys, software inventory, and winget — only exports WSL distros + .wslconfig
- **VBS silent launcher** (`PCmigrate.vbs`) — Launches the GUI via `wscript.exe` with no console window flash. Installer shortcuts use `wscript.exe` to invoke it.
- **80s box cover** (`docs/box-cover.svg`) — Retro synthwave-style software box art, displayed in README
- **FreeDOS floppy image** (`docs/PCmigrate.img`) — Novelty 1.2MB FAT12 5¼" floppy with ASCII banner

### Fixed
- **License key detection** — Replaced unreliable full-registry background job with targeted scans of uninstall entries and known software paths (Adobe, Office, Autodesk, VMware). Much faster, no timeout issues.
- **HTML keys display** — Removed separate keys section; keys now appear as a per-app column (hidden by default, click to reveal, copy button per key)
- **Installer VBS launch** — Shortcuts and post-install now use `wscript.exe "path\PCmigrate.vbs"` instead of executing .vbs directly

### Renamed
- All files from `MigrationTool*` to `PCmigrate*`
- Installer output: `PCmigrate_Setup.exe`
- Portable zip: `PCmigrate_Portable.zip`

### Added (continued)
- **Retro DOS GUI** (`PCmigrate-Retro.ps1`) — Alternative GUI with green-on-black CRT aesthetic, ASCII art banner, monospace font, `C:\>` prompt-style path input, and DOS-style button labels (`[F1] EXPORT`, `[F2] RESTORE`, `[ESC] ABORT`). Same full functionality as the main GUI.

## Session 8 — 2026-05-31 (evening)

### Removed
- **Retro DOS GUI** (`PCmigrate-Retro.ps1`) — Removed due to style-switching issues
- **Style switching** — Removed View menu and `.pcmigrate-style` preference file

### Fixed
- **Installer launch** — Shortcuts now use `powershell.exe -WindowStyle Hidden -File` directly with `WorkingDir` set. No more VBS intermediary for shortcuts.
- **Console window** — Self-elevation in GUI now passes `-WindowStyle Hidden` to hide the blue PowerShell console. WPF window shows independently.
- **PS 5.1 compatibility** — Fixed `$var = if(){}` expressions (PS7-only) and JS arrow functions in HTML strings

### Current Launch Flow
1. Shortcut/CMD/VBS calls `powershell.exe -WindowStyle Hidden -File PCmigrate-GUI.ps1`
2. Script detects non-admin → re-launches with `-Verb RunAs -WindowStyle Hidden`
3. UAC prompt appears → user approves
4. Elevated PowerShell (hidden console) loads WPF GUI → window appears

## Session 9 — 2026-05-31 (late)

### WSL Export Improvements
- **Shutdown before export** — Prompts user with Yes/No choice before stopping WSL
- **Restart after export** — Runs a brief command in the default distro to bring WSL back up
- **VHDX export on Win11** — Detects build 22000+ and uses `wsl --export --vhd` for faster disk-level export instead of tar
- **Restore handles both formats** — Imports `.tar` normally, `.vhdx` with `--vhd` flag
- Both full and WSL-only restore scripts updated

## Session 10 — 2026-05-31 (late night)

### Fixed
- **WSL `--vhd` export failing on WSL 1 distros** — The `--vhd` flag only works with WSL 2 distros. Previously the code assumed all distros on Win11 were WSL 2. Now parses `wsl -l -v` output to check each distro's version and only uses VHDX export for WSL 2 distros; WSL 1 distros fall back to `.tar`.

### Released
- Tagged and pushed `v0.3.4`

## Session 11 — 2026-06-01

### Improved
- **Post-restore reminder** — Both the full and WSL-only restore scripts now print a clear reminder after completion showing the exact `<distro> config --default-user` commands needed for each restored distro (instead of generic inline hints during import)
- **README** — Rewritten intro to emphasize dual-use as a standalone WSL backup/restore tool. Updated feature list to highlight WSL backup with `.tar`/`.vhdx` format details. Updated output structure to show both formats. Post-restore section now mentions the script prints reminders.
- **User Manual (LaTeX)** — Introduction rewritten to emphasize WSL backup use case. Added dedicated "Using as a WSL Backup & Restore Tool" section with use cases (pre-risky-changes, scheduled backups, machine migration, disaster recovery) and workflow examples. Updated output structure and file descriptions for VHDX. Updated post-restore section to reference printed reminders.

### Decisions
- Restore scripts track which distros were actually imported and print distro-specific commands (not generic placeholders)
- WSL backup/restore is now positioned as a first-class use case, not just a sub-feature of migration

### Added (continued)
- **App data backup** — During full export, scans `%APPDATA%` and `%LOCALAPPDATA%` for folders matching installed app names. Zips each matching folder (up to 500 MB) into `AppData/Roaming_<name>.zip` or `AppData/Local_<name>.zip`. Skips known non-useful folders (Microsoft, Windows, caches, temp, GPU drivers). Restore script extracts them back to the correct location (skips if folder already exists).

### Decisions (continued)
- App data backup only runs in full export mode (not WSL-only)
- 500 MB per-folder cap prevents accidentally zipping browser caches or large game data
- Restore skips existing folders to avoid overwriting fresh app installs with stale data

## Session 12 — 2026-06-02

### Fixed
- **WSL restore "system cannot find the path"** — `wsl --import` requires the target install directory to exist. Added `New-Item -Path $installDir -ItemType Directory -Force` before each `wsl.exe --import` call in both the full and WSL-only restore scripts.

## Session 13 — 2026-06-02

### Fixed
- **Restore bundle "Cannot bind argument to parameter 'path'"** — When the output path had a trailing backslash (common from the GUI folder browser dialog), `Split-Path -Parent` returned an empty string, causing `Join-Path` to fail. Fixed by resolving the path and trimming trailing backslashes before splitting. Added fallback for drive root paths and guard against empty file lists.

### Released
- Deleted erroneous `v0.3.5` tag, tagged and pushed `v0.4.2`

## Session 14 — 2026-06-03

### Fixed
- **Portable zip GUI not launching** — Files extracted from a zip have a Zone.Identifier ADS that blocks PowerShell execution even with `-ExecutionPolicy Bypass`. CMD launcher now runs `Unblock-File` on all `.ps1` files before launching the GUI.
- **Console window visible behind GUI** — Added Win32 `ShowWindow`/`GetConsoleWindow` call to hide the console after elevation. Both CMD launcher and self-elevation now pass `-WindowStyle Hidden`.

### Added
- **Custom window icon** — GUI now displays `PCmigrate.ico` in the title bar and taskbar instead of the default PowerShell icon. Uses `BitmapFrame::Create` to load the .ico at runtime.
- **80s tri-fold brochure** (`docs/brochure.svg`) — Synthwave-style tri-fold matching the box cover: cover panel, features panel, and how-it-works/specs panel.

### Released
- `v0.4.3` (debug portable launch)
- `v0.4.4` (show console for error diagnosis)
- `v0.4.5` (custom icon + hidden console — final fix)

## Session 15 — 2026-06-13

### Fixed
- **Log output not copyable** — GUI log panel used a `TextBlock` (no text selection). Replaced with a read-only `TextBox` with built-in scrollbar so users can select, copy, and paste log output.
- **Restore bundle "Stream was too long" error** — `Compress-Archive` in PowerShell 5.1 buffers into a `MemoryStream` (2 GB max). Replaced with `System.IO.Compression.ZipFile` API which writes directly to disk, removing the size limit. Fixed in both GUI and CLI (`-Bundle`) code paths.

### Released
- `v0.4.7`

## Session 16 — 2026-06-14

### Added
- **`-OptimizeWsl` switch** — New CLI flag and GUI menu option ("Optimize WSL + Export") that speeds up WSL export by:
  1. Converting WSL 1 distros to WSL 2 (enables fast VHDX export instead of slow tar)
  2. Compacting WSL 2 VHDX disk images before export (reclaims unused space)
- **`-ConvertWsl` switch** — Standalone mode that converts all WSL 1 distros to WSL 2 without performing an export. GUI: "Convert WSL 1 → 2 (no export)" in dropdown.
- **`-CompactWsl` switch** — Standalone mode that compacts all WSL 2 VHDX disk images without performing an export. Reports before/after sizes. GUI: "Compact WSL Disks (no export)" in dropdown.
- **Interactive WSL 1→2 prompt** — In CLI mode without `-OptimizeWsl`, if WSL 1 distros are detected, the script prompts the user to convert (defaults to No)
- **VHDX compaction** — Uses `Optimize-VHD` (Hyper-V) with diskpart fallback for systems without the Hyper-V module
- **GUI dropdown separator** — Visual separator between export modes and maintenance modes

### Updated
- **README.md** — Added `-OptimizeWsl`, `-ConvertWsl`, `-CompactWsl` CLI examples, updated GUI options list
- **UserManual.tex** — Added "Optimizing WSL Before Export" subsection, updated CLI examples and GUI options list

## Session 17 — 2026-06-15

### Fixed
- **`-ConvertWsl` and `-CompactWsl` silently doing nothing** — `wsl.exe -l -v` outputs UTF-16LE text with null characters between every real character. The script already stripped nulls for `wsl --list --quiet` but did **not** strip them from the `-l -v` output used to build `$wslVersionMap`. The regex never matched, so the version map was always empty — conversion found no WSL 1 distros and compaction found no WSL 2 distros. Fixed by adding `$line -replace "\`0",""` before the regex match in both the standalone maintenance mode and the export section.

## Session 18 — 2026-06-16

### Added
- **`.github/workflows/test-wsl.yml`** — GitHub Actions workflow implementing the Session 17 future work items:
  - **`test-convert-wsl` job** — Enables WSL + Virtual Machine Platform, installs WSL 2 kernel update, imports Alpine minirootfs as WSL 1, runs `-ConvertWsl`, verifies distro is now WSL 2 via `wsl -l -v`
  - **`test-compact-wsl` job** — Enables WSL + Virtual Machine Platform, installs WSL 2 kernel update, imports Alpine minirootfs as WSL 2, writes and deletes 50 MB of data (to create reclaimable blocks), runs `-CompactWsl`, verifies VHDX still exists and reports size
  - Both jobs use Alpine minirootfs (~3 MB) for fast CI
  - Triggers on push/PR to `master`, version tags (`v*`), and `workflow_dispatch`
  - Script output (`Tee-Object`) uploaded as workflow artifacts for visibility in GitHub Actions UI

### Released
- `v0.5.0`
