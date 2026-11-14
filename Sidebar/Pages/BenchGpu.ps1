# "Benchmark > GPU" page: "Run Benchmark" opens a dedicated modal popup (Show-GpuBenchmarkPopup in
# Core/Actions/Benchmark/GpuBenchmark.ps1) that hosts the live preview + progress gauge while the
# test runs; this page shows only the duration picker and the final result tiles once it closes.
function Show-PageBenchGpu {
    Clear-GuiContent
    Add-GuiPageTitle (T "GPU Benchmark")

    # NOTE: $Global:-scoped (not $Script:) - see comment in BenchCpu.ps1: GetNewClosure() snapshots
    # an isolated, detached copy of $Script: scope, so $Script: vars read back as $null in the
    # deferred click handler. $Global: does not have this problem.
    $Global:BenchGpuResultsCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("InfoCardStyle"); if ($cardStyle) { $Global:BenchGpuResultsCard.Style = $cardStyle }
    $Global:BenchGpuResultsCard.Padding = "12"
    $Global:BenchGpuResultsCard.Margin = "0,0,0,10"
    $Global:BenchGpuResultsCard.Visibility = "Collapsed"
    $Global:BenchGpuResultsStack = New-Object System.Windows.Controls.StackPanel
    $Global:BenchGpuResultsCard.Child = $Global:BenchGpuResultsStack

    Add-GuiCard (T "GPU Benchmark") (T "Creates a real Direct3D11 hardware device and times three independent workloads with GPU timestamp queries - ALU (full-screen animated fractal pixel shader), Texture (2048x2048 texture, 16 bilinear taps per pixel) and Compute (4M-element structured buffer, 384 dependent sin/sqrt iterations per element). Each sub-test is split into blocks of about 45 ms of GPU work and scored from the median block time, and the composite is the geometric mean of the three sub-test FPS - so a card cannot hide a weak area behind one fast test. GPU timestamps measure what the GPU executed, not how fast the CPU could issue draw calls. Live GPU temperature, power and clock are sampled during the run. Use the score for before/after comparison (driver, overclock, undervolt), not as a cross-vendor ranking.") {
        param($p)

        $durState = Add-GuiBenchDurationPicker $p -Options @(30, 60, 120, 180, 240) -Default 30

        Add-GuiBtn $p (T "Run Benchmark") "ActionButtonStyle" {
            Write-GuiLog ((T "Starting GPU benchmark (total budget {0}s)...") -f $durState.Seconds) "STEP"

            # Show-GpuBenchmarkPopup blocks (ShowDialog) until the user closes the popup, which only
            # becomes possible once the run completes or is stopped - see that function.
            $result = Show-GpuBenchmarkPopup -DurationSeconds $durState.Seconds

            if (-not $result) {
                Write-GuiLog (T "GPU benchmark closed before producing a result.") "WARN"
                return
            }

            $Global:BenchGpuResultsStack.Children.Clear()
            Add-GuiIconTitle $Global:BenchGpuResultsStack "&#xE950;" (T "Results") "Brush_AccentWarm" -AccentTitle -TitleColor "Brush_AccentWarm"

            $info = New-Object System.Windows.Controls.TextBlock
            $info.FontSize = 12
            $info.Margin = "0,0,0,8"
            $info.TextWrapping = "Wrap"
            $info.Text = "$(T 'Render') $($result.Width)x$($result.Height) - $($result.FeatureLevel), $(T 'shader model') $($result.ShaderModel) - $(T 'elapsed') $($result.ElapsedSeconds)s"
            $info.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
            $Global:BenchGpuResultsStack.AddChild($info)

            # Headline row: the handful of numbers people actually screenshot/compare between runs.
            # Full detail (ms/frame, min/max, 1st/2nd-half drift, power, load) is still computed and
            # cached in $Global:BenchGpuLastResult for the Export page - just not cluttering this card.
            $stabilityLabel = if ($result.Throttling) { "$(T 'Throttling') (-$($result.ThrottlePct)%)" } else { T "Stable" }
            $tel = $result.Telemetry
            $tempText = if ($tel -and $tel.Available -and $null -ne $tel.MaxTemp -and $tel.MaxTemp -ne 0) { "$($tel.MaxTemp) °C" } else { T "N/A" }
            $clockText = if ($tel -and $tel.Available -and $null -ne $tel.MaxClock -and $tel.MaxClock -ne 0) { "$($tel.MaxClock) MHz" } else { T "N/A" }
            Add-GuiBenchStatTiles $Global:BenchGpuResultsStack @(
                @{Label=(T "Composite (FPS)"); Value=$result.CompositeFps}
                @{Label=(T "Stability"); Value=$stabilityLabel}
                @{Label=(T "Max GPU Temp"); Value=$tempText}
                @{Label=(T "GPU Clock"); Value=$clockText}
            )

            # Per sub-test FPS, one tile each, same row.
            $subTestTiles = foreach ($test in $result.Tests) { @{Label="$($test.Name) $(T 'FPS')"; Value=$test.Fps} }
            if ($subTestTiles.Count -gt 0) { Add-GuiBenchStatTiles $Global:BenchGpuResultsStack $subTestTiles }

            $Global:BenchGpuResultsCard.Visibility = "Visible"

            $parts = foreach ($test in $result.Tests) { "$($test.Name)=$($test.Fps) fps ($($test.MedianMs) ms)" }
            $logLine = (T "GPU benchmark - composite {0} fps [{1}] - {2}") -f $result.CompositeFps, ($parts -join ', '), $stabilityLabel
            if ($result.Cancelled) {
                Write-GuiLog ((T "{0} (stopped, partial)") -f $logLine) "WARN"
            } else {
                Write-GuiLog $logLine "OK"
            }

            # Cache the result (kept until the program closes) so the Export page can include it.
            $tel = $result.Telemetry
            $Global:BenchGpuLastResult = @{
                DeviceName      = (Get-BenchDeviceName "GPU")
                DurationSeconds = $durState.Seconds
                ElapsedSeconds  = $result.ElapsedSeconds
                Mode            = "Direct3D11 ($($result.FeatureLevel), SM $($result.ShaderModel))"
                CompositeFps    = $result.CompositeFps
                CompositeMs     = $result.CompositeMs
                Tests           = $result.Tests
                MaxTemp         = $(if ($tel -and $tel.Available -and $tel.MaxTemp -ne 0) { $tel.MaxTemp } else { $null })
                MaxPower        = $(if ($tel -and $tel.Available -and $tel.MaxPower -ne 0) { $tel.MaxPower } else { $null })
                MaxClock        = $(if ($tel -and $tel.Available -and $tel.MaxClock -ne 0) { $tel.MaxClock } else { $null })
                MaxLoad         = $(if ($tel -and $tel.Available -and $tel.MaxLoad -ne 0) { $tel.MaxLoad } else { $null })
                ThrottlePct     = $result.ThrottlePct
                Throttling      = $result.Throttling
                Cancelled       = $result.Cancelled
                Timestamp       = Get-Date
            }
        }.GetNewClosure()
    } "&#xE950;" -WrapButtons

    $pnlContent.AddChild($Global:BenchGpuResultsCard)
}
