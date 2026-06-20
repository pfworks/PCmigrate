<#
.SYNOPSIS
    Windows Migration Tool - GUI Application
.DESCRIPTION
    WPF GUI wrapper for Migrate-Machine.ps1 and Restore-Machine.ps1.
    Provides a visual interface for export and import operations.
.NOTES
    Requires: Administrator privileges, PowerShell 5.1+, .NET Framework 4.5+
    Supports: Windows 10 (1709+) and Windows 11
#>

# Self-elevate to admin if not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Hide the console window
Add-Type -Name Win32 -Namespace Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();'
[Native.Win32]::ShowWindow([Native.Win32]::GetConsoleWindow(), 0) | Out-Null

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Migration Tool" Height="560" Width="680"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#1e1e2e">
    <Window.Resources>
        <Style TargetType="Menu">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
        </Style>
        <Style TargetType="MenuItem">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#89b4fa"/>
            <Setter Property="Foreground" Value="#1e1e2e"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#b4d0fb"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#45475a"/>
                                <Setter Property="Foreground" Value="#6c7086"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="BorderBrush" Value="#45475a"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
    </Window.Resources>
    <DockPanel>
        <!-- Menu Bar -->
        <Menu DockPanel.Dock="Top" Background="#313244" Foreground="#cdd6f4">
            <MenuItem Header="_File">
                <MenuItem x:Name="MenuExit" Header="E_xit"/>
            </MenuItem>
            <MenuItem Header="_Help">
                <MenuItem x:Name="MenuHelp" Header="_User Manual"/>
                <Separator/>
                <MenuItem x:Name="MenuAbout" Header="_About PCmigrate"/>
            </MenuItem>
        </Menu>
    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,20">
            <TextBlock Text="Windows Migration Tool" FontSize="24" FontWeight="Bold" Foreground="#cdd6f4"/>
            <TextBlock Text="Export your environment or restore on a new machine" FontSize="13" Foreground="#a6adc8" Margin="0,4,0,0"/>
        </StackPanel>

        <!-- Path Selection -->
        <StackPanel Grid.Row="1" Margin="0,0,0,16">
            <TextBlock Text="&#x1F4C1;  Backup / Restore Location:" FontSize="14" FontWeight="SemiBold" Foreground="#f9e2af" Margin="0,0,0,6"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="PathBox" Grid.Column="0" VerticalContentAlignment="Center" FontSize="14"/>
                <Button x:Name="BrowseBtn" Grid.Column="1" Content="Browse..." Margin="8,0,0,0" Padding="12,8" FontSize="12"/>
            </Grid>
            <TextBlock Text="Select the external drive or folder where your migration data will be saved (export) or read from (restore)." FontSize="11" Foreground="#6c7086" Margin="0,4,0,0" TextWrapping="Wrap"/>
        </StackPanel>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,16">
            <!-- Export split button -->
            <Border CornerRadius="6" Margin="0,0,10,0">
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="ExportBtn" Content="&#xE898;  Export" Padding="20,12"/>
                    <Button x:Name="ExportDropBtn" Content="&#x25BC;" Padding="6,12" FontSize="10" Margin="1,0,0,0"/>
                </StackPanel>
            </Border>
            <Button x:Name="ImportBtn" Content="&#xE896;  Restore" Padding="20,12" Margin="0,0,10,0"/>
            <Button x:Name="CancelBtn" Content="&#x2716;  Cancel" Padding="14,12" Background="#f38ba8" Visibility="Collapsed"/>
        </StackPanel>

        <!-- Log Output -->
        <Border Grid.Row="3" Background="#181825" CornerRadius="6" Padding="4" Margin="0,0,0,12">
            <TextBox x:Name="LogBlock" FontFamily="Cascadia Mono,Consolas,Courier New" FontSize="12"
                     Foreground="#a6adc8" Background="#181825" BorderThickness="0" Padding="8"
                     IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                     AcceptsReturn="True"/>
        </Border>

        <!-- Status Bar -->
        <Grid Grid.Row="4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ProgressBar x:Name="ProgressBar" Grid.Column="0" Height="6" Background="#313244" Foreground="#a6e3a1" BorderThickness="0" Margin="0,0,12,0"/>
            <TextBlock x:Name="StatusText" Grid.Column="1" Text="Ready" Foreground="#a6adc8" FontSize="12" VerticalAlignment="Center"/>
        </Grid>
    </Grid>
    </DockPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Set window icon
$iconPath = Join-Path $PSScriptRoot "PCmigrate.ico"
if (Test-Path $iconPath) { $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new($iconPath)) }

