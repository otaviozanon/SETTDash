# GPU benchmark: SETTDash has no bundled DirectX/CUDA interop to drive the GPU directly, so this
# stresses WPF's own hardware-accelerated compositor instead - a grid of continuously rotating/
# scaling shapes, rendered via CompositionTarget.Rendering for a fixed duration (10s by default -
# long enough to ride out driver/compositor warmup, unlike a 5s burst), reporting per-second FPS
# samples plus min/max/avg. This is a rendering-pipeline proxy (exercises the same GPU
# driver/compositor path as any WPF app), not a raw shader/compute benchmark - treat the score as
# relative (before/after driver or tweak changes), not as a cross-vendor number.
function Start-GpuRenderBenchmark {
    param($Panel, [double]$DurationSeconds = 30, [int]$GridCols = 16, [int]$GridRows = 9, [scriptblock]$OnComplete, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)

    $Panel.Children.Clear()
    $Panel.Rows = $GridRows
    $Panel.Columns = $GridCols

    $colors = @("#1F6FEB","#F0883E","#3FB950","#A371F7","#F85149","#D29922")
    for ($i = 0; $i -lt ($GridCols * $GridRows); $i++) {
        $cell = New-Object System.Windows.Shapes.Rectangle
        $cell.Width = 22; $cell.Height = 22; $cell.Margin = "3"
        $cell.Fill = $colors[$i % $colors.Count]
        $cell.RadiusX = 4; $cell.RadiusY = 4
        $transform = New-Object System.Windows.Media.RotateTransform
        $transform.CenterX = 11; $transform.CenterY = 11
        $cell.RenderTransform = $transform

        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.From = 0; $anim.To = 360
        $anim.Duration = [System.Windows.Duration]::new([timespan]::FromSeconds(1.2 + ($i % 5) * 0.2))
        $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $transform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)

        $Panel.Children.Add($cell) | Out-Null
    }

    # $Script:GpuBenchDelegate holds the actual EventHandler delegate instance (not the raw
    # scriptblock) so remove_Rendering can unhook the exact same object that was added.
    # NOTE: PowerShell implicitly builds a *new* EventHandler wrapper every time a scriptblock is
    # bound to a .NET event parameter, so calling add_Rendering($sb) then later
    # remove_Rendering($sb) with the same scriptblock variable actually passes two *different*
    # delegate instances - .NET's remove silently no-ops because it can't find a matching
    # subscriber, and CompositionTarget.Rendering keeps firing forever even after the duration
    # elapses (this is what caused the "several averages" / endless-loop bug: $OnComplete got
    # invoked on every remaining frame since the handler was never actually unsubscribed).
    # Casting the scriptblock to [EventHandler] once and reusing that exact object for both
    # add_Rendering and remove_Rendering guarantees it's the same delegate instance both times.
    $state = [PSCustomObject]@{
        Frames = 0L; LastSecondFrames = 0L; LastSecond = 0; Completed = $false
        Samples = [System.Collections.Generic.List[double]]::new()
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    $Script:GpuBenchDelegate = $null
    $Script:GpuBenchHandler = {
        if ($state.Completed) { return }
        $state.Frames++
        $elapsed = $state.Stopwatch.Elapsed.TotalSeconds
        $curSecond = [int][math]::Floor($elapsed)
        if ($curSecond -gt $state.LastSecond) {
            $sample = [double]($state.Frames - $state.LastSecondFrames)
            $state.Samples.Add($sample) | Out-Null
            $state.LastSecondFrames = $state.Frames
            $state.LastSecond = $curSecond
            if ($OnSample) { & $OnSample $sample }
        }
        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        if ($elapsed -ge $DurationSeconds -or $cancelled) {
            $state.Completed = $true
            [System.Windows.Media.CompositionTarget]::remove_Rendering($Script:GpuBenchDelegate)
            $avgFps = [math]::Round($state.Frames / $elapsed, 1)
            $result = [PSCustomObject]@{
                Cancelled = $cancelled
                AvgFps  = $avgFps
                MinFps  = if ($state.Samples.Count -gt 0) { [math]::Round(($state.Samples | Measure-Object -Minimum).Minimum, 1) } else { $avgFps }
                MaxFps  = if ($state.Samples.Count -gt 0) { [math]::Round(($state.Samples | Measure-Object -Maximum).Maximum, 1) } else { $avgFps }
                Samples = $state.Samples
            }
            if ($OnComplete) { & $OnComplete $result }
        }
    }.GetNewClosure()
    $Script:GpuBenchDelegate = [EventHandler]$Script:GpuBenchHandler
    [System.Windows.Media.CompositionTarget]::add_Rendering($Script:GpuBenchDelegate)
}

