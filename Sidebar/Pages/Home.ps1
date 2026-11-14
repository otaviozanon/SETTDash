function Show-PageHome {
    Clear-GuiContent

    Add-GuiPageTitle (T "Dashboard")

    # System Monitor Card: gauges (left) + specifications (right)
    $info = Get-SystemInfo
    $monCard = New-Object System.Windows.Controls.Border
    $monCard.Style = $Window.FindResource("CardStyle")
    $monCard.Padding = "14"

    $monGrid = New-Object System.Windows.Controls.Grid
    $gaugeCol = New-Object System.Windows.Controls.ColumnDefinition; $gaugeCol.Width = "Auto"
    $specCol = New-Object System.Windows.Controls.ColumnDefinition; $specCol.Width = "1*"
    $monGrid.ColumnDefinitions.Add($gaugeCol)
    $monGrid.ColumnDefinitions.Add($specCol)

    # Left: circular gauges
    $gaugePanel = New-Object System.Windows.Controls.StackPanel
    $gaugePanel.Orientation = "Vertical"
    $gaugePanel.Width = 200
    $gaugePanel.Margin = "0,0,14,0"
    $gaugePanel.VerticalAlignment = "Center"

    $cpuGauge = New-GuiMetricBar -Label (T "CPU") -AccentColor "Brush_Accent"
    $ramGauge = New-GuiMetricBar -Label (T "RAM") -AccentColor "Brush_AccentGreen"
    $gaugePanel.AddChild($cpuGauge.Panel)
    $gaugePanel.AddChild($ramGauge.Panel)

    # One GPU bar per physical GPU detected (1 GPU -> 1 bar, 2 GPUs -> 2 bars, etc.)
    $gpuCount = [math]::Max(1, @($info.GPUs).Count)
    $Script:HomeGpuGauges = @()
    for ($gi = 0; $gi -lt $gpuCount; $gi++) {
        $gpuLabel = if ($gpuCount -gt 1) { "$(T 'GPU') $($gi + 1)" } else { T "GPU" }
        $gGauge = New-GuiMetricBar -Label $gpuLabel -AccentColor "Brush_AccentAmber"
        $gaugePanel.AddChild($gGauge.Panel)
        $Script:HomeGpuGauges += $gGauge
    }

    if ($Script:HomeGpuGauges.Count -gt 0) {
        $Script:HomeGpuGauges[-1].Panel.Margin = "0,0,0,0"
    } else {
        $ramGauge.Panel.Margin = "0,0,0,0"
    }
    [System.Windows.Controls.Grid]::SetColumn($gaugePanel, 0)
    $monGrid.AddChild($gaugePanel)

    $Script:HomeCpuGauge = $cpuGauge
    $Script:HomeRamGauge = $ramGauge
    Update-GuiLiveMetrics

    # Divider between gauges and specs
    $divider = New-Object System.Windows.Controls.Border
    $divider.Width = 1
    $divider.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_Divider")
    $divider.Margin = "0,2,18,2"
    $divider.HorizontalAlignment = "Left"
    [System.Windows.Controls.Grid]::SetColumn($divider, 1)
    $monGrid.AddChild($divider)

    # Right: compact specifications list with icons
    $specPanel = New-Object System.Windows.Controls.StackPanel
    $specPanel.Margin = "18,0,0,0"
    $specPanel.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($specPanel, 1)

    $gpuValue = if ($info.GPUs -and $info.GPUs.Count -gt 0) {
        ($info.GPUs | ForEach-Object { "$($_.Vendor) - $($_.Name) ($($_.VRAM) GB VRAM)" }) -join " | "
    } else {
        "$($info.GPUVendor) - $($info.GPUName) ($($info.GPUVRAM) GB VRAM)"
    }
    $specs = @(
        @{Icon="&#xE770;"; Label=(T "CPU"); Value=$info.CPUName},
        @{Icon="&#xE7F1;"; Label=(T "RAM"); Value="$($info.RAMTotalGB) $(T 'GB Total')"},
        @{Icon="&#xEDA2;"; Label=(T "HD"); Value="$($info.DiskTotalGB) $(T 'GB total') | $($info.DiskFreeGB) $(T 'GB free')"},
        @{Icon="&#xE713;"; Label=(T "OS"); Value="$($info.OSCaption)"},
        @{Icon="&#xE7F4;"; Label=(T "GPU"); Value=$gpuValue}
    )

    foreach ($spec in $specs) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = "Horizontal"
        $row.Margin = "0,0,0,8"

        $icon = New-Object System.Windows.Controls.TextBlock
        $icon.Text = [regex]::Replace($spec.Icon, '&#x([0-9A-Fa-f]+);', { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
        $icon.FontFamily = "Segoe MDL2 Assets"
        $icon.FontSize = 14
        $icon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
        $icon.Width = 20
        $icon.VerticalAlignment = "Center"
        $row.AddChild($icon)

        $textStack = New-Object System.Windows.Controls.StackPanel
        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = $spec.Label
        $label.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
        $label.FontSize = 10
        $label.FontWeight = "SemiBold"
        $textStack.AddChild($label)

        $value = New-Object System.Windows.Controls.TextBlock
        $value.Text = $spec.Value
        $value.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $value.FontFamily = $Script:MonoFontFamily
        $value.FontSize = 11
        $value.FontWeight = "SemiBold"
        $value.TextWrapping = "Wrap"
        $textStack.AddChild($value)

        $row.AddChild($textStack)
        $specPanel.AddChild($row)
    }
    $monGrid.AddChild($specPanel)

    $monCard.Child = $monGrid
    $pnlContent.AddChild($monCard)

    # Safety First | Sett Utility - Two-column layout
    $safetyGrid = New-Object System.Windows.Controls.Grid
    $safetyCol1 = New-Object System.Windows.Controls.ColumnDefinition
    $safetyCol1.Width = "1*"
    $safetyGrid.ColumnDefinitions.Add($safetyCol1)
    $safetyCol2 = New-Object System.Windows.Controls.ColumnDefinition
    $safetyCol2.Width = "1*"
    $safetyGrid.ColumnDefinitions.Add($safetyCol2)
    $safetyGrid.HorizontalAlignment = "Stretch"

    # Left - Safety First
    $safetyLeftStack = New-Object System.Windows.Controls.StackPanel
    $safetyLeftStack.Margin = "0,0,6,0"
    $safetyBorder = New-Object System.Windows.Controls.Border
    $safetyBorder.Style = $Window.FindResource("CardStyle")
    $safetyBorder.Padding = "12"
    $safetyRow = New-Object System.Windows.Controls.Grid
    $safetyRowIconCol = New-Object System.Windows.Controls.ColumnDefinition; $safetyRowIconCol.Width = "Auto"
    $safetyRowTitleCol = New-Object System.Windows.Controls.ColumnDefinition; $safetyRowTitleCol.Width = "1*"
    $safetyRowInfoCol = New-Object System.Windows.Controls.ColumnDefinition; $safetyRowInfoCol.Width = "Auto"
    $safetyRowBtnCol = New-Object System.Windows.Controls.ColumnDefinition; $safetyRowBtnCol.Width = "Auto"
    $safetyRow.ColumnDefinitions.Add($safetyRowIconCol)
    $safetyRow.ColumnDefinitions.Add($safetyRowTitleCol)
    $safetyRow.ColumnDefinitions.Add($safetyRowInfoCol)
    $safetyRow.ColumnDefinitions.Add($safetyRowBtnCol)
    $safetyTitlePanel = New-Object System.Windows.Controls.StackPanel
    $safetyTitlePanel.VerticalAlignment = "Center"
    Add-GuiIconTitle $safetyTitlePanel "&#xEA18;" (T "Safety First") "Brush_AccentWarm"
    [System.Windows.Controls.Grid]::SetColumn($safetyTitlePanel, 0)
    [System.Windows.Controls.Grid]::SetColumnSpan($safetyTitlePanel, 2)
    $safetyRow.AddChild($safetyTitlePanel)
    $safetyInfoIcon = New-Object System.Windows.Controls.TextBlock
    $safetyInfoIcon.Text = [char]0xE946
    $safetyInfoIcon.FontFamily = "Segoe MDL2 Assets"
    $safetyInfoIcon.FontSize = 13
    $safetyInfoIcon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
    $safetyInfoIcon.Margin = "8,0,10,0"
    $safetyInfoIcon.VerticalAlignment = "Center"
    $safetyInfoIcon.Cursor = "Help"
    $safetyInfoIcon.ToolTip = T "Create a Windows System Restore Point before making any system changes. Highly recommended."
    [System.Windows.Controls.Grid]::SetColumn($safetyInfoIcon, 2)
    $safetyRow.AddChild($safetyInfoIcon)
    $safetyBtnPanel = New-Object System.Windows.Controls.StackPanel
    $safetyBtnPanel.Orientation = "Horizontal"
    $safetyBtnPanel.VerticalAlignment = "Center"
    # Checkpoint-Computer can take 30s+: runs in a background job so the button reads "Cancel".
    [void](Add-GuiBackgroundBtn $safetyBtnPanel (T "Create Restore Point") { Invoke-RestorePoint } @('Invoke-RestorePoint') {
        Set-GuiProgress 0
    })
    [System.Windows.Controls.Grid]::SetColumn($safetyBtnPanel, 3)
    $safetyRow.AddChild($safetyBtnPanel)
    $safetyBorder.Child = $safetyRow
    $safetyLeftStack.AddChild($safetyBorder)
    [System.Windows.Controls.Grid]::SetColumn($safetyLeftStack, 0)
    $safetyGrid.AddChild($safetyLeftStack)

    # Right - Sett Utility
    $utilRightStack = New-Object System.Windows.Controls.StackPanel
    $utilRightStack.Margin = "6,0,0,0"
    $utilBorder = New-Object System.Windows.Controls.Border
    $utilBorder.Style = $Window.FindResource("CardStyle")
    $utilBorder.Padding = "12"
    $utilRow = New-Object System.Windows.Controls.Grid
    $utilRowIconCol = New-Object System.Windows.Controls.ColumnDefinition; $utilRowIconCol.Width = "Auto"
    $utilRowTitleCol = New-Object System.Windows.Controls.ColumnDefinition; $utilRowTitleCol.Width = "1*"
    $utilRowInfoCol = New-Object System.Windows.Controls.ColumnDefinition; $utilRowInfoCol.Width = "Auto"
    $utilRowBtnCol = New-Object System.Windows.Controls.ColumnDefinition; $utilRowBtnCol.Width = "Auto"
    $utilRow.ColumnDefinitions.Add($utilRowIconCol)
    $utilRow.ColumnDefinitions.Add($utilRowTitleCol)
    $utilRow.ColumnDefinitions.Add($utilRowInfoCol)
    $utilRow.ColumnDefinitions.Add($utilRowBtnCol)
    $utilTitlePanel = New-Object System.Windows.Controls.StackPanel
    $utilTitlePanel.VerticalAlignment = "Center"
    Add-GuiIconTitle $utilTitlePanel "&#xE896;" (T "Sett Utility") "Brush_AccentWarm"
    [System.Windows.Controls.Grid]::SetColumn($utilTitlePanel, 0)
    [System.Windows.Controls.Grid]::SetColumnSpan($utilTitlePanel, 2)
    $utilRow.AddChild($utilTitlePanel)
    $utilInfoIcon = New-Object System.Windows.Controls.TextBlock
    $utilInfoIcon.Text = [char]0xE946
    $utilInfoIcon.FontFamily = "Segoe MDL2 Assets"
    $utilInfoIcon.FontSize = 13
    $utilInfoIcon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextMuted")
    $utilInfoIcon.Margin = "8,0,10,0"
    $utilInfoIcon.VerticalAlignment = "Center"
    $utilInfoIcon.Cursor = "Help"
    $utilInfoIcon.ToolTip = T "Download the SETT Utility toolset directly to your Desktop."
    [System.Windows.Controls.Grid]::SetColumn($utilInfoIcon, 2)
    $utilRow.AddChild($utilInfoIcon)
    $utilBtnPanel = New-Object System.Windows.Controls.StackPanel
    $utilBtnPanel.Orientation = "Horizontal"
    $utilBtnPanel.VerticalAlignment = "Center"
    [void](Add-GuiBtn $utilBtnPanel (T "Download SETT Utility") "InstallButtonStyle" { Invoke-DownloadRepoFile -RepoOwner "otaviozanon" -RepoName "settUtility" -FilePath "settUtility.zip" -Label "SETT Utility" })
    [System.Windows.Controls.Grid]::SetColumn($utilBtnPanel, 3)
    $utilRow.AddChild($utilBtnPanel)
    $utilBorder.Child = $utilRow
    $utilRightStack.AddChild($utilBorder)
    [System.Windows.Controls.Grid]::SetColumn($utilRightStack, 1)
    $safetyGrid.AddChild($utilRightStack)

    $pnlContent.AddChild($safetyGrid)
}

