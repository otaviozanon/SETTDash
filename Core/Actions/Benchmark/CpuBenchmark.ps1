# CPU benchmark: exercises three different kinds of CPU work - Integer (primality-test trial
# division), Float (trig/sqrt math, stresses the FPU), and Memory (random-access read/write over a
# large array, stresses cache/memory latency) - each counted as "work units per second", sampled
# once per second for the full run, then runs the same workload across all logical cores in
# parallel. Scores are raw "units/sec" - useful for before/after comparison (e.g. after applying
# SETTDash's Performance tweaks) and for comparing the three profiles against each other on the
# same machine, not an absolute/portable benchmark number (units/sec differ by workload type, so
# an Integer score is not comparable to a Float or Memory score).
# Returns the list of per-second samples so the caller can report min/max/avg and draw a chart,
# instead of only a single averaged number from a short run.

# Per-workload-type "do one unit of work, return whether it counts" closures used by both the
# single-thread (Invoke-CpuWorkload) and multi-thread (Invoke-CpuWorkloadMultiThread) loops below,
# so the three profiles stay in sync between the two code paths. $State carries whatever
# mutable per-iteration data a given workload type needs (e.g. the running $n for Integer, or the
# backing array for Memory) without polluting the caller's scope.
function New-CpuWorkloadState {
    param([string]$WorkloadType)
    switch ($WorkloadType) {
        'Float' {
            return [PSCustomObject]@{ Type = 'Float'; X = 0.0001 }
        }
        'Memory' {
            # 4M doubles (~32MB) - large enough to blow past L2/L3 cache on most consumer CPUs, so
            # the random-access pattern below is dominated by memory latency, not cache hits.
            $size = 4MB
            $buf = [double[]]::new($size)
            for ($i = 0; $i -lt $size; $i++) { $buf[$i] = $i * 1.0 }
            return [PSCustomObject]@{ Type = 'Memory'; Buffer = $buf; Size = $size; Rng = [System.Random]::new(); Acc = 0.0 }
        }
        default {
            return [PSCustomObject]@{ Type = 'Integer'; N = 2L }
        }
    }
}

# Runs exactly one unit of the selected workload type against $State, mutating it in place.
# Returns $true if this unit should increment the "work done" counter (every unit counts for
# Float/Memory; only on finding a prime for Integer, matching the original behavior/scale).
function Invoke-CpuWorkUnit {
    param($State)
    switch ($State.Type) {
        'Float' {
            # Fixed-size chunk of trig/sqrt math per unit (stresses the FPU, not just one op) -
            # accumulate into $State.X so the JIT/interpreter can't optimize the loop away.
            $x = $State.X
            for ($k = 0; $k -lt 50; $k++) {
                $x = [math]::Sqrt([math]::Abs([math]::Sin($x) * [math]::Cos($x * 1.0000001) + 1.0))
            }
            $State.X = $x
            return $true
        }
        'Memory' {
            # Chunk of random-index read-modify-write over the large buffer - each access likely
            # misses cache, so this profile is bound by memory latency rather than raw ALU speed.
            $buf = $State.Buffer
            $size = $State.Size
            $acc = $State.Acc
            for ($k = 0; $k -lt 200; $k++) {
                $idx = $State.Rng.Next($size)
                $acc += $buf[$idx]
                $buf[$idx] = $acc
            }
            $State.Acc = $acc
            return $true
        }
        default {
            $n = $State.N
            $isPrime = $true
            $limit = [math]::Sqrt($n)
            for ($i = 2; $i -le $limit; $i++) {
                if ($n % $i -eq 0) { $isPrime = $false; break }
            }
            $State.N = $n + 1
            return $isPrime
        }
    }
}

