# Used by: Get-AllSensorRows/Show-PageYourPCSensors only. Plain PSCustomObject rows have no
# change notification, so swapping values on the existing objects (done by the live-refresh timer
# below) never updates the DataGrid's cell text - only reassigning ItemsSource (which rebuilds
# every row/group container) did, and that rebuild on every 2s tick is the visible "travadinha".
# Implementing INotifyPropertyChanged lets WPF's binding engine update just the changed cell text
# in place, with no container rebuild, when ValueText/MinText/MaxText are mutated in a tick.
if (-not ([System.Management.Automation.PSTypeName]"SettSensorRow").Type) {
    Add-Type -TypeDefinition @"
using System.ComponentModel;

public class SettSensorRow : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    private void Raise(string name) {
        if (PropertyChanged != null) { PropertyChanged(this, new PropertyChangedEventArgs(name)); }
    }

    public string HardwareName { get; set; }
    public string Category { get; set; }
    public string CategoryDisplay { get; set; }
    public string SensorName { get; set; }

    private string _valueText;
    public string ValueText { get { return _valueText; } set { if (_valueText != value) { _valueText = value; Raise("ValueText"); } } }

    private string _minText;
    public string MinText { get { return _minText; } set { if (_minText != value) { _minText = value; Raise("MinText"); } } }

    private string _maxText;
    public string MaxText { get { return _maxText; } set { if (_maxText != value) { _maxText = value; Raise("MaxText"); } } }
}
"@
}

# Used by: Sensors page only.
# Mirrors ResetExplode's SensorMonitor.IsPawnIOInstalled: PawnIO registers this exact
# uninstall key when installed (used by LibreHardwareMonitor/FanControl too).
# NOTE: a plain "HKLM:\SOFTWARE\..." path is silently redirected by WOW64 to
# "HKLM:\SOFTWARE\WOW6432Node\..." whenever SETTDash runs inside a 32-bit host, and PawnIO's
# (64-bit) installer never writes its key there - causing "not installed" false negatives on
# 64-bit Windows even when PawnIO is present. Open the 64-bit registry view explicitly (like
# LibreHardwareMonitorLib's own PawnIo.cs does) so detection is correct regardless of this
# process's bitness.
function Test-PawnIOInstalled {
    try {
        $hklm64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $hklm64.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO")
        return [bool]$key
    } catch { return $false }
}

