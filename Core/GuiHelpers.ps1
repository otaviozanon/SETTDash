# Appends a colored, timestamped-style line to the log RichTextBox ($txtLog) and auto-scrolls to the end.
# $Type controls prefix/color: OK (green), ERR (red), WARN (yellow), STEP (purple), default/INFO (gray).
function Write-GuiLog {
    param([string]$Message, [string]$Type="INFO")
    $prefix = switch ($Type) { "OK" { "[OK]  " } "ERR" { "[ERR] " } "WARN" { "[WRN] " } "STEP" { "[>]   " } default { "[i]   " } }
    $color = switch ($Type) { "OK" { "#3FB950" } "ERR" { "#F85149" } "WARN" { "#D29922" } "STEP" { "#A371F7" } default { "#8B949E" } }
    
    $para = New-Object System.Windows.Documents.Paragraph
    $para.Margin = "0"
    $para.LineHeight = 16
    $run = New-Object System.Windows.Documents.Run("$prefix$Message")
    $colorObj = [System.Windows.Media.ColorConverter]::ConvertFromString($color)
    $run.Foreground = New-Object System.Windows.Media.SolidColorBrush($colorObj)
    $para.Inlines.Add($run)
    $txtLog.Document.Blocks.Add($para)
    $txtLog.ScrollToEnd()
}

# Updates the main progress bar value and, if provided, logs a STEP message. Forces a UI render
# by invoking an empty action at Background priority so the bar visibly updates during long loops.
function Set-GuiProgress { param([double]$Value, [string]$Status)
    $progressBar.Value = $Value
    if ($Status) { Write-GuiLog $Status "STEP" }
    $Window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Resets the log RichTextBox to a fresh, empty FlowDocument (clears all previous log lines).
function Clear-GuiLog {
    $doc = New-Object System.Windows.Documents.FlowDocument
    $txtLog.Document = $doc
}

if ($btnLogCopy) {
    $btnLogCopy.Add_Click({
        try {
            $range = New-Object System.Windows.Documents.TextRange($txtLog.Document.ContentStart, $txtLog.Document.ContentEnd)
            [System.Windows.Clipboard]::SetText($range.Text)
            Write-GuiLog "Log copied to clipboard" "OK"
        } catch { Write-GuiLog "Failed to copy log: $_" "ERR" }
    })
}

if ($btnLogClear) {
    $btnLogClear.Add_Click({ Clear-GuiLog })
}

# Shows/hides the small "applied" status dot next to a sidebar nav item named "status<Name>",
# used to indicate that a given page's tweaks are currently active.
function Set-NavStatus { param([string]$Name, [bool]$Applied)
    $indicator = $Window.FindName("status$Name")
    if ($indicator) { $indicator.Visibility = if ($Applied) { 'Visible' } else { 'Collapsed' } }
}

# Highlights the currently active sidebar nav button by swapping its style to NavButtonActiveStyle
# (and resets all others to NavButtonStyle), based on matching $btn.Tag to $activeTag.
function Update-GuiNavActive { param([string]$activeTag)
    foreach ($n in $navNames) {
        $btn = $navButtons[$n]
        if ($btn) {
            $activeStyle = $Window.FindResource("NavButtonActiveStyle"); $normalStyle = $Window.FindResource("NavButtonStyle")
            if ($activeStyle -and $normalStyle) { $btn.Style = if ($btn.Tag -eq $activeTag) { $activeStyle } else { $normalStyle } }
        }
    }
}

# Wipes the main content panel ($pnlContent) before rendering a new page, and resets the
# Home page gauge references so stale gauge objects aren't updated by the metrics timer.
function Clear-GuiContent {
    $pnlContent.Children.Clear()
    $Script:HomeCpuGauge = $null
    $Script:HomeRamGauge = $null
    $Script:HomeGpuGauges = @()
}

$Script:MetricsBusy = $false
$Script:MetricsRunspace = $null
$Script:MetricsPS = $null
$Script:MetricsAsync = $null

# Kicks off an async CPU/RAM/GPU usage sample on a background runspace (created lazily and reused)
# so the metrics collection (CIM queries, performance counters) never blocks the UI thread.
# Sets $Script:MetricsBusy so overlapping fetches are skipped until the current one completes.
function Start-GuiMetricsFetch {
    if ($Script:MetricsBusy) { return }
    if (-not $Script:MetricsRunspace) {
        $Script:MetricsRunspace = [runspacefactory]::CreateRunspace()
        $Script:MetricsRunspace.ApartmentState = 'MTA'
        $Script:MetricsRunspace.Open()
    }
    $Script:MetricsBusy = $true
    $ps = [powershell]::Create()
    $ps.Runspace = $Script:MetricsRunspace
    [void]$ps.AddScript({
        $result = [ordered]@{ Cpu = $null; RamPct = $null; GpuPcts = @() }
        try {
            $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $result.Cpu = $cpuLoad
        } catch {}
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $result.RamPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 0)
        } catch {}
        try {
            # Group by LUID so each physical GPU gets its own aggregated 3D engine usage.
            $gpuSamples = (Get-Counter '\GPU Engine(*engtype_3D)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples
            if ($gpuSamples) {
                $groups = $gpuSamples | Group-Object {
                    if ($_.InstanceName -match 'luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)') { $Matches[1] } else { 'unknown' }
                } | Sort-Object Name
                $result.GpuPcts = @($groups | ForEach-Object {
                    [math]::Min(100, [math]::Round(($_.Group | Measure-Object -Property CookedValue -Sum).Sum, 0))
                })
            }
        } catch {}

        [pscustomobject]$result
    })
    $Script:MetricsPS = $ps
    $Script:MetricsAsync = $ps.BeginInvoke()
}

