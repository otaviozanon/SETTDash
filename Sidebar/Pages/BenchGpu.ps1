# "Benchmark > GPU" page: "Run Benchmark" opens a dedicated modal popup (Show-GpuBenchmarkPopup in
# Core/Actions/Benchmark/GpuBenchmark.ps1) that hosts the live preview + progress gauge while the
# test runs; this page shows only the duration picker and the final result tiles once it closes.
function Show-PageBenchGpu {
    Clear-GuiContent
    Add-GuiPageTitle "GPU Benchmark"

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

    Add-GuiCard "GPU Benchmark" "Creates a real Direct3D11 hardware device and times three independent workloads with GPU timestamp queries - ALU (full-screen animated fractal pixel shader), Texture (2048x2048 texture, 16 bilinear taps per pixel) and Compute (4M-element structured buffer, 384 dependent sin/sqrt iterations per element). Each sub-test is split into blocks of about 45 ms of GPU work and scored from the median block time, and the composite is the geometric mean of the three sub-test FPS - so a card cannot hide a weak area behind one fast test. GPU timestamps measure what the GPU executed, not how fast the CPU could issue draw calls. Live GPU temperature, power and clock are sampled during the run. Use the score for before/after comparison (driver, overclock, undervolt), not as a cross-vendor ranking." {
        param($p)

        $durState = Add-GuiBenchDurationPicker $p -Options @(30, 60, 120, 180, 240) -Default 30

        Add-GuiBtn $p "Run Benchmark" "ActionButtonStyle" {
            Write-GuiLog "Starting GPU benchmark (total budget $($durState.Seconds)s)..." "STEP"

            # Show-GpuBenchmarkPopup blocks (ShowDialog) until the user closes the popup, which only
            # becomes possible once the run completes or is stopped - see that function.
            $result = Show-GpuBenchmarkPopup -DurationSeconds $durState.Seconds

            if (-not $result) {
                Write-GuiLog "GPU benchmark closed before producing a result." "WARN"
                return
            }

            $Global:BenchGpuResultsStack.Children.Clear()
            Add-GuiIconTitle $Global:BenchGpuResultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"

            $info = New-Object System.Windows.Controls.TextBlock
            $info.FontSize = 12
            $info.Margin = "0,0,0,8"
            $info.TextWrapping = "Wrap"
            $info.Text = "Render $($result.Width)x$($result.Height) - $($result.FeatureLevel), shader model $($result.ShaderModel) - elapsed $($result.ElapsedSeconds)s"
            $info.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
            $Global:BenchGpuResultsStack.AddChild($info)

            $stabilityLabel = if ($result.Throttling) { "Throttling (-$($result.ThrottlePct)%)" } else { "Stable" }
            Add-GuiBenchStatTiles $Global:BenchGpuResultsStack @(
                @{Label="Composite (FPS)"; Value=$result.CompositeFps}
                @{Label="Composite (ms/frame)"; Value=$result.CompositeMs}
                @{Label="Worst 1st/2nd Half Drift"; Value="$($result.ThrottlePct)%"}
                @{Label="Stability"; Value=$stabilityLabel}
            )

            foreach ($test in $result.Tests) {
                Add-GuiBenchStatTiles $Global:BenchGpuResultsStack @(
                    @{Label="$($test.Name) FPS"; Value=$test.Fps}
                    @{Label="$($test.Name) ms/frame"; Value=$test.MedianMs}
                    @{Label="$($test.Name) min/max FPS"; Value="$($test.MinFps) / $($test.MaxFps)"}
                    @{Label="$($test.Name) drift 1st/2nd"; Value="$($test.FirstHalfFps) / $($test.SecondHalfFps)"}
                )
            }

            if ($result.Telemetry -and $result.Telemetry.Available) {
                $tel = $result.Telemetry
                $tempText = if ($null -ne $tel.MaxTemp -and $tel.MaxTemp -ne 0) { "$($tel.MaxTemp) °C" } else { "N/A" }
                $powerText = if ($null -ne $tel.MaxPower -and $tel.MaxPower -ne 0) { "$($tel.MaxPower) W" } else { "N/A" }
                $clockText = if ($null -ne $tel.MaxClock -and $tel.MaxClock -ne 0) { "$($tel.MinClock) - $($tel.MaxClock) MHz" } else { "N/A" }
                $loadText = if ($null -ne $tel.MaxLoad -and $tel.MaxLoad -ne 0) { "$($tel.MaxLoad) %" } else { "N/A" }
                Add-GuiBenchStatTiles $Global:BenchGpuResultsStack @(
                    @{Label="Max GPU Temp"; Value=$tempText}
                    @{Label="Max GPU Power"; Value=$powerText}
                    @{Label="GPU Clock"; Value=$clockText}
                    @{Label="Max GPU Load"; Value=$loadText}
                )
            }

            $Global:BenchGpuResultsCard.Visibility = "Visible"

            $parts = foreach ($test in $result.Tests) { "$($test.Name)=$($test.Fps) fps ($($test.MedianMs) ms)" }
            $logLine = "GPU benchmark - composite $($result.CompositeFps) fps [$($parts -join ', ')] - $stabilityLabel"
            if ($result.Cancelled) {
                Write-GuiLog "$logLine (stopped, partial)" "WARN"
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
