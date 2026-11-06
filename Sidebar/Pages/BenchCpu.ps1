# "Benchmark > CPU" page: runs Get-CpuBenchmarkResult (Core/Actions/Benchmark/CpuBenchmark.ps1) and
# renders single-core/multi-core scores into a results card below the trigger card. Same
# card-then-results layout reused by the GPU/RAM/Disk benchmark pages.
function Show-PageBenchCpu {
    Clear-GuiContent
    Add-GuiPageTitle "CPU Benchmark"

    # NOTE: these are $Global:-scoped (not locals, and NOT $Script: either) because
    # GetNewClosure() on the "Run Benchmark" button handler snapshots an isolated, detached copy
    # of the enclosing $Script: scope at closure-creation time - so $Script: variables set here
    # read back as $null inside the deferred click handler, even though $Global: does not have
    # this problem (confirmed by isolated repro). Without this, the closure crossing the
    # Add-GuiCard/Add-GuiBtn function-call boundary captured $null, causing "cannot call a method
    # on a null-valued expression" at click time.
    $Global:BenchCpuResultsCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("InfoCardStyle"); if ($cardStyle) { $Global:BenchCpuResultsCard.Style = $cardStyle }
    $Global:BenchCpuResultsCard.Padding = "12"
    $Global:BenchCpuResultsCard.Margin = "0,0,0,10"
    $Global:BenchCpuResultsCard.Visibility = "Collapsed"
    $Global:BenchCpuResultsStack = New-Object System.Windows.Controls.StackPanel
    $Global:BenchCpuResultsCard.Child = $Global:BenchCpuResultsStack

    Add-GuiCard "CPU Benchmark" "Three compiled workloads, each timed single-core and then on every logical CPU: Integer (xorshift/rotate ALU chain with a data-dependent branch), Float (eight independent mul/add chains plus a throughput sqrt) and Hash (64-bit FNV-style mixing over a 4 MB cache-resident buffer). Each pass is split into short individually timed blocks and the reported score is the median block, with threads pinned to one logical CPU each, at high priority and with Windows power throttling disabled - so the number tracks the CPU instead of the scheduler. Compare a workload against itself across machines or runs; the three units are not comparable with each other. This is a relative benchmark, not an absolute/portable score." {
        param($p)
        $durState = Add-GuiBenchDurationPicker $p -Options @(30, 60, 120, 180, 240) -Default 30
        # $Global:BenchCpuRunning/-Cancel (not locals) so the "Stop" click - which fires in a nested
        # dispatcher pump while this same handler is still blocking the UI thread inside
        # Get-CpuBenchmarkResult - can signal the running loop; see the top-of-file note on why
        # $Global: (not $Script:) is required for GetNewClosure() to see live, not snapshotted, values.
        $Global:BenchCpuRunning = $false
        $Global:BenchCpuCancel = $false
        # Live telemetry tiles updated while the benchmark runs (not just at the end).
        $Global:BenchCpuTempText = New-Object System.Windows.Controls.TextBlock
        $Global:BenchCpuTempText.FontSize = 13; $Global:BenchCpuTempText.FontWeight = "Bold"
        $Global:BenchCpuTempText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $Global:BenchCpuPowerText = New-Object System.Windows.Controls.TextBlock
        $Global:BenchCpuPowerText.FontSize = 13; $Global:BenchCpuPowerText.FontWeight = "Bold"
        $Global:BenchCpuPowerText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $Global:BenchCpuClockText = New-Object System.Windows.Controls.TextBlock
        $Global:BenchCpuClockText.FontSize = 13; $Global:BenchCpuClockText.FontWeight = "Bold"
        $Global:BenchCpuClockText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $Global:BenchCpuLoadText = New-Object System.Windows.Controls.TextBlock
        $Global:BenchCpuLoadText.FontSize = 13; $Global:BenchCpuLoadText.FontWeight = "Bold"
        $Global:BenchCpuLoadText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextPrimary")
        $Global:BenchCpuBtn = Add-GuiBtn $p "Run Benchmark" "ActionButtonStyle" {
            if ($Global:BenchCpuRunning) {
                $Global:BenchCpuCancel = $true
                Write-GuiLog "Stopping CPU benchmark..." "STEP"
                return
            }
            $Global:BenchCpuRunning = $true
            $Global:BenchCpuCancel = $false
            $Global:BenchCpuBtn.Content = "Stop Benchmark"
            try {
                Write-GuiLog "Starting CPU benchmark (total budget $($durState.Seconds)s)..." "STEP"
                $resultsStack = $Global:BenchCpuResultsStack
                $resultsStack.Children.Clear()
                Add-GuiIconTitle $resultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"

                # Live telemetry strip (first item, centered above the charts) - updated every
                # telemetry sample while the benchmark runs, with no "Live:" prefix label.
                $telBox = New-Object System.Windows.Controls.Border
                $telBox.Margin = "0,6,0,10"
                $telBox.HorizontalAlignment = "Center"
                $telBox.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, "Brush_CardBg")
                $telBox.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, "Brush_CardBorder")
                $telBox.BorderThickness = "1"
                $telBox.SetResourceReference([System.Windows.Controls.Border]::CornerRadiusProperty, "Theme_CornerRadius")
                $telBox.Padding = "8,4,8,4"
                $telStrip = New-Object System.Windows.Controls.StackPanel
                $telStrip.Orientation = "Horizontal"
                $telStrip.HorizontalAlignment = "Center"
                $telBox.Child = $telStrip
                $telStrip.Children.Add($Global:BenchCpuTempText)
                $telSep1 = New-Object System.Windows.Controls.TextBlock
                $telSep1.Text = "   |   "
                $telSep1.FontSize = 11
                $telSep1.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $telStrip.Children.Add($telSep1)
                $telStrip.Children.Add($Global:BenchCpuPowerText)
                $telSep2 = New-Object System.Windows.Controls.TextBlock
                $telSep2.Text = "   |   "
                $telSep2.FontSize = 11
                $telSep2.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $telStrip.Children.Add($telSep2)
                $telStrip.Children.Add($Global:BenchCpuClockText)
                $telSep3 = New-Object System.Windows.Controls.TextBlock
                $telSep3.Text = "   |   "
                $telSep3.FontSize = 11
                $telSep3.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $telStrip.Children.Add($telSep3)
                $telStrip.Children.Add($Global:BenchCpuLoadText)
                $resultsStack.AddChild($telBox)

                # One single-core + one multi-core live chart per kernel, keyed by kernel name so the
                # -OnSingleSample/-OnMultiSample callbacks (which report which kernel is running) can
                # route each block sample to the right chart.
                $kernelMeta = @(
                    @{ Kernel = "Integer"; Label = "Integer ALU + branch"; Unit = "Mops/s" }
                    @{ Kernel = "Float";   Label = "Float mul/add + sqrt"; Unit = "Mflop/s" }
                    @{ Kernel = "Hash";    Label = "Hash (cache + ALU)";  Unit = "MB/s" }
                )
                $singleCharts = @{}
                $multiCharts = @{}
                foreach ($km in $kernelMeta) {
                    $sectionTitle = New-Object System.Windows.Controls.TextBlock
                    $sectionTitle.Text = "$($km.Label) - Single-Core ($($km.Unit))"
                    $sectionTitle.FontSize = 12; $sectionTitle.Margin = "0,8,0,4"
                    $sectionTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($sectionTitle)
                    $singleCharts[$km.Kernel] = New-GuiLiveChart $resultsStack -Unit $km.Unit

                    $sectionTitle2 = New-Object System.Windows.Controls.TextBlock
                    $sectionTitle2.Text = "$($km.Label) - All-Core ($($km.Unit))"
                    $sectionTitle2.FontSize = 12; $sectionTitle2.Margin = "0,4,0,4"
                    $sectionTitle2.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($sectionTitle2)
                    $multiCharts[$km.Kernel] = New-GuiLiveChart $resultsStack -Unit $km.Unit
                }
                $Global:BenchCpuResultsCard.Visibility = "Visible"

                $deviceName = Get-BenchDeviceName "CPU"
                $result = Get-CpuBenchmarkResult -DurationSeconds $durState.Seconds `
                    -OnSingleSample { param($kernel, $v) Add-GuiLiveChartSample $singleCharts[$kernel] $v }.GetNewClosure() `
                    -OnMultiSample { param($kernel, $v) Add-GuiLiveChartSample $multiCharts[$kernel] $v }.GetNewClosure() `
                    -OnTelemetrySample { param($t) Update-GuiCpuTelemetryTiles $t }.GetNewClosure() `
                    -CancelCheck { $Global:BenchCpuCancel }

                foreach ($chart in $singleCharts.Values) { Complete-GuiLiveChart $chart }
                foreach ($chart in $multiCharts.Values) { Complete-GuiLiveChart $chart }

                $threadsText = New-Object System.Windows.Controls.TextBlock
                $threadsText.FontSize = 12
                $threadsText.Margin = "0,0,0,8"
                $run = New-Object System.Windows.Documents.Run("Logical Threads: ")
                $run.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextSecondary")
                $threadsText.Inlines.Add($run)
                $valueRun = New-Object System.Windows.Documents.Run("$($result.Threads)")
                $valueRun.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextPrimary")
                $threadsText.Inlines.Add($valueRun)
                $run2 = New-Object System.Windows.Documents.Run("   Blocks per pass: ")
                $run2.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextSecondary")
                $threadsText.Inlines.Add($run2)
                $valueRun2 = New-Object System.Windows.Documents.Run("$($result.Blocks)")
                $valueRun2.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextPrimary")
                $threadsText.Inlines.Add($valueRun2)
                $run3 = New-Object System.Windows.Documents.Run("   Elapsed: ")
                $run3.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextSecondary")
                $threadsText.Inlines.Add($run3)
                $valueRun3 = New-Object System.Windows.Documents.Run("$($result.ElapsedSeconds)s")
                $valueRun3.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextPrimary")
                $threadsText.Inlines.Add($valueRun3)
                $resultsStack.AddChild($threadsText)

                $kernelResults = @{}
                foreach ($km in $kernelMeta) {
                    $prof = $result.($km.Kernel)
                    if (-not $prof) { continue }
                    $kernelResults[$km.Kernel] = $prof
                    Add-GuiBenchStatTiles $resultsStack @(
                        @{Label="$($km.Kernel) Single ($($km.Unit))"; Value=$prof.SingleScore}
                        @{Label="$($km.Kernel) All-Core ($($km.Unit))"; Value=$prof.MultiScore}
                        @{Label="$($km.Kernel) MT/ST"; Value="$($prof.MtStRatio)x"}
                    )
                }

                # Live CPU temperature/power/clock/load captured while the benchmark ran (peak
                # values). Hidden entirely when LibreHardwareMonitor is unavailable rather than
                # showing a fake number. A reading of 0 means the sensor could not be queried.
                $tel = $result.Telemetry
                if ($tel -and $tel.Available) {
                    $tempText = if ($null -ne $tel.MaxTemp -and $tel.MaxTemp -ne 0) { "$($tel.MaxTemp) °C" } else { "N/A" }
                    $powerText = if ($null -ne $tel.MaxPower -and $tel.MaxPower -ne 0) { "$($tel.MaxPower) W" } else { "N/A" }
                    $clockText = if ($null -ne $tel.MaxClock -and $tel.MaxClock -ne 0) { "$($tel.MaxClock) MHz" } else { "N/A" }
                    $loadText = if ($null -ne $tel.MaxLoad -and $tel.MaxLoad -ne 0) { "$($tel.MaxLoad) %" } else { "N/A" }
                    Add-GuiBenchStatTiles $resultsStack @(
                        @{Label="Max CPU Temp"; Value=$tempText}
                        @{Label="Max CPU Power"; Value=$powerText}
                        @{Label="Max CPU Clock"; Value=$clockText}
                        @{Label="Max CPU Load"; Value=$loadText}
                    )
                }

                $logParts = foreach ($km in $kernelMeta) {
                    $prof = $result.($km.Kernel)
                    if ($prof) { "$($km.Kernel) $($prof.SingleScore)/$($prof.MultiScore) $($km.Unit) (x$($prof.MtStRatio))" }
                }
                $logLine = "CPU benchmark - " + ($logParts -join ", ")
                if ($tel -and $tel.Available -and $null -ne $tel.MaxTemp -and $tel.MaxTemp -ne 0) { $logLine += " - max temp $($tel.MaxTemp) °C" }
                if ($result.Cancelled) {
                    Write-GuiLog "$logLine (stopped)" "WARN"
                } else {
                    Write-GuiLog $logLine "OK"
                }

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchCpuLastResult = @{
                    DeviceName      = $deviceName
                    DurationSeconds = $durState.Seconds
                    Threads         = $result.Threads
                    Blocks          = $result.Blocks
                    ElapsedSeconds  = $result.ElapsedSeconds
                    Integer         = $kernelResults["Integer"]
                    Float           = $kernelResults["Float"]
                    Hash            = $kernelResults["Hash"]
                    MaxTemp         = $(if ($tel -and $tel.Available -and $tel.MaxTemp -ne 0) { $tel.MaxTemp } else { $null })
                    MaxPower        = $(if ($tel -and $tel.Available -and $tel.MaxPower -ne 0) { $tel.MaxPower } else { $null })
                    MaxClock        = $(if ($tel -and $tel.Available -and $tel.MaxClock -ne 0) { $tel.MaxClock } else { $null })
                    MaxLoad         = $(if ($tel -and $tel.Available -and $tel.MaxLoad -ne 0) { $tel.MaxLoad } else { $null })
                    Cancelled       = $result.Cancelled
                    Timestamp       = Get-Date
                }
            } finally {
                $Global:BenchCpuRunning = $false
                $Global:BenchCpuBtn.Content = "Run Benchmark"
            }
        }.GetNewClosure()
    } "&#xE950;" -WrapButtons

    $pnlContent.AddChild($Global:BenchCpuResultsCard)
}