# Second GPU test mode: same FPS-sampling/timing machinery as Start-GpuRenderBenchmark above (see
# the delegate-identity note there - it's why $Script:Gpu3DBenchDelegate is cast to [EventHandler]
# once and reused for both add_Rendering/remove_Rendering), but drives a real Viewport3D scene
# (lit, rotating 3D meshes) instead of 2D RotateTransform rectangles - exercises WPF's 3D
# transform/lighting/projection pipeline, which is a heavier compositor path than flat 2D shapes.
function Start-Gpu3DRenderBenchmark {
    param($Viewport, [double]$DurationSeconds = 30, [int]$MeshCount = 48, [scriptblock]$OnComplete, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)

    $Viewport.Children.Clear()

    $camera = New-Object System.Windows.Media.Media3D.PerspectiveCamera
    $camera.Position = New-Object System.Windows.Media.Media3D.Point3D(0, 0, 14)
    $camera.LookDirection = New-Object System.Windows.Media.Media3D.Vector3D(0, 0, -1)
    $camera.FieldOfView = 60
    $Viewport.Camera = $camera

    $lightModel = New-Object System.Windows.Media.Media3D.Model3DGroup
    $lightModel.Children.Add((New-Object System.Windows.Media.Media3D.AmbientLight "#404040")) | Out-Null
    $dirLight = New-Object System.Windows.Media.Media3D.DirectionalLight
    $dirLight.Color = "#FFFFFF"
    $dirLight.Direction = New-Object System.Windows.Media.Media3D.Vector3D(-1, -1, -2)
    $lightModel.Children.Add($dirLight) | Out-Null
    $lightVisual = New-Object System.Windows.Media.Media3D.ModelVisual3D
    $lightVisual.Content = $lightModel
    $Viewport.Children.Add($lightVisual) | Out-Null

    $colors = @("#1F6FEB","#F0883E","#3FB950","#A371F7","#F85149","#D29922")
    $cols = [int][math]::Ceiling([math]::Sqrt($MeshCount))
    $transforms = @()
    for ($i = 0; $i -lt $MeshCount; $i++) {
        $mesh = New-Object System.Windows.Media.Media3D.MeshGeometry3D
        $pts = New-Object System.Windows.Media.Media3D.Point3DCollection
        @((-0.5,-0.5,-0.5),(0.5,-0.5,-0.5),(0.5,0.5,-0.5),(-0.5,0.5,-0.5),(-0.5,-0.5,0.5),(0.5,-0.5,0.5),(0.5,0.5,0.5),(-0.5,0.5,0.5)) | ForEach-Object {
            $pts.Add((New-Object System.Windows.Media.Media3D.Point3D($_[0], $_[1], $_[2]))) | Out-Null
        }
        $mesh.Positions = $pts
        $idx = @(0,1,2, 0,2,3, 4,6,5, 4,7,6, 0,4,5, 0,5,1, 1,5,6, 1,6,2, 2,6,7, 2,7,3, 3,7,4, 3,4,0)
        $triIdx = New-Object System.Windows.Media.Int32Collection
        $idx | ForEach-Object { $triIdx.Add($_) | Out-Null }
        $mesh.TriangleIndices = $triIdx

        $material = New-Object System.Windows.Media.Media3D.DiffuseMaterial((New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($colors[$i % $colors.Count]))))
        $geom = New-Object System.Windows.Media.Media3D.GeometryModel3D($mesh, $material)

        $row = [math]::Floor($i / $cols); $col = $i % $cols
        $translate = New-Object System.Windows.Media.Media3D.TranslateTransform3D((($col - $cols / 2.0) * 1.6), (($row - $cols / 2.0) * 1.6), 0)
        $rotation = New-Object System.Windows.Media.Media3D.AxisAngleRotation3D((New-Object System.Windows.Media.Media3D.Vector3D(0.4, 1, 0.2)), 0)
        $rotateTransform = New-Object System.Windows.Media.Media3D.RotateTransform3D($rotation)
        $group = New-Object System.Windows.Media.Media3D.Transform3DGroup
        $group.Children.Add($rotateTransform) | Out-Null
        $group.Children.Add($translate) | Out-Null
        $geom.Transform = $group

        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.From = 0; $anim.To = 360
        $anim.Duration = [System.Windows.Duration]::new([timespan]::FromSeconds(1.5 + ($i % 5) * 0.2))
        $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $rotation.BeginAnimation([System.Windows.Media.Media3D.AxisAngleRotation3D]::AngleProperty, $anim)

        $visual = New-Object System.Windows.Media.Media3D.ModelVisual3D
        $visual.Content = $geom
        $Viewport.Children.Add($visual) | Out-Null
    }

    $state = [PSCustomObject]@{
        Frames = 0L; LastSecondFrames = 0L; LastSecond = 0; Completed = $false
        Samples = [System.Collections.Generic.List[double]]::new()
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    $Script:Gpu3DBenchDelegate = $null
    $Script:Gpu3DBenchHandler = {
        if ($state.Completed) { return }
        $state.Frames++
        $elapsed = $state.Stopwatch.Elapsed.TotalSeconds
        $curSecond = [int][math]::Floor($elapsed)
        if ($curSecond -gt $state.LastSecond) {
            $sample = [double]($state.Frames - $state.LastSecondFrames)
            $state.Samples.Add($sample) | Out-Null
            $state.LastSecondFrames = $state.Frames
            $state.LastSecond = $curSecond
            if ($OnSample) { & $OnSample $sample }
        }
        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        if ($elapsed -ge $DurationSeconds -or $cancelled) {
            $state.Completed = $true
            [System.Windows.Media.CompositionTarget]::remove_Rendering($Script:Gpu3DBenchDelegate)
            $avgFps = [math]::Round($state.Frames / $elapsed, 1)
            $result = [PSCustomObject]@{
                Cancelled = $cancelled
                AvgFps  = $avgFps
                MinFps  = if ($state.Samples.Count -gt 0) { [math]::Round(($state.Samples | Measure-Object -Minimum).Minimum, 1) } else { $avgFps }
                MaxFps  = if ($state.Samples.Count -gt 0) { [math]::Round(($state.Samples | Measure-Object -Maximum).Maximum, 1) } else { $avgFps }
                Samples = $state.Samples
            }
            if ($OnComplete) { & $OnComplete $result }
        }
    }.GetNewClosure()
    $Script:Gpu3DBenchDelegate = [EventHandler]$Script:Gpu3DBenchHandler
    [System.Windows.Media.CompositionTarget]::add_Rendering($Script:Gpu3DBenchDelegate)
}

