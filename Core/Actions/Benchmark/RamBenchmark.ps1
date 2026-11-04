# RAM benchmark: allocates a large byte buffer and measures sequential write throughput (filling
# it) and copy throughput (Buffer.BlockCopy between two buffers, approximating read+write
# bandwidth) - a simple, dependency-free proxy for memory bandwidth, useful for before/after
# comparison rather than as an absolute/portable score. Each pass is timed individually (instead of
# only the total) so the result reports min/max/avg across passes and a per-pass chart. The write
# and copy phases each run for half of $DurationSeconds (user-selectable - 30/60/120s), repeating
# passes until that time budget is used up, instead of a fixed short pass count.
#
# NOTE: both phases move bytes exclusively via [Buffer]::BlockCopy (a single native memmove call),
# never a PowerShell-interpreted per-byte loop - a `for` loop writing one byte at a time to a
# 512 MB array is ~500M interpreted iterations and can take tens of seconds to minutes per single
# pass with no Dispatcher pump in between, which looks exactly like the UI hanging/crashing. Each
# pass is also kept running for at least $MinPassSeconds (looping BlockCopy repeatedly until that
# elapses) instead of doing one BlockCopy and dividing by whatever tiny elapsed time resulted -
# a single BlockCopy on a buffer this size can finish in a fraction of a millisecond, and dividing
# by a near-zero/zero Stopwatch reading produces huge/garbage throughput numbers and a tight loop
# that spams UI pumps (via OnWriteSample/OnCopySample) far faster than the chart can meaningfully
# redraw - the other symptom reported as "crashing".
function Get-RamBenchmarkResult {
    param([int]$BufferSizeMB = 512, [double]$DurationSeconds = 30, [scriptblock]$OnWriteSample = $null, [scriptblock]$OnCopySample = $null, [scriptblock]$CancelCheck = $null, [double]$MinPassSeconds = 0.15)
    # Under a 32-bit host (SETTDash.ps1 in 32-bit PowerShell) this process only has ~2 GB of
    # address space. Allocating two 512 MB byte[] buffers (1 GB total) back-to-back as contiguous
    # blocks can throw OutOfMemoryException there even with plenty of free system RAM, once the
    # managed heap (especially the Large Object Heap) is fragmented by everything else WPF has
    # already allocated - not an actual low-memory condition. Shrink the default buffer on 32-bit
    # processes, and retry with progressively smaller buffers if allocation still fails, instead of
    # letting the whole benchmark crash with an unhelpful .ctor OutOfMemoryException.
    if ([IntPtr]::Size -eq 4 -and $BufferSizeMB -gt 128) { $BufferSizeMB = 128 }

    $src = $null; $dst = $null
    while ($true) {
        try {
            $size = $BufferSizeMB * 1MB
            Set-GuiProgress 10 "Allocating $BufferSizeMB MB test buffers..."
            $src = [byte[]]::new($size)
            $dst = [byte[]]::new($size)
            break
        } catch [OutOfMemoryException] {
            $src = $null; $dst = $null
            [System.GC]::Collect()
            if ($BufferSizeMB -le 32) { throw }
            $BufferSizeMB = [Math]::Max(32, [int]($BufferSizeMB / 2))
            Write-GuiLog "RAM benchmark: not enough contiguous memory, retrying with a $BufferSizeMB MB buffer..." "WARN"
        }
    }
    $size = $BufferSizeMB * 1MB
    $phaseBudget = $DurationSeconds / 2
    $chunkSize = [Math]::Min(1MB, $size)
    $chunk = [byte[]]::new($chunkSize)
    $rnd = [System.Random]::new(42)
    $rnd.NextBytes($chunk)

    Set-GuiProgress 30 "Measuring write throughput ($phaseBudget s)..."
    $writeSamples = [System.Collections.Generic.List[double]]::new()
    $phaseSw = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $bytesMoved = 0L
        do {
            for ($offset = 0; $offset -lt $size; $offset += $chunkSize) {
                $len = [Math]::Min($chunkSize, $size - $offset)
                [System.Buffer]::BlockCopy($chunk, 0, $src, $offset, $len)
                $bytesMoved += $len
            }
        } while ($sw.Elapsed.TotalSeconds -lt $MinPassSeconds)
        $sw.Stop()
        $sample = [math]::Round(($bytesMoved / 1MB) / $sw.Elapsed.TotalSeconds)
        $writeSamples.Add($sample) | Out-Null
        if ($OnWriteSample) { & $OnWriteSample $sample }
        Set-GuiProgress (30 + [math]::Min(30, [math]::Round($phaseSw.Elapsed.TotalSeconds / $phaseBudget * 30)))
    } while ($phaseSw.Elapsed.TotalSeconds -lt $phaseBudget -and -not ($CancelCheck -and (& $CancelCheck)))
    $writeMBs = [math]::Round(($writeSamples | Measure-Object -Average).Average)

    Set-GuiProgress 65 "Measuring copy throughput ($phaseBudget s)..."
    $copySamples = [System.Collections.Generic.List[double]]::new()
    $phaseSw.Restart()
    do {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $passesMoved = 0L
        do {
            # BlockCopy touches both buffers (read source + write destination) each pass.
            [System.Buffer]::BlockCopy($src, 0, $dst, 0, $size)
            $passesMoved += (2 * $size)
        } while ($sw.Elapsed.TotalSeconds -lt $MinPassSeconds)
        $sw.Stop()
        $sample = [math]::Round(($passesMoved / 1MB) / $sw.Elapsed.TotalSeconds)
        $copySamples.Add($sample) | Out-Null
        if ($OnCopySample) { & $OnCopySample $sample }
        Set-GuiProgress (65 + [math]::Min(30, [math]::Round($phaseSw.Elapsed.TotalSeconds / $phaseBudget * 30)))
    } while ($phaseSw.Elapsed.TotalSeconds -lt $phaseBudget -and -not ($CancelCheck -and (& $CancelCheck)))
    $copyMBs = [math]::Round(($copySamples | Measure-Object -Average).Average)

    $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
    Set-GuiProgress 100 $(if ($cancelled) { "RAM benchmark stopped." } else { "RAM benchmark complete." })
    [PSCustomObject]@{
        BufferSizeMB  = $BufferSizeMB
        Cancelled     = $cancelled
        Passes        = $writeSamples.Count
        WriteMBs      = $writeMBs
        WriteMin      = [math]::Round(($writeSamples | Measure-Object -Minimum).Minimum)
        WriteMax      = [math]::Round(($writeSamples | Measure-Object -Maximum).Maximum)
        WriteSamples  = $writeSamples
        CopyMBs       = $copyMBs
        CopyMin       = [math]::Round(($copySamples | Measure-Object -Minimum).Minimum)
        CopyMax       = [math]::Round(($copySamples | Measure-Object -Maximum).Maximum)
        CopySamples   = $copySamples
    }
}

