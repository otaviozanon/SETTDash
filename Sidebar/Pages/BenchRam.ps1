# "Benchmark > RAM" page: runs Get-RamBenchmarkResult (Core/Actions/Benchmark/RamBenchmark.ps1) and
# renders write/copy throughput into a results card below the trigger card.
function Show-PageBenchRam {
    Clear-GuiContent
    Add-GuiPageTitle "RAM Benchmark"

    # NOTE: $Global:-scoped (not $Script:) - see comment in BenchCpu.ps1: GetNewClosure() snapshots
    # an isolated, detached copy of $Script: scope, so $Script: vars read back as $null in the
    # deferred click handler. $Global: does not have this problem.
    $Global:BenchRamResultsCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("InfoCardStyle"); if ($cardStyle) { $Global:BenchRamResultsCard.Style = $cardStyle }
    $Global:BenchRamResultsCard.Padding = "12"
    $Global:BenchRamResultsCard.Margin = "0,0,0,10"
    $Global:BenchRamResultsCard.Visibility = "Collapsed"
    $Global:BenchRamResultsStack = New-Object System.Windows.Controls.StackPanel
    $Global:BenchRamResultsCard.Child = $Global:BenchRamResultsStack

    Add-GuiCard "Memory Throughput Test" "Allocates a 512 MB buffer and measures sequential write throughput and copy throughput (read+write) across repeated individually-timed passes, split evenly across the selected test length. Use the scores to compare memory performance before/after applying tweaks - this is a relative benchmark, not an absolute/portable score." {
        param($p)
        $durState = Add-GuiBenchDurationPicker $p
        # See BenchCpu.ps1 for why these are $Global: (Stop click vs. GetNewClosure() scoping).
        $Global:BenchRamRunning = $false
        $Global:BenchRamCancel = $false
        $Global:BenchRamBtn = Add-GuiBtn $p "Run Benchmark" "ActionButtonStyle" {
            if ($Global:BenchRamRunning) {
                $Global:BenchRamCancel = $true
                Write-GuiLog "Stopping RAM benchmark..." "STEP"
                return
            }
            $Global:BenchRamRunning = $true
            $Global:BenchRamCancel = $false
            $Global:BenchRamBtn.Content = "Stop Benchmark"
            try {
                Write-GuiLog "Starting RAM benchmark ($($durState.Seconds)s)..." "STEP"
                $resultsStack = $Global:BenchRamResultsStack
                $resultsStack.Children.Clear()
                Add-GuiIconTitle $resultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"

                $writeTitle = New-Object System.Windows.Controls.TextBlock
                $writeTitle.Text = "Write Throughput (MB/s)"
                $writeTitle.FontSize = 12; $writeTitle.Margin = "0,8,0,4"
                $writeTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $resultsStack.AddChild($writeTitle)
                $writeChart = New-GuiLiveChart $resultsStack -Unit "MB/s"

                $copyTitle = New-Object System.Windows.Controls.TextBlock
                $copyTitle.Text = "Copy Throughput (MB/s)"
                $copyTitle.FontSize = 12; $copyTitle.Margin = "0,4,0,4"
                $copyTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $resultsStack.AddChild($copyTitle)
                $copyChart = New-GuiLiveChart $resultsStack -Unit "MB/s"
                $Global:BenchRamResultsCard.Visibility = "Visible"

                $result = Get-RamBenchmarkResult -DurationSeconds $durState.Seconds `
                    -OnWriteSample { param($v) Add-GuiLiveChartSample $writeChart $v }.GetNewClosure() `
                    -OnCopySample { param($v) Add-GuiLiveChartSample $copyChart $v }.GetNewClosure() `
                    -CancelCheck { $Global:BenchRamCancel }

                Complete-GuiLiveChart $writeChart
                Complete-GuiLiveChart $copyChart
                $bufferText = New-Object System.Windows.Controls.TextBlock
                $bufferText.FontSize = 12
                $bufferText.Margin = "0,0,0,8"
                $run = New-Object System.Windows.Documents.Run("Buffer Size: ")
                $run.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextSecondary")
                $bufferText.Inlines.Add($run)
                $valueRun = New-Object System.Windows.Documents.Run("$($result.BufferSizeMB) MB x $($result.Passes) passes")
                $valueRun.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextPrimary")
                $bufferText.Inlines.Add($valueRun)
                $resultsStack.AddChild($bufferText)
                Add-GuiBenchStatTiles $resultsStack @(
                    @{Label="Write Avg"; Value=$result.WriteMBs}
                    @{Label="Copy Avg"; Value=$result.CopyMBs}
                )

                if ($result.Cancelled) {
                    Write-GuiLog "RAM benchmark stopped - write: $($result.WriteMBs) MB/s, copy: $($result.CopyMBs) MB/s" "WARN"
                } else {
                    Write-GuiLog "RAM benchmark complete - write: $($result.WriteMBs) MB/s, copy: $($result.CopyMBs) MB/s" "OK"
                }

                # Pure-read + random-access latency sub-test (AIDA64-style Read/Latency scores).
                $rl = $null
                if (-not $Global:BenchRamCancel) {
                    Add-GuiIconTitle $resultsStack "&#xE950;" "Read / Latency" "#F0883E" -AccentTitle -TitleColor "#F0883E"
                    $readTitle = New-Object System.Windows.Controls.TextBlock
                    $readTitle.Text = "Read Throughput (MB/s)"
                    $readTitle.FontSize = 12; $readTitle.Margin = "0,8,0,4"
                    $readTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($readTitle)
                    $readChart = New-GuiLiveChart $resultsStack -Unit "MB/s"

                    $latTitle = New-Object System.Windows.Controls.TextBlock
                    $latTitle.Text = "Random-Access Latency (ns)"
                    $latTitle.FontSize = 12; $latTitle.Margin = "0,4,0,4"
                    $latTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($latTitle)
                    $latChart = New-GuiLiveChart $resultsStack -Unit "ns"

                    $rl = Get-RamReadLatencyResult -BufferSizeMB $result.BufferSizeMB -DurationSeconds ([math]::Min(20, $durState.Seconds)) `
                        -OnReadSample { param($v) Add-GuiLiveChartSample $readChart $v }.GetNewClosure() `
                        -OnLatencySample { param($v) Add-GuiLiveChartSample $latChart $v }.GetNewClosure() `
                        -CancelCheck { $Global:BenchRamCancel }
                    Complete-GuiLiveChart $readChart
                    Complete-GuiLiveChart $latChart

                    Add-GuiBenchStatTiles $resultsStack @(
                        @{Label="Read Avg"; Value="$($rl.ReadMBs) MB/s"}
                        @{Label="Latency"; Value="$($rl.LatencyNs) ns"}
                    )
                    Write-GuiLog "RAM read/latency - read: $($rl.ReadMBs) MB/s, latency: $($rl.LatencyNs) ns" "OK"
                }

                # Multi-threaded copy bandwidth sub-test (all-cores aggregate, AIDA64-style).
                $mt = $null
                if (-not $Global:BenchRamCancel) {
                    Add-GuiIconTitle $resultsStack "&#xE950;" "Multi-Thread Bandwidth" "#F0883E" -AccentTitle -TitleColor "#F0883E"
                    $mtTitle = New-Object System.Windows.Controls.TextBlock
                    $mtTitle.Text = "All-Core Copy Bandwidth (MB/s)"
                    $mtTitle.FontSize = 12; $mtTitle.Margin = "0,8,0,4"
                    $mtTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($mtTitle)
                    $mtChart = New-GuiLiveChart $resultsStack -Unit "MB/s"

                    $mt = Get-RamMultiThreadCopyResult -BufferSizeMB $result.BufferSizeMB -DurationSeconds ([math]::Min(15, $durState.Seconds)) `
                        -OnSample { param($v) Add-GuiLiveChartSample $mtChart $v }.GetNewClosure() `
                        -CancelCheck { $Global:BenchRamCancel }
                    Complete-GuiLiveChart $mtChart

                    Add-GuiBenchStatTiles $resultsStack @(
                        @{Label="MT Bandwidth"; Value="$($mt.AvgMBs) MB/s"}
                        @{Label="Threads"; Value=$mt.Threads}
                    )
                    Write-GuiLog "RAM multi-thread bandwidth - $($mt.AvgMBs) MB/s across $($mt.Threads) threads" "OK"
                }

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchRamLastResult = @{
                    DeviceName      = (Get-BenchDeviceName "RAM")
                    DurationSeconds = $durState.Seconds
                    BufferSizeMB    = $result.BufferSizeMB
                    Passes          = $result.Passes
                    WriteMBs        = $result.WriteMBs
                    CopyMBs         = $result.CopyMBs
                    ReadMBs         = if ($rl) { $rl.ReadMBs } else { $null }
                    LatencyNs       = if ($rl) { $rl.LatencyNs } else { $null }
                    MtBandwidthMBs  = if ($mt) { $mt.AvgMBs } else { $null }
                    MtThreads       = if ($mt) { $mt.Threads } else { $null }
                    Cancelled       = $result.Cancelled
                    Timestamp       = Get-Date
                }
            } finally {
                $Global:BenchRamRunning = $false
                $Global:BenchRamBtn.Content = "Run Benchmark"
            }
        }.GetNewClosure()
    } "&#xE950;" -WrapButtons

    $pnlContent.AddChild($Global:BenchRamResultsCard)
}
