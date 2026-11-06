# "Benchmark > GPU" page: "Run Benchmark" opens a dedicated modal popup (Show-GpuBenchmarkPopup in
# Core/Actions/Benchmark/GpuBenchmark.ps1) that hosts the actual render surface + a live FPS gauge
# while the test runs; this page only shows the mode/duration pickers and the final Avg FPS result
# tile once the popup closes - a WPF-compositor rendering proxy, not a raw GPU shader/compute benchmark.
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

    Add-GuiCard "Rendering Stress Test" "Opens a popup that creates a real Direct3D11 hardware device and renders an animated fractal pixel shader off-screen as fast as the GPU/driver can retire frames, with a live preview, for the selected test length. This measures genuine GPU/driver shader throughput - use the score for before/after comparison (e.g. after a driver update), not as a cross-vendor benchmark." {
        param($p)

        # Test length dropdown (replaces the pill picker used by CPU/RAM/Disk - Add-GuiBenchDurationPicker
        # in Core/Helpers/Cards.ps1 - with a ComboBox, per request for this page specifically).
        $durLabel = New-Object System.Windows.Controls.TextBlock
        $durLabel.Text = "Test length:"
        $durLabel.FontSize = 12
        $durLabel.VerticalAlignment = "Center"
        $durLabel.Margin = "0,0,8,0"
        $durLabel.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
        $p.AddChild($durLabel)

        $durOptions = @(30, 60, 120)
        $durState = [PSCustomObject]@{ Seconds = $durOptions[0] }
        $durCombo = New-GuiThemedComboBox -Width 100
        foreach ($opt in $durOptions) { $durCombo.Items.Add("${opt}s") | Out-Null }
        $durCombo.SelectedIndex = 0
        $durCombo.Add_SelectionChanged({
            if ($durCombo.SelectedIndex -ge 0) { $durState.Seconds = $durOptions[$durCombo.SelectedIndex] }
        }.GetNewClosure())
        $p.AddChild($durCombo)

        Add-GuiBtn $p "Run Benchmark" "ActionButtonStyle" {
            $modeName = "D3D11 Hardware"
            Write-GuiLog "Starting GPU render benchmark - $modeName ($($durState.Seconds)s)..." "STEP"

            # Show-GpuBenchmarkPopup blocks (ShowDialog) until the user closes the popup, which
            # only becomes possible once the run completes or is stopped - see that function.
            $result = Show-GpuBenchmarkPopup -Mode "D3D11" -DurationSeconds $durState.Seconds

            if ($result) {
                $Global:BenchGpuResultsStack.Children.Clear()
                Add-GuiIconTitle $Global:BenchGpuResultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"
                $stabilityLabel = if ($result.Throttling) { "Throttling (-$($result.ThrottlePct)%)" } else { "Stable" }
                Add-GuiBenchStatTiles $Global:BenchGpuResultsStack @(
                    @{Label="Avg FPS"; Value=$result.AvgFps}
                    @{Label="1st/2nd Half"; Value="$($result.FirstHalfFps) / $($result.SecondHalfFps)"}
                    @{Label="Stability"; Value=$stabilityLabel}
                )
                $Global:BenchGpuResultsCard.Visibility = "Visible"
                if ($result.Cancelled) {
                    Write-GuiLog "GPU render benchmark stopped ($modeName) - average FPS: $($result.AvgFps)" "WARN"
                } else {
                    Write-GuiLog "GPU render benchmark complete ($modeName) - average FPS: $($result.AvgFps) ($stabilityLabel)" "OK"
                }

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchGpuLastResult = @{
                    DeviceName      = (Get-BenchDeviceName "GPU")
                    DurationSeconds = $durState.Seconds
                    Mode            = $modeName
                    AvgFps          = $result.AvgFps
                    FirstHalfFps    = $result.FirstHalfFps
                    SecondHalfFps   = $result.SecondHalfFps
                    ThrottlePct     = $result.ThrottlePct
                    Throttling      = $result.Throttling
                    Cancelled       = $result.Cancelled
                    Timestamp       = Get-Date
                }
            }
        }.GetNewClosure()
    } "&#xE950;" -WrapButtons

    $pnlContent.AddChild($Global:BenchGpuResultsCard)
}