# Used by: Sensors page only.
# Mirrors ResetExplode's "Corrigir" flow: asks the user via the same styled dashboard popup
# used by Invoke-CheckForUpdates (Get-UpdatePopupXaml / Register-UpdatePopupDrag, defined in
# Core/Helpers/UpdateChecker.ps1), then runs the same winget command the original uses, in a
# visible console so progress/errors are visible.
function Show-PawnIOInstallPrompt {
    $t = Get-CurrentThemeColors
    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="$($t.CornerRadius)" Background="$($t.HoverBg)">
                <TextBlock Text="&#xE9CA;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="$($t.Accent)"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="$(T 'PawnIO Driver Missing')" FontFamily="JetBrains Mono, Consolas" Foreground="$($t.TextPrimary)" FontSize="14" FontWeight="Bold"/>
                <TextBlock FontFamily="JetBrains Mono, Consolas" Text="$(T 'Required for CPU temperature/power sensors')" Foreground="$($t.TextMuted)" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
        </StackPanel>
        <TextBlock Text="$(T "PawnIO is a free, signed driver (also used by LibreHardwareMonitor and FanControl) needed to read CPU temperature and power. Install it now via winget? This opens a console window; close and reopen SETTDash once it's done.")"
                   Foreground="$($t.TextSecondary)" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnLater" Content="$(T 'Not Now')" Style="{StaticResource DialogSecondaryButtonStyle}" Margin="0,0,12,0"/>
            <Button x:Name="btnUpdate" Content="$(T 'Install PawnIO')" Style="{StaticResource DialogPrimaryButtonStyle}"/>
        </StackPanel>
"@

    [xml]$xaml = Get-UpdatePopupXaml -Width 420 -Title "SETTDash" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $btnLater = $dlg.FindName("btnLater")
    $btnInstall = $dlg.FindName("btnUpdate")

    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar

    # Plain local (NOT $Script:) value used inside the Add_Click closure below: 'Script:
    # variables are not readable there - that scope expression resolves against the closure
    # MODULE's script scope (null), which corrupted 'Join-Path' with "Cannot bind argument to
    # parameter 'Path' because it is null" (same root cause as Invoke-SelfUpdate's $tempDir).
    $tempDir = $Script:TempDir

    $btnLater.Add_Click({ $dlg.Close() }.GetNewClosure())
    $btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
    $btnInstall.Add_Click({
        $dlg.Close()
        Write-GuiLog (T "Installing PawnIO via winget...") "STEP"
        $marker = Join-Path $tempDir "pawnio_install.flag"
        if (Test-Path $marker) { Remove-Item $marker -Force -ErrorAction SilentlyContinue }
        Start-Process "cmd.exe" -ArgumentList "/c winget install --id namazso.PawnIO -e --accept-package-agreements --accept-source-agreements & echo.>`"$marker`" & echo Done! You can close this window." -WindowStyle Normal
        Watch-PawnIOInstallResult -Marker $marker
    }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
}

# Used by: Show-PawnIOInstallPrompt only.
# Polls (via DispatcherTimer, non-blocking) for the marker file winget's cmd writes right after
# it finishes, then shows the same themed popup used everywhere else with the success message
# and a reminder to restart SETTDash so CPU temperature/power sensors become available -
# mirrors ResetExplode's own "Pronto! Feche e reabra o RESET EXPLODE" message.
function Watch-PawnIOInstallResult {
    param([string]$Marker)
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        if (Test-Path $Marker) {
            $timer.Stop()
            Remove-Item $Marker -Force -ErrorAction SilentlyContinue
            $installedNow = Test-PawnIOInstalled
            Write-GuiLog $(if ($installedNow) { T "PawnIO installed successfully" } else { T "PawnIO installer finished" }) $(if ($installedNow) { "OK" } else { "WARN" })
            Show-PawnIOInstallResultDialog -Success $installedNow
        }
    }.GetNewClosure())
    $timer.Start()
}

# Used by: Watch-PawnIOInstallResult only.
# Themed success/warning popup shown once winget finishes, telling the user to restart SETTDash
# (CPU sensors are only probed once, at startup).
function Show-PawnIOInstallResultDialog {
    param([bool]$Success)
    $t = Get-CurrentThemeColors
    $icon = if ($Success) { "&#xE930;" } else { "&#xE946;" }
    $title = if ($Success) { T "PawnIO Installed" } else { T "Installation Finished" }
    $msg = if ($Success) {
        T "PawnIO was installed successfully. Restart SETTDash now to enable CPU temperature and power sensors."
    } else {
        T "The winget installer finished, but PawnIO was not detected yet. If you just installed it, restart your PC, then restart SETTDash."
    }
    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="$($t.CornerRadius)" Background="$($t.HoverBg)">
                <TextBlock Text="$icon" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="$($t.Accent)"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="$title" FontFamily="JetBrains Mono, Consolas" Foreground="$($t.TextPrimary)" FontSize="14" FontWeight="Bold"/>
            </StackPanel>
        </StackPanel>
        <TextBlock Text="$msg" Foreground="$($t.TextSecondary)" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnUpdate" Content="$(T 'OK')" Style="{StaticResource DialogPrimaryButtonStyle}"/>
        </StackPanel>
"@
    [xml]$xaml = Get-UpdatePopupXaml -Width 420 -Title "SETTDash" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)
    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $btnOk = $dlg.FindName("btnUpdate")
    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar
    $btnOk.Add_Click({ $dlg.Close() }.GetNewClosure())
    $btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())
    $dlg.ShowDialog() | Out-Null
}

# Used by: Show-PageYourPCSensors only. Walks the visual tree to find a DataGrid's internal
# ScrollViewer (part of its default template), so the live-refresh timer can save/restore the
# scroll offset around each ItemsSource swap - without this, re-pointing ItemsSource to a brand
# new filtered list every tick (see $render) snaps the grid back to the top every 2s, making it
# impossible to actually read a sensor list longer than one screen while it's live-updating.
function Get-DataGridScrollViewer {
    param($Visual)
    if ($null -eq $Visual) { return $null }
    for ($i = 0; $i -lt [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Visual); $i++) {
        $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Visual, $i)
        if ($child -is [System.Windows.Controls.ScrollViewer]) { return $child }
        $found = Get-DataGridScrollViewer $child
        if ($found) { return $found }
    }
    return $null
}

# Used by: Get-AllSensorRows only. Mirrors SensorRow.CategoryName: maps a LibreHardwareMonitor
# SensorType to the display category used for the chips/pills (e.g. "Temperature", "Load").
function Get-LHMSensorCategory {
    param([string]$Type)
    switch ($Type) {
        "Fan"       { "Fans" }
        "SmallData" { "Data" }
        default     { $Type }
    }
}

# Used by: Show-PageYourPCSensors only. Builds the flat, unified sensor list the page renders -
# real per-sensor readings from LibreHardwareMonitor when available (mirrors SensorMonitor.Refresh,
# including Min/Max), falling back to the previous WMI-based approximations (no Min/Max available)
# otherwise. Each row carries Hardware/Category/Sensor/Value/Min/Max, matching SensorRow.cs's columns.
function Get-AllSensorRows {
    param([bool]$LhmOk, [bool]$PawnIOInstalled)
    $list = New-Object System.Collections.Generic.List[object]
    $add = {
        param($Hw, $Cat, $Name, $Val, $Min = "—", $Max = "—")
        $row = New-Object SettSensorRow
        $row.HardwareName = $Hw; $row.Category = $Cat; $row.CategoryDisplay = (T $Cat); $row.SensorName = $Name
        $row.ValueText = $Val; $row.MinText = $Min; $row.MaxText = $Max
        $list.Add($row) | Out-Null
    }.GetNewClosure()

    if ($LhmOk) {
        foreach ($s in (Get-LHMSensorRows)) {
            & $add $s.HardwareName (Get-LHMSensorCategory $s.SensorType) $s.SensorName `
                (Format-LHMSensorValue $s.SensorType $s.Value) (Format-LHMSensorValue $s.SensorType $s.Min) (Format-LHMSensorValue $s.SensorType $s.Max)
        }
    }
    if ($list.Count -gt 0) { return $list }

    # ---- WMI fallback (no PawnIO / LHM init failed) - no Min/Max history available here ----
    try {
        $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        & $add "CPU" "Load" "CPU Total" "$cpuLoad %"
    } catch {}
    try {
        $i = 1
        foreach ($c in (Get-CimInstance Win32_Processor)) { & $add "CPU" "Clock" "Core $i" "$($c.CurrentClockSpeed) MHz"; $i++ }
    } catch {}
    $tempMsg = if ($PawnIOInstalled) { T "Unavailable (if you just installed PawnIO, restart your PC)" } else { T "Unavailable: PawnIO driver not installed" }
    & $add "CPU" "Temperature" "Package" $tempMsg
    & $add "CPU" "Power" "Package" $tempMsg

    try {
        $engines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop
        $byGpu = $engines | Group-Object { ($_.Name -split '_eng_')[0] }
        foreach ($g in $byGpu) {
            $load = ($g.Group | Measure-Object -Property UtilizationPercentage -Sum).Sum
            & $add "GPU" "Load" "GPU Total" "$([math]::Round($load,1)) %"
        }
    } catch { & $add "GPU" "Load" "GPU Total" (T "Unavailable on this system.") }
    try {
        $mem = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -ErrorAction Stop
        & $add "GPU" "Data" "Dedicated Memory In Use" (Format-ByteSizeAuto (($mem | Measure-Object -Property DedicatedUsage -Sum).Sum))
        & $add "GPU" "Data" "Shared Memory In Use" (Format-ByteSizeAuto (($mem | Measure-Object -Property SharedUsage -Sum).Sum))
    } catch {}

    try {
        $zones = Get-CimInstance -Namespace "root\wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        $i = 1
        foreach ($z in $zones) { & $add "Motherboard" "Temperature" "Thermal Zone $i" "$([math]::Round(($z.CurrentTemperature / 10) - 273.15, 1)) °C"; $i++ }
    } catch { & $add "Motherboard" "Temperature" "Thermal Zones" (T "Unavailable (requires vendor ACPI sensor exposure).") }
    try {
        $i = 1
        foreach ($f in (Get-CimInstance Win32_Fan -ErrorAction Stop)) { & $add "Motherboard" "Fans" "Fan $i" $(if ($f.StatusInfo -eq 3) { T "Active" } else { T "Unknown" }); $i++ }
    } catch {}

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totKb = [double]$os.TotalVisibleMemorySize; $freeKb = [double]$os.FreePhysicalMemory; $usedKb = $totKb - $freeKb
        $pct = if ($totKb -gt 0) { [math]::Round(($usedKb / $totKb) * 100, 1) } else { 0 }
        & $add "Memory" "Load" "Memory" "$pct %"
        & $add "Memory" "Data" "In Use" (Format-ByteSizeAuto ($usedKb * 1024))
        & $add "Memory" "Data" "Available" (Format-ByteSizeAuto ($freeKb * 1024))
    } catch {}

    try {
        $disks = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop | Where-Object { $_.Name -ne "_Total" }
        foreach ($d in $disks) {
            & $add $d.Name "Load" "Disk Time" "$([math]::Round($d.PercentDiskTime,1)) %"
            & $add $d.Name "Throughput" "Read Speed" "$([math]::Round($d.DiskReadBytesPersec / 1MB, 2)) MB/s"
            & $add $d.Name "Throughput" "Write Speed" "$([math]::Round($d.DiskWriteBytesPersec / 1MB, 2)) MB/s"
        }
    } catch { & $add "Storage" "Load" (T "Status") (T "Disk activity counters unavailable.") }

    try {
        # @(...): if every adapter is filtered out the pipeline emits nothing ($null), and
        # $null.Count throws under StrictMode - which would surface as a bogus "counters
        # unavailable" error instead of the "no active interface" message below.
        $nics = @(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop |
            Where-Object { $_.Name -notmatch "isatap|Loopback|Teredo" -and ($_.BytesTotalPersec -gt 0) })
        foreach ($n in $nics) {
            & $add $n.Name "Throughput" "Upload" "$([math]::Round($n.BytesSentPersec * 8 / 1MB, 2)) Mbps"
            & $add $n.Name "Throughput" "Download" "$([math]::Round($n.BytesReceivedPersec * 8 / 1MB, 2)) Mbps"
        }
        if ($nics.Count -eq 0) { & $add "Network" "Load" (T "Status") (T "No active network interface detected.") }
    } catch { & $add "Network" "Load" (T "Status") (T "Network counters unavailable.") }

    return $list
}