# Called on each tick of the Home page's live-metrics timer. Starts a new background fetch if none
# is running, or - once the pending fetch completes - reads the result and pushes CPU/RAM/GPU values
# into the Home page gauges. No-op if the Home gauges aren't currently on screen.
function Update-GuiLiveMetrics {
    if (-not $Script:HomeCpuGauge -or -not $Script:HomeRamGauge) { return }
    if (-not $Script:MetricsBusy) { Start-GuiMetricsFetch; return }
    if ($Script:MetricsAsync -and $Script:MetricsAsync.IsCompleted) {
        try {
            $data = $Script:MetricsPS.EndInvoke($Script:MetricsAsync)
            if ($data -and $null -ne $data.Cpu) {
                Set-GuiMetricBarValue -MetricBar $Script:HomeCpuGauge -Value $data.Cpu
            }
            if ($data -and $null -ne $data.RamPct) {
                Set-GuiMetricBarValue -MetricBar $Script:HomeRamGauge -Value $data.RamPct
            }
            if ($data -and $Script:HomeGpuGauges) {
                for ($gi = 0; $gi -lt $Script:HomeGpuGauges.Count; $gi++) {
                    $gpuVal = if ($data.GpuPcts -and $gi -lt $data.GpuPcts.Count) { $data.GpuPcts[$gi] } else { 0 }
                    Set-GuiMetricBarValue -MetricBar $Script:HomeGpuGauges[$gi] -Value $gpuVal
                }
            }
        } catch {
        } finally {
            $Script:MetricsPS.Dispose()
            $Script:MetricsPS = $null
            $Script:MetricsAsync = $null
            $Script:MetricsBusy = $false
        }
    }
}

# Disposes the metrics PowerShell instance/runspace used by Start-GuiMetricsFetch. Called on
# window close so the background runspace doesn't keep the process alive.
function Stop-GuiMetricsRunspace {
    try { if ($Script:MetricsPS) { $Script:MetricsPS.Dispose() } } catch {}
    try { if ($Script:MetricsRunspace) { $Script:MetricsRunspace.Close(); $Script:MetricsRunspace.Dispose() } } catch {}
}

