# "Benchmark > Disk" page: runs Get-DiskBenchmarkResult (Core/Actions/Benchmark/DiskBenchmark.ps1)
# and renders write/read throughput into a results card below the trigger card.
function Show-PageBenchDisk {
    Clear-GuiContent
    Add-GuiPageTitle "Disk Benchmark"

    # NOTE: $Global:-scoped (not $Script:) - see comment in BenchCpu.ps1: GetNewClosure() snapshots
    # an isolated, detached copy of $Script: scope, so $Script: vars read back as $null in the
    # deferred click handler. $Global: does not have this problem.
    $Global:BenchDiskResultsCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("InfoCardStyle"); if ($cardStyle) { $Global:BenchDiskResultsCard.Style = $cardStyle }
    $Global:BenchDiskResultsCard.Padding = "12"
    $Global:BenchDiskResultsCard.Margin = "0,0,0,10"
    $Global:BenchDiskResultsCard.Visibility = "Collapsed"
    $Global:BenchDiskResultsStack = New-Object System.Windows.Controls.StackPanel
    $Global:BenchDiskResultsCard.Child = $Global:BenchDiskResultsStack

    Add-GuiCard "Disk Read/Write Test" "Writes a temp file to disk (bypassing the OS write cache) in 64 MB chunks for half of the selected test length, then reads it all back, sampling MB/s per chunk in each direction. The temp file is deleted automatically. Read speed can be inflated by OS caching - use the scores for before/after comparison rather than an absolute number." {
        param($p)
        $durState = Add-GuiBenchDurationPicker $p
        # See BenchCpu.ps1 for why these are $Global: (Stop click vs. GetNewClosure() scoping).
        $Global:BenchDiskRunning = $false
        $Global:BenchDiskCancel = $false
        $Global:BenchDiskBtn = Add-GuiBtn $p "Run Benchmark" "ActionButtonStyle" {
            if ($Global:BenchDiskRunning) {
                $Global:BenchDiskCancel = $true
                Write-GuiLog "Stopping Disk benchmark..." "STEP"
                return
            }
            $Global:BenchDiskRunning = $true
            $Global:BenchDiskCancel = $false
            $Global:BenchDiskBtn.Content = "Stop Benchmark"
            try {
                Write-GuiLog "Starting Disk benchmark ($($durState.Seconds)s)..." "STEP"
                $resultsStack = $Global:BenchDiskResultsStack
                $resultsStack.Children.Clear()
                Add-GuiIconTitle $resultsStack "&#xE950;" "Results" "Brush_AccentWarm" -AccentTitle -TitleColor "Brush_AccentWarm"

                $writeTitle = New-Object System.Windows.Controls.TextBlock
                $writeTitle.Text = "Write Speed (MB/s)"
                $writeTitle.FontSize = 12; $writeTitle.Margin = "0,8,0,4"
                $writeTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $resultsStack.AddChild($writeTitle)
                $writeChart = New-GuiLiveChart $resultsStack -Unit "MB/s"

                $readTitle = New-Object System.Windows.Controls.TextBlock
                $readTitle.Text = "Read Speed (MB/s)"
                $readTitle.FontSize = 12; $readTitle.Margin = "0,4,0,4"
                $readTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                $resultsStack.AddChild($readTitle)
                $readChart = New-GuiLiveChart $resultsStack -Unit "MB/s"
                $Global:BenchDiskResultsCard.Visibility = "Visible"

                $result = Get-DiskBenchmarkResult -DurationSeconds $durState.Seconds `
                    -OnWriteSample { param($v) Add-GuiLiveChartSample $writeChart $v }.GetNewClosure() `
                    -OnReadSample { param($v) Add-GuiLiveChartSample $readChart $v }.GetNewClosure() `
                    -CancelCheck { $Global:BenchDiskCancel }

                Complete-GuiLiveChart $writeChart
                Complete-GuiLiveChart $readChart
                $sizeText = New-Object System.Windows.Controls.TextBlock
                $sizeText.FontSize = 12
                $sizeText.Margin = "0,0,0,8"
                $run = New-Object System.Windows.Documents.Run("Test File Size: ")
                $run.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextSecondary")
                $sizeText.Inlines.Add($run)
                $valueRun = New-Object System.Windows.Documents.Run("$($result.TotalSizeMB) MB")
                $valueRun.SetResourceReference([System.Windows.Documents.Run]::ForegroundProperty, "Brush_TextPrimary")
                $sizeText.Inlines.Add($valueRun)
                $resultsStack.AddChild($sizeText)
                Add-GuiBenchStatTiles $resultsStack @(
                    @{Label="Write Avg"; Value=$result.WriteMBs}
                    @{Label="Read Avg"; Value=$result.ReadMBs}
                )

                if ($result.Cancelled) {
                    Write-GuiLog "Disk benchmark stopped - write: $($result.WriteMBs) MB/s, read: $($result.ReadMBs) MB/s" "WARN"
                } else {
                    Write-GuiLog "Disk benchmark complete - write: $($result.WriteMBs) MB/s, read: $($result.ReadMBs) MB/s" "OK"
                }

                # Random 4K IOPS sub-test (CrystalDiskMark-style RND4K Q1T1) - bypasses the OS cache
                # entirely, unlike the sequential read above, so it actually hits the device.
                $r4k = $null
                if (-not $Global:BenchDiskCancel) {
                    Add-GuiIconTitle $resultsStack "&#xE950;" "Random 4K (Q1T1)" "Brush_AccentWarm" -AccentTitle -TitleColor "Brush_AccentWarm"
                    $write4kTitle = New-Object System.Windows.Controls.TextBlock
                    $write4kTitle.Text = "Write IOPS"
                    $write4kTitle.FontSize = 12; $write4kTitle.Margin = "0,8,0,4"
                    $write4kTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($write4kTitle)
                    $write4kChart = New-GuiLiveChart $resultsStack -Unit "IOPS"

                    $read4kTitle = New-Object System.Windows.Controls.TextBlock
                    $read4kTitle.Text = "Read IOPS"
                    $read4kTitle.FontSize = 12; $read4kTitle.Margin = "0,4,0,4"
                    $read4kTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($read4kTitle)
                    $read4kChart = New-GuiLiveChart $resultsStack -Unit "IOPS"

                    $r4k = Get-Disk4kRandomResult -DurationSeconds ([math]::Min(20, $durState.Seconds)) `
                        -OnWriteSample { param($v) Add-GuiLiveChartSample $write4kChart $v }.GetNewClosure() `
                        -OnReadSample { param($v) Add-GuiLiveChartSample $read4kChart $v }.GetNewClosure() `
                        -CancelCheck { $Global:BenchDiskCancel }
                    Complete-GuiLiveChart $write4kChart
                    Complete-GuiLiveChart $read4kChart

                    if ($r4k) {
                        Add-GuiBenchStatTiles $resultsStack @(
                            @{Label="4K Write IOPS"; Value=$r4k.WriteIops}
                            @{Label="4K Read IOPS"; Value=$r4k.ReadIops}
                        )
                        Write-GuiLog "Disk 4K random - write: $($r4k.WriteIops) IOPS, read: $($r4k.ReadIops) IOPS" "OK"
                    } else {
                        $naText = New-Object System.Windows.Controls.TextBlock
                        $naText.Text = "Not available on this drive/filesystem."
                        $naText.FontSize = 12; $naText.Margin = "0,0,0,8"
                        $naText.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                        $resultsStack.AddChild($naText)
                    }
                }

                # Queue depth / multi-thread random 4K read sub-test (CrystalDiskMark-style RND4K
                # Q32T1) - shows a modern NVMe drive's real ceiling, which Q1T1 alone doesn't reveal.
                $qd = $null
                if (-not $Global:BenchDiskCancel) {
                    Add-GuiIconTitle $resultsStack "&#xE950;" "Random 4K (Queue Depth)" "Brush_AccentWarm" -AccentTitle -TitleColor "Brush_AccentWarm"
                    $qdTitle = New-Object System.Windows.Controls.TextBlock
                    $qdTitle.Text = "Read IOPS (multi-threaded)"
                    $qdTitle.FontSize = 12; $qdTitle.Margin = "0,8,0,4"
                    $qdTitle.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                    $resultsStack.AddChild($qdTitle)
                    $qdChart = New-GuiLiveChart $resultsStack -Unit "IOPS"

                    $qd = Get-DiskQueueDepthResult -DurationSeconds ([math]::Min(15, $durState.Seconds)) `
                        -OnSample { param($v) Add-GuiLiveChartSample $qdChart $v }.GetNewClosure() `
                        -CancelCheck { $Global:BenchDiskCancel }
                    Complete-GuiLiveChart $qdChart

                    if ($qd) {
                        Add-GuiBenchStatTiles $resultsStack @(
                            @{Label="QD Read IOPS"; Value=$qd.Iops}
                            @{Label="Threads"; Value=$qd.Threads}
                        )
                        Write-GuiLog "Disk queue-depth random 4K - $($qd.Iops) IOPS across $($qd.Threads) threads" "OK"
                    } else {
                        $naText2 = New-Object System.Windows.Controls.TextBlock
                        $naText2.Text = "Not available on this drive/filesystem."
                        $naText2.FontSize = 12; $naText2.Margin = "0,0,0,8"
                        $naText2.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
                        $resultsStack.AddChild($naText2)
                    }
                }

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchDiskLastResult = @{
                    DeviceName      = (Get-BenchDeviceName "Disk")
                    DurationSeconds = $durState.Seconds
                    TotalSizeMB     = $result.TotalSizeMB
                    WriteMBs        = $result.WriteMBs
                    ReadMBs         = $result.ReadMBs
                    Write4kIops     = if ($r4k) { $r4k.WriteIops } else { $null }
                    Read4kIops      = if ($r4k) { $r4k.ReadIops } else { $null }
                    QdReadIops      = if ($qd) { $qd.Iops } else { $null }
                    QdThreads       = if ($qd) { $qd.Threads } else { $null }
                    Cancelled       = $result.Cancelled
                    Timestamp       = Get-Date
                }
            } finally {
                $Global:BenchDiskRunning = $false
                $Global:BenchDiskBtn.Content = "Run Benchmark"
            }
        }.GetNewClosure()
    } "&#xE950;" -WrapButtons

    $pnlContent.AddChild($Global:BenchDiskResultsCard)
}
