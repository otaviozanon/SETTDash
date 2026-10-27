
# ================================================
#region CLEAN TAB - CHECKLIST RENDERER
# ================================================
# Shared "scan results" checklist used by all 4 Clean sub-sections (System Cleaner,
# Registry Cleaner, Startup Manager, Network Cleanup). Mirrors Kudu's scan-then-select
# -then-apply UX (scanned items rendered as selectable rows with label + detail text).
# Each item object must expose: Label, Detail, Selected (bool). A row (Border+CheckBox) is
# created per item and bound back onto the SAME object instance via a closure, so toggling
# the checkbox mutates $item.Selected directly - no separate "read back" pass is needed.

# Colors shared by every checklist row (kept in sync with the project's card/list palette).
$Script:CleanRowBg         = "#11151B"
$Script:CleanRowBorder     = "#21262D"
$Script:CleanRowHoverBg    = "#161B22"
$Script:CleanRowHoverBrd   = "#30363D"
$Script:CleanRowCheckedBg  = "#0D419D"
$Script:CleanRowCheckedBrd = "#1F6FEB"

# Formats a byte count as a human-readable size (0 B, 1 KB, 2 MB, 200 MB, 2.09 GB, etc).
# Bytes/KB use no decimals; MB/GB/TB use 2 decimals (trimmed of trailing zeros where whole).
function Format-ByteSize {
    param([double]$Bytes)
    if ($Bytes -le 0) { return "Empty" }
    $units = @("B", "KB", "MB", "GB", "TB")
    $i = 0
    $val = [double]$Bytes
    while ($val -ge 1024 -and $i -lt ($units.Count - 1)) {
        $val = $val / 1024
        $i++
    }
    if ($i -eq 0) { return "{0:N0} {1}" -f $val, $units[$i] }
    $formatted = "{0:N2}" -f $val
    $formatted = $formatted.TrimEnd('0').TrimEnd('.')
    return "$formatted $($units[$i])"
}

# Wraps $InnerPanel (a StackPanel that will hold the checklist rows) in a bordered "list"
# container - a visually separated box below the card, matching the app's CardStyle look.
# Returns the outer Border so the caller can add it directly to the page content.
function New-CleanListContainer {
    param($InnerPanel)
    $box = New-Object System.Windows.Controls.Border
    $box.Background = "#0A0D12"
    $box.BorderBrush = $Script:CleanRowBorder
    $box.BorderThickness = "1"
    $box.CornerRadius = "8"
    $box.Padding = "8"
    $box.Margin = "0,-6,0,16"
    $box.Child = $InnerPanel
    return $box
}

# Applies the visual state (background/border) of a checklist row based on checked/hover state.
function script:Update-CleanRowVisual {
    param($Row, [bool]$Checked, [bool]$Hover)
    if ($Checked) {
        $Row.Background = $Script:CleanRowCheckedBg
        $Row.BorderBrush = $Script:CleanRowCheckedBrd
    } elseif ($Hover) {
        $Row.Background = $Script:CleanRowHoverBg
        $Row.BorderBrush = $Script:CleanRowHoverBrd
    } else {
        $Row.Background = $Script:CleanRowBg
        $Row.BorderBrush = $Script:CleanRowBorder
    }
}

