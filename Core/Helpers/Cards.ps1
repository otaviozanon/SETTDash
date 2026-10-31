# Builds a standard content "card" (bordered box with icon/title/description on the left and
# optional action buttons on the right) and appends it to $TargetPanel (defaults to $pnlContent).
# Used by virtually every page to lay out a single setting/action group.
# -WrapButtons: buttons wrap onto their own line (left-aligned) when the card gets too narrow,
# instead of clipping the title; handled via a SizeChanged handler that re-measures and re-docks
# the title/button panels into either one row (side-by-side) or two rows (stacked).
function Add-GuiCard {
    param([string]$Title, [string]$Description, [scriptblock]$Content= $null, [string]$Icon = "&#xE90F;", [string]$AccentColor = "#F0883E", [switch]$WrapButtons, $TargetPanel = $null, $CollapseTarget = $null)
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
    $chevronBox = $null
    if ($CollapseTarget) { $chevronBox = @{} }
    Add-GuiIconTitle $titlePanel $Icon $Title $AccentColor $Description $chevronBox
    [System.Windows.Controls.Grid]::SetColumn($titlePanel, 0)
    $row.AddChild($titlePanel)

    if ($CollapseTarget -and $chevronBox -and $chevronBox.Chevron) {
        $chevron = $chevronBox.Chevron
        $titlePanel.Cursor = "Hand"
        # Starts collapsed (list hidden) until the user clicks the card title/chevron,
        # or an action (e.g. Scan) explicitly expands it via Expand-GuiCard.
        # State lives on titlePanel.Tag (no free variables): event handlers execute later
        # under Set-StrictMode without access to function locals, so relying on
        # .GetNewClosure() snapshots for the target/chevron/state is fragile.
        $collapseState = [pscustomobject]@{ Collapsed = $true; Chevron = $chevron; Target = $CollapseTarget }
        $CollapseTarget.Visibility = "Collapsed"
        $chevron.Text = [char]0xE76C
        $CollapseTarget.Tag = $collapseState
        $titlePanel.Tag = $collapseState
        $collapseHandler = {
            param($s, $e)
            $state = $s.Tag
            $state.Collapsed = -not $state.Collapsed
            if ($state.Collapsed) {
                $state.Target.Visibility = "Collapsed"
                $state.Chevron.Text = [char]0xE76C
            } else {
                $state.Target.Visibility = "Visible"
                $state.Chevron.Text = [char]0xE70D
            }
        }
        $titlePanel.Add_MouseLeftButtonUp($collapseHandler)
    }
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
        # Mutable state + element refs live on $row.Tag: event handlers execute later
        # under Set-StrictMode without access to function locals, so bindings for
        # $titlePanel/$btnPanel/$wrapState cannot rely on a GetNewClosure() snapshot.
        $row.Tag = [pscustomobject]@{ Title = $titlePanel; Btns = $btnPanel; NeededWidth = 0.0; IsStacked = $false }
        $handler = {
            param($s, $e)
            $wrapState = $s.Tag
            if ($wrapState.NeededWidth -eq 0.0) {
                $infSize = New-Object System.Windows.Size ([double]::PositiveInfinity), ([double]::PositiveInfinity)
                $wrapState.Title.Measure($infSize)
                $wrapState.Btns.Measure($infSize)
                $wrapState.NeededWidth = $wrapState.Title.DesiredSize.Width + $wrapState.Btns.DesiredSize.Width + 12
            }
            $shouldStack = ($s.ActualWidth -gt 0) -and ($s.ActualWidth -lt $wrapState.NeededWidth)
            if ($shouldStack -ne $wrapState.IsStacked) {
                $wrapState.IsStacked = $shouldStack
                $titlePanel = $wrapState.Title
                $btnPanel = $wrapState.Btns
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
        }
        $row.Add_SizeChanged($handler)
    }
    return $card
}

# Forces an already-collapsed card list (built with -CollapseTarget) open — used by Scan
# buttons so results are visible immediately instead of requiring a manual chevron click.
function Expand-GuiCard {
    param($CollapseTarget)
    if (-not $CollapseTarget -or -not $CollapseTarget.Tag) { return }
    $state = $CollapseTarget.Tag
    if ($state.Collapsed) {
        $state.Collapsed = $false
        $CollapseTarget.Visibility = "Visible"
        if ($state.Chevron) { $state.Chevron.Text = [char]0xE70D }
    }
}