# Sensors page: unified live sensor list with category pills ("Todos" + one per sensor type, e.g.
# Temperature/Load/Clock/Power/Voltage/Fans) and a search box filtering by sensor or hardware name -
# mirrors ResetExplode's PageSensors (CategoryChips + SensorSearch + SensorGrid grouped by Hardware).
function Show-PageYourPCSensors {
    $pawnIOInstalled = Test-PawnIOInstalled
    if (-not $pawnIOInstalled) { Show-PawnIOInstallPrompt }

    $lhmOk = Initialize-LibreHardwareMonitor
    $allRows = Get-AllSensorRows -LhmOk $lhmOk -PawnIOInstalled $pawnIOInstalled

    Clear-GuiContent
    Add-GuiPageTitle (T "Sensors")

    # ---- Header row: subtitle + search box (like ResetExplode's StatusText + SensorSearch) ----
    $headerGrid = New-Object System.Windows.Controls.Grid
    $headerGrid.Margin = "0,0,0,14"
    $subTitle = New-Object System.Windows.Controls.TextBlock
    $subTitle.Text = if ($lhmOk) { T "Live sensor readings" } else { T "Limited readings (install PawnIO for full CPU sensors)" }
    $subTitle.FontSize = 12
    $subTitle.HorizontalAlignment = "Left"
    $subTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    $headerGrid.AddChild($subTitle)

    $searchBorder = New-Object System.Windows.Controls.Border
    $searchBorder.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
    $searchBorder.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
    $searchBorder.BorderThickness = "1"
    $searchBorder.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
    $searchBorder.Padding = "8,4,8,4"
    $searchBorder.Width = 260
    $searchBorder.HorizontalAlignment = "Right"
    $searchStack = New-Object System.Windows.Controls.StackPanel
    $searchStack.Orientation = "Horizontal"
    $searchIcon = New-Object System.Windows.Controls.TextBlock
    $searchIcon.Text = [char]0xE721
    $searchIcon.FontFamily = "Segoe MDL2 Assets"
    $searchIcon.FontSize = 12
    $searchIcon.VerticalAlignment = "Center"
    $searchIcon.Margin = "0,0,6,0"
    $searchIcon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
    $searchStack.AddChild($searchIcon)
    $searchBox = New-Object System.Windows.Controls.TextBox
    $searchBox.Width = 210
    $searchBox.Background = "Transparent"
    $searchBox.BorderThickness = "0"
    $searchBox.SetResourceReference([System.Windows.Controls.TextBox]::ForegroundProperty, "Brush_TextPrimary")
    $searchBox.SetResourceReference([System.Windows.Controls.TextBox]::CaretBrushProperty, "Brush_Accent")
    $searchBox.SetResourceReference([System.Windows.Controls.TextBox]::FontFamilyProperty, "Theme_FontFamily")
    $searchBox.Tag = (T "Search sensor or hardware...")
    $searchStack.AddChild($searchBox)
    $searchBorder.Child = $searchStack
    $headerGrid.AddChild($searchBorder)
    $pnlContent.AddChild($headerGrid)

    # ---- Category pills ----
    $pillsCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("CardStyle"); if ($cardStyle) { $pillsCard.Style = $cardStyle }
    $pillsCard.Padding = "8"
    $pillsCard.Margin = "0,0,0,14"
    $pillsStack = New-Object System.Windows.Controls.WrapPanel
    $pillsStack.Orientation = "Horizontal"
    $pillsStack.HorizontalAlignment = "Center"
    $pillsCard.Child = $pillsStack
    $pnlContent.AddChild($pillsCard)

    # ---- Detail card: DataGrid with SENSOR/TYPE/VALUE/MIN/MAX columns, grouped by hardware -
    # mirrors ResetExplode's SensorGrid (DataGrid.GroupStyle header = hardware Name). ----
    $detailCard = New-Object System.Windows.Controls.Border
    if ($cardStyle) { $detailCard.Style = $cardStyle }
    $detailCard.Padding = "6,14,6,6"
    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.AutoGenerateColumns = $false
    $grid.IsReadOnly = $true
    $grid.CanUserResizeColumns = $false

    # NOTE: parsed standalone (outside the Window's resource scope), so StaticResource/DynamicResource
    # lookups here can't see Window.Resources - the text color is baked in as a literal hex instead
    # (page is fully rebuilt on every visit/theme switch, so this never goes stale).
    # Hardware name group header uses the accent orange (same emphasis as the hardware-identity
    # titles on the System page / Add-GuiInfoCard), not the plain text color.
    $groupHeaderColor = (Get-CurrentThemeColors).Accent
    $groupHeaderTemplate = [Windows.Markup.XamlReader]::Parse(@"
<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <TextBlock Text="{Binding Name}" FontSize="13" FontWeight="SemiBold" Margin="12,18,0,6" Foreground="$groupHeaderColor"/>
</DataTemplate>
"@)
    $groupStyle = New-Object System.Windows.Controls.GroupStyle
    $groupStyle.HeaderTemplate = $groupHeaderTemplate
    $grid.GroupStyle.Add($groupStyle)

    $mutedStyle = $Window.FindResource("MutedCellStyle")
    $monoStyle = $Window.FindResource("MonoCellStyle")
    $mutedMonoStyle = $Window.FindResource("MutedMonoCellStyle")
    $sensorNameStyle = $Window.FindResource("SensorNameCellStyle")

    function New-SensorColumn {
        param([string]$Header, [string]$Path, $Width, $ElementStyle)
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $Header
        $col.Binding = New-Object System.Windows.Data.Binding $Path
        $col.Width = $Width
        if ($ElementStyle) { $col.ElementStyle = $ElementStyle }
        return $col
    }
    $grid.Columns.Add((New-SensorColumn (T "SENSOR") "SensorName" (New-Object System.Windows.Controls.DataGridLength(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)) $sensorNameStyle)) | Out-Null
    $grid.Columns.Add((New-SensorColumn (T "TYPE (column)") "CategoryDisplay" 130 $mutedStyle)) | Out-Null
    $grid.Columns.Add((New-SensorColumn (T "VALUE") "ValueText" 130 $monoStyle)) | Out-Null
    $grid.Columns.Add((New-SensorColumn (T "MIN") "MinText" 110 $mutedMonoStyle)) | Out-Null
    $grid.Columns.Add((New-SensorColumn (T "MAX") "MaxText" 110 $mutedMonoStyle)) | Out-Null

    # DataGrid has its own internal ScrollViewer, which swallows mouse-wheel input even when the
    # cursor is just hovering a row (not over its own scrollbar) - that's the "can't scroll the page
    # while a card/control is selected/hovered" bug. Forward unhandled wheel ticks up to the outer
    # page ScrollViewer (Main/Layout.ps1's pnlContent host) instead of letting the DataGrid eat them.
    $grid.Add_PreviewMouseWheel({
        param($s, $e)
        if ($e.Handled) { return }
        $e.Handled = $true
        $arg = New-Object System.Windows.Input.MouseWheelEventArgs($e.MouseDevice, $e.Timestamp, $e.Delta)
        $arg.RoutedEvent = [System.Windows.Controls.ScrollViewer]::MouseWheelEvent
        $arg.Source = $s
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($s)
        while ($parent -and -not ($parent -is [System.Windows.Controls.ScrollViewer])) {
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
        }
        if ($parent) { $parent.RaiseEvent($arg) }
    }.GetNewClosure())

    $detailCard.Child = $grid
    $pnlContent.AddChild($detailCard)

    # $rowsBox.Rows holds the live sensor list - a hashtable is a reference type, so mutating
    # .Rows on each timer tick (below) is immediately visible to $render without needing
    # GetNewClosure() to re-snapshot it (plain array/variable reassignment would NOT be visible
    # to the already-created closure).
    $rowsBox = @{ Rows = $allRows }
    $state = @{ Category = $null; Search = "" }
    $pillButtons = @{}
    $activeStyle = $Window.FindResource("CategoryPillActiveStyle")
    $normalStyle = $Window.FindResource("CategoryPillStyle")

    $render = {
        $filtered = @($rowsBox.Rows | Where-Object {
            ($null -eq $state.Category -or $_.Category -eq $state.Category) -and
            ($state.Search.Length -eq 0 -or $_.SensorName -like "*$($state.Search)*" -or $_.HardwareName -like "*$($state.Search)*")
        })
        $grid.ItemsSource = $filtered
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($grid.ItemsSource)
        if ($view) {
            $view.GroupDescriptions.Clear()
            $view.GroupDescriptions.Add((New-Object System.Windows.Data.PropertyGroupDescription "HardwareName")) | Out-Null
        }
    }.GetNewClosure()

    $setPill = {
        param($name)
        foreach ($bn in $pillButtons.Keys) { $pillButtons[$bn].Style = if ($bn -eq $name) { $activeStyle } else { $normalStyle } }
        $state.Category = if ($name -eq "All") { $null } else { $name }
        & $render
    }.GetNewClosure()

    $allCats = @("All") + @($allRows | Select-Object -ExpandProperty Category -Unique | Sort-Object)
    foreach ($name in $allCats) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = (T $name)
        $btn.Style = $normalStyle
        $btn.Add_Click({ & $setPill $name }.GetNewClosure())
        $pillButtons[$name] = $btn
        $pillsStack.AddChild($btn)
    }

    $searchBox.Add_TextChanged({ $state.Search = $searchBox.Text.Trim(); & $render }.GetNewClosure())

    & $setPill "All"

    # Keep sensor values updating in real time while this page stays open (stopped by
    # Clear-GuiContent as soon as the user navigates away - see $Script:LivePageTimer).
    # $gridScrollViewer is looked up lazily (resolved on the first tick, once the DataGrid's
    # template is realized) and its offset is saved/restored around the refresh, so the user's
    # scroll position survives the ItemsSource swap instead of jumping back to the top every 2s.
    $gridScrollViewer = $null

    # NOTE: a background-runspace fetch (to keep $Hw.Update() off the UI thread) was tried here and
    # reverted - LibreHardwareMonitor's Computer/Hardware handles are opened on the main thread and
    # reading them from a different thread came back empty (likely a thread-affinity requirement on
    # the underlying Ring0 driver handles, not something this app can safely work around), so the
    # fetch below stays synchronous on the UI thread like the CPU/GPU pages' own live-refresh timers.
    $Script:LivePageTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Script:LivePageTimer.Interval = [TimeSpan]::FromSeconds(2)
    $Script:LivePageTimer.Add_Tick({
        if (-not $gridScrollViewer) { $gridScrollViewer = Get-DataGridScrollViewer $grid }
        $offset = if ($gridScrollViewer) { $gridScrollViewer.VerticalOffset } else { 0 }
        $newRows = Get-AllSensorRows -LhmOk $lhmOk -PawnIOInstalled $pawnIOInstalled

        # NOTE: an in-place mutation optimization (update ValueText/MinText/MaxText on the existing
        # SettSensorRow objects instead of reassigning ItemsSource, relying on INotifyPropertyChanged
        # to refresh just the changed cell text with no container rebuild) was tried here and reverted -
        # confirmed via diagnostic logging that the underlying data WAS changing correctly every tick,
        # but the already-realized DataGridCell containers never redrew (likely an interaction between
        # DataGridTextColumn's generated binding and this grid's GroupStyle/GroupDescriptions, which
        # isn't trivial to fix). Reassigning ItemsSource (rebuilding groups/containers) every tick is
        # the only path confirmed to reliably refresh the grid, so it's used unconditionally again -
        # trades the small per-tick rebuild cost ("travadinha") for actually-live values, which matters
        # more than smoothness here.
        $rowsBox.Rows = $newRows
        & $render
        if ($gridScrollViewer) { $gridScrollViewer.ScrollToVerticalOffset($offset) }
    }.GetNewClosure())
    $Script:LivePageTimer.Start()
}