# Get controls
$pathBox = $window.FindName("PathBox")
$browseBtn = $window.FindName("BrowseBtn")
$exportBtn = $window.FindName("ExportBtn")
$exportDropBtn = $window.FindName("ExportDropBtn")
$importBtn = $window.FindName("ImportBtn")
$cancelBtn = $window.FindName("CancelBtn")
$logBlock = $window.FindName("LogBlock")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Menu items
$menuExit = $window.FindName("MenuExit")
$menuHelp = $window.FindName("MenuHelp")
$menuAbout = $window.FindName("MenuAbout")

# Menu handlers
$menuExit.Add_Click({ $window.Close() })

$menuHelp.Add_Click({
    $manualPath = Join-Path $PSScriptRoot "docs\UserManual.pdf"
    if (Test-Path $manualPath) {
        Start-Process $manualPath
    } else {
        Start-Process "https://github.com/pfworks/PCmigrate#readme"
    }
})

$menuAbout.Add_Click({
    [System.Windows.MessageBox]::Show(
        "PCmigrate v0.5.2`nTotal System Transfer Utility`n`n(C) 2026 pfworks`nMIT License`n`nhttps://github.com/pfworks/PCmigrate",
        "About PCmigrate",
        "OK",
        "Information"
    )
})

# State - use a hashtable so all closures share the same reference
$state = @{
    PowerShell = $null
    Runspace   = $null
}

# Default path
$pathBox.Text = "$env:USERPROFILE\Desktop\PCmigrate"

# Helpers
function Set-Running {
    $exportBtn.IsEnabled = $false
    $exportDropBtn.IsEnabled = $false
    $importBtn.IsEnabled = $false
    $cancelBtn.Visibility = "Visible"
    $progressBar.IsIndeterminate = $true
}

function Set-Idle {
    $exportBtn.IsEnabled = $true
    $exportDropBtn.IsEnabled = $true
    $importBtn.IsEnabled = $true
    $cancelBtn.Visibility = "Collapsed"
    $progressBar.IsIndeterminate = $false
}

# Cancel button
$cancelBtn.Add_Click({
    if ($state.PowerShell) {
        $ps = $state.PowerShell
        $state.PowerShell = $null
        $state.Runspace = $null

        # Kill child processes first (fast, no WMI)
        try {
            $myPid = $PID
            Get-Process wsl, winget, cscript -ErrorAction SilentlyContinue | Where-Object {
                try { 
                    $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).ParentProcessId
                    $parent -eq $myPid
                } catch { $false }
            } | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}

        # Stop the pipeline (non-blocking) then dispose on a thread pool thread
        try { $ps.BeginStop($null, $null) } catch {}
        [System.Threading.ThreadPool]::QueueUserWorkItem([System.Threading.WaitCallback]{
            param($p)
            Start-Sleep -Milliseconds 500
            try { $p.Dispose() } catch {}
        }, $ps) | Out-Null

        $logBlock.Text += "`n[CANCELLED] Operation stopped by user.`n"
        $logBlock.ScrollToEnd()
        $statusText.Text = "Cancelled"
        $progressBar.IsIndeterminate = $false
        $progressBar.Value = 0
        Set-Idle
    }
})

# Browse button
$browseBtn.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select backup/restore location"
    $dialog.SelectedPath = $pathBox.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.SelectedPath
    }
})

# Run a script in a background runspace
function Start-BackgroundTask {
    param([scriptblock]$Script, [hashtable]$Variables)

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()

    # Always pass UI controls
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("logBlock", $logBlock)
    $runspace.SessionStateProxy.SetVariable("statusText", $statusText)
    $runspace.SessionStateProxy.SetVariable("progressBar", $progressBar)
    $runspace.SessionStateProxy.SetVariable("exportBtn", $exportBtn)
    $runspace.SessionStateProxy.SetVariable("exportDropBtn", $exportDropBtn)
    $runspace.SessionStateProxy.SetVariable("importBtn", $importBtn)
    $runspace.SessionStateProxy.SetVariable("cancelBtn", $cancelBtn)

    foreach ($key in $Variables.Keys) {
        $runspace.SessionStateProxy.SetVariable($key, $Variables[$key])
    }

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $state.PowerShell = $ps
    $state.Runspace = $runspace

    $ps.AddScript($Script) | Out-Null
    $ps.BeginInvoke() | Out-Null
}

