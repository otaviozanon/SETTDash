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

    Add-GuiCard "Rendering Stress Test" "Opens a popup that animates either a grid of rotating 2D shapes or a lit, rotating 3D mesh scene via WPF's hardware-accelerated compositor for the selected test length - long enough to ride out compositor/driver warmup - sampling FPS every second on a live gauge. This exercises the GPU driver/compositor rendering path, not a raw shader/compute workload - use the score for before/after comparison (e.g. after a driver update), not as a cross-vendor benchmark." {
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

        # Test type dropdown (2D Compositor / 3D Viewport) - also a ComboBox per request.
        $modeLabel = New-Object System.Windows.Controls.TextBlock
        $modeLabel.Text = "Test type:"
        $modeLabel.FontSize = 12
        $modeLabel.VerticalAlignment = "Center"
        $modeLabel.Margin = "16,0,8,0"
        $modeLabel.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "Brush_TextSecondary")
        $p.AddChild($modeLabel)

        $modeOptions = @(
            @{ Key = "2D"; Text = "2D Compositor" },
            @{ Key = "3D"; Text = "3D Viewport" }
        )
        $modeState = [PSCustomObject]@{ Mode = $modeOptions[0].Key }
        $modeCombo = New-GuiThemedComboBox -Width 150
        foreach ($opt in $modeOptions) { $modeCombo.Items.Add($opt.Text) | Out-Null }
        $modeCombo.SelectedIndex = 0
        $modeCombo.Add_SelectionChanged({
            if ($modeCombo.SelectedIndex -ge 0) { $modeState.Mode = $modeOptions[$modeCombo.SelectedIndex].Key }
        }.GetNewClosure())
        $p.AddChild($modeCombo)

        Add-GuiBtn $p "Run Benchmark" "ActionButtonStyle" {
            $modeName = if ($modeState.Mode -eq "3D") { "3D Viewport" } else { "2D Compositor" }
            Write-GuiLog "Starting GPU render benchmark - $modeName ($($durState.Seconds)s)..." "STEP"

            # Show-GpuBenchmarkPopup blocks (ShowDialog) until the user closes the popup, which
            # only becomes possible once the run completes or is stopped - see that function.
            $result = Show-GpuBenchmarkPopup -Mode $modeState.Mode -DurationSeconds $durState.Seconds

            if ($result) {
                $Global:BenchGpuResultsStack.Children.Clear()
                Add-GuiIconTitle $Global:BenchGpuResultsStack "&#xE950;" "Results" "#F0883E" -AccentTitle -TitleColor "#F0883E"
                Add-GuiBenchStatTiles $Global:BenchGpuResultsStack @(
                    @{Label="Avg FPS"; Value=$result.AvgFps}
                )
                $Global:BenchGpuResultsCard.Visibility = "Visible"
                if ($result.Cancelled) {
                    Write-GuiLog "GPU render benchmark stopped ($modeName) - average FPS: $($result.AvgFps)" "WARN"
                } else {
                    Write-GuiLog "GPU render benchmark complete ($modeName) - average FPS: $($result.AvgFps)" "OK"
                }

                # Cache the result (kept until the program closes) so the Export page can include it.
                $Global:BenchGpuLastResult = @{
                    DurationSeconds = $durState.Seconds
                    Mode            = $modeName
                    AvgFps          = $result.AvgFps
                    Cancelled       = $result.Cancelled
                    Timestamp       = Get-Date
                }
            }
        }.GetNewClosure()
    } "&#xE950;" -WrapButtons

    $pnlContent.AddChild($Global:BenchGpuResultsCard)
}
