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
        $durState = Add-GuiBenchDurationPicker $p -Options @(10, 20, 30) -Default 20
        # $Global:BenchCpuRunning/-Cancel (not locals) so the "Stop" click - which fires in a nested
        # dispatcher pump while this same handler is still blocking the UI thread inside
        # Get-CpuBenchmarkResult - can signal the running loop; see the top-of-file note on why
        # $Global: (not $Script:) is required for GetNewClosure() to see live, not snapshotted, values.
        $Global:BenchCpuRunning = $false
        $Global:BenchCpuCancel = $false
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
                # showing a fake number.
                $tel = $result.Telemetry
                if ($tel -and $tel.Available) {
                    $tempText = if ($null -ne $tel.MaxTemp) { "$($tel.MaxTemp) °C" } else { "N/A" }
                    $powerText = if ($null -ne $tel.MaxPower) { "$($tel.MaxPower) W" } else { "N/A" }
                    $clockText = if ($null -ne $tel.MaxClock) { "$($tel.MaxClock) MHz" } else { "N/A" }
                    $loadText = if ($null -ne $tel.MaxLoad) { "$($tel.MaxLoad) %" } else { "N/A" }
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
                if ($tel -and $tel.Available -and $null -ne $tel.MaxTemp) { $logLine += " - max temp $($tel.MaxTemp) °C" }
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
                    MaxTemp         = $(if ($tel) { $tel.MaxTemp } else { $null })
                    MaxPower        = $(if ($tel) { $tel.MaxPower } else { $null })
                    MaxClock        = $(if ($tel) { $tel.MaxClock } else { $null })
                    MaxLoad         = $(if ($tel) { $tel.MaxLoad } else { $null })
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
