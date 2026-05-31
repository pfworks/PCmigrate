<#
.SYNOPSIS
    PCmigrate - Retro DOS-style GUI
.DESCRIPTION
    Alternative GUI with a retro DOS/ASCII aesthetic.
    Same functionality as PCmigrate-GUI.ps1.
.NOTES
    Requires: Administrator privileges, PowerShell 5.1+, .NET Framework 4.5+
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
        Title="PCmigrate v0.2 - Total System Transfer Utility" Height="600" Width="750"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="Black">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="Black"/>
            <Setter Property="Foreground" Value="#00ff00"/>
            <Setter Property="FontFamily" Value="Consolas,Courier New,monospace"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="BorderBrush" Value="#00ff00"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#003300"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="BorderBrush" Value="#005500"/>
                                <Setter Property="Foreground" Value="#005500"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="Black"/>
            <Setter Property="Foreground" Value="#00ff00"/>
            <Setter Property="BorderBrush" Value="#00ff00"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Consolas,Courier New,monospace"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="CaretBrush" Value="#00ff00"/>
        </Style>
    </Window.Resources>
    <DockPanel>
        <Menu DockPanel.Dock="Top" Background="Black" Foreground="#00ff00" FontFamily="Consolas" FontSize="12">
            <MenuItem Header="_File" Foreground="#00ff00">
                <MenuItem x:Name="MenuExit" Header="E_xit" Foreground="#00ff00" Background="Black"/>
            </MenuItem>
            <MenuItem Header="_View" Foreground="#00ff00">
                <MenuItem x:Name="MenuModern" Header="Switch to _Modern Style" Foreground="#00ff00" Background="Black"/>
            </MenuItem>
            <MenuItem Header="_Help" Foreground="#00ff00">
                <MenuItem x:Name="MenuHelp" Header="_User Manual" Foreground="#00ff00" Background="Black"/>
                <Separator/>
                <MenuItem x:Name="MenuAbout" Header="_About" Foreground="#00ff00" Background="Black"/>
            </MenuItem>
        </Menu>
    <Border BorderBrush="#00ff00" BorderThickness="2" Margin="8">
        <Grid Margin="16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- ASCII Banner -->
            <TextBlock Grid.Row="0" FontFamily="Consolas,Courier New,monospace" FontSize="9" Foreground="#00ff00" Margin="0,0,0,8" xml:space="preserve"><Run Text=" ██████╗  ██████╗███╗   ███╗██╗ ██████╗ ██████╗  █████╗ ████████╗███████╗"/>
<Run Text=" ██╔══██╗██╔════╝████╗ ████║██║██╔════╝ ██╔══██╗██╔══██╗╚══██╔══╝██╔════╝"/>
<Run Text=" ██████╔╝██║     ██╔████╔██║██║██║  ███╗██████╔╝███████║   ██║   █████╗  "/>
<Run Text=" ██╔═══╝ ██║     ██║╚██╔╝██║██║██║   ██║██╔══██╗██╔══██║   ██║   ██╔══╝  "/>
<Run Text=" ██║     ╚██████╗██║ ╚═╝ ██║██║╚██████╔╝██║  ██║██║  ██║   ██║   ███████╗"/>
<Run Text=" ╚═╝      ╚═════╝╚═╝     ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝"/>
<Run Text="           Total System Transfer Utility v0.2  (C) 2026 pfworks"/></TextBlock>

            <!-- Path -->
            <StackPanel Grid.Row="1" Margin="0,8,0,12">
                <TextBlock FontFamily="Consolas" FontSize="13" Foreground="#00ff00" Margin="0,0,0,4">C:\&gt; SET OUTPUT_PATH=</TextBlock>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="PathBox" Grid.Column="0"/>
                    <Button x:Name="BrowseBtn" Grid.Column="1" Content="[DIR]" Margin="8,0,0,0" Padding="10,4"/>
                </Grid>
            </StackPanel>

            <!-- Buttons -->
            <WrapPanel Grid.Row="2" Margin="0,0,0,12">
                <Button x:Name="ExportBtn" Content="[F1] EXPORT" Margin="0,0,8,0"/>
                <Button x:Name="ExportDropBtn" Content="[+]" Margin="0,0,8,0" Padding="6,6"/>
                <Button x:Name="ImportBtn" Content="[F2] RESTORE" Margin="0,0,8,0"/>
                <Button x:Name="CancelBtn" Content="[ESC] ABORT" Margin="0,0,0,0" BorderBrush="#ff5555" Foreground="#ff5555" Visibility="Collapsed"/>
            </WrapPanel>

            <!-- Log Output -->
            <Border Grid.Row="3" BorderBrush="#005500" BorderThickness="1" Margin="0,0,0,8">
                <ScrollViewer x:Name="LogScroller" VerticalScrollBarVisibility="Auto" Background="Black">
                    <TextBlock x:Name="LogBlock" FontFamily="Consolas,Courier New,monospace" FontSize="12"
                               Foreground="#00ff00" TextWrapping="Wrap" Padding="8"/>
                </ScrollViewer>
            </Border>

            <!-- Status -->
            <Grid Grid.Row="4">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ProgressBar x:Name="ProgressBar" Grid.Column="0" Height="4" Background="#001100" Foreground="#00ff00" BorderThickness="0" Margin="0,0,12,0"/>
                <TextBlock x:Name="StatusText" Grid.Column="1" Text="READY_" FontFamily="Consolas" FontSize="12" Foreground="#00ff00"/>
            </Grid>
        </Grid>
    </Border>
    </DockPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$pathBox = $window.FindName("PathBox")
