
# ================================================
#region CLEAN TAB - CHECKLIST RENDERER
# ================================================
# Shared "scan results" checklist used by all 4 Clean sub-sections (System Cleaner,
# Registry Cleaner, Startup Manager, Network Cleanup). Mirrors Kudu's scan-then-select
# -then-apply UX (scanned items rendered as selectable rows with label + detail text).
# Each item object must expose: Label, Detail, Selected (bool). A row (Border+CheckBox) is
# created per item and bound back onto the SAME object instance via a closure, so toggling
# the checkbox mutates $item.Selected directly - no separate "read back" pass is needed.

# Colors for the checklist rows come from the active theme's resources (Brush_*), so switching
# to Terminal Retro repaints them too. No hardcoded hex values here on purpose.

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
    $box.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_LogBg")
    $box.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
    $box.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
    $box.BorderThickness = "1"
    $box.Padding = "8"
    $box.Margin = "0,-6,0,16"
    $box.Child = $InnerPanel
    return $box
}

# Applies the visual state (background/border) of a checklist row based on checked/hover state.
function script:Update-CleanRowVisual {
    param($Row, [bool]$Checked, [bool]$Hover)
    if ($Checked) {
        $Row.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_AccentMuted")
        $Row.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_Accent")
    } elseif ($Hover) {
        $Row.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_HoverBg")
        $Row.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_Border")
    } else {
        $Row.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
        $Row.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
    }
}

# True when $Items is non-empty and every item is selected. Drives the "Select All" button
# label and the select/unselect direction on click.
function Test-CleanAllSelected {
    param([array]$Items)
    if (-not $Items) { return $false }
    return (@($Items | Where-Object { -not $_.Selected }).Count -eq 0)
}

# Flips the label of the "Select All"/"Unselect All" button (stored on $Panel.Tag) to match the
# current rows. No-op on panels that have no such button (e.g. Startup page toggle lists).
function script:Update-CleanSelectAllLabel {
    param($Panel)
    if (-not $Panel -or $Panel.Tag -isnot [System.Windows.Controls.Button]) { return }
    $items = @($Panel.Children | Where-Object { $_ -is [System.Windows.Controls.Border] -and $_.Tag -and $_.Tag.Item } | ForEach-Object { $_.Tag.Item })
    $Panel.Tag.Content = if (Test-CleanAllSelected $items) { "Unselect All" } else { "Select All" }
}

