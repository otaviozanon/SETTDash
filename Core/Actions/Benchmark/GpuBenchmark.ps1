# GPU benchmark: SETTDash has no bundled DirectX/CUDA interop to drive the GPU directly, so this
# stresses WPF's own hardware-accelerated compositor instead - a grid of continuously rotating/
# scaling shapes (2D mode) or a heavy lit 3D mesh scene (3D mode), reporting per-second FPS
# samples plus min/max/avg. This is a rendering-pipeline proxy (exercises the same GPU
# driver/compositor path as any WPF app), not a raw shader/compute benchmark - treat the score as
# relative (before/after driver or tweak changes), not as a cross-vendor number.
#
# IMPORTANT - no vsync cap: both modes used to count frames via CompositionTarget.Rendering,
# which only fires once per on-screen compositor frame - i.e. it's hard-capped at the monitor's
# refresh rate (~60Hz), so a GPU that could push 300 FPS and one that barely holds 60 FPS both
# report "60". To actually differentiate GPU throughput, frames are instead rendered as fast as
# possible to an off-screen RenderTargetBitmap (Start-GpuUncappedFrameLoop below) in a tight
# Dispatcher.BeginInvoke(Background) loop - that path is not tied to the display's swap chain, so
# the measured FPS reflects how fast the GPU/driver can actually rasterize the scene.
function Start-GpuUncappedFrameLoop {
    param($Visual, [int]$Width = 960, [int]$Height = 540, [double]$DurationSeconds, [scriptblock]$OnComplete, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)

    $state = [PSCustomObject]@{
        Frames = 0L; LastSecondFrames = 0L; LastSecond = 0; Completed = $false
        Samples = [System.Collections.Generic.List[double]]::new()
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    # NOTE: self-requeuing via a $Script:-scoped variable (the previous approach) resolved to
    # $null by the time the closure ran as an async [Action] delegate off the Dispatcher queue
    # ("Value cannot be null. Parameter name: method" on the recursive BeginInvoke call) - script
    # scope lookup from inside a delegate invoked later off the WPF message pump isn't reliable
    # here. A $holder object (reference type) captured once by .GetNewClosure() sidesteps that:
    # mutating $holder.Tick after the closure is created is still visible through the same shared
    # reference every time the closure (which also captured $holder) runs.
    $holder = [PSCustomObject]@{ Tick = $null }
    $holder.Tick = {
        if ($state.Completed) { return }

        # Defensive try/catch: a single failed frame render (e.g. a transient GPU/driver hiccup)
        # used to kill this self-requeuing loop silently (BeginInvoke has no app-level
        # DispatcherUnhandledException handler - see Main/Startup.ps1's Window.Add_Closing note),
        # leaving the popup stuck forever at "Running... 0/Ns" with Stop/Close unresponsive since
        # $OnComplete was never reached. Now a bad frame is just skipped and the loop keeps going;
        # only requeuing itself is what matters for the run to actually finish.
        try {
            # Fresh bitmap every frame (a reused target would just accumulate/overwrite the same
            # buffer without forcing the GPU to redo the rasterization work) - forces a full,
            # uncapped re-render of the current animated scene each iteration.
            $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Width, $Height, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
            $rtb.Render($Visual)
            $state.Frames++
        } catch {
            Write-GuiLog "GPU benchmark frame render error: $($_.Exception.Message)" "WARN"
        }

        $elapsed = $state.Stopwatch.Elapsed.TotalSeconds
        $curSecond = [int][math]::Floor($elapsed)
        if ($curSecond -gt $state.LastSecond) {
            $sample = [double]($state.Frames - $state.LastSecondFrames)
            $state.Samples.Add($sample) | Out-Null
            $state.LastSecondFrames = $state.Frames
            $state.LastSecond = $curSecond
            if ($OnSample) {
                try { & $OnSample $sample } catch { Write-GuiLog "GPU benchmark sample callback error: $($_.Exception.Message)" "WARN" }
            }
        }
        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        if ($elapsed -ge $DurationSeconds -or $cancelled) {
            $state.Completed = $true

            # Discard the first ~1-2s of samples before scoring - same rationale as the CPU
            # benchmark's Get-CpuScoredSamples: the first second(s) include shader/pipeline
            # "cold start" (driver JIT-compiling shaders, allocating GPU resources for the
            # RenderTargetBitmap/scene) which FurMark/3DMark don't count toward the final score,
            # and which otherwise drags the Min (and sometimes Avg) down artificially.
            $warmupSeconds = [math]::Min(2, [math]::Max(0, $state.Samples.Count - 1))
            # NOTE: must NOT use "$scored = if (...) {...} else {...}" here - assigning from an
            # if/else expression captures the branch's output through the pipeline, and PowerShell
            # auto-enumerates any IEnumerable (List[double]) passing through it. With exactly one
            # sample (e.g. Stop clicked almost immediately), that collapses the 1-item list into a
            # bare [double] instead of a List - $scored.GetRange(...) below then fails with
            # "System.Double does not contain a method named 'GetRange'". A plain imperative
            # assignment (no stream capture) keeps the List[double] type intact regardless of count.
            $scored = $state.Samples
            if ($state.Samples.Count -gt $warmupSeconds) {
                $scored = [System.Collections.Generic.List[double]]::new($state.Samples.GetRange($warmupSeconds, $state.Samples.Count - $warmupSeconds))
            }

            $avgFps = if ($scored.Count -gt 0) { [math]::Round(($scored | Measure-Object -Average).Average, 1) } else { [math]::Round($state.Frames / $elapsed, 1) }
            $minFps = if ($scored.Count -gt 0) { [math]::Round(($scored | Measure-Object -Minimum).Minimum, 1) } else { $avgFps }
            $maxFps = if ($scored.Count -gt 0) { [math]::Round(($scored | Measure-Object -Maximum).Maximum, 1) } else { $avgFps }

            # Thermal/driver-throttling indicator: FurMark-style stability runs compare FPS over
            # time to see if it decays. Here, split the scored (post-warmup) samples into first vs
            # second half and compare averages - a meaningful drop signals throttling/instability
            # rather than a flat, sustained render rate.
            $half = [int][math]::Floor($scored.Count / 2)
            $firstHalfAvg = $avgFps; $secondHalfAvg = $avgFps; $throttlePct = 0
            if ($half -ge 2) {
                $firstHalfAvg = [math]::Round((($scored.GetRange(0, $half)) | Measure-Object -Average).Average, 1)
                $secondHalfAvg = [math]::Round((($scored.GetRange($scored.Count - $half, $half)) | Measure-Object -Average).Average, 1)
                if ($firstHalfAvg -gt 0) { $throttlePct = [math]::Round((($firstHalfAvg - $secondHalfAvg) / $firstHalfAvg) * 100, 1) }
            }

            $result = [PSCustomObject]@{
                Cancelled      = $cancelled
                AvgFps         = $avgFps
                MinFps         = $minFps
                MaxFps         = $maxFps
                Samples        = $state.Samples
                FirstHalfFps   = $firstHalfAvg
                SecondHalfFps  = $secondHalfAvg
                ThrottlePct    = $throttlePct
                Throttling     = ($throttlePct -ge 10)
            }
            if ($OnComplete) { & $OnComplete $result }
            return
        }
        # Background priority: not synced to the compositor's per-frame ("Render" priority)
        # queue, so this re-queues as fast as the dispatcher can drain it - uncapped by vsync.
        # NOTE: must cast the scriptblock to [Action] explicitly - Dispatcher.BeginInvoke has
        # several overloads taking a bare Delegate, and PowerShell can't pick one for an
        # unconverted scriptblock + enum arg pair ("Cannot find an overload for 'BeginInvoke' and
        # the argument count: 2"), which silently aborted this closure (swallowed by the WPF event
        # pump in the compiled exe) before a single frame/requeue ever happened.
        $Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]$holder.Tick) | Out-Null
    }.GetNewClosure()
    $Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]$holder.Tick) | Out-Null
}

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

    # Uncapped (no vsync) frame driver - see Start-GpuUncappedFrameLoop above.
    Start-GpuUncappedFrameLoop -Visual $Panel -Width 960 -Height 540 -DurationSeconds $DurationSeconds `
        -OnSample $OnSample -CancelCheck $CancelCheck -OnComplete $OnComplete
}

# Builds a UV-sphere MeshGeometry3D with $Segments longitude/latitude subdivisions (far more
# triangles than a cube: 2*Segments^2 vs 12) - used by Start-Gpu3DRenderBenchmark below to make
# the 3D test an actually heavy workload (Opcao A) instead of ~50 flat cubes.
function New-GpuSphereMesh {
    param([int]$Segments = 14)
    $mesh = New-Object System.Windows.Media.Media3D.MeshGeometry3D
    $pts = New-Object System.Windows.Media.Media3D.Point3DCollection
    $normals = New-Object System.Windows.Media.Media3D.Vector3DCollection
    for ($lat = 0; $lat -le $Segments; $lat++) {
        $theta = [math]::PI * $lat / $Segments
        $sinT = [math]::Sin($theta); $cosT = [math]::Cos($theta)
        for ($lon = 0; $lon -le $Segments; $lon++) {
            $phi = 2 * [math]::PI * $lon / $Segments
            $x = $sinT * [math]::Cos($phi); $y = $cosT; $z = $sinT * [math]::Sin($phi)
            $pts.Add((New-Object System.Windows.Media.Media3D.Point3D(($x * 0.5), ($y * 0.5), ($z * 0.5)))) | Out-Null
            $normals.Add((New-Object System.Windows.Media.Media3D.Vector3D($x, $y, $z))) | Out-Null
        }
    }
    $mesh.Positions = $pts
    $mesh.Normals = $normals
    $triIdx = New-Object System.Windows.Media.Int32Collection
    for ($lat = 0; $lat -lt $Segments; $lat++) {
        for ($lon = 0; $lon -lt $Segments; $lon++) {
            $a = $lat * ($Segments + 1) + $lon
            $b = $a + $Segments + 1
            $triIdx.Add($a) | Out-Null; $triIdx.Add($b) | Out-Null; $triIdx.Add($a + 1) | Out-Null
            $triIdx.Add($a + 1) | Out-Null; $triIdx.Add($b) | Out-Null; $triIdx.Add($b + 1) | Out-Null
        }
    }
    $mesh.TriangleIndices = $triIdx
    return $mesh
}

# Second GPU test mode - "Opcao A": a much heavier lit 3D scene than before. Each instance is now
# a ~14-segment UV sphere (~390 triangles vs. a cube's 12), there are more instances, each has a
# diffuse + specular material (specular highlights force the GPU to recompute lighting per-pixel
# as the view/normals change every frame, instead of a flat-shaded cube face), and the scene is
# lit by one ambient + two directional + one point light (4 light passes instead of 2). Framing
# (frame counting / FPS) is handled by the shared uncapped loop in Start-GpuUncappedFrameLoop -
# see the no-vsync note at the top of this file.
function Start-Gpu3DRenderBenchmark {
    param($Viewport, [double]$DurationSeconds = 30, [int]$MeshCount = 90, [scriptblock]$OnComplete, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)

    $Viewport.Children.Clear()

    $camera = New-Object System.Windows.Media.Media3D.PerspectiveCamera
    $camera.Position = New-Object System.Windows.Media.Media3D.Point3D(0, 0, 18)
    $camera.LookDirection = New-Object System.Windows.Media.Media3D.Vector3D(0, 0, -1)
    $camera.FieldOfView = 60
    $Viewport.Camera = $camera

    $lightModel = New-Object System.Windows.Media.Media3D.Model3DGroup
    $lightModel.Children.Add((New-Object System.Windows.Media.Media3D.AmbientLight "#303030")) | Out-Null
    $dirLight1 = New-Object System.Windows.Media.Media3D.DirectionalLight
    $dirLight1.Color = "#FFFFFF"
    $dirLight1.Direction = New-Object System.Windows.Media.Media3D.Vector3D(-1, -1, -2)
    $lightModel.Children.Add($dirLight1) | Out-Null
    $dirLight2 = New-Object System.Windows.Media.Media3D.DirectionalLight
    $dirLight2.Color = "#8080FF"
    $dirLight2.Direction = New-Object System.Windows.Media.Media3D.Vector3D(1, 0.5, 1)
    $lightModel.Children.Add($dirLight2) | Out-Null
    $pointLight = New-Object System.Windows.Media.Media3D.PointLight
    $pointLight.Color = "#FFE0A0"
    $pointLight.Position = New-Object System.Windows.Media.Media3D.Point3D(0, 0, 10)
    $pointLight.Range = 40
    $lightModel.Children.Add($pointLight) | Out-Null
    $lightVisual = New-Object System.Windows.Media.Media3D.ModelVisual3D
    $lightVisual.Content = $lightModel
    $Viewport.Children.Add($lightVisual) | Out-Null

    $colors = @("#1F6FEB","#F0883E","#3FB950","#A371F7","#F85149","#D29922")
    $cols = [int][math]::Ceiling([math]::Sqrt($MeshCount))
    $sharedMesh = New-GpuSphereMesh -Segments 14
    for ($i = 0; $i -lt $MeshCount; $i++) {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($colors[$i % $colors.Count])
        $matGroup = New-Object System.Windows.Media.Media3D.MaterialGroup
        $matGroup.Children.Add((New-Object System.Windows.Media.Media3D.DiffuseMaterial((New-Object System.Windows.Media.SolidColorBrush($color))))) | Out-Null
        $specular = New-Object System.Windows.Media.Media3D.SpecularMaterial((New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::White)), 48)
        $matGroup.Children.Add($specular) | Out-Null
        $geom = New-Object System.Windows.Media.Media3D.GeometryModel3D($sharedMesh, $matGroup)

        $row = [math]::Floor($i / $cols); $col = $i % $cols
        $translate = New-Object System.Windows.Media.Media3D.TranslateTransform3D((($col - $cols / 2.0) * 1.6), (($row - $cols / 2.0) * 1.6), 0)
        $rotation = New-Object System.Windows.Media.Media3D.AxisAngleRotation3D((New-Object System.Windows.Media.Media3D.Vector3D(0.4, 1, 0.2)), 0)
        $rotateTransform = New-Object System.Windows.Media.Media3D.RotateTransform3D($rotation)
        $scaleTransform = New-Object System.Windows.Media.Media3D.ScaleTransform3D(1, 1, 1)
        $group = New-Object System.Windows.Media.Media3D.Transform3DGroup
        $group.Children.Add($rotateTransform) | Out-Null
        $group.Children.Add($scaleTransform) | Out-Null
        $group.Children.Add($translate) | Out-Null
        $geom.Transform = $group

        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.From = 0; $anim.To = 360
        $anim.Duration = [System.Windows.Duration]::new([timespan]::FromSeconds(1.5 + ($i % 5) * 0.2))
        $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $rotation.BeginAnimation([System.Windows.Media.Media3D.AxisAngleRotation3D]::AngleProperty, $anim)

        # Pulsing scale on top of the rotation - extra per-frame transform/lighting recompute work.
        $scaleAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $scaleAnim.From = 0.8; $scaleAnim.To = 1.3
        $scaleAnim.Duration = [System.Windows.Duration]::new([timespan]::FromSeconds(0.8 + ($i % 7) * 0.15))
        $scaleAnim.AutoReverse = $true
        $scaleAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $scaleTransform.BeginAnimation([System.Windows.Media.Media3D.ScaleTransform3D]::ScaleXProperty, $scaleAnim)
        $scaleTransform.BeginAnimation([System.Windows.Media.Media3D.ScaleTransform3D]::ScaleYProperty, $scaleAnim)
        $scaleTransform.BeginAnimation([System.Windows.Media.Media3D.ScaleTransform3D]::ScaleZProperty, $scaleAnim)

        $visual = New-Object System.Windows.Media.Media3D.ModelVisual3D
        $visual.Content = $geom
        $Viewport.Children.Add($visual) | Out-Null
    }

    # Uncapped (no vsync) frame driver - see Start-GpuUncappedFrameLoop above.
    Start-GpuUncappedFrameLoop -Visual $Viewport -Width 960 -Height 540 -DurationSeconds $DurationSeconds `
        -OnSample $OnSample -CancelCheck $CancelCheck -OnComplete $OnComplete
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

    # Scales FPS to a 0-100 arc percentage and shows the raw FPS number (not a percent) in the
    # center, since FPS - not percent completion - is the meaningful unit here. The render loop
    # is no longer vsync-capped (see the note above Start-GpuUncappedFrameLoop), so FPS can climb
    # well past 60 on a fast GPU - 240 FPS is used as the "full ring" reference instead.
    $updateGauge = {
        param($fps)
        $pct = [math]::Max(0, [math]::Min(100, ($fps / 240.0) * 100))
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
        if ($result.Cancelled) {
            # User already asked to stop (clicked "Stop Benchmark"/the X button once) - that click
            # is the intent to close, not just to freeze the run. Previously this only flipped the
            # button to "Close" (enabled) and waited for a *second* click, which from the user's
            # side looked exactly like "I clicked Stop, it says Stopping..., and the window never
            # closes" (they only clicked once). Auto-close here instead of waiting on an extra click.
            $dlg.Close()
            return
        }
        & $updateGauge $result.AvgFps
        $txtStatus.Text = "Complete ($modeName, ${DurationSeconds}s)"
        $throttleNote = if ($result.Throttling) { " - throttling detected (-$($result.ThrottlePct)%)" } else { "" }
        $txtResult.Text = "Average: $($result.AvgFps) FPS$throttleNote"
        $btnAction.Content = "Close"
        $btnAction.IsEnabled = $true
    }.GetNewClosure()

    # NOTE: -CancelCheck must carry its own .GetNewClosure() here, not just rely on the outer
    # ContentRendered scriptblock's closure. $Script:GpuLoopTick (Start-GpuUncappedFrameLoop) is
    # itself a separate, detached GetNewClosure() - a bare `{ $popupState.Cancelled }` scriptblock
    # invoked via "& $CancelCheck" from inside that detached closure can't see $popupState (same
    # closure-isolation issue documented in BenchCpu.ps1 for $Script: vars), so Cancelled always
    # read back as $null/false - the Stop button's click was never actually detected by the loop,
    # leaving the popup stuck on "Stopping..." with Close unresponsive.
    $cancelCheck = { $popupState.Cancelled }.GetNewClosure()
    $dlg.Add_ContentRendered({
        # NOTE: this handler runs on a WPF event callback - in the compiled exe (ps2exe, no
        # console host) an unhandled exception here doesn't surface anywhere visible, it just
        # silently aborts before Start-GpuUncappedFrameLoop ever kicks off the tick loop. That
        # left the popup permanently stuck at "Running... 0/Ns" with Stop/Close unresponsive
        # (nothing was ever listening for Cancelled, because the loop never started). Wrap it so
        # a scene-building failure is visible in the log and the popup becomes closable instead
        # of hanging forever.
        try {
            if ($is3D) {
                Start-Gpu3DRenderBenchmark -Viewport $viewport -DurationSeconds $DurationSeconds `
                    -OnSample $onSample -CancelCheck $cancelCheck -OnComplete $onComplete
            } else {
                Start-GpuRenderBenchmark -Panel $renderPanel -DurationSeconds $DurationSeconds `
                    -OnSample $onSample -CancelCheck $cancelCheck -OnComplete $onComplete
            }
        } catch {
            Write-GuiLog "GPU benchmark failed to start: $($_.Exception.Message)" "ERR"
            $popupState.Done = $true
            $txtStatus.Text = "Error"
            $txtResult.Text = "$($_.Exception.Message)"
            $btnAction.Content = "Close"
            $btnAction.IsEnabled = $true
        }
    }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
    return $popupState.Result
}
