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
    [string]$OutputPath = "$env:USERPROFILE\Desktop\PCmigrate",
    [switch]$Bundle,
    [switch]$WslOnly
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
if ($WslOnly) { Write-Log "Mode: WSL Only" }

# Check winget availability early
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "WARNING: winget not found. Install it from the Microsoft Store or https://github.com/microsoft/winget-cli/releases"
    Write-Log "         Winget export will be skipped, but all other exports will proceed."
}

if (-not $WslOnly) {
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
    "${env:ProgramFiles(x86)}\Microsoft Office\Office16",
    "${env:ProgramFiles}\Microsoft Office\Office15",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office15"
)
foreach ($op in $officePaths) {
    $ospp = Join-Path $op "ospp.vbs"
    if (Test-Path $ospp) {
        $officeInfo = cscript //nologo $ospp /dstatus 2>$null
        $content += "[Microsoft Office]`n$($officeInfo | Out-String)`n"
        break
    }
}

# Try Microsoft 365 / Click-to-Run Office
$c2rPath = "${env:ProgramFiles}\Microsoft Office\root\Licenses16"
if (-not $content.Contains("[Microsoft Office]") -and (Test-Path $c2rPath)) {
    $officeC2R = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -ErrorAction SilentlyContinue
    if ($officeC2R) {
        $content += "[Microsoft Office (Click-to-Run)]`n"
        $content += "  Product: $($officeC2R.ProductReleaseIds)`n"
        $content += "  Version: $($officeC2R.VersionToReport)`n"
        $content += "  License: Likely tied to Microsoft account (check account.microsoft.com)`n`n"
    }
}

# Registry-stored keys for other software
# Strategy: check uninstall entries and known software paths for key-like values
$knownKeyNames = @("Serial", "SerialNumber", "LicenseKey", "ProductKey", "Registration", "CDKey", "Key", "LicenseCode", "ActivationCode", "RegisteredKey", "PID", "DigitalProductId")
$foundKeys = @()

# Scan uninstall registry entries (same ones used for software inventory)
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($path in $uninstallPaths) {
    Get-ItemProperty $path -ErrorAction SilentlyContinue | ForEach-Object {
        $appName = $_.DisplayName
        if (-not $appName) { return }
        foreach ($keyName in $knownKeyNames) {
            $val = $_.$keyName
            if ($val -and $val -is [string] -and $val.Trim().Length -ge 5 -and $val -match "[A-Z0-9]{3,}") {
                $foundKeys += [PSCustomObject]@{ App = $appName; KeyName = $keyName; Value = $val.Trim() }
            }
        }
    }
}

# Scan known software registry locations
$knownPaths = @(
    "HKLM:\SOFTWARE\Adobe",
    "HKLM:\SOFTWARE\WOW6432Node\Adobe",
    "HKLM:\SOFTWARE\Microsoft\Office",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office",
    "HKCU:\SOFTWARE\Adobe",
    "HKLM:\SOFTWARE\Autodesk",
    "HKLM:\SOFTWARE\WOW6432Node\Autodesk",
    "HKLM:\SOFTWARE\VMware, Inc.",
    "HKLM:\SOFTWARE\WOW6432Node\VMware, Inc."
)
foreach ($basePath in $knownPaths) {
    if (-not (Test-Path $basePath)) { continue }
    Get-ChildItem $basePath -Recurse -ErrorAction SilentlyContinue |
        Get-ItemProperty -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($keyName in $knownKeyNames) {
                $val = $_.$keyName
                if ($val -and $val -is [string] -and $val.Trim().Length -ge 5 -and $val -match "[A-Z0-9]{3,}") {
                    $pathLabel = $_.PSPath -replace 'Microsoft.PowerShell.Core\\Registry::',''
                    $foundKeys += [PSCustomObject]@{ App = $pathLabel; KeyName = $keyName; Value = $val.Trim() }
                }
            }
        }
}

# Deduplicate
$foundKeys = $foundKeys | Sort-Object App, Value -Unique