$browseBtn = $window.FindName("BrowseBtn")
$exportBtn = $window.FindName("ExportBtn")
$exportDropBtn = $window.FindName("ExportDropBtn")
$importBtn = $window.FindName("ImportBtn")
$cancelBtn = $window.FindName("CancelBtn")
$logBlock = $window.FindName("LogBlock")
$logScroller = $window.FindName("LogScroller")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Menu items
$menuExit = $window.FindName("MenuExit")
$menuModern = $window.FindName("MenuModern")
$menuHelp = $window.FindName("MenuHelp")
$menuAbout = $window.FindName("MenuAbout")

$menuExit.Add_Click({ $window.Close() })

$script:switchTo = $null

$menuModern.Add_Click({
    $script:switchTo = "Modern"
    # Save preference
    Set-Content -Path (Join-Path $PSScriptRoot ".pcmigrate-style") -Value "Modern"
    $window.Close()
})

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
        "PCmigrate v0.2`nTotal System Transfer Utility`n`n(C) 2026 pfworks`nMIT License`n`nhttps://github.com/pfworks/PCmigrate",
        "About PCmigrate",
        "OK",
        "Information"
    )
})

# State
$state = @{ PowerShell = $null; Runspace = $null }

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

# Cancel
$cancelBtn.Add_Click({
    if ($state.PowerShell) {
        $ps = $state.PowerShell
        $state.PowerShell = $null
        $state.Runspace = $null
        try {
            $myPid = $PID
            Get-Process wsl, winget, cscript -ErrorAction SilentlyContinue | Where-Object {
                try {
                    $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).ParentProcessId
                    $parent -eq $myPid
                } catch { $false }
            } | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}
        try { $ps.BeginStop($null, $null) } catch {}
        [System.Threading.ThreadPool]::QueueUserWorkItem([System.Threading.WaitCallback]{
            param($p); Start-Sleep -Milliseconds 500; try { $p.Dispose() } catch {}
        }, $ps) | Out-Null
        $logBlock.Text += "`n*** ABORTED BY USER ***`n"
        $logScroller.ScrollToEnd()
        $statusText.Text = "ABORTED_"
        $progressBar.IsIndeterminate = $false
        $progressBar.Value = 0
        Set-Idle
    }
})

# Browse
$browseBtn.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select output directory"
    $dialog.SelectedPath = $pathBox.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pathBox.Text = $dialog.SelectedPath
    }
})

