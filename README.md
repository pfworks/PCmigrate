# Windows 11 Migration Tool

A Windows application (with GUI) to export and restore your environment when moving to a new Windows 11 machine.

## What It Does

- **Exports WSL distributions** as `.tar` archives (plus `.wslconfig`)
- **Inventories all installed software** (Win32 + Store apps) with versions and download URLs
- **Retrieves license keys** — Windows product key, Office activation, registry-stored serials
- **Exports winget packages** for automated bulk reinstall on the new machine
- **Generates a restore script** that runs on the destination machine

## Requirements

- Windows 11 (source and destination)
- PowerShell 5.1+
- **Run as Administrator**
- External drive or network share with enough space for WSL exports

## Installation

### Option A: Installer
1. Download and install [Inno Setup 6](https://jrsoftware.org/isinfo.php)
2. Compile `installer.iss` to produce `MigrationTool_Setup.exe`
3. Run the installer — it creates a Start Menu shortcut and optional desktop icon

### Option B: Portable (no install)
Double-click `MigrationTool.cmd` or run `MigrationTool-GUI.ps1` directly.

## Usage

### GUI Mode
Launch the app from the Start Menu, desktop shortcut, or `MigrationTool.cmd`. Use the Browse button to select your external drive, then click **Export** or **Restore**.

### Command Line

#### On the old machine

```powershell
# Export to an external drive
.\Migrate-Machine.ps1 -OutputPath "E:\MigrationExport"

# Or default to Desktop\MigrationExport
.\Migrate-Machine.ps1
```

#### On the new machine

Move the drive over, then:

```powershell
E:\MigrationExport\Restore-Machine.ps1
```

Or specify the path manually:

```powershell
.\Restore-Machine.ps1 -ImportPath "E:\MigrationExport"
```

## Output Structure

```
MigrationExport/
├── license_keys.txt          # Windows/Office/software keys
├── installed_software.csv    # Full inventory (machine-readable)
├── installed_software.txt    # Full inventory (human-readable)
├── winget_packages.json      # For 'winget import'
├── WSL/
│   ├── Ubuntu.tar            # (example) WSL distro archive
│   └── .wslconfig            # WSL global config
├── Restore-Machine.ps1       # Run this on the new machine
└── migration_log_*.txt       # Export log
```

## Post-Restore Steps

1. Set your default WSL user: `<distro> config --default-user <username>`
2. Manually install apps not available via winget (check the CSV)
3. Re-enter license keys from `license_keys.txt`
4. Restore any app-specific settings/configs not covered by this tool

## Limitations

- License keys are only retrievable if stored in BIOS/UEFI or the registry. Digital licenses tied to a Microsoft account transfer automatically.
- Some winget packages may fail to import if the source or package ID has changed.
- WSL exports include the full filesystem — large distros will produce large tar files.