if ($foundKeys) {
    $content += "`n[Other Software Keys Found in Registry]`n"
    $foundKeys | ForEach-Object { $content += "  $($_.App): $($_.KeyName) = $($_.Value)`n" }
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

# Search for download URLs for apps missing one
Write-Log "--- Searching for download links for apps without URLs ---"
$appsNeedingURL = $installedApps | Where-Object { -not $_.DownloadURL -and $_.Source -eq "Win32" }
$searchCount = 0
foreach ($app in $appsNeedingURL) {
    try {
        $query = [System.Net.WebUtility]::UrlEncode("$($app.Name) official download")
        $response = Invoke-WebRequest -Uri "https://www.google.com/search?q=$query&num=5" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        # Extract non-google, non-ad URLs from results
        $urls = [regex]::Matches($response.Content, 'href="/url\?q=([^&"]+)') | ForEach-Object { $_.Groups[1].Value }
        $downloadUrl = $urls | Where-Object { $_ -notmatch "google\.com|youtube\.com|wikipedia\.org|googleadservices|doubleclick\.net" } | Select-Object -First 1
        if ($downloadUrl) {
            $app.DownloadURL = [System.Net.WebUtility]::UrlDecode($downloadUrl)
            $searchCount++
        }
    } catch {}
    # Rate limit to avoid being blocked
    Start-Sleep -Milliseconds 500
}
Write-Log "Found download links for $searchCount additional apps via web search"

$installedApps | Export-Csv -Path (Join-Path $OutputPath "installed_software.csv") -NoTypeInformation
$installedApps | Format-Table Name, Version, Source, DownloadURL -AutoSize |
    Out-String -Width 300 |
    Set-Content (Join-Path $OutputPath "installed_software.txt")

# Generate interactive HTML checklist
# Build key lookup by app name
$keyLookup = @{}
if ($foundKeys) {
    foreach ($k in $foundKeys) {
        $keyLookup[$k.App] = $k.Value
    }
}
# Also add Windows key
if ($biosKey) { $keyLookup["Windows"] = $biosKey }

$htmlRows = $installedApps | ForEach-Object {
    $encodedName = [System.Net.WebUtility]::HtmlEncode($_.Name)
    $searchQuery = [System.Net.WebUtility]::UrlEncode("$($_.Name) download")
    if ($_.DownloadURL) {
        $link = "<a href=`"$($_.DownloadURL)`" target=`"_blank`">Download</a>"
    } else {
        $link = "<a href=`"https://www.google.com/search?q=$searchQuery`" target=`"_blank`">Search</a>"
    }
    # Match key to app name (partial match)
    $appKey = ""
    foreach ($kName in $keyLookup.Keys) {
        if ($_.Name -and $kName -and $_.Name -like "*$kName*") { $appKey = $keyLookup[$kName]; break }
        if ($_.Name -and $kName -and $kName -like "*$($_.Name)*") { $appKey = $keyLookup[$kName]; break }
    }
    $keyCell = ""
    if ($appKey) {
        $escapedKey = [System.Net.WebUtility]::HtmlEncode($appKey)
        $keyCell = "<span class=`"key-hidden`" onclick=`"this.classList.toggle('key-visible')`">$escapedKey</span><button class=`"key-copy`" onclick=`"copyKey(this,'$escapedKey')`">Copy</button>"
    }
    "        <tr><td><input type=`"checkbox`" onchange=`"this.parentElement.parentElement.classList.toggle('done')`"></td><td>$encodedName</td><td>$([System.Net.WebUtility]::HtmlEncode($_.Version))</td><td>$($_.Source)</td><td>$link</td><td>$keyCell</td></tr>"
}
$html = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Installed Software Checklist</title>
<style>
body { font-family: -apple-system, sans-serif; max-width: 1100px; margin: 2em auto; background: #1e1e2e; color: #cdd6f4; }
h1 { color: #89b4fa; }
table { border-collapse: collapse; width: 100%; }
th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #313244; }
th { background: #313244; position: sticky; top: 0; }
tr:hover { background: #313244; }
tr.done { opacity: 0.4; text-decoration: line-through; }
a { color: #89b4fa; }
input[type=checkbox] { width: 18px; height: 18px; cursor: pointer; }
.count { color: #a6adc8; margin-bottom: 1em; }
.key-hidden { background: #313244; color: #313244; padding: 2px 6px; border-radius: 3px; cursor: pointer; font-family: monospace; font-size: 12px; user-select: none; }
.key-hidden.key-visible { color: #f9e2af; }
.key-copy { background: #45475a; color: #cdd6f4; border: none; padding: 2px 8px; border-radius: 3px; cursor: pointer; font-size: 11px; margin-left: 6px; }
.key-copy:hover { background: #585b70; }
</style></head><body>
<h1>Installed Software Checklist</h1>
<p class="count">$($installedApps.Count) applications &mdash; check off items as you reinstall them &mdash; click key fields to reveal</p>
<table><thead><tr><th></th><th>Name</th><th>Version</th><th>Source</th><th>Link</th><th>Key</th></tr></thead><tbody>
$($htmlRows -join "`n")
</tbody></table>
<script>function copyKey(btn,key){navigator.clipboard.writeText(key);btn.textContent='Done';setTimeout(function(){btn.textContent='Copy'},1000)}</script>
</body></html>
"@
Set-Content -Path (Join-Path $OutputPath "installed_software.html") -Value $html -Encoding UTF8

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
} # end if (-not $WslOnly)

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
        # Ask user before shutting down WSL (skip prompt in non-interactive hosts)
        $shutdownChoice = 0
        if ($host.UI -and $host.Name -eq 'ConsoleHost') {
            try {
                $shutdownChoice = $host.UI.PromptForChoice(
                    "WSL Shutdown Required",
                    "WSL must be shut down for a clean export. Running Linux processes will be stopped. Continue?",
                    @([System.Management.Automation.Host.ChoiceDescription]::new("&Yes","Shutdown WSL and export"),
                      [System.Management.Automation.Host.ChoiceDescription]::new("&No","Skip WSL export")),
                    0
                )
            } catch {
                $shutdownChoice = 0
            }
        }
        if ($shutdownChoice -eq 1) {
            Write-Log "WSL export skipped by user"
        } else {
            Write-Log "Shutting down WSL for clean export..."
            wsl.exe --shutdown
            Start-Sleep -Seconds 2

            # Detect Win11 for --vhd support (build 22000+)
            $osBuild = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
            $useVhd = $osBuild -ge 22000

            foreach ($distro in $distros) {
                $distro = $distro.Trim()
                if (-not $distro) { continue }
                if ($useVhd) {
                    $exportFile = Join-Path $wslDir "$distro.vhdx"
                    Write-Log "Exporting WSL distro: $distro -> $exportFile (VHDX - fast)"
                    Write-Log "  (This may take a while for large distributions...)"
                    wsl.exe --export $distro $exportFile --vhd
                } else {
                    $exportFile = Join-Path $wslDir "$distro.tar"
                    Write-Log "Exporting WSL distro: $distro -> $exportFile"
                    Write-Log "  (This may take a while for large distributions...)"
                    wsl.exe --export $distro $exportFile
                }
                if (Test-Path $exportFile) {
                    $sizeMB = [math]::Round((Get-Item $exportFile).Length / 1MB, 1)
                    Write-Log "  Exported $distro ($sizeMB MB)"
                } else {
                    Write-Log "  WARNING: Export failed for $distro"
                }
            }

            # Restart WSL
            Write-Log "Restarting WSL..."
            wsl.exe --shutdown 2>$null  # ensure clean state
            # Start the default distro briefly to restart the WSL service
            $defaultDistro = ($distros | Select-Object -First 1).Trim()
            if ($defaultDistro) {
                wsl.exe -d $defaultDistro -- echo "WSL restarted" 2>$null
            }
            Write-Log "WSL restarted"
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

Write-Host "=== Windows Migration Import ===" -ForegroundColor Cyan

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
    Get-ChildItem $wslDir -Filter "*.vhdx" | ForEach-Object {
        $name = $_.BaseName
        $installDir = "$env:LOCALAPPDATA\WSL\$name"
        Write-Host "  Importing $name (VHDX)..."
        wsl.exe --import $name $installDir $_.FullName --vhd
        Write-Host "  Done: $name (set default user with: $name config --default-user USERNAME)"
    }
} else {
    Write-Host "`n[2/2] No WSL exports found, skipping" -ForegroundColor DarkYellow
}

Write-Host "`n=== Import Complete ===" -ForegroundColor Green
Write-Host "Review installed_software.csv for apps that need manual installation."
Write-Host "Review license_keys.txt for product keys to re-enter."
'@

if ($WslOnly) {
    # Simpler restore script for WSL-only mode
    $restoreScript = @'
#Requires -RunAsAdministrator
param([string]$ImportPath = $PSScriptRoot)
Write-Host "=== WSL Restore ===" -ForegroundColor Cyan
$wslDir = Join-Path $ImportPath "WSL"
if (Test-Path $wslDir) {
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
    Get-ChildItem $wslDir -Filter "*.vhdx" | ForEach-Object {
        $name = $_.BaseName
        $installDir = "$env:LOCALAPPDATA\WSL\$name"
        Write-Host "  Importing $name (VHDX)..."
        wsl.exe --import $name $installDir $_.FullName --vhd
        Write-Host "  Done: $name (set default user with: $name config --default-user USERNAME)"
    }
} else {
    Write-Host "No WSL exports found in $wslDir" -ForegroundColor DarkYellow
}
Write-Host "`n=== WSL Restore Complete ===" -ForegroundColor Green
'@
}

Set-Content -Path (Join-Path $OutputPath "Restore-Machine.ps1") -Value $restoreScript
Write-Log "Restore script created: Restore-Machine.ps1"

# ─────────────────────────────────────────────
# 6. RESTORE BUNDLE (optional zip)
# ─────────────────────────────────────────────
if ($Bundle) {
    Write-Log "--- Creating restore bundle ---"
    $parentDir = Split-Path $OutputPath -Parent
    $folderName = Split-Path $OutputPath -Leaf
    $zipPath = Join-Path $parentDir "${folderName}_RestoreBundle.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    $items = Get-ChildItem -LiteralPath $OutputPath
    Compress-Archive -LiteralPath $items.FullName -DestinationPath $zipPath -CompressionLevel Optimal
    if (Test-Path $zipPath) {
        $sizeBytes = (Get-Item $zipPath).Length
        if ($sizeBytes -ge 1MB) { $sizeStr = "$([math]::Round($sizeBytes / 1MB, 1)) MB" } else { $sizeStr = "$([math]::Round($sizeBytes / 1KB, 0)) KB" }
        Write-Log "Restore bundle created: $zipPath ($sizeStr)"
    } else {
        Write-Log "WARNING: Failed to create restore bundle"
    }
}

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