# Runs the GPU benchmark (2D or 3D mode) inside its own modal popup window instead of in the
# BenchGpu.ps1 page itself: the popup hosts the render surface + a live FPS gauge while the test
# runs, and only the final Avg FPS result is reported back to the page (Show-PageBenchGpu adds
# just a result stat-tile - no render surface lives on the page anymore).
#
# This popup is a plain XamlReader Window (like the update-checker dialogs in UpdateChecker.ps1),
# not part of the main $Window visual tree, so it can't use {DynamicResource} against
# $Window.Resources - all chrome/gauge colors are baked in as literal values from the current
# theme (same approach as Get-UpdatePopupXaml/Get-CurrentThemeColors).
# Returns the benchmark $result (Cancelled/AvgFps/MinFps/MaxFps/Samples), or $null if the window
# was closed before a result was produced (shouldn't normally happen - Close only becomes
# available once the run completes).
function Show-GpuBenchmarkPopup {
    param([string]$Mode = "2D", [double]$DurationSeconds = 30)

    $is3D = ($Mode -eq "3D")
    $modeName = if ($is3D) { "3D Viewport" } else { "2D Compositor" }
    $t = Get-CurrentThemeColors
    $fontFamily = if ($t.FontFamily -eq "MONO") { "Consolas" } else { "Segoe UI" }
    $radius = $t.CornerRadius

    $body = @"
        <StackPanel>
            <Border x:Name="renderHost" Height="560" Background="$($t.CardBg)" BorderBrush="$($t.CardBorder)" BorderThickness="1" CornerRadius="$radius" Margin="0,0,0,14"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Border x:Name="gaugeHost" Width="60" Height="60" VerticalAlignment="Center"/>
                <StackPanel Width="220" Margin="14,0,0,0" VerticalAlignment="Center">
                    <TextBlock x:Name="txtStatus" Text="Running... 0 / ${DurationSeconds}s" Foreground="$($t.TextSecondary)" FontFamily="$fontFamily" FontSize="11" TextAlignment="Center"/>
                    <TextBlock x:Name="txtResult" Text="" Foreground="$($t.TextPrimary)" FontFamily="$fontFamily" FontSize="13" FontWeight="Bold" Margin="0,3,0,0" TextAlignment="Center"/>
                </StackPanel>
                <Button x:Name="btnAction" Content="Stop Benchmark" Style="{StaticResource DialogPrimaryButtonStyle}" Margin="14,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
        </StackPanel>
"@

    [xml]$xaml = Get-UpdatePopupXaml -Width 1000 -Title "GPU Benchmark - $modeName" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $renderHost = $dlg.FindName("renderHost")
    $gaugeHost = $dlg.FindName("gaugeHost")
    $txtStatus = $dlg.FindName("txtStatus")
    $txtResult = $dlg.FindName("txtResult")
    $btnAction = $dlg.FindName("btnAction")
    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar

    # Render surface: only the active mode's control is created/attached to renderHost.
    if ($is3D) {
        $viewport = New-Object System.Windows.Controls.Viewport3D
        $renderHost.Child = $viewport
    } else {
        $renderPanel = New-Object System.Windows.Controls.Primitives.UniformGrid
        $renderHost.Child = $renderPanel
    }

    # Literal-color circular gauge (track + arc + center value) - mirrors New-GuiCircularGauge's
    # structure (Core/Gauges/GuiGauges.ps1) but with baked colors instead of SetResourceReference,
    # since this popup has no live {DynamicResource} wiring to $Window.Resources.
    $gaugeSize = 60; $gaugeThickness = 7; $gaugeRadius = ($gaugeSize - $gaugeThickness) / 2.0
    $gaugeGrid = New-Object System.Windows.Controls.Grid
    $gaugeCanvas = New-Object System.Windows.Controls.Canvas
    $gaugeCanvas.Width = $gaugeSize; $gaugeCanvas.Height = $gaugeSize
    $gaugeGrid.AddChild($gaugeCanvas)
    $gaugeTrack = New-Object System.Windows.Shapes.Ellipse
    $gaugeTrack.Width = $gaugeRadius * 2; $gaugeTrack.Height = $gaugeRadius * 2
    $gaugeTrack.Stroke = $t.GaugeTrack
    $gaugeTrack.StrokeThickness = $gaugeThickness
    [System.Windows.Controls.Canvas]::SetLeft($gaugeTrack, $gaugeThickness / 2)
    [System.Windows.Controls.Canvas]::SetTop($gaugeTrack, $gaugeThickness / 2)
    $gaugeCanvas.AddChild($gaugeTrack)
    $gaugeArc = New-Object System.Windows.Shapes.Path
    $gaugeArc.Stroke = $t.Accent
    $gaugeArc.StrokeThickness = $gaugeThickness
    $gaugeArc.StrokeStartLineCap = "Round"; $gaugeArc.StrokeEndLineCap = "Round"
    $gaugeCanvas.AddChild($gaugeArc)
    $gaugeValueText = New-Object System.Windows.Controls.TextBlock
    $gaugeValueText.Text = "--"
    $gaugeValueText.Foreground = $t.TextPrimary
    $gaugeValueText.FontFamily = $fontFamily
    $gaugeValueText.FontSize = 12
    $gaugeValueText.FontWeight = "Bold"
    $gaugeValueText.HorizontalAlignment = "Center"
    $gaugeValueText.VerticalAlignment = "Center"
    $gaugeGrid.AddChild($gaugeValueText)
    $gaugeHost.Child = $gaugeGrid

    # Scales FPS to a 0-100 arc percentage (assumes ~60 FPS "full ring", the common WPF
    # compositor vsync ceiling - see the notes above Start-GpuRenderBenchmark) and shows the raw
    # FPS number (not a percent) in the center, since FPS - not percent completion - is the
    # meaningful unit here.
    $updateGauge = {
        param($fps)
        $pct = [math]::Max(0, [math]::Min(100, ($fps / 60.0) * 100))
        $gaugeArc.Data = New-GuiGaugeArcGeometry -Radius $gaugeRadius -Cx ($gaugeSize / 2.0) -Cy ($gaugeSize / 2.0) -ValuePercent $pct
        $gaugeValueText.Text = "$([math]::Round($fps))"
    }.GetNewClosure()

    $popupState = [PSCustomObject]@{ Cancelled = $false; Done = $false; Result = $null; SampleCount = 0 }

    $actionHandler = {
        if ($popupState.Done) { $dlg.Close(); return }
        $popupState.Cancelled = $true
        $btnAction.Content = "Stopping..."
        $btnAction.IsEnabled = $false
    }.GetNewClosure()
    $btnAction.Add_Click($actionHandler)
    $btnClose.Add_Click($actionHandler)

    $onSample = {
        param($v)
        $popupState.SampleCount++
        $txtStatus.Text = "Running... $($popupState.SampleCount) / ${DurationSeconds}s"
        & $updateGauge $v
    }.GetNewClosure()

    $onComplete = {
        param($result)
        if ($is3D) { $viewport.Children.Clear() } else { $renderPanel.Children.Clear() }
        $popupState.Done = $true
        $popupState.Result = $result
        & $updateGauge $result.AvgFps
        if ($result.Cancelled) {
            $txtStatus.Text = "Stopped"
            $txtResult.Text = "Average: $($result.AvgFps) FPS"
        } else {
            $txtStatus.Text = "Complete ($modeName, ${DurationSeconds}s)"
            $txtResult.Text = "Average: $($result.AvgFps) FPS"
        }
        $btnAction.Content = "Close"
        $btnAction.IsEnabled = $true
    }.GetNewClosure()

    $dlg.Add_ContentRendered({
        if ($is3D) {
            Start-Gpu3DRenderBenchmark -Viewport $viewport -DurationSeconds $DurationSeconds `
                -OnSample $onSample -CancelCheck { $popupState.Cancelled } -OnComplete $onComplete
        } else {
            Start-GpuRenderBenchmark -Panel $renderPanel -DurationSeconds $DurationSeconds `
                -OnSample $onSample -CancelCheck { $popupState.Cancelled } -OnComplete $onComplete
        }
    }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
    return $popupState.Result
}