# Builds a standard content "card" (bordered box with icon/title/description on the left and
# optional action buttons on the right) and appends it to $TargetPanel (defaults to $pnlContent).
# Used by virtually every page to lay out a single setting/action group.
# -WrapButtons: buttons wrap onto their own line (left-aligned) when the card gets too narrow,
# instead of clipping the title; handled via a SizeChanged handler that re-measures and re-docks
# the title/button panels into either one row (side-by-side) or two rows (stacked).
function Add-GuiCard {
    param([string]$Title, [string]$Description, [scriptblock]$Content= $null, [string]$Icon = "&#xE90F;", [string]$AccentColor = "#F0883E", [switch]$WrapButtons, $TargetPanel = $null)
    if (-not $TargetPanel) { $TargetPanel = $pnlContent }
    $card = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("CardStyle"); if ($cardStyle) { $card.Style = $cardStyle }
    $card.Padding = "12"
    $row = New-Object System.Windows.Controls.Grid
    $colTitle = New-Object System.Windows.Controls.ColumnDefinition; $colTitle.Width = "1*"
    $colBtn = New-Object System.Windows.Controls.ColumnDefinition; $colBtn.Width = "Auto"
    $row.ColumnDefinitions.Add($colTitle)
    $row.ColumnDefinitions.Add($colBtn)
    $titlePanel = New-Object System.Windows.Controls.StackPanel
    $titlePanel.VerticalAlignment = "Center"
    Add-GuiIconTitle $titlePanel $Icon $Title $AccentColor $Description
    [System.Windows.Controls.Grid]::SetColumn($titlePanel, 0)
    $row.AddChild($titlePanel)
    $btnPanel = $null
    if ($Content) {
        if ($WrapButtons) {
            $btnPanel = New-Object System.Windows.Controls.WrapPanel
            $btnPanel.Orientation = "Horizontal"
            $btnPanel.HorizontalAlignment = "Right"
        } else {
            $btnPanel = New-Object System.Windows.Controls.StackPanel
            $btnPanel.Orientation = "Horizontal"
        }
        $btnPanel.VerticalAlignment = "Center"
        $btnPanel.Margin = "12,0,0,0"
        & $Content $btnPanel
        [System.Windows.Controls.Grid]::SetColumn($btnPanel, 1)
        $row.AddChild($btnPanel)
    }
    $card.Child = $row
    $TargetPanel.AddChild($card)

    if ($WrapButtons -and $btnPanel) {
        # Same-line layout (title left, buttons right) while there is room; once the
        # combined natural width no longer fits, buttons drop to their own line below,
        # left-aligned, so the title is never clipped.
        $rowAuto1 = New-Object System.Windows.Controls.RowDefinition; $rowAuto1.Height = "Auto"
        $rowAuto2 = New-Object System.Windows.Controls.RowDefinition; $rowAuto2.Height = "Auto"
        $row.RowDefinitions.Add($rowAuto1)
        $row.RowDefinitions.Add($rowAuto2)
        # Mutable state must live on a reference object: a scriptblock bound to a .NET
        # event (Add_SizeChanged) does not persist plain local variable writes across calls.
        $wrapState = [pscustomobject]@{ NeededWidth = 0.0; IsStacked = $false }
        $handler = {
            param($s, $e)
            if ($wrapState.NeededWidth -eq 0.0) {
                $infSize = New-Object System.Windows.Size ([double]::PositiveInfinity), ([double]::PositiveInfinity)
                $titlePanel.Measure($infSize)
                $btnPanel.Measure($infSize)
                $wrapState.NeededWidth = $titlePanel.DesiredSize.Width + $btnPanel.DesiredSize.Width + 12
            }
            $shouldStack = ($s.ActualWidth -gt 0) -and ($s.ActualWidth -lt $wrapState.NeededWidth)
            if ($shouldStack -ne $wrapState.IsStacked) {
                $wrapState.IsStacked = $shouldStack
                if ($shouldStack) {
                    [System.Windows.Controls.Grid]::SetRow($titlePanel, 0); [System.Windows.Controls.Grid]::SetColumn($titlePanel, 0); [System.Windows.Controls.Grid]::SetColumnSpan($titlePanel, 2)
                    [System.Windows.Controls.Grid]::SetRow($btnPanel, 1); [System.Windows.Controls.Grid]::SetColumn($btnPanel, 0); [System.Windows.Controls.Grid]::SetColumnSpan($btnPanel, 2)
                    $btnPanel.HorizontalAlignment = "Left"
                    $btnPanel.Margin = "0,8,0,0"
                } else {
                    [System.Windows.Controls.Grid]::SetRow($titlePanel, 0); [System.Windows.Controls.Grid]::SetColumn($titlePanel, 0); [System.Windows.Controls.Grid]::SetColumnSpan($titlePanel, 1)
                    [System.Windows.Controls.Grid]::SetRow($btnPanel, 0); [System.Windows.Controls.Grid]::SetColumn($btnPanel, 1); [System.Windows.Controls.Grid]::SetColumnSpan($btnPanel, 1)
                    $btnPanel.HorizontalAlignment = "Right"
                    $btnPanel.Margin = "12,0,0,0"
                }
            }
        }.GetNewClosure()
        $row.Add_SizeChanged($handler)
    }
    return $card
}

