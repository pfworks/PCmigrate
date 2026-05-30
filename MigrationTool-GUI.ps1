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
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

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
            <Button x:Name="ExportBtn" Content="&#xE898;  Export" Padding="20,12" Margin="0,0,10,0"/>
            <Button x:Name="ImportBtn" Content="&#xE896;  Restore" Padding="20,12" Margin="0,0,10,0"/>
            <Button x:Name="BundleBtn" Content="&#x1F4E6;  Create Restore Bundle" Padding="20,12" Margin="0,0,10,0" Background="#a6e3a1"/>
            <Button x:Name="CancelBtn" Content="&#x2716;  Cancel" Padding="14,12" Background="#f38ba8" Visibility="Collapsed"/>
        </StackPanel>

        <!-- Log Output -->
        <Border Grid.Row="3" Background="#181825" CornerRadius="6" Padding="4" Margin="0,0,0,12">
            <ScrollViewer x:Name="LogScroller" VerticalScrollBarVisibility="Auto">
                <TextBlock x:Name="LogBlock" FontFamily="Cascadia Mono,Consolas,Courier New" FontSize="12"
                           Foreground="#a6adc8" TextWrapping="Wrap" Padding="8"/>
            </ScrollViewer>
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
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$pathBox = $window.FindName("PathBox")
$browseBtn = $window.FindName("BrowseBtn")
$exportBtn = $window.FindName("ExportBtn")
$importBtn = $window.FindName("ImportBtn")
$bundleBtn = $window.FindName("BundleBtn")
$cancelBtn = $window.FindName("CancelBtn")
$logBlock = $window.FindName("LogBlock")
$logScroller = $window.FindName("LogScroller")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# State
$script:currentPowerShell = $null
$script:currentRunspace = $null

# Default path
$pathBox.Text = "$env:USERPROFILE\Desktop\MigrationExport"

# Helpers
function Set-Running {
    $exportBtn.IsEnabled = $false
    $importBtn.IsEnabled = $false
    $bundleBtn.IsEnabled = $false
    $cancelBtn.Visibility = "Visible"
    $progressBar.IsIndeterminate = $true
}

function Set-Idle {
    $exportBtn.IsEnabled = $true
    $importBtn.IsEnabled = $true
    $bundleBtn.IsEnabled = $true
    $cancelBtn.Visibility = "Collapsed"
    $progressBar.IsIndeterminate = $false
}

# Cancel button
$cancelBtn.Add_Click({
    if ($script:currentPowerShell) {
        $script:currentPowerShell.Stop()
        $script:currentRunspace.Close()
        $script:currentPowerShell = $null
        $script:currentRunspace = $null
        $logBlock.Text += "`n[CANCELLED] Operation stopped by user.`n"
        $logScroller.ScrollToEnd()
        $statusText.Text = "Cancelled"
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
    $runspace.SessionStateProxy.SetVariable("logScroller", $logScroller)
    $runspace.SessionStateProxy.SetVariable("statusText", $statusText)
    $runspace.SessionStateProxy.SetVariable("progressBar", $progressBar)
    $runspace.SessionStateProxy.SetVariable("exportBtn", $exportBtn)
    $runspace.SessionStateProxy.SetVariable("importBtn", $importBtn)
    $runspace.SessionStateProxy.SetVariable("bundleBtn", $bundleBtn)
    $runspace.SessionStateProxy.SetVariable("cancelBtn", $cancelBtn)

    foreach ($key in $Variables.Keys) {
        $runspace.SessionStateProxy.SetVariable($key, $Variables[$key])
    }

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $script:currentPowerShell = $ps
    $script:currentRunspace = $runspace

    $ps.AddScript($Script) | Out-Null
    $ps.BeginInvoke() | Out-Null
}

# Export button
$exportBtn.Add_Click({
    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "Exporting..."

    Start-BackgroundTask -Variables @{ outputPath = $pathBox.Text; scriptRoot = $PSScriptRoot } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logScroller.ScrollToEnd() }) }
        function Done {
            $window.Dispatcher.Invoke([Action]{
                $cancelBtn.Visibility = "Collapsed"
                $exportBtn.IsEnabled = $true; $importBtn.IsEnabled = $true; $bundleBtn.IsEnabled = $true
                $progressBar.IsIndeterminate = $false; $progressBar.Value = 100
            })
        }
        try {
            $migrateScript = Join-Path $scriptRoot "Migrate-Machine.ps1"
            if (-not (Test-Path $migrateScript)) { Log "ERROR: Migrate-Machine.ps1 not found at $scriptRoot"; return }
            Log "Starting export to: $outputPath"
            Log ""
            $output = & $migrateScript -OutputPath $outputPath 2>&1
            foreach ($line in $output) { Log $line }
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Export complete!" })
            Log ""; Log "=== DONE ==="; Log "Export folder: $outputPath"
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Export failed" })
        } finally { Done }
    }
})

