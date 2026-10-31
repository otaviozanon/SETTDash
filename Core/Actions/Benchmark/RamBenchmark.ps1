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
    $size = $BufferSizeMB * 1MB
    $phaseBudget = $DurationSeconds / 2
    Set-GuiProgress 10 "Allocating $BufferSizeMB MB test buffers..."
    $src = [byte[]]::new($size)
    $dst = [byte[]]::new($size)
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