# Clears $Panel and renders one selectable row per item in $Items (array of pscustomobject
# with Label/Detail/Selected). Row layout: top line = checkbox + Name (left) + right-side
# extra (size text in JetBrains Mono for "size" mode, Enable/Disable button for "toggle" mode);
# bottom line = Detail (path/location), indented under the name. $Mode: 'size' | 'toggle' | 'plain'.
# $OnToggle (used only in 'toggle' mode): scriptblock invoked as & $OnToggle $item -> should
# return $true/$false for the new enabled state (used to flip the button's own enabled label).
function Set-CleanChecklist {
    param($Panel, [array]$Items, [string]$EmptyText = "Nothing found.", [string]$Mode = "plain", $OnToggle = $null)
    $Panel.Children.Clear()
    if (-not $Items -or $Items.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $EmptyText
        $t.Foreground = "#6E7681"
        $t.FontSize = 12
        $t.Margin = "6,8,6,8"
        $t.HorizontalAlignment = "Center"
        $Panel.AddChild($t)
        return
    }
    foreach ($item in $Items) {
        $row = New-Object System.Windows.Controls.Border
        $row.CornerRadius = "6"
        $row.BorderThickness = "1"
        $row.Padding = "10,8,10,8"
        $row.Margin = "0,0,0,4"
        $row.Cursor = "Hand"
        $row.Tag = [pscustomobject]@{ Item = $item; Hover = $false }
        Update-CleanRowVisual -Row $row -Checked ([bool]$item.Selected) -Hover $false

        $outer = New-Object System.Windows.Controls.StackPanel

        # --- Top line: checkbox + name (left) / size-or-toggle (right) ---
        $topGrid = New-Object System.Windows.Controls.Grid
        $colCb = New-Object System.Windows.Controls.ColumnDefinition; $colCb.Width = "Auto"
        $colName = New-Object System.Windows.Controls.ColumnDefinition; $colName.Width = "1*"
        $colRight = New-Object System.Windows.Controls.ColumnDefinition; $colRight.Width = "Auto"
        $topGrid.ColumnDefinitions.Add($colCb)
        $topGrid.ColumnDefinitions.Add($colName)
        $topGrid.ColumnDefinitions.Add($colRight)

        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.IsChecked = [bool]$item.Selected
        $cb.VerticalAlignment = "Center"
        $cb.Margin = "0,0,10,0"
        $cb.IsHitTestVisible = $false
        [System.Windows.Controls.Grid]::SetColumn($cb, 0)
        $topGrid.AddChild($cb)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $item.Label
        $lbl.FontWeight = "SemiBold"
        $lbl.FontSize = 13
        $lbl.Foreground = "#E6EDF3"
        $lbl.TextWrapping = "Wrap"
        $lbl.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($lbl, 1)
        $topGrid.AddChild($lbl)

        if ($Mode -eq "size" -and $item.SizeText) {
            $size = New-Object System.Windows.Controls.TextBlock
            $size.Text = $item.SizeText
            $size.FontFamily = "JetBrains Mono, Consolas"
            $size.FontSize = 12
            $size.Foreground = "#58A6FF"
            $size.Margin = "10,0,0,0"
            $size.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($size, 2)
            $topGrid.AddChild($size)
        } elseif ($Mode -eq "toggle" -and $OnToggle) {
            $toggleBtn = New-Object System.Windows.Controls.Button
            $toggleBtn.Content = if ($item.Selected) { "Disable" } else { "Enable" }
            $toggleBtn.FontSize = 11
            $toggleBtn.Padding = "10,3,10,3"
            $toggleBtn.Margin = "10,0,0,0"
            $toggleBtn.Background = "#161B22"
            $toggleBtn.Foreground = "#C9D1D9"
            $toggleBtn.BorderBrush = "#30363D"
            $toggleBtn.BorderThickness = "1"
            $toggleBtn.Cursor = "Hand"
            $toggleBtn.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($toggleBtn, 2)
            $toggleHandler = {
                param($s, $e)
                $e.Handled = $true
                $ok = & $OnToggle $item
                if ($ok) {
                    $item.Selected = -not [bool]$item.Selected
                    $s.Content = if ($item.Selected) { "Disable" } else { "Enable" }
                    Update-CleanRowVisual -Row $row -Checked ([bool]$item.Selected) -Hover $row.Tag.Hover
                    $cb.IsChecked = [bool]$item.Selected
                }
            }.GetNewClosure()
            $toggleBtn.Add_Click($toggleHandler)
            $topGrid.AddChild($toggleBtn)
        }
        $outer.AddChild($topGrid)

        # --- Bottom line: detail/path, indented under the name ---
        if ($item.Detail) {
            $det = New-Object System.Windows.Controls.TextBlock
            $det.Text = $item.Detail
            $det.Foreground = "#8B949E"
            $det.FontSize = 11
            $det.Margin = "28,3,0,0"
            $det.TextWrapping = "Wrap"
            $outer.AddChild($det)
        }
        $row.Child = $outer

        $toggleSelect = {
            param($s, $e)
            $state = $s.Tag
            $state.Item.Selected = -not [bool]$state.Item.Selected
            $cb.IsChecked = [bool]$state.Item.Selected
            Update-CleanRowVisual -Row $s -Checked ([bool]$state.Item.Selected) -Hover $state.Hover
        }.GetNewClosure()
        $row.Add_MouseLeftButtonUp($toggleSelect)

        $row.Add_MouseEnter({
            param($s, $e)
            $s.Tag.Hover = $true
            Update-CleanRowVisual -Row $s -Checked ([bool]$s.Tag.Item.Selected) -Hover $true
        }.GetNewClosure())
        $row.Add_MouseLeave({
            param($s, $e)
            $s.Tag.Hover = $false
            Update-CleanRowVisual -Row $s -Checked ([bool]$s.Tag.Item.Selected) -Hover $false
        }.GetNewClosure())

        $Panel.AddChild($row)
    }
}

# Returns only the items in $Items whose Selected flag is currently true.
function Get-CleanSelected {
    param([array]$Items)
    if (-not $Items) { return @() }
    return @($Items | Where-Object { $_.Selected })
}
#endregion