# Background task runner
function Start-BackgroundTask {
    param([scriptblock]$Script, [hashtable]$Variables)
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("logBlock", $logBlock)
    $runspace.SessionStateProxy.SetVariable("logScroller", $logScroller)
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

# Export dropdown menu
$exportMenu = New-Object System.Windows.Controls.ContextMenu
$exportMenu.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("Black")
$exportMenu.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#00ff00")

$menuExportOnly = New-Object System.Windows.Controls.MenuItem
$menuExportOnly.Header = "EXPORT ONLY"
$menuExportBundle = New-Object System.Windows.Controls.MenuItem
$menuExportBundle.Header = "EXPORT + RESTORE BUNDLE"
$menuWslOnly = New-Object System.Windows.Controls.MenuItem
$menuWslOnly.Header = "WSL ONLY"

$exportMenu.Items.Add($menuExportOnly) | Out-Null
$exportMenu.Items.Add($menuExportBundle) | Out-Null
$exportMenu.Items.Add($menuWslOnly) | Out-Null

$exportDropBtn.Add_Click({
    $exportMenu.PlacementTarget = $exportDropBtn
    $exportMenu.Placement = "Bottom"
    $exportMenu.IsOpen = $true
})

# Shared export logic
function Start-Export {
    param([bool]$CreateBundle, [bool]$WslOnly)
    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "WORKING..."
    if ($WslOnly) { $statusText.Text = "WSL EXPORT..." }

    Start-BackgroundTask -Variables @{ outputPath = $pathBox.Text; scriptRoot = $PSScriptRoot; createBundle = $CreateBundle; wslOnly = $WslOnly } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logScroller.ScrollToEnd() }) }
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
            if (-not (Test-Path $migrateScript)) { Log "ERROR: Migrate-Machine.ps1 not found"; return }
            Log "C:\> Migrate-Machine.ps1 -OutputPath $outputPath"
            Log ""
            $params = @{ OutputPath = $outputPath }
            if ($wslOnly) { $params.WslOnly = $true }
            $output = & $migrateScript @params 2>&1
            foreach ($line in $output) { Log $line }
            if ($createBundle) {
                Log ""; Log "C:\> Creating restore bundle..."
                $parentDir = Split-Path $outputPath -Parent
                $folderName = Split-Path $outputPath -Leaf
                $zipPath = Join-Path $parentDir "${folderName}_RestoreBundle.zip"
                if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
                $items = Get-ChildItem -LiteralPath $outputPath
                Compress-Archive -LiteralPath $items.FullName -DestinationPath $zipPath -CompressionLevel Optimal
                if (Test-Path $zipPath) {
                    $sizeBytes = (Get-Item $zipPath).Length
                    if ($sizeBytes -ge 1MB) { $sizeStr = "$([math]::Round($sizeBytes / 1MB, 1)) MB" } else { $sizeStr = "$([math]::Round($sizeBytes / 1KB, 0)) KB" }
                    Log "Bundle: $zipPath ($sizeStr)"
                }
            }
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "DONE_" })
            Log ""; Log "*** TRANSFER COMPLETE ***"
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "ERROR_" })
        } finally { Done }
    }
}

# Restore
$importBtn.Add_Click({
    Set-Running
    $logBlock.Text = ""
    $statusText.Text = "RESTORING..."
    Start-BackgroundTask -Variables @{ importPath = $pathBox.Text } -Script {
        function Log($msg) { $window.Dispatcher.Invoke([Action]{ $logBlock.Text += "$msg`n"; $logScroller.ScrollToEnd() }) }
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
            if (-not (Test-Path $restoreScript)) { Log "ERROR: Restore-Machine.ps1 not found in $importPath"; return }
            Log "C:\> Restore-Machine.ps1 -ImportPath $importPath"
            Log ""
            $output = & $restoreScript -ImportPath $importPath 2>&1
            foreach ($line in $output) { Log $line }
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "DONE_" })
            Log ""; Log "*** RESTORE COMPLETE ***"
        } catch {
            Log "ERROR: $_"
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "ERROR_" })
        } finally { Done }
    }
})

# Button handlers
$exportBtn.Add_Click({ Start-Export -CreateBundle $false -WslOnly $false })
$menuExportOnly.Add_Click({ Start-Export -CreateBundle $false -WslOnly $false })
$menuExportBundle.Add_Click({ Start-Export -CreateBundle $true -WslOnly $false })
$menuWslOnly.Add_Click({ Start-Export -CreateBundle $false -WslOnly $true })

$window.ShowDialog() | Out-Null

if ($script:switchTo -eq "Modern") {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -NoProfile -File `"$PSScriptRoot\PCmigrate-GUI.ps1`""
}