# Builds a standard "card" with a pill toggle switch instead of action buttons (Settings page:
# Auto-Start, Minimize to Tray). Layout: icon/title row + description, toggle switch docked to the
# right, and a status line below ("Active: ..." / "Inactive: ...") that updates immediately on click.
# $GetState: scriptblock returning the current bool state (re-evaluated on load, e.g. registry read).
# $OnToggle: scriptblock invoked with the new bool state ($true/$false) when the user flips it.
function Add-GuiToggleCard {
    param([string]$Title, [string]$Description, [scriptblock]$GetState, [scriptblock]$OnToggle,
          [string]$OnStatus, [string]$OffStatus, [string]$Icon = "&#xE90F;", [string]$AccentColor = "#F0883E", $TargetPanel = $null)
    if (-not $TargetPanel) { $TargetPanel = $pnlContent }
    $card = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("InfoCardStyle"); if ($cardStyle) { $card.Style = $cardStyle }
    $card.Padding = "12"
    $card.Margin = "0,0,0,10"

    $outer = New-Object System.Windows.Controls.StackPanel

    $row = New-Object System.Windows.Controls.Grid
    $colTitle = New-Object System.Windows.Controls.ColumnDefinition; $colTitle.Width = "1*"
    $colToggle = New-Object System.Windows.Controls.ColumnDefinition; $colToggle.Width = "Auto"
    $row.ColumnDefinitions.Add($colTitle)
    $row.ColumnDefinitions.Add($colToggle)

    $titlePanel = New-Object System.Windows.Controls.StackPanel
    $titlePanel.VerticalAlignment = "Center"
    Add-GuiIconTitle $titlePanel $Icon $Title $AccentColor
    [System.Windows.Controls.Grid]::SetColumn($titlePanel, 0)
    $row.AddChild($titlePanel)

    $toggle = New-Object System.Windows.Controls.Primitives.ToggleButton
    $toggleStyle = $Window.FindResource("ToggleSwitchStyle"); if ($toggleStyle) { $toggle.Style = $toggleStyle }
    $toggle.VerticalAlignment = "Center"
    $toggle.Margin = "12,0,0,0"
    $toggle.IsChecked = [bool](& $GetState)
    [System.Windows.Controls.Grid]::SetColumn($toggle, 1)
    $row.AddChild($toggle)
    $outer.AddChild($row)

    $desc = New-Object System.Windows.Controls.TextBlock
    $descStyle = $Window.FindResource("CardDescStyle"); if ($descStyle) { $desc.Style = $descStyle }
    $desc.Text = $Description
    $desc.Margin = "0,6,0,6"
    $outer.AddChild($desc)

    $status = New-Object System.Windows.Controls.TextBlock
    $status.FontSize = 11
    $status.FontStyle = "Italic"
    $status.TextWrapping = "Wrap"
    $outer.AddChild($status)

    $updateStatus = {
        param($s, $isOn)
        $s.Text = if ($isOn) { "Active: $OnStatus" } else { "Inactive: $OffStatus" }
        $s.Foreground = if ($isOn) { "#3FB950" } else { "#8B949E" }
    }.GetNewClosure()
    & $updateStatus $status ([bool]$toggle.IsChecked)

    $toggle.Add_Click({
        $isOn = [bool]$toggle.IsChecked
        Clear-GuiLog; Set-GuiProgress 0
        & $OnToggle $isOn
        & $updateStatus $status $isOn
    }.GetNewClosure())

    $card.Child = $outer
    $TargetPanel.AddChild($card)
    return $card
}

# Lays out a row of side-by-side columns (e.g. two cards sharing a line instead of stacking full
# width) and appends it to $TargetPanel. $Weights controls each column's relative width (star
# sizing), so e.g. @(2,1) gives a wide left column + narrow right column. Returns an array of
# StackPanel columns (same order as $Weights) to pass as -TargetPanel to Add-GuiCard/
# Add-GuiToggleCard - the cards' own bottom margin (from CardStyle/InfoCardStyle) keeps vertical
# spacing consistent with full-width cards.
function Add-GuiCardRow {
    param([double[]]$Weights = @(1, 1), $TargetPanel = $null)
    if (-not $TargetPanel) { $TargetPanel = $pnlContent }
    $grid = New-Object System.Windows.Controls.Grid
    for ($i = 0; $i -lt $Weights.Count; $i++) {
        if ($i -gt 0) {
            $gap = New-Object System.Windows.Controls.ColumnDefinition; $gap.Width = "14"
            $grid.ColumnDefinitions.Add($gap)
        }
        $col = New-Object System.Windows.Controls.ColumnDefinition; $col.Width = "$($Weights[$i])*"
        $grid.ColumnDefinitions.Add($col)
    }
    $columns = @()
    for ($i = 0; $i -lt $Weights.Count; $i++) {
        $panel = New-Object System.Windows.Controls.StackPanel
        [System.Windows.Controls.Grid]::SetColumn($panel, $i * 2)
        $grid.AddChild($panel)
        $columns += , $panel
    }
    $TargetPanel.AddChild($grid)
    return $columns
}

# Lays out an N-column grid of equal-size cells (same width AND height, unlike Add-GuiCardRow's
# star-sized columns which only match width) and appends it to $TargetPanel. Used when several
# cards should look like a uniform tile grid (e.g. Settings: Theme/Auto-Start/Minimize to Tray/
# Check for Updates) regardless of how much content each one has. Returns an array of StackPanel
# cells (row-major order, same count as $Columns * $Rows) to pass as -TargetPanel to
# Add-GuiCard/Add-GuiToggleCard; each cell carries its own right/bottom gap so cards never touch.
function Add-GuiCardGrid {
    param([int]$Columns = 2, [int]$Rows = 2, $TargetPanel = $null)
    if (-not $TargetPanel) { $TargetPanel = $pnlContent }
    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $grid.Columns = $Columns
    $grid.Rows = $Rows
    $cells = @()
    for ($i = 0; $i -lt ($Columns * $Rows); $i++) {
        # Grid (not StackPanel) so the card border inside stretches to fill the cell in both
        # directions - a StackPanel only stretches children horizontally, which would leave
        # shorter cards vertically smaller than the (equal-height) cell around them.
        $cell = New-Object System.Windows.Controls.Grid
        $cell.Margin = "0,0,10,10"
        $grid.AddChild($cell)
        $cells += , $cell
    }
    $TargetPanel.AddChild($grid)
    return $cells
}


