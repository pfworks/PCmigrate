<#
.SYNOPSIS
    Windows Migration Script - Exports installed software, license keys, 
    WSL instances, and download sources for setting up a new machine.
.DESCRIPTION
    Run as Administrator on the SOURCE machine (Windows 10 1709+ or Windows 11).
    Creates a migration folder with:
    - WSL distribution tar archives
    - Installed software list with versions and download URLs
    - Windows/Office license keys (where retrievable)
    - Winget export for automated reinstall on new machine
.NOTES
    Requires: Administrator privileges, PowerShell 5.1+
    Windows 10: winget must be installed (get it from the Microsoft Store or GitHub)
#>

#Requires -RunAsAdministrator

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\MigrationExport"
)

$ErrorActionPreference = "Continue"
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$logFile = Join-Path $OutputPath "migration_log_$timestamp.txt"

function Write-Log {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "=== Windows Migration Export Started ==="
Write-Log "Output: $OutputPath"

# Check winget availability early
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "WARNING: winget not found. Install it from the Microsoft Store or https://github.com/microsoft/winget-cli/releases"
    Write-Log "         Winget export will be skipped, but all other exports will proceed."
}

# ─────────────────────────────────────────────
# 1. LICENSE KEYS
# ─────────────────────────────────────────────
Write-Log "--- Retrieving license keys ---"
$licenseFile = Join-Path $OutputPath "license_keys.txt"

# Windows product key (from BIOS/UEFI or software licensing)
$biosKey = (Get-WmiObject -Query "SELECT OA3xOriginalProductKey FROM SoftwareLicensingService" -ErrorAction SilentlyContinue).OA3xOriginalProductKey
if (-not $biosKey) {
    $biosKey = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue).OA3xOriginalProductKey
}

$content = @"
=== LICENSE KEYS ($(Get-Date)) ===

[Windows Product Key]
Key: $(if ($biosKey) { $biosKey } else { 'Not found (likely digital license tied to Microsoft account)' })

"@

# Office key (partial - last 5 chars via ospp.vbs)
$officePaths = @(
    "${env:ProgramFiles}\Microsoft Office\Office16",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office16"
)
foreach ($op in $officePaths) {
    $ospp = Join-Path $op "ospp.vbs"
    if (Test-Path $ospp) {
        $officeInfo = cscript //nologo $ospp /dstatus 2>$null
        $content += "[Microsoft Office]`n$($officeInfo | Out-String)`n"
        break
    }
}

# Registry-stored keys for other software
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DigitalProductId",
    "HKLM:\SOFTWARE\WOW6432Node\*"
)
$knownKeyNames = @("Serial", "SerialNumber", "LicenseKey", "ProductKey", "Registration", "CDKey")
$foundKeys = @()
$regJob = Start-Job -ScriptBlock {
    param($knownKeyNames)
    $results = @()
    foreach ($keyName in $knownKeyNames) {
        $found = Get-ChildItem "HKLM:\SOFTWARE","HKLM:\SOFTWARE\WOW6432Node" -Recurse -ErrorAction SilentlyContinue |
            Get-ItemProperty -ErrorAction SilentlyContinue |
            Where-Object { $_.$keyName -and $_.$keyName -match "^[A-Z0-9-]{5,}" } |
            Select-Object @{N='Path';E={$_.PSPath}}, @{N='KeyName';E={$keyName}}, @{N='Value';E={$_.$keyName}}
        $results += $found
    }
    $results
} -ArgumentList (,$knownKeyNames)
$regJob | Wait-Job -Timeout 120 | Out-Null
if ($regJob.State -eq 'Completed') {
    $foundKeys = Receive-Job $regJob
} else {
    Stop-Job $regJob
    Write-Log "WARNING: Registry key scan timed out after 120 seconds"
}
Remove-Job $regJob -Force
if ($foundKeys) {
    $content += "[Other Software Keys Found in Registry]`n"
    $foundKeys | ForEach-Object { $content += "  $($_.Path -replace 'Microsoft.PowerShell.Core\\Registry::',''): $($_.KeyName) = $($_.Value)`n" }
}

Set-Content -Path $licenseFile -Value $content
Write-Log "License keys saved to license_keys.txt"

# ─────────────────────────────────────────────
# 2. INSTALLED SOFTWARE INVENTORY
# ─────────────────────────────────────────────
Write-Log "--- Building installed software inventory ---"

$installedApps = @()

# Registry uninstall entries (traditional Win32 apps)
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($path in $uninstallPaths) {
    Get-ItemProperty $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "^(Update|KB\d)" } |
        ForEach-Object {
            $installedApps += [PSCustomObject]@{
                Name        = $_.DisplayName
                Version     = $_.DisplayVersion
                Publisher   = $_.Publisher
                InstallDate = $_.InstallDate
                Source      = "Win32"
                DownloadURL = $(if ($_.URLInfoAbout) { $_.URLInfoAbout } elseif ($_.URLUpdateInfo) { $_.URLUpdateInfo } elseif ($_.HelpLink) { $_.HelpLink } else { "" })
            }
        }
}

# Microsoft Store / MSIX apps
Get-AppxPackage -ErrorAction SilentlyContinue |
    Where-Object { $_.IsFramework -eq $false -and $_.Name -notmatch "^(Microsoft\.NET|Microsoft\.VCLibs|Microsoft\.UI)" } |
    ForEach-Object {
        $installedApps += [PSCustomObject]@{
            Name        = $_.Name
            Version     = $_.Version
            Publisher   = $_.Publisher
            InstallDate = ""
            Source      = "MicrosoftStore"
            DownloadURL = "ms-windows-store://pdp/?PFN=$($_.PackageFamilyName)"
        }
    }