# Import/Restore button
$importBtn.Add_Click({
    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "Restoring..."

    Start-BackgroundTask -Variables @{ importPath = $pathBox.Text } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logBlock.ScrollToEnd() }) }
        function Done {
            try {
                $window.Dispatcher.Invoke([Action]{
                    $cancelBtn.Visibility = "Collapsed"
                    $exportBtn.IsEnabled = $true; $importBtn.IsEnabled = $true; $exportDropBtn.IsEnabled = $true
                    $progressBar.IsIndeterminate = $false; $progressBar.Value = 100
                })
            } catch {}
        }
        try {
            $restoreScript = Join-Path $importPath "Restore-Machine.ps1"
            if (-not (Test-Path $restoreScript)) {
                Log "ERROR: Restore-Machine.ps1 not found in $importPath"
                Log "Make sure you select the PCmigrate folder."
                return
            }
            Log "Starting restore from: $importPath"
            Log ""
            $output = & $restoreScript -ImportPath $importPath 2>&1
            foreach ($line in $output) { Log $line }
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Restore complete!" })
            Log ""; Log "=== DONE ==="
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Restore failed" })
        } finally { Done }
    }
})

# Export dropdown menu
$exportMenu = New-Object System.Windows.Controls.ContextMenu
$exportMenu.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#313244")
$exportMenu.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#cdd6f4")

$menuExportOnly = New-Object System.Windows.Controls.MenuItem
$menuExportOnly.Header = "Export Only"
$menuExportBundle = New-Object System.Windows.Controls.MenuItem
$menuExportBundle.Header = "Export + Create Restore Bundle"
$menuWslOnly = New-Object System.Windows.Controls.MenuItem
$menuWslOnly.Header = "WSL Only"
$menuOptimizeExport = New-Object System.Windows.Controls.MenuItem
$menuOptimizeExport.Header = "Optimize WSL + Export"
$menuSep = New-Object System.Windows.Controls.Separator
$menuConvertWsl = New-Object System.Windows.Controls.MenuItem
$menuConvertWsl.Header = "Convert WSL 1 → 2 (no export)"
$menuCompactWsl = New-Object System.Windows.Controls.MenuItem
$menuCompactWsl.Header = "Compact WSL Disks (no export)"

$exportMenu.Items.Add($menuExportOnly) | Out-Null
$exportMenu.Items.Add($menuExportBundle) | Out-Null
$exportMenu.Items.Add($menuWslOnly) | Out-Null
$exportMenu.Items.Add($menuOptimizeExport) | Out-Null
$exportMenu.Items.Add($menuSep) | Out-Null
$exportMenu.Items.Add($menuConvertWsl) | Out-Null
$exportMenu.Items.Add($menuCompactWsl) | Out-Null

$exportDropBtn.Add_Click({
    $exportMenu.PlacementTarget = $exportDropBtn
    $exportMenu.Placement = "Bottom"
    $exportMenu.IsOpen = $true
})

