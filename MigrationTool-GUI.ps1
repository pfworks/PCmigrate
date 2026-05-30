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
        Title="Windows Migration Tool" Height="520" Width="650"
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
        <Grid Grid.Row="1" Margin="0,0,0,16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="PathBox" Grid.Column="0" VerticalContentAlignment="Center"/>
            <Button x:Name="BrowseBtn" Grid.Column="1" Content="Browse..." Margin="8,0,0,0" Padding="12,8" FontSize="12"/>
        </Grid>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,16">
            <Button x:Name="ExportBtn" Content="&#xE898;  Export This Machine" Padding="20,12" Margin="0,0,12,0"/>
            <Button x:Name="ImportBtn" Content="&#xE896;  Restore to This Machine" Padding="20,12"/>
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
$logBlock = $window.FindName("LogBlock")
$logScroller = $window.FindName("LogScroller")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Default path
$pathBox.Text = "$env:USERPROFILE\Desktop\MigrationExport"

# Helper: append to log
function Add-Log {
    param([string]$Text)
    $window.Dispatcher.Invoke([Action]{
        $logBlock.Text += "$Text`n"
        $logScroller.ScrollToEnd()
    })
}

function Set-Status {
    param([string]$Text, [int]$Progress = -1)
    $window.Dispatcher.Invoke([Action]{
        $statusText.Text = $Text
        if ($Progress -ge 0) {
            $progressBar.IsIndeterminate = $false
            $progressBar.Value = $Progress
        }
    })
}

# Browse button
$browseBtn.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select migration folder"
    $dialog.SelectedPath = $pathBox.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.SelectedPath
    }
})

# Export button
$exportBtn.Add_Click({
    $exportBtn.IsEnabled = $false
    $importBtn.IsEnabled = $false
    $logBlock.Text = ""
    $outputPath = $pathBox.Text

    $progressBar.IsIndeterminate = $true
    Set-Status "Exporting..."

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("outputPath", $outputPath)
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("logBlock", $logBlock)
    $runspace.SessionStateProxy.SetVariable("logScroller", $logScroller)
    $runspace.SessionStateProxy.SetVariable("progressBar", $progressBar)
    $runspace.SessionStateProxy.SetVariable("statusText", $statusText)
    $runspace.SessionStateProxy.SetVariable("exportBtn", $exportBtn)
    $runspace.SessionStateProxy.SetVariable("importBtn", $importBtn)
    $runspace.SessionStateProxy.SetVariable("scriptRoot", $PSScriptRoot)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        function Log($msg) {
            $window.Dispatcher.Invoke([Action]{
                $logBlock.Text += "$msg`n"
                $logScroller.ScrollToEnd()
            })
        }
        function Status($msg) {
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = $msg })
        }

        try {
            $migrateScript = Join-Path $scriptRoot "Migrate-Machine.ps1"
            if (-not (Test-Path $migrateScript)) {
                Log "ERROR: Migrate-Machine.ps1 not found at $scriptRoot"
                return
            }

            Log "Starting export to: $outputPath"
            Log "Running Migrate-Machine.ps1..."
            Log ""

            # Run the migration script and capture output
            $output = & $migrateScript -OutputPath $outputPath 2>&1
            foreach ($line in $output) {
                Log $line
            }

            Status "Export complete!"
            Log ""
            Log "=== DONE ==="
            Log "Export folder: $outputPath"
        } catch {
            Log "ERROR: $_"
            Status "Export failed"
        } finally {
            $window.Dispatcher.Invoke([Action]{
                $exportBtn.IsEnabled = $true
                $importBtn.IsEnabled = $true
                $progressBar.IsIndeterminate = $false
                $progressBar.Value = 100
            })
        }
    }) | Out-Null

    $ps.BeginInvoke() | Out-Null
})

# Import/Restore button
$importBtn.Add_Click({
    $exportBtn.IsEnabled = $false
    $importBtn.IsEnabled = $false
    $logBlock.Text = ""
    $importPath = $pathBox.Text

    $progressBar.IsIndeterminate = $true
    Set-Status "Restoring..."

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("importPath", $importPath)
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("logBlock", $logBlock)
    $runspace.SessionStateProxy.SetVariable("logScroller", $logScroller)
    $runspace.SessionStateProxy.SetVariable("progressBar", $progressBar)
    $runspace.SessionStateProxy.SetVariable("statusText", $statusText)
    $runspace.SessionStateProxy.SetVariable("exportBtn", $exportBtn)
    $runspace.SessionStateProxy.SetVariable("importBtn", $importBtn)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        function Log($msg) {
            $window.Dispatcher.Invoke([Action]{
                $logBlock.Text += "$msg`n"
                $logScroller.ScrollToEnd()
            })
        }
        function Status($msg) {
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = $msg })
        }

        try {
            $restoreScript = Join-Path $importPath "Restore-Machine.ps1"
            if (-not (Test-Path $restoreScript)) {
                Log "ERROR: Restore-Machine.ps1 not found in $importPath"
                Log "Make sure you select the MigrationExport folder."
                return
            }

            Log "Starting restore from: $importPath"
            Log "Running Restore-Machine.ps1..."
            Log ""

            $output = & $restoreScript -ImportPath $importPath 2>&1
            foreach ($line in $output) {
                Log $line
            }

            Status "Restore complete!"
            Log ""
            Log "=== DONE ==="
        } catch {
            Log "ERROR: $_"
            Status "Restore failed"
        } finally {
            $window.Dispatcher.Invoke([Action]{
                $exportBtn.IsEnabled = $true
                $importBtn.IsEnabled = $true
                $progressBar.IsIndeterminate = $false
                $progressBar.Value = 100
            })
        }
    }) | Out-Null

    $ps.BeginInvoke() | Out-Null
})

$window.ShowDialog() | Out-Null