# Renders an icon + title row (used as a card header) into $Panel, optionally followed by a
# small "i" info glyph with a tooltip explaining the setting in more detail.
function Add-GuiIconTitle {
    param($Panel, [string]$Glyph, [string]$Text, [string]$AccentColor = "#8B949E", [string]$Tooltip = "", $ChevronBox = $null, [switch]$AccentTitle, [string]$TitleColor = $null)
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
    # Hardware identity titles (GPU/CPU/disk name, battery name, etc. via Add-GuiInfoCard) get the
    # orange accent, same emphasis already used for IsHeader rows on the System page - action/feature
    # card titles (Add-GuiCard: "AMD", "Network Optimizer"...) keep the neutral CardTitleStyle color.
    if ($AccentTitle) { $title.Foreground = if ($TitleColor) { $TitleColor } else { $AccentColor } }
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
    if ($ChevronBox) {
        $chevron = New-Object System.Windows.Controls.TextBlock
        $chevron.Text = [char]0xE70D
        $chevron.FontFamily = "Segoe MDL2 Assets"
        $chevron.FontSize = 12
        $chevron.Foreground = "#6E7681"
        $chevron.Margin = "8,0,0,0"
        $chevron.VerticalAlignment = "Center"
        $row.AddChild($chevron)
        $ChevronBox.Chevron = $chevron
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
    $btn.Add_Click({
        Clear-GuiLog
        Set-GuiProgress 0
        try {
            & $Handler
        } catch {
            # Surfaces the full exception (message + where it happened) straight into the on-screen
            # log instead of letting it bubble up to ps2exe's generic crash MessageBox - lets errors
            # be diagnosed from the in-app log alone instead of requiring a repro/trace session.
            Write-GuiLog "Action failed: $($_.Exception.Message)" "ERR"
            if ($_.ScriptStackTrace) { Write-GuiLog $_.ScriptStackTrace "ERR" }
            Set-GuiProgress 0
        }
    }.GetNewClosure())
    $Panel.AddChild($btn)
    return $btn
}

# Renders a single read-only row into $Panel: either a Label/Value pair (two-column grid) or,
# when $Row.IsHeader is set, a compact sub-section chip (used to separate e.g. multiple disks/GPUs
# within the same detail panel). Shared by Add-GuiInfoCard and Show-GuiCategoryDetailPage.
function Add-GuiInfoRowItem {
    param($Panel, $Row, [string]$AccentColor = "#F0883E")
    # Under Set-StrictMode -Version Latest, accessing a key that is absent from a hashtable via
    # dot notation throws ("...cannot be found on this object"), so check with .Contains() first.
    $isHeader = $Row.Contains("IsHeader") -and $Row["IsHeader"]
    if ($isHeader) {
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = [string]$Row.Label
        $header.Foreground = $AccentColor
        $header.FontSize = 12
        $header.FontWeight = "SemiBold"
        $headerBorder = New-Object System.Windows.Controls.Border
        $headerBorder.Child = $header
        $headerBorder.Padding = "10,4,10,4"
        $headerBorder.Margin = "0,10,0,6"
        $headerBorder.CornerRadius = New-Object System.Windows.CornerRadius(4)
        $headerBorder.HorizontalAlignment = "Left"
        $headerBorder.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_HoverBg")
        $Panel.AddChild($headerBorder)
        return
    }
    $rowGrid = New-Object System.Windows.Controls.Grid
    $rowGrid.Margin = "0,3,0,3"
    $colLabel = New-Object System.Windows.Controls.ColumnDefinition; $colLabel.Width = "220"
    $colValue = New-Object System.Windows.Controls.ColumnDefinition; $colValue.Width = "1*"
    $rowGrid.ColumnDefinitions.Add($colLabel)
    $rowGrid.ColumnDefinitions.Add($colValue)

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = [string]$Row.Label
    $label.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    $label.FontSize = 12
    $label.TextWrapping = "Wrap"
    $label.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($label, 0)
    $rowGrid.AddChild($label)

    # Optional "ValueColor" key (e.g. the disk health Verdict row) renders the value as a bold
    # colored pill instead of plain text, to draw the eye straight to Good/Warning/Critical.
    $valueColor = if ($Row.Contains("ValueColor")) { $Row["ValueColor"] } else { $null }
    if ($valueColor) {
        $pill = New-Object System.Windows.Controls.Border
        $pill.CornerRadius = New-Object System.Windows.CornerRadius(4)
        $pill.Padding = "8,2,8,2"
        $pill.HorizontalAlignment = "Left"
        $pill.VerticalAlignment = "Center"
        $bg = [System.Windows.Media.Color]::FromArgb(38, 0, 0, 0)
        try { $base = [System.Windows.Media.ColorConverter]::ConvertFromString($valueColor); $bg = [System.Windows.Media.Color]::FromArgb(38, $base.R, $base.G, $base.B) } catch {}
        $pill.Background = New-Object System.Windows.Media.SolidColorBrush($bg)
        $value = New-Object System.Windows.Controls.TextBlock
        $value.Text = [string]$Row.Value
        $value.Foreground = $valueColor
        $value.FontSize = 12
        $value.FontWeight = "Bold"
        $value.TextWrapping = "Wrap"
        $pill.Child = $value
        [System.Windows.Controls.Grid]::SetColumn($pill, 1)
        $rowGrid.AddChild($pill)
    } else {
        $value = New-Object System.Windows.Controls.TextBlock
        $value.Text = [string]$Row.Value
        $value.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $value.FontSize = 12
        $value.TextWrapping = "Wrap"
        $value.VerticalAlignment = "Center"
        [System.Windows.Controls.Grid]::SetColumn($value, 1)
        $rowGrid.AddChild($value)
    }

    $border = New-Object System.Windows.Controls.Border
    $border.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_Divider")
    $border.BorderThickness = "0,0,0,1"
    $border.Padding = "0,0,0,8"
    $border.Child = $rowGrid
    $Panel.AddChild($border)
}

# Filters a flat $Rows list (as built by Get-CpuInfoRows/Get-GpuInfoRows/etc., a mix of
# @{IsHeader=$true; Label=...} section chips and @{Label=...; Value=...} data rows) down to only
# the data rows whose Label or Value matches $Search, keeping each matching row's section header
# so the result still reads as grouped sections instead of a flat list. Returns $Rows unchanged
# when $Search is empty. Shared by the CPU/GPU page search boxes (mirrors the Sensors page filter,
# adapted to header+rows cards instead of a flat DataGrid).
function Get-GuiFilteredInfoRows {
    param([array]$Rows, [string]$Search)
    if ([string]::IsNullOrWhiteSpace($Search)) { return $Rows }
    $result = New-Object System.Collections.Generic.List[object]
    $pendingHeader = $null
    foreach ($row in $Rows) {
        if ($row.Contains("IsHeader") -and $row["IsHeader"]) { $pendingHeader = $row; continue }
        $labelText = [string]$row.Label
        $valueText = [string]$row.Value
        if ($labelText -like "*$Search*" -or $valueText -like "*$Search*") {
            if ($pendingHeader) { $result.Add($pendingHeader) | Out-Null; $pendingHeader = $null }
            $result.Add($row) | Out-Null
        }
    }
    return $result
}

# Builds the same subtitle + search box header row used by the Sensors page (Show-PageYourPCSensors)
# and appends it to $pnlContent, returning the TextBox so callers can wire Add_TextChanged themselves.
# Reused by the CPU/GPU pages so their per-card Info/Sensors rows can be filtered by label/value too.
function Add-GuiPageSearchHeader {
    param([string]$SubtitleText, [string]$Placeholder = "Search...")
    $headerGrid = New-Object System.Windows.Controls.Grid
    $headerGrid.Margin = "0,0,0,14"
    $subTitle = New-Object System.Windows.Controls.TextBlock
    $subTitle.Text = $SubtitleText
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
    $searchBox.Tag = $Placeholder
    $searchStack.AddChild($searchBox)
    $searchBorder.Child = $searchStack
    $headerGrid.AddChild($searchBorder)
    $pnlContent.AddChild($headerGrid)
    return $searchBox
}

# Renders a read-only information card (icon/title header + a list of Label/Value rows) and
# appends it to $pnlContent. Used by the "Your PC" pages (Sensors/GPU/Disks/Energy) to
# display hardware info gathered via WMI, without any action buttons.
function Add-GuiInfoCard {
    param([string]$Title, [string]$Icon = "&#xE90F;", [string]$AccentColor = "#F0883E", [array]$Rows = @())
    $card = New-Object System.Windows.Controls.Border
    # InfoCardStyle (no hover-grow animation) - see Main/Layout.ps1 comment. These cards are
    # read-only and the hover-grow Margin animation could shift text wrapping on long rows.
    $cardStyle = $Window.FindResource("InfoCardStyle"); if ($cardStyle) { $card.Style = $cardStyle }
    $card.Padding = "12"
    $card.Margin = "0,0,0,10"

    $stack = New-Object System.Windows.Controls.StackPanel
    $titlePanel = New-Object System.Windows.Controls.StackPanel
    # Title always gets the orange "hardware identity" accent (GPU/CPU/disk/battery name).
    # $AccentColor still tints the icon glyph (e.g. a verdict color), but the verdict itself
    # is shown via the row-level ValueColor pill, not the title text.
    Add-GuiIconTitle $titlePanel $Icon $Title $AccentColor -AccentTitle -TitleColor "#F0883E"
    $stack.AddChild($titlePanel)

    foreach ($row in $Rows) { Add-GuiInfoRowItem $stack $row $AccentColor }

    $card.Child = $stack
    $pnlContent.AddChild($card)
    return $card
}

# Renders a "Test length:" label + theme-aware ComboBox letting the user pick the benchmark run
# length (e.g. 30/60/120s) before clicking "Run Benchmark" - same ComboBox used by BenchGpu.ps1's
# test length/type selectors (New-GuiThemedComboBox below). Appended to $Panel. Returns a
# PSCustomObject with a single .Seconds property that benchmark Run-click handlers read at click
# time (not a return value from this function, since the user can change the selection after the
# picker is rendered).
function Add-GuiBenchDurationPicker {
    param($Panel, [int[]]$Options = @(30, 60, 120), [int]$Default = 30)
    $state = [PSCustomObject]@{ Seconds = $Default }
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = "Test length:"
    $label.FontSize = 12
    $label.VerticalAlignment = "Center"
    $label.Margin = "0,0,8,0"
    $label.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    $Panel.AddChild($label)

    $defaultIndex = [array]::IndexOf($Options, $Default)
    if ($defaultIndex -lt 0) { $defaultIndex = 0 }
    $combo = New-GuiThemedComboBox -Width 100
    foreach ($opt in $Options) { $combo.Items.Add("${opt}s") | Out-Null }
    $combo.SelectedIndex = $defaultIndex
    $combo.Add_SelectionChanged({
        if ($combo.SelectedIndex -ge 0) { $state.Seconds = $Options[$combo.SelectedIndex] }
    }.GetNewClosure())
    $Panel.AddChild($combo)
    return $state
}

# Creates a theme-aware ComboBox using ThemedComboBoxStyle (Main/Layout.ps1), which fully replaces the
# default WPF ComboBox chrome (toggle button + popup) so it actually follows the active theme via
# DynamicResource, same as every other styled control in the app - for use as a dropdown alternative to
# the pill-button pickers above (e.g. BenchGpu.ps1's test type/length selectors). Caller still adds
# items and wires Add_SelectionChanged. Margin matches the pill pickers' row spacing.
function New-GuiThemedComboBox {
    param([int]$Width = 120)
    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.Width = $Width
    $combo.Margin = "0,0,6,0"
    $combo.VerticalAlignment = "Center"
    $combo.VerticalContentAlignment = "Center"
    $combo.Style = $Window.FindResource("ThemedComboBoxStyle")
    return $combo
}

# Renders a row of "stat tile" boxes (big number + small label underneath), e.g. Score/Min/Max/Avg -
# mirrors ResetExplode's benchmark result rows (Nota/FPS medio/1% low/etc. shown as a quick strip).
# $Tiles is an array of @{Label=...; Value=...; AccentColor=...} (AccentColor optional, falls back
# to $DefaultAccent). Appended to $Panel (typically a benchmark page's results StackPanel).
function Add-GuiBenchStatTiles {
    param($Panel, [array]$Tiles, [string]$DefaultAccent = "#F0883E")
    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid
    $grid.Rows = 1
    $grid.Columns = [math]::Max(1, $Tiles.Count)
    $grid.Margin = "0,2,0,10"
    foreach ($tile in $Tiles) {
        $box = New-Object System.Windows.Controls.Border
        $box.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
        $box.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
        $box.BorderThickness = "1"
        $box.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
        $box.Margin = "0,0,8,0"
        $box.Padding = "10,8,10,8"
        $inner = New-Object System.Windows.Controls.StackPanel
        $valueText = New-Object System.Windows.Controls.TextBlock
        $valueText.Text = [string]$tile.Value
        $valueText.FontSize = 20
        $valueText.FontWeight = "Bold"
        $valueText.HorizontalAlignment = "Center"
        # NOTE: ps2exe's compiled .exe runs with Set-StrictMode enabled (unlike running the .ps1
        # directly via powershell.exe), so a plain `$tile.AccentColor` throws "The property
        # 'AccentColor' cannot be found on this object" for any hashtable that omits the optional
        # key - ContainsKey() avoids the strict-mode property lookup entirely.
        $accent = if ($tile.ContainsKey('AccentColor') -and $tile.AccentColor) { $tile.AccentColor } else { $DefaultAccent }
        $valueText.Foreground = $accent
        $inner.AddChild($valueText)
        $labelText = New-Object System.Windows.Controls.TextBlock
        $labelText.Text = [string]$tile.Label
        $labelText.FontSize = 11
        $labelText.HorizontalAlignment = "Center"
        $labelText.Margin = "0,2,0,0"
        $labelText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
        $inner.AddChild($labelText)
        $box.Child = $inner
        $grid.AddChild($box)
    }
    $Panel.AddChild($grid)
}

# Renders a simple line chart (one Polyline across all samples) - a lightweight stand-in for
# ResetExplode's live FPS/load graphs, used by the benchmark pages to visualize per-second samples
# (e.g. iterations/s or FPS over the run) without a charting library. The Polyline is built from
# raw (index, -value) points and uses Stretch="Fill" so WPF scales/positions it to the available
# render size automatically - no manual min/max-to-pixel math needed (Y is negated so a larger
# sample value renders higher on the chart instead of lower, since WPF Y grows downward).
function Add-GuiBenchChart {
    param($Panel, [double[]]$Samples, [string]$AccentColor = "#F0883E", [double]$Height = 90, [string]$Unit = "")
    if (-not $Samples -or $Samples.Count -eq 0) { return }
    $wrap = New-Object System.Windows.Controls.Border
    $wrap.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
    $wrap.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
    $wrap.BorderThickness = "1"
    $wrap.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
    $wrap.Padding = "10,8,10,6"
    $wrap.Margin = "0,0,0,10"
    $outer = New-Object System.Windows.Controls.StackPanel
    $caption = New-Object System.Windows.Controls.TextBlock
    $caption.Text = "Samples over time" + $(if ($Unit) { " ($Unit)" } else { "" })
    $caption.FontSize = 11
    $caption.Margin = "0,0,0,6"
    $caption.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    $outer.AddChild($caption)

    $chartHost = New-Object System.Windows.Controls.Grid
    $chartHost.Height = $Height
    $line = New-Object System.Windows.Shapes.Polyline
    $line.Stroke = $AccentColor
    $line.StrokeThickness = 2
    $line.StrokeLineJoin = "Round"
    $line.HorizontalAlignment = "Stretch"
    $line.VerticalAlignment = "Stretch"
    $line.Stretch = "Fill"
    $points = New-Object System.Windows.Media.PointCollection
    if ($Samples.Count -eq 1) {
        $points.Add((New-Object System.Windows.Point(0, -$Samples[0])))
        $points.Add((New-Object System.Windows.Point(1, -$Samples[0])))
    } else {
        for ($i = 0; $i -lt $Samples.Count; $i++) { $points.Add((New-Object System.Windows.Point($i, -$Samples[$i]))) }
    }
    $line.Points = $points
    $chartHost.AddChild($line)
    $outer.AddChild($chartHost)
    $wrap.Child = $outer
    $Panel.AddChild($wrap)
}

# Creates an empty bar-chart shell (same visual as Add-GuiBenchChart) that can be grown one sample
# at a time via Add-GuiLiveChartSample while a benchmark is still running, instead of only being
# drawn once at the end from the final $result.Samples - mirrors ResetExplode's live FPS/progress
# readout during a running bench. Appended to $Panel immediately (even with zero samples) so the
# user sees the chart container as soon as the run starts. Returns a state object that both
# Add-GuiLiveChartSample and the caller can keep a reference to (e.g. to change the caption once
# the run completes).
function New-GuiLiveChart {
    param($Panel, [string]$AccentColor = "#F0883E", [double]$Height = 90, [string]$Unit = "", [string]$Title = "")
    $wrap = New-Object System.Windows.Controls.Border
    $wrap.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
    $wrap.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
    $wrap.BorderThickness = "1"
    $wrap.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
    $wrap.Padding = "10,8,10,6"
    $wrap.Margin = "0,0,0,10"
    $outer = New-Object System.Windows.Controls.StackPanel

    # Header row: caption (left, "<Title> - Running.../Samples over time (Unit)") + a compact
    # live readout (right, monospace) - just "now X" while running, swapped for "avg X" once the
    # benchmark completes (final Min/Avg/Max breakdown is already covered by the separate
    # stat-tiles strip rendered after every chart, so the gauge itself stays to a single number).
    $headerGrid = New-Object System.Windows.Controls.Grid
    $colCaption = New-Object System.Windows.Controls.ColumnDefinition; $colCaption.Width = "1*"
    $colStats = New-Object System.Windows.Controls.ColumnDefinition; $colStats.Width = "Auto"
    $headerGrid.ColumnDefinitions.Add($colCaption)
    $headerGrid.ColumnDefinitions.Add($colStats)
    $headerGrid.Margin = "0,0,0,6"

    $caption = New-Object System.Windows.Controls.TextBlock
    $caption.Text = $(if ($Title) { "$Title - " } else { "" }) + "Running..." + $(if ($Unit) { " ($Unit)" } else { "" })
    $caption.FontSize = 11
    $caption.VerticalAlignment = "Center"
    $caption.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    [System.Windows.Controls.Grid]::SetColumn($caption, 0)
    $headerGrid.AddChild($caption)

    $statsText = New-Object System.Windows.Controls.TextBlock
    $statsText.FontSize = 11
    $statsText.FontFamily = $Script:MonoFontFamily
    $statsText.VerticalAlignment = "Center"
    $statsText.Text = "now --"
    $statsText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    [System.Windows.Controls.Grid]::SetColumn($statsText, 1)
    $headerGrid.AddChild($statsText)

    $outer.AddChild($headerGrid)

    $chartHost = New-Object System.Windows.Controls.Grid
    $chartHost.Height = $Height
    # Polyline with Stretch="Fill" scales/positions itself to the render size automatically from
    # whatever raw (index, -value) points it's given - see Add-GuiBenchChart for why Y is negated.
    $line = New-Object System.Windows.Shapes.Polyline
    $line.Stroke = $AccentColor
    $line.StrokeThickness = 2
    $line.StrokeLineJoin = "Round"
    $line.HorizontalAlignment = "Stretch"
    $line.VerticalAlignment = "Stretch"
    $line.Stretch = "Fill"
    $line.Points = New-Object System.Windows.Media.PointCollection
    $chartHost.AddChild($line)
    $outer.AddChild($chartHost)
    $wrap.Child = $outer
    $Panel.AddChild($wrap)

    [PSCustomObject]@{
        Wrap        = $wrap
        Caption     = $caption
        StatsText   = $statsText
        ChartHost   = $chartHost
        Line        = $line
        AccentColor = $AccentColor
        Height      = $Height
        Unit        = $Unit
        Title       = $Title
        Samples     = [System.Collections.Generic.List[double]]::new()
    }
}

# Formats a sample value for the Min/Avg/Max/Now readout: whole numbers (e.g. iterations/s, FPS)
# print without decimals, everything else (e.g. MB/s) keeps one decimal place.
function Format-GuiChartStat {
    param([double]$Value)
    if ([math]::Abs($Value - [math]::Round($Value)) -lt 0.05) { return "{0:N0}" -f $Value }
    return "{0:N1}" -f $Value
}

# Appends $Value to a live chart created by New-GuiLiveChart and redraws the Polyline through all
# samples so far, then pumps the dispatcher at Background priority (same trick as
# Set-GuiProgress) so the new point is actually painted before the caller's synchronous benchmark
# loop continues - without this pump the chart would only flash into view once the whole loop ends.
function Add-GuiLiveChartSample {
    param($Chart, [double]$Value)
    if (-not $Chart) { return }
    $Chart.Samples.Add($Value) | Out-Null
    $points = New-Object System.Windows.Media.PointCollection
    if ($Chart.Samples.Count -eq 1) {
        $points.Add((New-Object System.Windows.Point(0, -$Value)))
        $points.Add((New-Object System.Windows.Point(1, -$Value)))
    } else {
        for ($i = 0; $i -lt $Chart.Samples.Count; $i++) { $points.Add((New-Object System.Windows.Point($i, -$Chart.Samples[$i]))) }
    }
    $Chart.Line.Points = $points
    if ($Chart.StatsText) { $Chart.StatsText.Text = "now $(Format-GuiChartStat $Value)" }
    $Window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Marks a live chart as finished - swaps the "Running..." caption for the final "Samples over
# time" label, and the "now X" readout for "avg X" (computed over all samples) once the
# benchmark completes - the per-chart gauge shows one final number, the full Min/Avg/Max
# breakdown stays in the stat-tiles strip rendered right after the chart.
function Complete-GuiLiveChart {
    param($Chart)
    if (-not $Chart) { return }
    $Chart.Caption.Text = $(if ($Chart.Title) { "$($Chart.Title) - " } else { "" }) + "Samples over time" + $(if ($Chart.Unit) { " ($($Chart.Unit))" } else { "" })
    if ($Chart.StatsText -and $Chart.Samples.Count -gt 0) {
        $avg = ($Chart.Samples | Measure-Object -Average).Average
        $Chart.StatsText.Text = "avg $(Format-GuiChartStat $avg)"
    }
}

# Renders a "category picker + single big detail card" page, matching the ResetExplode "Sistema"
# layout: a card with one button per category on top, and a single large card below showing the
# Label/Value rows for whichever category is currently selected.
# $Categories is an ordered dictionary: category name -> scriptblock that returns an array of
# row hashtables (@{Label=...;Value=...} or @{IsHeader=$true;Label=...}) when invoked.
function Show-GuiCategoryDetailPage {
    param([string]$PageTitle, [System.Collections.Specialized.OrderedDictionary]$Categories)
    Clear-GuiContent
    Add-GuiPageTitle $PageTitle

    $optCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("CardStyle"); if ($cardStyle) { $optCard.Style = $cardStyle }
    $optCard.Padding = "8"
    $optStack = New-Object System.Windows.Controls.WrapPanel
    $optStack.Orientation = "Horizontal"
    $optStack.HorizontalAlignment = "Center"
    $optCard.Child = $optStack
    $pnlContent.AddChild($optCard)

    # NOTE: no inner ScrollViewer here on purpose. $pnlContent (the whole page) already scrolls
    # via the outer ScrollViewer in Main/Layout.ps1. A nested ScrollViewer here would swallow
    # mouse-wheel events while the cursor is over this card - even when its own content fits and
    # there's nothing to scroll internally - blocking the page scroll (known WPF nested-ScrollViewer
    # behavior), so the detail card is just a plain panel and scrolls together with the rest of the page.
    $detailCard = New-Object System.Windows.Controls.Border
    if ($cardStyle) { $detailCard.Style = $cardStyle }
    $detailCard.Padding = "16"
    $detailPanel = New-Object System.Windows.Controls.StackPanel
    $detailCard.Child = $detailPanel
    $pnlContent.AddChild($detailCard)

    $buttons = @{}
    $activeStyle = $Window.FindResource("CategoryPillActiveStyle")
    $normalStyle = $Window.FindResource("CategoryPillStyle")

    $renderCategory = {
        param($name)
        foreach ($bn in $buttons.Keys) {
            $buttons[$bn].Style = if ($bn -eq $name) { $activeStyle } else { $normalStyle }
        }
        $detailPanel.Children.Clear()
        $detailTitle = New-Object System.Windows.Controls.TextBlock
        $detailTitle.Text = $name
        $detailTitle.FontSize = 18
        $detailTitle.FontWeight = "SemiBold"
        $detailTitle.Margin = "0,0,0,10"
        $detailTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $detailPanel.AddChild($detailTitle)
        $rows = & $Categories[$name]
        foreach ($row in $rows) { Add-GuiInfoRowItem $detailPanel $row }
    }.GetNewClosure()

    foreach ($name in $Categories.Keys) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $name
        $btn.Style = $normalStyle
        $btn.Add_Click({ & $renderCategory $name }.GetNewClosure())
        $buttons[$name] = $btn
        $optStack.AddChild($btn)
    }

    $exportBtn = New-Object System.Windows.Controls.Button
    $exportBtn.Content = "Export Report"
    $installStyle = $Window.FindResource("InstallButtonStyle")
    if ($installStyle) { $exportBtn.Style = $installStyle }
    $exportBtn.Margin = "16,0,0,0"
    $exportBtn.Add_Click({ Export-GuiSystemReport -Categories $Categories -PageTitle $PageTitle }.GetNewClosure())
    $optStack.AddChild($exportBtn)

    $firstName = @($Categories.Keys)[0]
    if ($firstName) { & $renderCategory $firstName }
}

# Escapes text for safe embedding inside HTML (Export-GuiSystemReport).
function script:ConvertTo-GuiHtmlSafe { param($Text) [System.Net.WebUtility]::HtmlEncode([string]$Text) }

# Exports every category's rows (as built by $Categories, the same dictionary used by
# Show-GuiCategoryDetailPage) into a single-file, theme-matched HTML report written to a temp
# file and opened directly in the default browser - no Save dialog for the HTML itself. The page
# auto-triggers the browser's print dialog on load, so the user just has to pick "Save as PDF" /
# a printer right there (no extra PDF library dependency). Skips rows whose label looks like
# sensitive/identifying data (serial numbers, MAC/PNP device IDs) - the report is meant for
# sharing specs (OS, BIOS, motherboard, CPU, GPU, RAM, storage...), not machine identity.
function Export-GuiSystemReport {
    param($Categories, [string]$PageTitle)

    $t = $Script:Themes[$Script:CurrentTheme]
    if (-not $t) { $t = $Script:Themes["Default"] }
    $fontFamily = if ($t.FontFamily -eq "MONO") { "Consolas, 'Courier New', monospace" } else { "'Segoe UI', Arial, sans-serif" }
    $radius = $t.CornerRadius

    $sensitivePattern = "Serial Number|PNP Device ID|MAC Address"
    $sectionsHtml = New-Object System.Text.StringBuilder
    foreach ($name in $Categories.Keys) {
        # Skip an "All" aggregate pill (e.g. Benchmark Export's "All" tab, which just concatenates
        # the other categories for on-screen viewing) - including it here would duplicate every
        # other section's rows in the printed report.
        if ($name -eq "All") { continue }
        [void]$sectionsHtml.Append("<section class=`"card`"><h2>$(ConvertTo-GuiHtmlSafe $name)</h2><table>")
        $rows = & $Categories[$name]
        foreach ($row in $rows) {
            $isHeader = $row.Contains("IsHeader") -and $row["IsHeader"]
            if ($isHeader) {
                [void]$sectionsHtml.Append("<tr class=`"subhead`"><td colspan=`"2`">$(ConvertTo-GuiHtmlSafe $row.Label)</td></tr>")
                continue
            }
            if ($row.Label -match $sensitivePattern) { continue }
            [void]$sectionsHtml.Append("<tr><td class=`"label`">$(ConvertTo-GuiHtmlSafe $row.Label)</td><td class=`"value`">$(ConvertTo-GuiHtmlSafe $row.Value)</td></tr>")
        }
        [void]$sectionsHtml.Append("</table></section>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SETTDash - $(ConvertTo-GuiHtmlSafe $PageTitle) Report</title>
<style>
  :root {
    --bg: $($t.WindowBg); --card-bg: $($t.CardBg); --card-border: $($t.CardBorder);
    --text: $($t.TextPrimary); --text-secondary: $($t.TextSecondary); --accent: $($t.Accent);
    --divider: $($t.Divider); --radius: $($radius)px;
  }
  * { box-sizing: border-box; }
  body { background: var(--bg); color: var(--text); font-family: $fontFamily; margin: 0; padding: 40px; }
  .report-header { display: flex; align-items: center; justify-content: space-between; border-bottom: 2px solid var(--accent); padding-bottom: 16px; margin-bottom: 28px; }
  .report-header .brand { font-size: 22px; font-weight: 700; letter-spacing: 0.5px; }
  .report-header .brand span { color: var(--accent); }
  .report-header .meta { text-align: right; color: var(--text-secondary); font-size: 12px; }
  h1 { font-size: 18px; font-weight: 600; margin: 0 0 28px 0; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 1px; }
  section.card { background: var(--card-bg); border: 1px solid var(--card-border); border-radius: var(--radius); margin-bottom: 18px; padding: 16px 20px; }
  section.card h2 { font-size: 14px; font-weight: 600; color: var(--accent); margin: 0 0 10px 0; text-transform: uppercase; letter-spacing: 0.5px; }
  table { width: 100%; border-collapse: collapse; }
  tr:not(:last-child) td { border-bottom: 1px solid var(--divider); }
  td { padding: 6px 0; font-size: 13px; vertical-align: top; }
  td.label { color: var(--text-secondary); width: 45%; padding-right: 16px; }
  td.value { color: var(--text); font-weight: 500; word-break: break-word; }
  tr.subhead td { padding-top: 14px; color: var(--accent); font-weight: 600; font-size: 12px; text-transform: uppercase; border-bottom: none; }
  .report-footer { margin-top: 24px; text-align: center; color: var(--text-secondary); font-size: 11px; opacity: 0.8; }
  /* Printed/PDF output: plain white page (saves ink, reads better on paper) with tighter
     spacing than the on-screen theme. section.card/tr are NOT marked page-break-inside:avoid -
     that was forcing an entire card (e.g. a long GPU section) to jump to the next page as soon
     as it didn't fully fit the remaining space, leaving a large blank gap below shorter cards
     (e.g. GPU ends 1/4 down the page, then RAM starts on page 2 instead of right after it).
     Only the subheads keep their row glued to the next row so a section title never ends up
     alone at the bottom of a page. */
  @media print {
    @page { margin: 10mm; }
    body { padding: 0; background: #fff; color: #000; }
    .report-header { margin-bottom: 14px; padding-bottom: 10px; }
    h1 { margin-bottom: 14px; color: #555; }
    section.card { border: 1px solid #ccc; background: #fff; margin-bottom: 10px; padding: 10px 14px; }
    section.card h2 { margin-bottom: 6px; color: #333; }
    tr:not(:last-child) td { border-bottom: 1px solid #ddd; }
    td { padding: 3px 0; font-size: 12px; }
    td.label { color: #555; }
    td.value { color: #000; }
    tr.subhead td { padding-top: 8px; color: #333; page-break-after: avoid; }
    .report-footer { margin-top: 14px; color: #777; }
  }
</style>
<script>
  // Auto-open the browser's print dialog so the user can pick "Save as PDF" right away,
  // without a separate "save the HTML" step.
  window.addEventListener("load", function () { window.print(); });
</script>
</head>
<body>
  <div class="report-header">
    <div class="brand">SETT<span>Dash</span></div>
    <div class="meta">v$($Script:AppVersion)<br>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
  </div>
  <h1>$(ConvertTo-GuiHtmlSafe $PageTitle) Report</h1>
  $($sectionsHtml.ToString())
  <div class="report-footer">Generated by SETTDash &middot; settdash.local &middot; Sensitive identifiers (serial numbers, MAC/PNP IDs) omitted.</div>
</body>
</html>
"@

    try {
        $tempPath = Join-Path $env:TEMP "SETTDash_SystemReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        [System.IO.File]::WriteAllText($tempPath, $html, [System.Text.Encoding]::UTF8)
        Write-GuiLog "System report generated, opening in browser for PDF export..." "OK"
        Start-Process $tempPath
    } catch {
        Write-GuiLog "Failed to generate report: $($_.Exception.Message)" "ERROR"
    }
}