# Renders an icon + title row (used as a card header) into $Panel, optionally followed by a
# small "i" info glyph with a tooltip explaining the setting in more detail.
function Add-GuiIconTitle {
    param($Panel, [string]$Glyph, [string]$Text, [string]$AccentColor = "#8B949E", [string]$Tooltip = "")
    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"
    $row.Margin = "0,0,0,4"
    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.Text = [regex]::Replace($Glyph, '&#x([0-9A-Fa-f]+);', { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
    $icon.FontFamily = "Segoe MDL2 Assets"
    $icon.FontSize = 14
    $icon.Foreground = $AccentColor
    $icon.Margin = "0,0,8,0"
    $icon.VerticalAlignment = "Center"
    $row.AddChild($icon)
    $title = New-Object System.Windows.Controls.TextBlock
    $titleStyle = $Window.FindResource("CardTitleStyle"); if ($titleStyle) { $title.Style = $titleStyle }
    $title.Margin = "0"
    $title.Text = $Text
    $title.VerticalAlignment = "Center"
    $row.AddChild($title)
    if ($Tooltip) {
        $infoIcon = New-Object System.Windows.Controls.TextBlock
        $infoIcon.Text = [char]0xE946
        $infoIcon.FontFamily = "Segoe MDL2 Assets"
        $infoIcon.FontSize = 13
        $infoIcon.Foreground = "#6E7681"
        $infoIcon.Margin = "8,0,0,0"
        $infoIcon.VerticalAlignment = "Center"
        $infoIcon.Cursor = "Help"
        $infoIcon.ToolTip = $Tooltip
        $row.AddChild($infoIcon)
    }
    $Panel.AddChild($row)
}

# Adds the big page title text block at the top of $pnlContent for the current page.
function Add-GuiPageTitle { param([string]$Title)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Style = $Window.FindResource("PageTitleStyle")
    $t.Text = $Title
    $pnlContent.AddChild($t)
}

# Creates a styled button inside $Panel that, on click, clears the log, resets the progress bar,
# then invokes $Handler (the actual apply/revert/etc. action scriptblock for that button).
function Add-GuiBtn {
    param($Panel, [string]$Text, [string]$Style, $Handler)
    $btn = New-Object System.Windows.Controls.Button
    $styleObj = $Window.FindResource($Style); if ($styleObj) { $btn.Style = $styleObj }
    $btn.MinWidth = 100
    $btn.Margin = "0,2,5,2"
    $btn.Content = $Text
    $btn.Add_Click({ Clear-GuiLog; Set-GuiProgress 0; & $Handler }.GetNewClosure())
    $Panel.AddChild($btn)
}

#endregion

#region HELPER: REGISTRY APPLY
# Generic helper to apply a batch of registry settings: iterates $Settings (each with Path/Name/
# Type/Value), creating missing keys as needed, updates the progress bar per item, and logs a
# summary of how many succeeded/failed. Used by most Invoke-*Apply functions in Core/Actions.ps1.
function Invoke-RegistryApply {
    param([array]$Settings, [string]$Label)
    $total = $Settings.Count
    $applied = 0; $failed = 0
    for ($i = 0; $i -lt $total; $i++) {
        $s = $Settings[$i]
        Set-GuiProgress ([math]::Round(($i+1)/$total*100)) "$Label : $($i+1)/$total"
        try {
            if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            New-ItemProperty -Path $s.Path -Name $s.Name -PropertyType $s.Type -Value $s.Value -Force -ErrorAction SilentlyContinue | Out-Null
            $applied++
        } catch { $failed++ }
    }
    Set-GuiProgress 0
    Write-GuiLog "$Label : $applied applied, $failed failed" "OK"
    return @{Applied=$applied; Failed=$failed}
}
#endregion

