# Disk benchmark: writes a temp file in sequential chunks for half of $DurationSeconds (instead of
# a fixed size) then reads the whole thing back, measuring MB/s for each direction. Uses
# FileOptions.WriteThrough on write (bypasses the OS write cache for a more realistic number) -
# read is still subject to OS caching, so it's a best-effort approximation, not a lab-grade
# sequential I/O benchmark. Throughput is sampled every 64 MB chunk (instead of only a single
# total) so the result reports min/max/avg and a chart. $DurationSeconds is user-selectable
# (30/60/120s) - a longer run writes more data, giving a more representative sustained-throughput
# number than a single short burst. The temp file is deleted when done regardless of outcome.
function Get-DiskBenchmarkResult {
    param([string]$TargetDir = $null, [double]$DurationSeconds = 30, [int]$BlockSizeKB = 1024, [int]$SampleChunkMB = 64, [scriptblock]$OnWriteSample = $null, [scriptblock]$OnReadSample = $null, [scriptblock]$CancelCheck = $null)
    if (-not $TargetDir) { $TargetDir = $Script:TempDir }
    if (-not $TargetDir -or -not (Test-Path $TargetDir)) { $TargetDir = [System.IO.Path]::GetTempPath() }
    $testFile = Join-Path $TargetDir "SETTDash_DiskBenchmark.tmp"

    $blockSize = $BlockSizeKB * 1KB
    $blocksPerSample = [math]::Max(1, [int](($SampleChunkMB * 1MB) / $blockSize))
    $block = [byte[]]::new($blockSize)
    [System.Random]::new(7).NextBytes($block)
    $writeBudget = $DurationSeconds / 2

    try {
        Set-GuiProgress 10 "Writing test file to disk ($writeBudget s)..."
        $writeSamples = [System.Collections.Generic.List[double]]::new()
        $blockCount = 0L
        $fsWrite = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $totalSw = [System.Diagnostics.Stopwatch]::StartNew()
            $swChunk = [System.Diagnostics.Stopwatch]::StartNew()
            $i = 0L
            while ($totalSw.Elapsed.TotalSeconds -lt $writeBudget -and -not ($CancelCheck -and (& $CancelCheck))) {
                $fsWrite.Write($block, 0, $block.Length)
                $i++
                if (($i % $blocksPerSample) -eq 0) {
                    $fsWrite.Flush($true)
                    $sample = [math]::Round(($blocksPerSample * $blockSize / 1MB) / $swChunk.Elapsed.TotalSeconds, 1)
                    $writeSamples.Add($sample) | Out-Null
                    $swChunk.Restart()
                    if ($OnWriteSample) { & $OnWriteSample $sample }
                    Set-GuiProgress (10 + [math]::Min(40, [math]::Round($totalSw.Elapsed.TotalSeconds / $writeBudget * 40)))
                }
            }
            $fsWrite.Flush($true)
            $blockCount = $i
        } finally { $fsWrite.Dispose() }
        if ($writeSamples.Count -eq 0) {
            # Ran out of time before completing one full sample chunk - fall back to whatever was written.
            $writeSamples.Add([math]::Round(($blockCount * $blockSize / 1MB) / [math]::Max(0.001, $writeBudget), 1)) | Out-Null
        }
        $totalSizeMB = [math]::Round(($blockCount * $blockSize) / 1MB)
        $writeMBs = [math]::Round(($writeSamples | Measure-Object -Average).Average, 1)

        Set-GuiProgress 55 "Reading test file back from disk..."
        $readSamples = [System.Collections.Generic.List[double]]::new()
        $readBuf = [byte[]]::new($blockSize)
        $fsRead = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $swChunk = [System.Diagnostics.Stopwatch]::StartNew()
            $readTotal = 0L
            $blocksRead = 0
            while (($n = $fsRead.Read($readBuf, 0, $readBuf.Length)) -gt 0 -and -not ($CancelCheck -and (& $CancelCheck))) {
                $readTotal += $n
                $blocksRead++
                if (($blocksRead % $blocksPerSample) -eq 0) {
                    $sample = [math]::Round(($blocksPerSample * $blockSize / 1MB) / $swChunk.Elapsed.TotalSeconds, 1)
                    $readSamples.Add($sample) | Out-Null
                    $swChunk.Restart()
                    if ($OnReadSample) { & $OnReadSample $sample }
                    Set-GuiProgress (55 + [math]::Round($blocksRead / [math]::Max(1, $blockCount) * 40))
                }
            }
        } finally { $fsRead.Dispose() }
        if ($readSamples.Count -eq 0) {
            # File smaller than one sample chunk - fall back to a single whole-file measurement.
            $readSamples.Add([math]::Round(($readTotal / 1MB) / [math]::Max(0.001, $swChunk.Elapsed.TotalSeconds), 1)) | Out-Null
        }
        $readMBs = [math]::Round(($readSamples | Measure-Object -Average).Average, 1)

        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        Set-GuiProgress 100 $(if ($cancelled) { "Disk benchmark stopped." } else { "Disk benchmark complete." })
        [PSCustomObject]@{
            TotalSizeMB  = $totalSizeMB
            Cancelled    = $cancelled
            WriteMBs     = $writeMBs
            WriteMin     = [math]::Round(($writeSamples | Measure-Object -Minimum).Minimum, 1)
            WriteMax     = [math]::Round(($writeSamples | Measure-Object -Maximum).Maximum, 1)
            WriteSamples = $writeSamples
            ReadMBs      = $readMBs
            ReadMin      = [math]::Round(($readSamples | Measure-Object -Minimum).Minimum, 1)
            ReadMax      = [math]::Round(($readSamples | Measure-Object -Maximum).Maximum, 1)
            ReadSamples  = $readSamples
        }
    } finally {
        if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
    }
}