#region PURE-READ THROUGHPUT + RANDOM-ACCESS LATENCY (mirrors AIDA64's separate Read/Latency scores)
# AIDA64 reports Read, Write, Copy, and Latency as four distinct numbers - the existing test above
# only gives Write (fill) and Copy (read+write simultaneously via BlockCopy), with no pure-read or
# access-latency figure. Adds both here as an optional second sub-test.
#
# Pure read: a PowerShell `for` loop summing one byte at a time is too slow to measure memory
# bandwidth (interpreter overhead dominates, same problem noted for Write/Copy above) - instead,
# each chunk of the large source buffer is BlockCopy'd into one small, reused destination buffer
# (sized to fit comfortably in CPU cache). The destination write cost is amortized/cached since it's
# the same small region every time, so the measurement is dominated by reading the large buffer
# rather than by writing - a pure-write test this is not, but it isolates "read a big buffer" far
# better than the existing Copy phase (which reads AND writes buffers of equal, uncached size).
#
# Latency: builds a single-cycle random permutation over an int32 array (Sattolo's algorithm -
# unlike a plain Fisher-Yates shuffle, this guarantees one cycle covering every element instead of
# many short cycles, which the CPU's hardware prefetcher could otherwise learn and hide most of the
# real access latency behind) sized well above typical L3 cache, then repeatedly follows
# idx = order[idx] - each jump is a data-dependent, unpredictable address, so the CPU cannot
# prefetch ahead and the measured time per jump approximates real random-access RAM latency in ns.
function Get-RamReadLatencyResult {
    param([int]$BufferSizeMB = 512, [double]$DurationSeconds = 20, [scriptblock]$OnReadSample = $null, [scriptblock]$OnLatencySample = $null, [scriptblock]$CancelCheck = $null, [double]$MinPassSeconds = 0.15)
    if ([IntPtr]::Size -eq 4 -and $BufferSizeMB -gt 128) { $BufferSizeMB = 128 }

    $src = $null
    while ($true) {
        try {
            $size = $BufferSizeMB * 1MB
            Set-GuiProgress 5 "Allocating $BufferSizeMB MB read test buffer..."
            $src = [byte[]]::new($size)
            [System.Random]::new(5).NextBytes($src)
            break
        } catch [OutOfMemoryException] {
            $src = $null
            [System.GC]::Collect()
            if ($BufferSizeMB -le 32) { throw }
            $BufferSizeMB = [Math]::Max(32, [int]($BufferSizeMB / 2))
            Write-GuiLog "RAM read test: not enough contiguous memory, retrying with a $BufferSizeMB MB buffer..." "WARN"
        }
    }
    $size = $BufferSizeMB * 1MB
    $readBudget = $DurationSeconds * 0.6
    $chunkSize = [Math]::Min(256KB, $size)
    $dst = [byte[]]::new($chunkSize)

    Set-GuiProgress 15 "Measuring read throughput ($([math]::Round($readBudget)) s)..."
    $readSamples = [System.Collections.Generic.List[double]]::new()
    $phaseSw = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $bytesRead = 0L
        do {
            for ($offset = 0; $offset -lt $size; $offset += $chunkSize) {
                $len = [Math]::Min($chunkSize, $size - $offset)
                [System.Buffer]::BlockCopy($src, $offset, $dst, 0, $len)
                $bytesRead += $len
            }
        } while ($sw.Elapsed.TotalSeconds -lt $MinPassSeconds)
        $sw.Stop()
        $sample = [math]::Round(($bytesRead / 1MB) / $sw.Elapsed.TotalSeconds)
        $readSamples.Add($sample) | Out-Null
        if ($OnReadSample) { & $OnReadSample $sample }
        Set-GuiProgress (15 + [math]::Min(35, [math]::Round($phaseSw.Elapsed.TotalSeconds / $readBudget * 35)))
    } while ($phaseSw.Elapsed.TotalSeconds -lt $readBudget -and -not ($CancelCheck -and (& $CancelCheck)))
    $readMBs = [math]::Round(($readSamples | Measure-Object -Average).Average)

    # Latency array: 64MB (16M elements) on 64-bit, 16MB on 32-bit - comfortably bigger than any
    # consumer CPU's L3 cache, so pointer-chasing through it can't stay cache-resident.
    $latencyMB = if ([IntPtr]::Size -eq 4) { 16 } else { 64 }
    $elements = [int](($latencyMB * 1MB) / 4)
    Set-GuiProgress 55 "Building random-access pattern ($latencyMB MB)..."
    $order = [int[]]::new($elements)
    for ($i = 0; $i -lt $elements; $i++) { $order[$i] = $i }
    $rnd = [System.Random]::new(99)
    for ($i = $elements - 1; $i -gt 0; $i--) {
        $j = $rnd.Next(0, $i)
        $tmp = $order[$i]; $order[$i] = $order[$j]; $order[$j] = $tmp
    }

    $latencyBudget = [Math]::Max(2, $DurationSeconds - $readBudget)
    Set-GuiProgress 65 "Measuring random-access latency ($([math]::Round($latencyBudget)) s)..."
    $latencySamples = [System.Collections.Generic.List[double]]::new()
    $phaseSw.Restart()
    $idx = 0
    $batchSize = 200000
    do {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        for ($k = 0; $k -lt $batchSize; $k++) { $idx = $order[$idx] }
        $sw.Stop()
        $nsPerAccess = [math]::Round(($sw.Elapsed.TotalMilliseconds * 1000000.0) / $batchSize, 1)
        $latencySamples.Add($nsPerAccess) | Out-Null
        if ($OnLatencySample) { & $OnLatencySample $nsPerAccess }
        Set-GuiProgress (65 + [math]::Min(30, [math]::Round($phaseSw.Elapsed.TotalSeconds / $latencyBudget * 30)))
    } while ($phaseSw.Elapsed.TotalSeconds -lt $latencyBudget -and -not ($CancelCheck -and (& $CancelCheck)) -and $idx -ge 0)
    $latencyNs = [math]::Round(($latencySamples | Measure-Object -Average).Average, 1)

    $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
    Set-GuiProgress 100 $(if ($cancelled) { "RAM read/latency test stopped." } else { "RAM read/latency test complete." })
    [PSCustomObject]@{
        Cancelled      = $cancelled
        ReadMBs        = $readMBs
        ReadMin        = [math]::Round(($readSamples | Measure-Object -Minimum).Minimum)
        ReadMax        = [math]::Round(($readSamples | Measure-Object -Maximum).Maximum)
        ReadSamples    = $readSamples
        LatencyNs      = $latencyNs
        LatencySamples = $latencySamples
        LatencyArrayMB = $latencyMB
    }
}
#endregion

