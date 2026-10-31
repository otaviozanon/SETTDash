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

    Add-GuiCard "CPU Stress Test" "Runs a single-core pass followed by an all-core pass (each half the selected test length - long enough to ride out boost/thermal ramp-up), counting primality-test iterations per second sampled every second. Use the scores to compare performance before/after applying SETTDash's Performance tweaks - this is a relative benchmark, not an absolute/portable score." {
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
                Write-GuiLog "Starting CPU benchmark ($($durState.Seconds)s)..." "STEP"
                $resultsStack = $Global:BenchCpuResultsStack
                $resultsStack.Children.Clear()
                Add-GuiIconTitle $resultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"

                $singleTitle = New-Object System.Windows.Controls.TextBlock
                $singleTitle.Text = "Single-Core (iterations/s)"
                $singleTitle.FontSize = 12; $singleTitle.Margin = "0,8,0,4"
                $singleTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $resultsStack.AddChild($singleTitle)
                $singleChart = New-GuiLiveChart $resultsStack -Unit "it/s"

                $multiTitle = New-Object System.Windows.Controls.TextBlock
                $multiTitle.Text = "Multi-Core (iterations/s)"
                $multiTitle.FontSize = 12; $multiTitle.Margin = "0,4,0,4"
                $multiTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $resultsStack.AddChild($multiTitle)
                $multiChart = New-GuiLiveChart $resultsStack -Unit "it/s"
                $Global:BenchCpuResultsCard.Visibility = "Visible"

                $result = Get-CpuBenchmarkResult -DurationSeconds $durState.Seconds `
                    -OnSingleSample { param($v) Add-GuiLiveChartSample $singleChart $v }.GetNewClosure() `
                    -OnMultiSample { param($v) Add-GuiLiveChartSample $multiChart $v }.GetNewClosure() `
                    -CancelCheck { $Global:BenchCpuCancel }

                Complete-GuiLiveChart $singleChart
                Complete-GuiLiveChart $multiChart
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
                Add-GuiBenchStatTiles $resultsStack @(
                    @{Label="Single Avg"; Value=$result.SingleScore}
                    @{Label="Multi Avg"; Value=$result.MultiScore}
                )

                if ($result.Cancelled) {
                    Write-GuiLog "CPU benchmark stopped - single: $($result.SingleScore) it/s, multi: $($result.MultiScore) it/s" "WARN"
                } else {
                    Write-GuiLog "CPU benchmark complete - single: $($result.SingleScore) it/s, multi: $($result.MultiScore) it/s" "OK"
                }

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchCpuLastResult = @{
                    DurationSeconds = $durState.Seconds
                    Threads         = $result.Threads
                    SingleScore     = $result.SingleScore
                    MultiScore      = $result.MultiScore
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
