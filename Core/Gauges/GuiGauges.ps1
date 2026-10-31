# Builds a labeled horizontal progress-bar widget (label + "--%" text on top, colored bar below)
# used for Home dashboard metrics (CPU/RAM/GPU). Returns a hashtable with Panel/Bar/Text so the
# caller can add it to the layout and later update it via Set-GuiMetricBarValue.
function New-GuiMetricBar {
    param([string]$Label, [string]$AccentColor = "#1F6FEB")
    $wrap = New-Object System.Windows.Controls.StackPanel
    $wrap.Margin = "0,0,0,10"

    # Default theme keeps the distinct per-metric accent colors (blue/green/orange) passed in by
    # the caller. Terminal Retro always collapses every bar to the single theme accent (orange) so
    # the dashboard doesn't mix unrelated hues against the retro palette - only orange "pops".
    $isRetro = $false
    try { if ($Window -and $Window.Resources.Contains("Theme_IsRetro")) { $isRetro = [bool]$Window.Resources["Theme_IsRetro"] } } catch {}

    $headerGrid = New-Object System.Windows.Controls.Grid
    $headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $colAuto = New-Object System.Windows.Controls.ColumnDefinition; $colAuto.Width = "Auto"
    $headerGrid.ColumnDefinitions.Add($colAuto)

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $Label
    $lbl.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    $lbl.SetResourceReference([System.Windows.Controls.TextBlock]::FontFamilyProperty, "Theme_FontFamily")
    $lbl.FontSize = 11
    [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
    $headerGrid.AddChild($lbl)

    $pct = New-Object System.Windows.Controls.TextBlock
    $pct.Text = "--%"
    $pct.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
    $pct.SetResourceReference([System.Windows.Controls.TextBlock]::FontFamilyProperty, "Theme_FontFamily")
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
    if ($isRetro) {
        $bar.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, "Brush_Accent")
    } else {
        $bar.Foreground = $AccentColor
    }
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
    $track.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, "Brush_GaugeTrack")
    $track.StrokeThickness = $Thickness
    [System.Windows.Controls.Canvas]::SetLeft($track, $Thickness / 2)
    [System.Windows.Controls.Canvas]::SetTop($track, $Thickness / 2)
    $canvas.AddChild($track)

    # Retro theme: flat caps + a dash pattern turn the smooth arc into a segmented
    # LED-ring look (blocky ticks) instead of a continuous curve; Default theme keeps
    # the original smooth rounded-cap arc untouched.
    $isRetro = $false
    try { if ($Window -and $Window.Resources.Contains("Theme_IsRetro")) { $isRetro = [bool]$Window.Resources["Theme_IsRetro"] } } catch {}

    # Retro theme: a thin ring of small white pixelated dots sits just inside the track, purely
    # decorative (always full circle, independent of the value) to read as an 8-bit LED dial face.
    if ($isRetro) {
        $dotRing = New-Object System.Windows.Shapes.Ellipse
        $dotRadius = $radius - ($Thickness * 0.75)
        $dotRing.Width = $dotRadius * 2; $dotRing.Height = $dotRadius * 2
        $dotRing.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, "Brush_GaugeDot")
        $dotRing.StrokeThickness = 1.5
        $dotRing.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection @(0.6, 2.4)
        [System.Windows.Controls.Canvas]::SetLeft($dotRing, $radius - $dotRadius)
        [System.Windows.Controls.Canvas]::SetTop($dotRing, $radius - $dotRadius)
        $canvas.AddChild($dotRing)
    }

    $arc = New-Object System.Windows.Shapes.Path
    if ($isRetro) {
        $arc.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, "Brush_Accent")
    } else {
        $arc.Stroke = $AccentColor
    }
    $arc.StrokeThickness = $Thickness
    if ($isRetro) {
        $arc.StrokeStartLineCap = "Flat"
        $arc.StrokeEndLineCap = "Flat"
        $arc.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection @(1.1, 0.9)
    } else {
        $arc.StrokeStartLineCap = "Round"
        $arc.StrokeEndLineCap = "Round"
    }
    $canvas.AddChild($arc)

    $pctText = New-Object System.Windows.Controls.TextBlock
    $pctText.Text = "--%"
    $pctText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
    $pctText.FontFamily = $Script:MonoFontFamily
    $pctText.FontSize = [math]::Max(10, [math]::Round($Size * 0.174))
    $pctText.FontWeight = "Bold"
    $pctText.HorizontalAlignment = "Center"
    $pctText.VerticalAlignment = "Center"
    $grid.AddChild($pctText)

    $wrap.AddChild($grid)

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $Label
    $lbl.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
    $lbl.SetResourceReference([System.Windows.Controls.TextBlock]::FontFamilyProperty, "Theme_FontFamily")
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

    # Keep the arc's cap/dash style in sync with the currently active theme on every refresh,
    # so switching themes updates already-rendered gauges immediately (not just newly created ones).
    $isRetro = $false
    try { if ($Window -and $Window.Resources.Contains("Theme_IsRetro")) { $isRetro = [bool]$Window.Resources["Theme_IsRetro"] } } catch {}
    if ($isRetro) {
        $Gauge.Arc.StrokeStartLineCap = "Flat"
        $Gauge.Arc.StrokeEndLineCap = "Flat"
        $Gauge.Arc.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection @(1.1, 0.9)
    } else {
        $Gauge.Arc.StrokeStartLineCap = "Round"
        $Gauge.Arc.StrokeEndLineCap = "Round"
        $Gauge.Arc.StrokeDashArray = $null
    }
}