#region MULTI-THREADED COPY BANDWIDTH (mirrors AIDA64's "all cores" memory bandwidth figure)
# The single-thread Write/Copy/Read phases above only exercise one core's memory controller path -
# on modern multi-channel memory, a single thread usually can't saturate total available bandwidth
# (AIDA64/Intel MLC report a much higher number when all cores read/write memory concurrently). This
# runs the same BlockCopy-based copy workload as the single-thread Copy phase, but split across one
# RunspacePool worker per logical core, each with its own private src/dst buffer pair (sized
# BufferSizeMB / cores, so total memory footprint stays comparable to the single-thread test)
# so threads aren't fighting each other for the same cache lines - same RunspacePool pattern as
# Invoke-CpuWorkloadMultiThread in CpuBenchmark.ps1.
function Get-RamMultiThreadCopyResult {
    param([int]$BufferSizeMB = 512, [double]$DurationSeconds = 15, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)
    $cores = [Environment]::ProcessorCount
    if ([IntPtr]::Size -eq 4 -and $BufferSizeMB -gt 128) { $BufferSizeMB = 128 }
    $perThreadMB = [Math]::Max(4, [int]($BufferSizeMB / $cores))

    $workloadScript = {
        param($PerThreadMB, $DurationSeconds, $Sync)
        $size = $PerThreadMB * 1MB
        $src = [byte[]]::new($size)
        $dst = [byte[]]::new($size)
        [System.Random]::new().NextBytes($src)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $bytesMoved = 0L
        while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds -and -not $Sync.Cancel) {
            [System.Buffer]::BlockCopy($src, 0, $dst, 0, $size)
            $bytesMoved += (2 * $size)
            # Same note as Invoke-CpuWorkloadMultiThread: plain assignment, not Interlocked - fine
            # for an approximate once-a-second progress sample, not the authoritative total below.
            $Sync.Bytes = $bytesMoved
        }
        $Sync.Bytes = $bytesMoved
        return $bytesMoved
    }

    $counters = for ($i = 0; $i -lt $cores; $i++) { [PSCustomObject]@{ Bytes = 0L; Cancel = $false } }
    $pool = [runspacefactory]::CreateRunspacePool(1, $cores)
    $pool.Open()
    try {
        Set-GuiProgress 5 "Allocating $perThreadMB MB x $cores thread buffers..."
        $jobs = for ($i = 0; $i -lt $cores; $i++) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($workloadScript).AddArgument($perThreadMB).AddArgument($DurationSeconds).AddArgument($counters[$i])
            [PSCustomObject]@{ Shell = $ps; Handle = $ps.BeginInvoke() }
        }
        Set-GuiProgress 15 "Measuring multi-threaded bandwidth across $cores threads ($DurationSeconds s)..."
        $samples = [System.Collections.Generic.List[double]]::new()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastTotalBytes = 0L
        $lastSecond = 0
        while (($jobs | Where-Object { -not $_.Handle.IsCompleted } | Measure-Object).Count -gt 0) {
            Start-Sleep -Milliseconds 50
            if ($CancelCheck -and (& $CancelCheck)) { foreach ($c in $counters) { $c.Cancel = $true } }
            $curSecond = [int][math]::Floor($sw.Elapsed.TotalSeconds)
            if ($curSecond -gt $lastSecond) {
                $curTotalBytes = ($counters | Measure-Object -Property Bytes -Sum).Sum
                $sample = [math]::Round((($curTotalBytes - $lastTotalBytes) / 1MB), 0)
                $samples.Add($sample) | Out-Null
                $lastTotalBytes = $curTotalBytes
                $lastSecond = $curSecond
                if ($OnSample) { & $OnSample $sample }
                Set-GuiProgress (15 + [math]::Min(80, [math]::Round($sw.Elapsed.TotalSeconds / $DurationSeconds * 80)))
            }
        }
        $totalBytes = 0L
        foreach ($j in $jobs) {
            $totalBytes += ($j.Shell.EndInvoke($j.Handle) | Select-Object -First 1)
            $j.Shell.Dispose()
        }
        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        $avgMBs = if ($samples.Count -gt 0) { [math]::Round(($samples | Measure-Object -Average).Average) } else { [math]::Round(($totalBytes / 1MB) / $DurationSeconds) }
        Set-GuiProgress 100 $(if ($cancelled) { "Multi-threaded RAM test stopped." } else { "Multi-threaded RAM test complete." })
        [PSCustomObject]@{
            Cancelled   = $cancelled
            Threads     = $cores
            PerThreadMB = $perThreadMB
            AvgMBs      = $avgMBs
            MinMBs      = if ($samples.Count -gt 0) { [math]::Round(($samples | Measure-Object -Minimum).Minimum) } else { $avgMBs }
            MaxMBs      = if ($samples.Count -gt 0) { [math]::Round(($samples | Measure-Object -Maximum).Maximum) } else { $avgMBs }
            Samples     = $samples
        }
    } finally { $pool.Close(); $pool.Dispose() }
}
#endregion