# Updates the live telemetry strip from inside Get-CpuBenchmarkResult (called via OnTelemetrySample
# once per telemetry sample, ~1/s). Runs on the UI dispatcher because Get-CpuBenchmarkResult pumps
# the dispatcher via Set-GuiProgress between blocks.
function Update-GuiCpuTelemetryTiles {
    param($t)
    $tempText = if ($null -ne $t.MaxTemp -and $t.MaxTemp -ne 0) { "$($t.MaxTemp) °C" } else { "-- °C" }
    $powerText = if ($null -ne $t.MaxPower -and $t.MaxPower -ne 0) { "$($t.MaxPower) W" } else { "-- W" }
    $clockText = if ($null -ne $t.MaxClock -and $t.MaxClock -ne 0) { "$($t.MaxClock) MHz" } else { "-- MHz" }
    $loadText = if ($null -ne $t.MaxLoad -and $t.MaxLoad -ne 0) { "$($t.MaxLoad) %" } else { "-- %" }
    $Global:BenchCpuTempText.Text  = "CPU Temp: $tempText"
    $Global:BenchCpuPowerText.Text = "Power: $powerText"
    $Global:BenchCpuClockText.Text = "Clock: $clockText"
    $Global:BenchCpuLoadText.Text  = "Load: $loadText"
}