function Invoke-CpuWorkload {
    param([double]$DurationSeconds, [string]$WorkloadType = 'Integer', [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)
    # State init (allocates/fills the 32MB buffer for Memory) must happen before the stopwatch
    # starts - otherwise that one-time setup cost eats into $DurationSeconds and, on a short
    # duration or many parallel threads, can consume the entire budget before any work unit runs.
    $state = New-CpuWorkloadState -WorkloadType $WorkloadType
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $count = 0L
    $lastTickCount = 0L
    $lastTickSecond = 0
    $samples = [System.Collections.Generic.List[double]]::new()
    while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds -and -not ($CancelCheck -and (& $CancelCheck))) {
        if (Invoke-CpuWorkUnit $state) { $count++ }
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

# Runs the same workload (Integer/Float/Memory, selected by $WorkloadType) on every logical
# processor in parallel using a RunspacePool (PowerShell's own mechanism for running script code
# on separate threads - plain .NET Tasks can't safely re-enter the main runspace's functions),
# sampling the combined units/sec across all cores once per second, and returns the total plus the
# per-second samples.
function Invoke-CpuWorkloadMultiThread {
    param([double]$DurationSeconds, [string]$WorkloadType = 'Integer', [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)
    $cores = [Environment]::ProcessorCount
    $workloadScript = {
        param($DurationSeconds, $Sync, $WorkloadType, $DefFn1, $DefFn2)
        . ([scriptblock]::Create($DefFn1))
        . ([scriptblock]::Create($DefFn2))
        # Same ordering fix as Invoke-CpuWorkload: init before the stopwatch starts, so the
        # Memory profile's buffer allocation/fill isn't counted against $DurationSeconds.
        $state = New-CpuWorkloadState -WorkloadType $WorkloadType
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $count = 0L
        $tick = 0
        while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds -and -not $Sync.Cancel) {
            if (Invoke-CpuWorkUnit $state) { $count++ }
            $tick++
            # NOTE: PowerShell's [ref] to a PSCustomObject property does not actually bind to the
            # property storage for Interlocked.Exchange - it silently no-ops instead of throwing,
            # which left $Sync.Count stuck at 0 forever. A plain assignment is not atomic, but a
            # 64-bit aligned write is safe enough here since $Sync.Count is only ever read for the
            # approximate once-a-second progress sample, not for the final authoritative total
            # (that comes from this runspace's own return value via EndInvoke).
            if (($tick -band 0xFFF) -eq 0) { $Sync.Count = $count }
        }
        $Sync.Count = $count
        return $count
    }
    # A thread-safe shared counter per worker lets the main thread sample combined throughput once
    # per second while the RunspacePool jobs are still running, instead of only getting one total
    # at the very end (which would give no per-second samples for the chart).
    $counters = for ($i = 0; $i -lt $cores; $i++) { [PSCustomObject]@{ Count = 0L; Cancel = $false } }
    # Each RunspacePool worker starts with a bare runspace that does not see functions defined in
    # this script's scope, so New-CpuWorkloadState/Invoke-CpuWorkUnit are shipped over as their
    # own source text (via (Get-Command).Definition) and re-declared inside $workloadScript above.
    $defState = "function New-CpuWorkloadState { $((Get-Command New-CpuWorkloadState).Definition) }"
    $defUnit = "function Invoke-CpuWorkUnit { $((Get-Command Invoke-CpuWorkUnit).Definition) }"
    $pool = [runspacefactory]::CreateRunspacePool(1, $cores)
    $pool.Open()
    try {
        $jobs = for ($i = 0; $i -lt $cores; $i++) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($workloadScript).AddArgument($DurationSeconds).AddArgument($counters[$i]).AddArgument($WorkloadType).AddArgument($defState).AddArgument($defUnit)
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

# Discards the first few per-second samples of a benchmark pass before scoring - both single and
# multi-thread workloads here start "cold" (branch predictor/caches not warmed, and on modern CPUs
# the first 1-2s often still ride a transient boost clock that isn't sustainable for the full run).
# Cinebench/Geekbench-style tools don't count this ramp-up window in the final score; without
# discarding it, the Min (and sometimes the Avg) comes out skewed by an unrepresentative first
# second rather than the steady-state throughput the rest of the run settles into.
function Get-CpuScoredSamples {
    param([System.Collections.Generic.List[double]]$Samples, [int]$WarmupSeconds = 2)
    if ($Samples.Count -le $WarmupSeconds) { return $Samples }
    return [System.Collections.Generic.List[double]]::new($Samples.GetRange($WarmupSeconds, $Samples.Count - $WarmupSeconds))
}

# Workload types run in the fixed order Integer -> Float -> Memory for both the single-core and
# multi-core passes, each for its own full $DurationSeconds slice (not a 1/3 split - keeps each
# profile's steady-state/warm-up math identical to running it alone, at the cost of a longer total
# run: 3 types x 2 passes x $DurationSeconds).
$Script:CpuWorkloadTypes = @('Integer', 'Float', 'Memory')

function Get-CpuBenchmarkResult {
    param([double]$DurationSeconds = 30, [scriptblock]$OnSingleSample = $null, [scriptblock]$OnMultiSample = $null, [scriptblock]$CancelCheck = $null)
    $cores = [Environment]::ProcessorCount
    $types = $Script:CpuWorkloadTypes
    $progressStep = [math]::Floor(90 / ($types.Count * 2))
    $progress = 5
    $profiles = @{}

    foreach ($type in $types) {
        Set-GuiProgress $progress "Running $type single-core workload ($DurationSeconds s)..."
        $single = Invoke-CpuWorkload -DurationSeconds $DurationSeconds -WorkloadType $type -OnSample { param($v) if ($OnSingleSample) { & $OnSingleSample $type $v } }.GetNewClosure() -CancelCheck $CancelCheck
        $progress += $progressStep
        Set-GuiProgress $progress "Running $type multi-core workload across $cores threads ($DurationSeconds s)..."
        $multi = Invoke-CpuWorkloadMultiThread -DurationSeconds $DurationSeconds -WorkloadType $type -OnSample { param($v) if ($OnMultiSample) { & $OnMultiSample $type $v } }.GetNewClosure() -CancelCheck $CancelCheck
        $progress += $progressStep

        # Score off the post-warm-up samples (steady-state throughput) instead of Total/DurationSeconds,
        # which still includes the discarded ramp-up seconds in its denominator and average.
        # @(...): Get-CpuScoredSamples unrolls its List, so a cancelled run with fewer samples than
        # the warm-up window returns nothing ($null), and $null.Count throws under StrictMode.
        $singleScored = @(Get-CpuScoredSamples $single.Samples)
        $multiScored = @(Get-CpuScoredSamples $multi.Samples)
        $singleScore = if ($singleScored.Count -gt 0) { [math]::Round(($singleScored | Measure-Object -Average).Average) } else { [math]::Round($single.Total / $DurationSeconds) }
        $multiScore = if ($multiScored.Count -gt 0) { [math]::Round(($multiScored | Measure-Object -Average).Average) } else { [math]::Round($multi.Total / $DurationSeconds) }

        $profiles[$type] = [PSCustomObject]@{
            WorkloadType  = $type
            SingleScore   = $singleScore
            SingleMin     = if ($singleScored.Count -gt 0) { [math]::Round(($singleScored | Measure-Object -Minimum).Minimum) } else { $singleScore }
            SingleMax     = if ($singleScored.Count -gt 0) { [math]::Round(($singleScored | Measure-Object -Maximum).Maximum) } else { $singleScore }
            SingleSamples = $single.Samples
            MultiScore    = $multiScore
            MultiMin      = if ($multiScored.Count -gt 0) { [math]::Round(($multiScored | Measure-Object -Minimum).Minimum) } else { $multiScore }
            MultiMax      = if ($multiScored.Count -gt 0) { [math]::Round(($multiScored | Measure-Object -Maximum).Maximum) } else { $multiScore }
            MultiSamples  = $multi.Samples
            # Multi/Single ratio - how well this workload type scales with core count (e.g. ~N on
            # an N-core CPU with no SMT/efficiency-core penalty; well below N signals thermal/power
            # limits or heterogeneous (P+E) core scheduling eating into scaling). Same metric
            # Geekbench/Cinebench report as "multi-core score / single-core score".
            MtStRatio     = if ($singleScore -gt 0) { [math]::Round($multiScore / $singleScore, 2) } else { 0 }
        }

        if ($CancelCheck -and (& $CancelCheck)) { break }
    }

    $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
    Set-GuiProgress 100 $(if ($cancelled) { "CPU benchmark stopped." } else { "CPU benchmark complete." })
    [PSCustomObject]@{
        Threads   = $cores
        Cancelled = $cancelled
        Integer   = $profiles['Integer']
        Float     = $profiles['Float']
        Memory    = $profiles['Memory']
    }
}
