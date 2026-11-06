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

    Add-GuiCard "CPU Stress Test" "Runs a single-core pass followed by an all-core pass for each of three workload profiles - Integer (primality-test trial division), Float (trig/sqrt math) and Memory (random-access read/write over a large buffer) - counting work units per second sampled every second. Units differ per profile, so only compare a profile against itself (e.g. Integer before/after a tweak), not across profiles. This is a relative benchmark, not an absolute/portable score." {
        param($p)
        $durState = Add-GuiBenchDurationPicker $p
        # $Global:BenchCpuRunning/-Cancel (not locals) so the "Stop" click - which fires in a nested
        # dispatcher pump while this same handler is still blocking the UI thread inside
        # Get-CpuBenchmarkResult - can signal the running loop; see BenchCpu.ps1 top-of-file note on
        # why $Global: (not $Script:) is required for GetNewClosure() to see live, not snapshotted, values.
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
                Write-GuiLog "Starting CPU benchmark ($($durState.Seconds)s per profile)..." "STEP"
                $resultsStack = $Global:BenchCpuResultsStack
                $resultsStack.Children.Clear()
                Add-GuiIconTitle $resultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"

                # One single-core + one multi-core live chart per workload profile, keyed by type
                # name so the -OnSingleSample/-OnMultiSample callbacks (which now report which
                # profile is currently running) can route each sample to the right chart.
                $profileMeta = @(
                    @{ Type = "Integer"; Unit = "primes/s" }
                    @{ Type = "Float"; Unit = "units/s" }
                    @{ Type = "Memory"; Unit = "units/s" }
                )
                $singleCharts = @{}
                $multiCharts = @{}
                foreach ($pm in $profileMeta) {
                    $sectionTitle = New-Object System.Windows.Controls.TextBlock
                    $sectionTitle.Text = "$($pm.Type) - Single-Core ($($pm.Unit))"
                    $sectionTitle.FontSize = 12; $sectionTitle.Margin = "0,8,0,4"
                    $sectionTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($sectionTitle)
                    $singleCharts[$pm.Type] = New-GuiLiveChart $resultsStack -Unit $pm.Unit

                    $sectionTitle2 = New-Object System.Windows.Controls.TextBlock
                    $sectionTitle2.Text = "$($pm.Type) - Multi-Core ($($pm.Unit))"
                    $sectionTitle2.FontSize = 12; $sectionTitle2.Margin = "0,4,0,4"
                    $sectionTitle2.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($sectionTitle2)
                    $multiCharts[$pm.Type] = New-GuiLiveChart $resultsStack -Unit $pm.Unit
                }
                $Global:BenchCpuResultsCard.Visibility = "Visible"

                $deviceName = Get-BenchDeviceName "CPU"
                $result = Get-CpuBenchmarkResult -DurationSeconds $durState.Seconds `
                    -OnSingleSample { param($type, $v) Add-GuiLiveChartSample $singleCharts[$type] $v }.GetNewClosure() `
                    -OnMultiSample { param($type, $v) Add-GuiLiveChartSample $multiCharts[$type] $v }.GetNewClosure() `
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
                $resultsStack.AddChild($threadsText)

                foreach ($pm in $profileMeta) {
                    $prof = $result.($pm.Type)
                    if (-not $prof) { continue }
                    Add-GuiBenchStatTiles $resultsStack @(
                        @{Label="$($pm.Type) Single Avg"; Value=$prof.SingleScore}
                        @{Label="$($pm.Type) Multi Avg"; Value=$prof.MultiScore}
                        @{Label="$($pm.Type) MT/ST Ratio"; Value="$($prof.MtStRatio)x"}
                    )
                }

                $logParts = foreach ($pm in $profileMeta) {
                    $prof = $result.($pm.Type)
                    if ($prof) { "$($pm.Type) single=$($prof.SingleScore) multi=$($prof.MultiScore) (x$($prof.MtStRatio))" }
                }
                $logLine = "CPU benchmark - " + ($logParts -join ", ")
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
                    Integer         = $result.Integer
                    Float           = $result.Float
                    Memory          = $result.Memory
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