# Shared export logic
function Start-Export {
    param([bool]$CreateBundle, [bool]$WslOnly, [bool]$OptimizeWsl)

    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "Exporting..."
    if ($WslOnly) { $statusText.Text = "Exporting WSL..." }
    if ($OptimizeWsl) { $statusText.Text = "Optimizing WSL + Exporting..." }

    Start-BackgroundTask -Variables @{ outputPath = $pathBox.Text; scriptRoot = $PSScriptRoot; createBundle = $CreateBundle; wslOnly = $WslOnly; optimizeWsl = $OptimizeWsl } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logBlock.ScrollToEnd() }) }
        function Done {
            try {
                $window.Dispatcher.Invoke([Action]{
                    $cancelBtn.Visibility = "Collapsed"
                    $exportBtn.IsEnabled = $true; $importBtn.IsEnabled = $true; $exportDropBtn.IsEnabled = $true
                    $progressBar.IsIndeterminate = $false; $progressBar.Value = 100
                })
            } catch {}
        }
        try {
            $migrateScript = Join-Path $scriptRoot "Migrate-Machine.ps1"
            if (-not (Test-Path $migrateScript)) { Log "ERROR: Migrate-Machine.ps1 not found at $scriptRoot"; return }
            Log "Starting export to: $outputPath"
            Log ""
            $params = @{ OutputPath = $outputPath }
            if ($wslOnly) { $params.WslOnly = $true }
            if ($optimizeWsl) { $params.OptimizeWsl = $true }
            $output = & $migrateScript @params 2>&1
            foreach ($line in $output) { Log $line }
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Export complete!" })
            Log ""; Log "=== EXPORT DONE ==="; Log "Export folder: $outputPath"

            if ($createBundle) {
                Log ""; Log "--- Creating restore bundle ---"
                $resolvedOutput = (Resolve-Path $outputPath).Path -replace '\\$', ''
                $parentDir = Split-Path $resolvedOutput -Parent
                $folderName = Split-Path $resolvedOutput -Leaf
                if (-not $parentDir -or -not $folderName -or $folderName -match '^[A-Z]:$') {
                    $zipName = "PCmigrate_RestoreBundle.zip"
                    $zipPath = Join-Path "$resolvedOutput\" $zipName
                } else {
                    $zipName = "${folderName}_RestoreBundle.zip"
                    $zipPath = Join-Path $parentDir $zipName
                }
                if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
                Log "Compressing files (this may take a while for large WSL exports)..."
                if ($resolvedOutput -match '^[A-Z]:$') { $listPath = "$resolvedOutput\" } else { $listPath = $resolvedOutput }
                $items = Get-ChildItem -LiteralPath $listPath
                if (-not $items) { Log "WARNING: No files to bundle"; return }
                Add-Type -AssemblyName System.IO.Compression
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
                try {
                    foreach ($item in $items) {
                        if ($item.PSIsContainer) {
                            $subFiles = Get-ChildItem -LiteralPath $item.FullName -Recurse -File
                            foreach ($f in $subFiles) {
                                $entryName = $item.Name + '/' + $f.FullName.Substring($item.FullName.Length + 1).Replace('\', '/')
                                # Store WSL exports uncompressed — VHDX/tar don't compress well and waste time
                                if ($f.Extension -match '\.(vhdx|tar)$') { $level = 'NoCompression' } else { $level = 'Optimal' }
                                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entryName, $level) | Out-Null
                            }
                        } else {
                            if ($item.Extension -match '\.(vhdx|tar)$') { $level = 'NoCompression' } else { $level = 'Optimal' }
                            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $item.FullName, $item.Name, $level) | Out-Null
                        }
                    }
                } finally { $zip.Dispose() }
                if (Test-Path $zipPath) {
                    $sizeBytes = (Get-Item $zipPath).Length
                    if ($sizeBytes -ge 1MB) { $sizeStr = "$([math]::Round($sizeBytes / 1MB, 1)) MB" } else { $sizeStr = "$([math]::Round($sizeBytes / 1KB, 0)) KB" }
                    Log ""
                    Log "=== BUNDLE CREATED ==="
                    Log "File: $zipPath"
                    Log "Size: $sizeStr"
                    Log ""
                    Log "To restore on the new machine:"
                    Log "  1. Copy $zipName to the new machine"
                    Log "  2. Extract the zip"
                    Log "  3. Double-click Restore.cmd"
                    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Bundle created ($sizeStr)" })
                } else {
                    Log "ERROR: Failed to create zip file."
                }
            }
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Export failed" })
        } finally { Done }
    }
}

# Export button (default: export only)
$exportBtn.Add_Click({ Start-Export -CreateBundle $false -WslOnly $false -OptimizeWsl $false })

# Menu items
$menuExportOnly.Add_Click({ Start-Export -CreateBundle $false -WslOnly $false -OptimizeWsl $false })
$menuExportBundle.Add_Click({ Start-Export -CreateBundle $true -WslOnly $false -OptimizeWsl $false })
$menuWslOnly.Add_Click({ Start-Export -CreateBundle $false -WslOnly $true -OptimizeWsl $false })
$menuOptimizeExport.Add_Click({ Start-Export -CreateBundle $false -WslOnly $false -OptimizeWsl $true })

# WSL maintenance (no export)
function Start-WslTask {
    param([string]$Flag, [string]$Label)
    Set-Running
    $logBlock.Text = ""
    $statusText.Text = $Label
    Start-BackgroundTask -Variables @{ scriptRoot = $PSScriptRoot; flag = $Flag } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logBlock.ScrollToEnd() }) }
        function Done {
            try { $window.Dispatcher.Invoke([Action]{
                $cancelBtn.Visibility = "Collapsed"
                $exportBtn.IsEnabled = $true; $importBtn.IsEnabled = $true; $exportDropBtn.IsEnabled = $true
                $progressBar.IsIndeterminate = $false; $progressBar.Value = 100
            }) } catch {}
        }
        try {
            $migrateScript = Join-Path $scriptRoot "Migrate-Machine.ps1"
            if (-not (Test-Path $migrateScript)) { Log "ERROR: Migrate-Machine.ps1 not found"; return }
            $params = @{ $flag = $true }
            $output = & $migrateScript @params 2>&1
            foreach ($line in $output) { Log $line }
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Done!" })
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Failed" })
        } finally { Done }
    }
}

$menuConvertWsl.Add_Click({ Start-WslTask -Flag "ConvertWsl" -Label "Converting WSL 1 → 2..." })
$menuCompactWsl.Add_Click({ Start-WslTask -Flag "CompactWsl" -Label "Compacting WSL disks..." })

$window.ShowDialog() | Out-Null
