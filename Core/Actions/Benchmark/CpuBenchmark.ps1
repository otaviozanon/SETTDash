# CPU benchmark: counts how many primality-test iterations a thread can perform per second,
# sampled once per second for the full run, then runs the same workload across all logical cores
# in parallel. Scores are raw "iterations per second" - useful for before/after comparison (e.g.
# after applying SETTDash's Performance tweaks), not an absolute/portable benchmark number.
# Returns the list of per-second samples so the caller can report min/max/avg and draw a chart,
# instead of only a single averaged number from a short run.
function Invoke-CpuWorkload {
    param([double]$DurationSeconds, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $n = 2L
    $count = 0L
    $lastTickCount = 0L
    $lastTickSecond = 0
    $samples = [System.Collections.Generic.List[double]]::new()
    while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds -and -not ($CancelCheck -and (& $CancelCheck))) {
        $isPrime = $true
        $limit = [math]::Sqrt($n)
        for ($i = 2; $i -le $limit; $i++) {
            if ($n % $i -eq 0) { $isPrime = $false; break }
        }
        if ($isPrime) { $count++ }
        $n++
        $curSecond = [int][math]::Floor($sw.Elapsed.TotalSeconds)
        if ($curSecond -gt $lastTickSecond) {
            $sample = [double]($count - $lastTickCount)
            $samples.Add($sample) | Out-Null
            $lastTickCount = $count
            $lastTickSecond = $curSecond
            if ($OnSample) { & $OnSample $sample }
        }
    }
    return [PSCustomObject]@{ Total = $count; Samples = $samples }
}

# Runs the same primality-counting workload on every logical processor in parallel using a
# RunspacePool (PowerShell's own mechanism for running script code on separate threads - plain
# .NET Tasks can't safely re-enter the main runspace's functions), sampling the combined
# iterations/sec across all cores once per second, and returns the total plus the per-second samples.
function Invoke-CpuWorkloadMultiThread {
    param([double]$DurationSeconds, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)
    $cores = [Environment]::ProcessorCount
    $workloadScript = {
        param($DurationSeconds, $Sync)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $n = 2L
        $count = 0L
        while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds -and -not $Sync.Cancel) {
            $isPrime = $true
            $limit = [math]::Sqrt($n)
            for ($i = 2; $i -le $limit; $i++) { if ($n % $i -eq 0) { $isPrime = $false; break } }
            if ($isPrime) { $count++ }
            $n++
            # NOTE: PowerShell's [ref] to a PSCustomObject property does not actually bind to the
            # property storage for Interlocked.Exchange - it silently no-ops instead of throwing,
            # which left $Sync.Count stuck at 0 forever. A plain assignment is not atomic, but a
            # 64-bit aligned write is safe enough here since $Sync.Count is only ever read for the
            # approximate once-a-second progress sample, not for the final authoritative total
            # (that comes from this runspace's own return value via EndInvoke).
            if (($n -band 0xFFF) -eq 0) { $Sync.Count = $count }
        }
        $Sync.Count = $count
        return $count
    }
    # A thread-safe shared counter per worker lets the main thread sample combined throughput once
    # per second while the RunspacePool jobs are still running, instead of only getting one total
    # at the very end (which would give no per-second samples for the chart).
    $counters = for ($i = 0; $i -lt $cores; $i++) { [PSCustomObject]@{ Count = 0L; Cancel = $false } }
    $pool = [runspacefactory]::CreateRunspacePool(1, $cores)
    $pool.Open()
    try {
        $jobs = for ($i = 0; $i -lt $cores; $i++) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($workloadScript).AddArgument($DurationSeconds).AddArgument($counters[$i])
            [PSCustomObject]@{ Shell = $ps; Handle = $ps.BeginInvoke() }
        }
        $samples = [System.Collections.Generic.List[double]]::new()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastTotal = 0L
        $lastSecond = 0
        while (($jobs | Where-Object { -not $_.Handle.IsCompleted } | Measure-Object).Count -gt 0) {
            Start-Sleep -Milliseconds 50
            if ($CancelCheck -and (& $CancelCheck)) {
                foreach ($c in $counters) { $c.Cancel = $true }
            }
            $curSecond = [int][math]::Floor($sw.Elapsed.TotalSeconds)
            if ($curSecond -gt $lastSecond) {
                $curTotal = ($counters | Measure-Object -Property Count -Sum).Sum
                $sample = [double]($curTotal - $lastTotal)
                $samples.Add($sample) | Out-Null
                $lastTotal = $curTotal
                $lastSecond = $curSecond
                if ($OnSample) { & $OnSample $sample }
            }
        }
        $total = 0L
        foreach ($j in $jobs) {
            $total += ($j.Shell.EndInvoke($j.Handle) | Select-Object -First 1)
            $j.Shell.Dispose()
        }
        return [PSCustomObject]@{ Total = $total; Samples = $samples }
    } finally { $pool.Close(); $pool.Dispose() }
}

# Orchestrates the full CPU benchmark: single-core pass then all-core pass (10 seconds each by
# default - long enough for thermal/boost behavior to settle, unlike a short 4-5s burst), logging
# progress and returning both per-second sample sets plus min/max/avg for each pass.
function Get-CpuBenchmarkResult {
    param([double]$DurationSeconds = 30, [scriptblock]$OnSingleSample = $null, [scriptblock]$OnMultiSample = $null, [scriptblock]$CancelCheck = $null)
    $cores = [Environment]::ProcessorCount
    Set-GuiProgress 10 "Running single-core workload ($DurationSeconds s)..."
    $single = Invoke-CpuWorkload -DurationSeconds $DurationSeconds -OnSample $OnSingleSample -CancelCheck $CancelCheck
    $singleScore = [math]::Round($single.Total / $DurationSeconds)
    Set-GuiProgress 55 "Running multi-core workload across $cores threads ($DurationSeconds s)..."
    $multi = Invoke-CpuWorkloadMultiThread -DurationSeconds $DurationSeconds -OnSample $OnMultiSample -CancelCheck $CancelCheck
    $multiScore = [math]::Round($multi.Total / $DurationSeconds)
    $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
    Set-GuiProgress 100 $(if ($cancelled) { "CPU benchmark stopped." } else { "CPU benchmark complete." })
    [PSCustomObject]@{
        Threads       = $cores
        Cancelled     = $cancelled
        SingleScore   = $singleScore
        SingleMin     = if ($single.Samples.Count -gt 0) { [math]::Round(($single.Samples | Measure-Object -Minimum).Minimum) } else { $singleScore }
        SingleMax     = if ($single.Samples.Count -gt 0) { [math]::Round(($single.Samples | Measure-Object -Maximum).Maximum) } else { $singleScore }
        SingleSamples = $single.Samples
        MultiScore    = $multiScore
        MultiMin      = if ($multi.Samples.Count -gt 0) { [math]::Round(($multi.Samples | Measure-Object -Minimum).Minimum) } else { $multiScore }
        MultiMax      = if ($multi.Samples.Count -gt 0) { [math]::Round(($multi.Samples | Measure-Object -Maximum).Maximum) } else { $multiScore }
        MultiSamples  = $multi.Samples
    }
}