# Import/Restore button
$importBtn.Add_Click({
    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "Restoring..."

    Start-BackgroundTask -Variables @{ importPath = $pathBox.Text } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logScroller.ScrollToEnd() }) }
        function Done {
            $window.Dispatcher.Invoke([Action]{
                $cancelBtn.Visibility = "Collapsed"
                $exportBtn.IsEnabled = $true; $importBtn.IsEnabled = $true; $bundleBtn.IsEnabled = $true
                $progressBar.IsIndeterminate = $false; $progressBar.Value = 100
            })
        }
        try {
            $restoreScript = Join-Path $importPath "Restore-Machine.ps1"
            if (-not (Test-Path $restoreScript)) {
                Log "ERROR: Restore-Machine.ps1 not found in $importPath"
                Log "Make sure you select the MigrationExport folder."
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

# Create Restore Bundle button
$bundleBtn.Add_Click({
    $exportPath = $pathBox.Text
    if (-not (Test-Path $exportPath)) {
        $logBlock.Text = "ERROR: Export folder not found at '$exportPath'.`nRun an export first, then create the bundle."
        return
    }
    $restoreScript = Join-Path $exportPath "Restore-Machine.ps1"
    if (-not (Test-Path $restoreScript)) {
        $logBlock.Text = "ERROR: No Restore-Machine.ps1 found in '$exportPath'.`nRun an export first."
        return
    }

    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "Creating restore bundle..."

    Start-BackgroundTask -Variables @{ exportPath = $exportPath } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logScroller.ScrollToEnd() }) }
        function Done {
            $window.Dispatcher.Invoke([Action]{
                $cancelBtn.Visibility = "Collapsed"
                $exportBtn.IsEnabled = $true; $importBtn.IsEnabled = $true; $bundleBtn.IsEnabled = $true
                $progressBar.IsIndeterminate = $false; $progressBar.Value = 100
            })
        }
        try {
            $parentDir = Split-Path $exportPath -Parent
            $folderName = Split-Path $exportPath -Leaf
            $zipName = "${folderName}_RestoreBundle.zip"
            $zipPath = Join-Path $parentDir $zipName

            Log "Creating restore bundle..."
            Log "Source: $exportPath"
            Log "Output: $zipPath"
            Log ""

            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
                Log "Removed existing bundle."
            }

            Log "Compressing files (this may take a while for large WSL exports)..."
            Compress-Archive -Path "$exportPath\*" -DestinationPath $zipPath -CompressionLevel Optimal

            if (Test-Path $zipPath) {
                $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
                Log ""
                Log "=== BUNDLE CREATED ==="
                Log "File: $zipPath"
                Log "Size: $sizeMB MB"
                Log ""
                Log "To restore on the new machine:"
                Log "  1. Copy $zipName to the new machine"
                Log "  2. Extract the zip"
                Log "  3. Right-click Restore-Machine.ps1 -> Run with PowerShell (as Admin)"
                $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Bundle created ($sizeMB MB)" })
            } else {
                Log "ERROR: Failed to create zip file."
                $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Bundle failed" })
            }
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Bundle failed" })
        } finally { Done }
    }
})

$window.ShowDialog() | Out-Null