# Sort and export
$installedApps = $installedApps | Sort-Object Name -Unique
$installedApps | Export-Csv -Path (Join-Path $OutputPath "installed_software.csv") -NoTypeInformation
$installedApps | Format-Table Name, Version, Source, DownloadURL -AutoSize |
    Out-String -Width 300 |
    Set-Content (Join-Path $OutputPath "installed_software.txt")

Write-Log "Found $($installedApps.Count) installed applications"

# ─────────────────────────────────────────────
# 3. WINGET EXPORT (for automated reinstall)
# ─────────────────────────────────────────────
Write-Log "--- Exporting winget package list ---"
$wingetExport = Join-Path $OutputPath "winget_packages.json"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget export -o $wingetExport --accept-source-agreements 2>$null
    if (Test-Path $wingetExport) {
        Write-Log "Winget export saved (use 'winget import -i winget_packages.json' on new machine)"
    } else {
        # Fallback: list all winget packages
        winget list | Out-File (Join-Path $OutputPath "winget_list.txt")
        Write-Log "Winget export failed, saved 'winget list' output instead"
    }
} else {
    Write-Log "WARNING: winget not found, skipping"
}

# ─────────────────────────────────────────────
# 4. WSL EXPORT
# ─────────────────────────────────────────────
Write-Log "--- Exporting WSL distributions ---"
$wslDir = Join-Path $OutputPath "WSL"
New-Item -Path $wslDir -ItemType Directory -Force | Out-Null

if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $distros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -and $_ -notmatch "^\s*$" } |
        ForEach-Object { $_ -replace "`0","" }  # Remove null chars from wsl output

    if ($distros) {
        foreach ($distro in $distros) {
            $distro = $distro.Trim()
            if (-not $distro) { continue }
            $tarFile = Join-Path $wslDir "$distro.tar"
            Write-Log "Exporting WSL distro: $distro -> $tarFile"
            Write-Log "  (This may take a while for large distributions...)"
            wsl.exe --export $distro $tarFile
            if (Test-Path $tarFile) {
                $sizeMB = [math]::Round((Get-Item $tarFile).Length / 1MB, 1)
                Write-Log "  Exported $distro ($sizeMB MB)"
            } else {
                Write-Log "  WARNING: Export failed for $distro"
            }
        }
    } else {
        Write-Log "No WSL distributions found"
    }

    # Save WSL config if present
    $wslConfig = "$env:USERPROFILE\.wslconfig"
    if (Test-Path $wslConfig) {
        Copy-Item $wslConfig -Destination $wslDir
        Write-Log "Copied .wslconfig"
    }
} else {
    Write-Log "WARNING: WSL not installed, skipping"
}

# ─────────────────────────────────────────────
# 5. GENERATE RESTORE SCRIPT
# ─────────────────────────────────────────────
Write-Log "--- Generating restore script for new machine ---"
$restoreScript = @'
<#
.SYNOPSIS
    Run on the NEW machine to restore from migration export.
    Requires Administrator privileges.
#>
#Requires -RunAsAdministrator

param(
    [string]$ImportPath = $PSScriptRoot
)

Write-Host "=== Windows 11 Migration Import ===" -ForegroundColor Cyan

# Install winget packages
$wingetFile = Join-Path $ImportPath "winget_packages.json"
if (Test-Path $wingetFile) {
    Write-Host "`n[1/2] Importing winget packages..." -ForegroundColor Yellow
    winget import -i $wingetFile --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "`n[1/2] No winget export found, skipping" -ForegroundColor DarkYellow
}

# Import WSL distributions
$wslDir = Join-Path $ImportPath "WSL"
if (Test-Path $wslDir) {
    Write-Host "`n[2/2] Importing WSL distributions..." -ForegroundColor Yellow
    $wslConfig = Join-Path $wslDir ".wslconfig"
    if (Test-Path $wslConfig) {
        Copy-Item $wslConfig -Destination "$env:USERPROFILE\.wslconfig" -Force
        Write-Host "  Restored .wslconfig"
    }
    Get-ChildItem $wslDir -Filter "*.tar" | ForEach-Object {
        $name = $_.BaseName
        $installDir = "$env:LOCALAPPDATA\WSL\$name"
        Write-Host "  Importing $name..."
        wsl.exe --import $name $installDir $_.FullName
        Write-Host "  Done: $name (set default user with: $name config --default-user USERNAME)"
    }
} else {
    Write-Host "`n[2/2] No WSL exports found, skipping" -ForegroundColor DarkYellow
}

Write-Host "`n=== Import Complete ===" -ForegroundColor Green
Write-Host "Review installed_software.csv for apps that need manual installation."
Write-Host "Review license_keys.txt for product keys to re-enter."
'@

Set-Content -Path (Join-Path $OutputPath "Restore-Machine.ps1") -Value $restoreScript
Write-Log "Restore script created: Restore-Machine.ps1"

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
Write-Log ""
Write-Log "=== Migration Export Complete ==="
Write-Log "Output folder: $OutputPath"
Write-Log ""
Write-Log "Contents:"
Write-Log "  license_keys.txt        - Windows/Office/software license keys"
Write-Log "  installed_software.csv  - Full software inventory with download URLs"
Write-Log "  installed_software.txt  - Human-readable software list"
Write-Log "  winget_packages.json    - Winget package list (for automated reinstall)"
Write-Log "  WSL\                    - WSL distribution archives (.tar)"
Write-Log "  Restore-Machine.ps1    - Run this on the new machine to import"
Write-Log ""
Write-Log "NEXT STEPS:"
Write-Log "  1. Copy this entire folder to the new machine"
Write-Log "  2. Run Restore-Machine.ps1 as Administrator on the new machine"
Write-Log "  3. Manually install apps not available via winget (check the CSV)"
Write-Log "  4. Re-enter license keys from license_keys.txt"
