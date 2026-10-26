$Script:MetricsBusy = $false
$Script:MetricsRunspace = $null
$Script:MetricsPS = $null
$Script:MetricsAsync = $null

# Kicks off an async CPU/RAM/GPU usage sample on a background runspace (created lazily and reused)
# so the metrics collection (CIM queries, performance counters) never blocks the UI thread.
# Sets $Script:MetricsBusy so overlapping fetches are skipped until the current one completes.
function Start-GuiMetricsFetch {
    if ($Script:MetricsBusy) { return }
    if (-not $Script:MetricsRunspace) {
        $Script:MetricsRunspace = [runspacefactory]::CreateRunspace()
        $Script:MetricsRunspace.ApartmentState = 'MTA'
        $Script:MetricsRunspace.Open()
    }
    $Script:MetricsBusy = $true
    $ps = [powershell]::Create()
    $ps.Runspace = $Script:MetricsRunspace
    [void]$ps.AddScript({
        $result = [ordered]@{ Cpu = $null; RamPct = $null; GpuPcts = @() }
        try {
            $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $result.Cpu = $cpuLoad
        } catch {}
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $result.RamPct = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 0)
        } catch {}
        try {
            # Group by LUID so each physical GPU gets its own aggregated 3D engine usage.
            $gpuSamples = (Get-Counter '\GPU Engine(*engtype_3D)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples
            if ($gpuSamples) {
                $groups = $gpuSamples | Group-Object {
                    if ($_.InstanceName -match 'luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)') { $Matches[1] } else { 'unknown' }
                } | Sort-Object Name
                $result.GpuPcts = @($groups | ForEach-Object {
                    [math]::Min(100, [math]::Round(($_.Group | Measure-Object -Property CookedValue -Sum).Sum, 0))
                })
            }
        } catch {}

        [pscustomobject]$result
    })
    $Script:MetricsPS = $ps
    $Script:MetricsAsync = $ps.BeginInvoke()
}

# Called on each tick of the Home page's live-metrics timer. Starts a new background fetch if none
# is running, or - once the pending fetch completes - reads the result and pushes CPU/RAM/GPU values
# into the Home page gauges. No-op if the Home gauges aren't currently on screen.
function Update-GuiLiveMetrics {
    if (-not $Script:HomeCpuGauge -or -not $Script:HomeRamGauge) { return }
    if (-not $Script:MetricsBusy) { Start-GuiMetricsFetch; return }
    if ($Script:MetricsAsync -and $Script:MetricsAsync.IsCompleted) {
        try {
            $data = $Script:MetricsPS.EndInvoke($Script:MetricsAsync)
            if ($data -and $null -ne $data.Cpu) {
                Set-GuiMetricBarValue -MetricBar $Script:HomeCpuGauge -Value $data.Cpu
            }
            if ($data -and $null -ne $data.RamPct) {
                Set-GuiMetricBarValue -MetricBar $Script:HomeRamGauge -Value $data.RamPct
            }
            if ($data -and $Script:HomeGpuGauges) {
                for ($gi = 0; $gi -lt $Script:HomeGpuGauges.Count; $gi++) {
                    $gpuVal = if ($data.GpuPcts -and $gi -lt $data.GpuPcts.Count) { $data.GpuPcts[$gi] } else { 0 }
                    Set-GuiMetricBarValue -MetricBar $Script:HomeGpuGauges[$gi] -Value $gpuVal
                }
            }
        } catch {
        } finally {
            $Script:MetricsPS.Dispose()
            $Script:MetricsPS = $null
            $Script:MetricsAsync = $null
            $Script:MetricsBusy = $false
        }
    }
}

# Disposes the metrics PowerShell instance/runspace used by Start-GuiMetricsFetch. Called on
# window close so the background runspace doesn't keep the process alive.
function Stop-GuiMetricsRunspace {
    try { if ($Script:MetricsPS) { $Script:MetricsPS.Dispose() } } catch {}
    try { if ($Script:MetricsRunspace) { $Script:MetricsRunspace.Close(); $Script:MetricsRunspace.Dispose() } } catch {}
}
