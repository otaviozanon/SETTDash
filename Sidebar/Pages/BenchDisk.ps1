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
                Add-GuiIconTitle $resultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"

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

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchDiskLastResult = @{
                    DurationSeconds = $durState.Seconds
                    TotalSizeMB     = $result.TotalSizeMB
                    WriteMBs        = $result.WriteMBs
                    ReadMBs         = $result.ReadMBs
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
