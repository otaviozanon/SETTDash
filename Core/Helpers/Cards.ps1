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

# Renders an icon + title row (used as a card header) into $Panel, optionally followed by a
# small "i" info glyph with a tooltip explaining the setting in more detail.
function Add-GuiIconTitle {
    param($Panel, [string]$Glyph, [string]$Text, [string]$AccentColor = "#8B949E", [string]$Tooltip = "", $ChevronBox = $null)
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
    $btn.Add_Click({ Clear-GuiLog; Set-GuiProgress 0; & $Handler }.GetNewClosure())
    $Panel.AddChild($btn)
}