# Adds a "Select All" / "Unselect All" toggle to a card's button row. $ListPanel is the
# checklist StackPanel rendered by Set-CleanChecklist; $GetItems is re-invoked on every click, so
# a rescan (which replaces the item array) is always picked up. The button is stashed on
# $ListPanel.Tag so Set-CleanChecklist can reset its label after rendering a fresh list.
function Add-CleanSelectAllBtn {
    param($BtnPanel, $ListPanel, [string]$Style = "ActionButtonStyle", $GetItems)
    $btn = New-Object System.Windows.Controls.Button
    $styleObj = $Window.FindResource($Style); if ($styleObj) { $btn.Style = $styleObj }
    $btn.MinWidth = 100
    $btn.Margin = "0,2,5,2"
    $btn.Content = "Select All"
    $btn.Add_Click({
        $items = @(& $GetItems)
        if ($items.Count -eq 0) { return }
        $select = -not (Test-CleanAllSelected $items)
        foreach ($it in $items) { $it.Selected = $select }
        foreach ($row in $ListPanel.Children) {
            if ($row -is [System.Windows.Controls.Border] -and $row.Tag -and $row.Tag.Item) {
                if ($row.Tag.CheckBox) { $row.Tag.CheckBox.IsChecked = $select }
                Update-CleanRowVisual -Row $row -Checked $select -Hover $row.Tag.Hover
            }
        }
        Update-CleanSelectAllLabel $ListPanel
    }.GetNewClosure())
    $BtnPanel.AddChild($btn)
    $ListPanel.Tag = $btn
    return $btn
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
    if ($Panel.Tag -is [System.Windows.Controls.Button]) { $Panel.Tag.Content = "Select All" }
    if (-not $Items -or $Items.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $EmptyText
        $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
        $t.FontSize = 12
        $t.Margin = "6,8,6,8"
        $t.HorizontalAlignment = "Center"
        $Panel.AddChild($t)
        return
    }
    foreach ($item in $Items) {
        $row = New-Object System.Windows.Controls.Border
        $row.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
        $row.BorderThickness = "1"
        $row.Padding = "10,8,10,8"
        $row.Margin = "0,0,0,4"
        $row.Cursor = "Hand"
        $row.Tag = [pscustomobject]@{ Item = $item; Hover = $false; CheckBox = $null }
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
        $cb.SetResourceReference([System.Windows.Controls.CheckBox]::ForegroundProperty, "Brush_TextPrimary")
        $cb.SetResourceReference([System.Windows.Controls.CheckBox]::FontFamilyProperty, "Theme_FontFamily")
        [System.Windows.Controls.Grid]::SetColumn($cb, 0)
        $topGrid.AddChild($cb)
        $row.Tag.CheckBox = $cb

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $item.Label
        $lbl.FontWeight = "SemiBold"
        $lbl.FontSize = 13
        $lbl.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $lbl.TextWrapping = "Wrap"
        $lbl.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($lbl, 1)
        $topGrid.AddChild($lbl)

        if ($Mode -eq "size" -and $item.SizeText) {
            $size = New-Object System.Windows.Controls.TextBlock
            $size.Text = $item.SizeText
            $size.FontFamily = "JetBrains Mono, Consolas"
            $size.FontSize = 12
            $size.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_Accent")
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
            $toggleBtn.SetResourceReference([System.Windows.Controls.Button]::BackgroundProperty, "Brush_HoverBg")
            $toggleBtn.SetResourceReference([System.Windows.Controls.Button]::ForegroundProperty, "Brush_TextPrimary")
            $toggleBtn.SetResourceReference([System.Windows.Controls.Button]::BorderBrushProperty, "Brush_Border")
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
                    Update-CleanSelectAllLabel $Panel
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
            $det.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
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
            Update-CleanSelectAllLabel $Panel
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

# Builds a compact inline search box (icon + TextBox in a bordered pill) meant to be dropped
# into a card's button row (the $p WrapPanel passed into Add-GuiCard's -Content scriptblock),
# next to its Scan/Delete buttons. Returns the outer Border; the TextBox itself is stashed on
# Border.Tag so the caller can read .Text / wire Add_TextChanged without a second lookup.
function New-CleanSearchBox {
    param([string]$Placeholder = "Search...")
    $border = New-Object System.Windows.Controls.Border
    $border.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
    $border.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
    $border.BorderThickness = "1"
    $border.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
    $border.Padding = "8,4,8,4"
    $border.Width = 170
    $border.Margin = "0,0,8,0"
    $border.VerticalAlignment = "Center"
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Orientation = "Horizontal"
    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.Text = [char]0xE721
    $icon.FontFamily = "Segoe MDL2 Assets"
    $icon.FontSize = 12
    $icon.VerticalAlignment = "Center"
    $icon.Margin = "0,0,6,0"
    $icon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
    $stack.AddChild($icon)
    $box = New-Object System.Windows.Controls.TextBox
    $box.Width = 120
    $box.Background = "Transparent"
    $box.BorderThickness = "0"
    $box.ToolTip = $Placeholder
    $box.SetResourceReference([System.Windows.Controls.TextBox]::ForegroundProperty, "Brush_TextPrimary")
    $box.SetResourceReference([System.Windows.Controls.TextBox]::CaretBrushProperty, "Brush_Accent")
    $box.SetResourceReference([System.Windows.Controls.TextBox]::FontFamilyProperty, "Theme_FontFamily")
    $stack.AddChild($box)
    $border.Child = $stack
    $border.Tag = $box
    return $border
}

# Shows/hides rows already rendered by Set-CleanChecklist in $Panel, based on whether the
# item's Label or Detail contains $Text (case-insensitive). Does not touch $Items/Selected -
# purely a visual filter, so toggling a hidden row's checkbox state is unaffected if it's
# revealed again later.
function Set-CleanFilter {
    param($Panel, [string]$Text)
    if (-not $Panel) { return }
    $f = $Text.Trim().ToLowerInvariant()
    foreach ($row in $Panel.Children) {
        if ($row -is [System.Windows.Controls.Border] -and $row.Tag -and $row.Tag.Item) {
            $it = $row.Tag.Item
            $hay = ("$($it.Label) $($it.Detail)").ToLowerInvariant()
            $row.Visibility = if ($f -eq "" -or $hay.Contains($f)) { "Visible" } else { "Collapsed" }
        }
    }
}

# Re-runs a Clean page scan in the background and re-renders $Panel when it finishes, so an apply
# (Clean Selected / Fix Selected / Delete Selected) never leaves stale rows on screen and the
# window does not freeze while sizes are measured again. $Assign receives the fresh array and
# stores it in the page's $Script: variable (kept explicit so no page list can silently go stale).
function Update-CleanChecklist {
    param($Panel, [scriptblock]$Scan, [scriptblock]$Assign, [string[]]$Functions,
          [string]$EmptyText = "Nothing found.", [string]$Mode = "plain", $OnToggle = $null)
    $done = {
        param($items)
        $fresh = @($items)
        & $Assign $fresh
        Set-GuiProgress 90
        Set-CleanChecklist $Panel $fresh $EmptyText $Mode $OnToggle
        Set-GuiProgress 0
        Write-GuiLog "List refreshed" "OK"
    }.GetNewClosure()
    Set-GuiProgress 10 "Refreshing list..."
    Start-GuiBackgroundJob -Work $Scan -Functions $Functions -OnDone $done -Name "Refresh" | Out-Null
}

# Returns only the items in $Items whose Selected flag is currently true.
# NOTE: like every other collection-returning function here, an empty result comes back as
# $null (PowerShell unrolls the empty array). Callers must normalize with @(...) before
# touching .Count - $null.Count throws "The property 'Count' cannot be found on this object"
# under Set-StrictMode.
function Get-CleanSelected {
    param([array]$Items)
    if (-not $Items) { return @() }
    return @($Items | Where-Object { $_.Selected })
}
#endregion
