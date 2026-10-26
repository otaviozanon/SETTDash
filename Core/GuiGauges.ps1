# Builds a labeled horizontal progress-bar widget (label + "--%" text on top, colored bar below)
# used for Home dashboard metrics (CPU/RAM/GPU). Returns a hashtable with Panel/Bar/Text so the
# caller can add it to the layout and later update it via Set-GuiMetricBarValue.
function New-GuiMetricBar {
    param([string]$Label, [string]$AccentColor = "#1F6FEB")
    $wrap = New-Object System.Windows.Controls.StackPanel
    $wrap.Margin = "0,0,0,10"

    $headerGrid = New-Object System.Windows.Controls.Grid
    $headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $colAuto = New-Object System.Windows.Controls.ColumnDefinition; $colAuto.Width = "Auto"
    $headerGrid.ColumnDefinitions.Add($colAuto)

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $Label
    $lbl.Foreground = "#8B949E"
    $lbl.FontSize = 11
    [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
    $headerGrid.AddChild($lbl)

    $pct = New-Object System.Windows.Controls.TextBlock
    $pct.Text = "--%"
    $pct.Foreground = "#E6EDF3"
    $pct.FontSize = 11
    $pct.FontWeight = "SemiBold"
    [System.Windows.Controls.Grid]::SetColumn($pct, 1)
    $headerGrid.AddChild($pct)

    $wrap.AddChild($headerGrid)

    $bar = New-Object System.Windows.Controls.ProgressBar
    $bar.Style = $Window.FindResource("ProgressBarStyle")
    $bar.Minimum = 0
    $bar.Maximum = 100
    $bar.Value = 0
    $bar.Height = 8
    $bar.Margin = "0,6,0,0"
    $bar.Foreground = $AccentColor
    $wrap.AddChild($bar)

    return @{ Panel = $wrap; Bar = $bar; Text = $pct }
}

# Updates a metric bar created by New-GuiMetricBar: clamps $Value to 0-100 and refreshes both
# the bar fill and its percentage text.
function Set-GuiMetricBarValue {
    param($MetricBar, [double]$Value)
    if (-not $MetricBar) { return }
    $v = [math]::Max(0, [math]::Min(100, $Value))
    $MetricBar.Bar.Value = $v
    $MetricBar.Text.Text = "$([math]::Round($v))%"
}

# Computes the WPF StreamGeometry for the colored arc of a circular gauge, representing
# $ValuePercent (0-100) as a clockwise arc starting at the top (-90deg). Handles the near-100%
# edge case (full circle) by splitting it into two half-arcs, since a single ArcTo can't draw
# a complete 360-degree circle. Returns $null when the value is 0 (nothing to draw).
function New-GuiGaugeArcGeometry {
    param([double]$Radius, [double]$Cx, [double]$Cy, [double]$ValuePercent)
    $val = [math]::Max(0, [math]::Min(100, $ValuePercent))
    if ($val -le 0) { return $null }
    $startAngle = -90
    $sweep = $val / 100 * 360
    $startRad = $startAngle * [math]::PI / 180
    $p0 = New-Object System.Windows.Point(($Cx + $Radius * [math]::Cos($startRad)), ($Cy + $Radius * [math]::Sin($startRad)))
    $geo = New-Object System.Windows.Media.StreamGeometry
    $ctx = $geo.Open()
    if ($val -ge 99.9) {
        $midRad = ($startAngle + 180) * [math]::PI / 180
        $pMid = New-Object System.Windows.Point(($Cx + $Radius * [math]::Cos($midRad)), ($Cy + $Radius * [math]::Sin($midRad)))
        $size = New-Object System.Windows.Size($Radius, $Radius)
        $ctx.BeginFigure($p0, $false, $false)
        $ctx.ArcTo($pMid, $size, 0, $false, [System.Windows.Media.SweepDirection]::Clockwise, $true, $false)
        $ctx.ArcTo($p0, $size, 0, $false, [System.Windows.Media.SweepDirection]::Clockwise, $true, $false)
    } else {
        $endRad = ($startAngle + $sweep) * [math]::PI / 180
        $p1 = New-Object System.Windows.Point(($Cx + $Radius * [math]::Cos($endRad)), ($Cy + $Radius * [math]::Sin($endRad)))
        $isLarge = $sweep -gt 180
        $size = New-Object System.Windows.Size($Radius, $Radius)
        $ctx.BeginFigure($p0, $false, $false)
        $ctx.ArcTo($p1, $size, 0, $isLarge, [System.Windows.Media.SweepDirection]::Clockwise, $true, $false)
    }
    $ctx.Close()
    $geo.Freeze()
    return $geo
}

# Builds a circular ring gauge (gray track circle + colored progress arc + percentage text in the
# center + label below) used on the Home dashboard. Returns a pscustomobject with the Arc/Text
# elements and geometry info (Radius/Cx/Cy) needed by Set-GuiGaugeValue to redraw the arc.
function New-GuiCircularGauge {
    param([string]$Label, [string]$AccentColor = "#1F6FEB", [int]$Size = 86, [int]$Thickness = 8)
    $radius = ($Size - $Thickness) / 2
    $wrap = New-Object System.Windows.Controls.StackPanel
    $wrap.HorizontalAlignment = "Center"

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Width = $Size; $grid.Height = $Size

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = $Size; $canvas.Height = $Size
    $grid.AddChild($canvas)

    $track = New-Object System.Windows.Shapes.Ellipse
    $track.Width = $radius * 2; $track.Height = $radius * 2
    $track.Stroke = "#242A32"
    $track.StrokeThickness = $Thickness
    [System.Windows.Controls.Canvas]::SetLeft($track, $Thickness / 2)
    [System.Windows.Controls.Canvas]::SetTop($track, $Thickness / 2)
    $canvas.AddChild($track)

    $arc = New-Object System.Windows.Shapes.Path
    $arc.Stroke = $AccentColor
    $arc.StrokeThickness = $Thickness
    $arc.StrokeStartLineCap = "Round"
    $arc.StrokeEndLineCap = "Round"
    $canvas.AddChild($arc)

    $pctText = New-Object System.Windows.Controls.TextBlock
    $pctText.Text = "--%"
    $pctText.Foreground = "#E6EDF3"
    $pctText.FontFamily = $Script:MonoFontFamily
    $pctText.FontSize = [math]::Max(10, [math]::Round($Size * 0.174))
    $pctText.FontWeight = "Bold"
    $pctText.HorizontalAlignment = "Center"
    $pctText.VerticalAlignment = "Center"
    $grid.AddChild($pctText)

    $wrap.AddChild($grid)

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $Label
    $lbl.Foreground = "#8B949E"
    $lbl.FontSize = 11
    $lbl.HorizontalAlignment = "Center"
    $lbl.Margin = "0,6,0,0"
    $wrap.AddChild($lbl)

    return [pscustomobject]@{ Panel = $wrap; Arc = $arc; Text = $pctText; Radius = $radius; Cx = $Size / 2.0; Cy = $Size / 2.0 }
}

# Updates a circular gauge created by New-GuiCircularGauge: clamps $Value to 0-100, updates the
# center percentage text, and regenerates the arc geometry to reflect the new value.
function Set-GuiGaugeValue {
    param($Gauge, [double]$Value)
    if (-not $Gauge) { return }
    $v = [math]::Max(0, [math]::Min(100, $Value))
    $Gauge.Text.Text = "$([math]::Round($v))%"
    $Gauge.Arc.Data = New-GuiGaugeArcGeometry -Radius $Gauge.Radius -Cx $Gauge.Cx -Cy $Gauge.Cy -ValuePercent $v
}

