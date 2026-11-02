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

#region 4K RANDOM IOPS TEST (mirrors CrystalDiskMark's RND4K Q1T1)
# FILE_FLAG_NO_BUFFERING forces Windows to bypass the OS page cache entirely (reads/writes go
# straight to the storage device), unlike the sequential test above where only the write phase
# uses WriteThrough - without this, random reads on a file that fits in RAM would just measure
# memory speed, not the disk. Requires offsets/lengths aligned to the sector size, which is why
# every I/O here uses a fixed 4096-byte block at a 4096-aligned random offset - safe for the
# overwhelming majority of drives (512 and 4Kn native sector sizes are both multiples of 4096... in
# the 512 case 4096 is a multiple of the sector size, which is what CreateFile actually requires).
$Script:DiskIoTypeReady = $false
function Initialize-DiskIoType {
    if ($Script:DiskIoTypeReady) { return $true }
    try {
        if (-not ([System.Management.Automation.PSTypeName]"SettDiskIo").Type) {
            Add-Type -TypeDefinition @"
using System;
using System.IO;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;

public static class SettDiskIo
{
    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 0x1;
    const uint FILE_SHARE_WRITE = 0x2;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_NO_BUFFERING = 0x20000000;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern SafeFileHandle CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    public static SafeFileHandle OpenUnbuffered(string path)
    {
        // FILE_SHARE_READ | FILE_SHARE_WRITE: the queue-depth test opens this same file from
        // several threads concurrently, each requesting GENERIC_READ | GENERIC_WRITE - without
        // also sharing WRITE, the first thread's handle blocks every subsequent thread's open
        // with ERROR_SHARING_VIOLATION (caught and silently ignored by the caller), so only one
        // of the N threads ever actually ran despite the result reporting "Threads: N".
        SafeFileHandle h = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException("CreateFile (unbuffered) failed, Win32 error " + Marshal.GetLastWin32Error());
        return h;
    }
}
"@ -ErrorAction Stop
        }
        $Script:DiskIoTypeReady = $true
        return $true
    } catch {
        Write-GuiLog "4K random disk test unavailable on this system (unbuffered I/O setup failed): $($_.Exception.Message)" "WARN"
        $Script:DiskIoTypeReady = $false
        return $false
    }
}

# Runs random 4K write IOPS then random 4K read IOPS (queue depth 1, single thread - same as
# CrystalDiskMark's "RND4K Q1T1") against a fixed-size pre-allocated file, bypassing the OS cache
# via FILE_FLAG_NO_BUFFERING so the read pass measures the actual device, not RAM. Returns $null
# (caller should skip the sub-test and keep only the sequential result) if unbuffered I/O can't be
# set up on this system/filesystem (e.g. non-NTFS volumes that reject the flag combination).
function Get-Disk4kRandomResult {
    param([string]$TargetDir = $null, [double]$DurationSeconds = 10, [int]$FileSizeMB = 256, [scriptblock]$OnWriteSample = $null, [scriptblock]$OnReadSample = $null, [scriptblock]$CancelCheck = $null)
    if (-not $TargetDir) { $TargetDir = $Script:TempDir }
    if (-not $TargetDir -or -not (Test-Path $TargetDir)) { $TargetDir = [System.IO.Path]::GetTempPath() }
    if (-not (Initialize-DiskIoType)) { return $null }

    $testFile = Join-Path $TargetDir "SETTDash_Disk4K.tmp"
    $blockSize = 4096
    $fileSize = [int64]$FileSizeMB * 1MB
    $blocksInFile = [math]::Max(1, [int]($fileSize / $blockSize))
    $phaseBudget = $DurationSeconds / 2
    $buffer = [byte[]]::new($blockSize)
    [System.Random]::new(11).NextBytes($buffer)
    $rnd = [System.Random]::new(13)

    $handle = $null; $fs = $null
    try {
        try {
            Set-GuiProgress 5 "Preparing 4K random test file ($FileSizeMB MB)..."
            $fsCreate = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
            try { $fsCreate.SetLength($fileSize) } finally { $fsCreate.Dispose() }

            $handle = [SettDiskIo]::OpenUnbuffered($testFile)
            $fs = [System.IO.FileStream]::new($handle, [System.IO.FileAccess]::ReadWrite, $blockSize, $false)
        } catch {
            Write-GuiLog "4K random disk test skipped: $($_.Exception.Message)" "WARN"
            return $null
        }

        Set-GuiProgress 10 "Random 4K write IOPS ($phaseBudget s)..."
        $writeSamples = [System.Collections.Generic.List[double]]::new()
        $phaseSw = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $ops = 0L
            do {
                $offset = [int64]($rnd.Next(0, $blocksInFile)) * $blockSize
                $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Write($buffer, 0, $blockSize)
                $fs.Flush($true)
                $ops++
            } while ($sw.Elapsed.TotalMilliseconds -lt 150)
            $sw.Stop()
            $iops = [math]::Round($ops / $sw.Elapsed.TotalSeconds)
            $writeSamples.Add($iops) | Out-Null
            if ($OnWriteSample) { & $OnWriteSample $iops }
            Set-GuiProgress (10 + [math]::Min(40, [math]::Round($phaseSw.Elapsed.TotalSeconds / $phaseBudget * 40)))
        } while ($phaseSw.Elapsed.TotalSeconds -lt $phaseBudget -and -not ($CancelCheck -and (& $CancelCheck)))
        $writeIops = [math]::Round(($writeSamples | Measure-Object -Average).Average)

        Set-GuiProgress 55 "Random 4K read IOPS ($phaseBudget s)..."
        $readSamples = [System.Collections.Generic.List[double]]::new()
        $readBuf = [byte[]]::new($blockSize)
        $phaseSw.Restart()
        do {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $ops = 0L
            do {
                $offset = [int64]($rnd.Next(0, $blocksInFile)) * $blockSize
                $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Read($readBuf, 0, $blockSize) | Out-Null
                $ops++
            } while ($sw.Elapsed.TotalMilliseconds -lt 150)
            $sw.Stop()
            $iops = [math]::Round($ops / $sw.Elapsed.TotalSeconds)
            $readSamples.Add($iops) | Out-Null
            if ($OnReadSample) { & $OnReadSample $iops }
            Set-GuiProgress (55 + [math]::Min(40, [math]::Round($phaseSw.Elapsed.TotalSeconds / $phaseBudget * 40)))
        } while ($phaseSw.Elapsed.TotalSeconds -lt $phaseBudget -and -not ($CancelCheck -and (& $CancelCheck)))
        $readIops = [math]::Round(($readSamples | Measure-Object -Average).Average)

        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        Set-GuiProgress 100 $(if ($cancelled) { "4K random test stopped." } else { "4K random test complete." })
        [PSCustomObject]@{
            Cancelled      = $cancelled
            WriteIops      = $writeIops
            WriteMBs       = [math]::Round(($writeIops * $blockSize) / 1MB, 1)
            WriteSamples   = $writeSamples
            ReadIops       = $readIops
            ReadMBs        = [math]::Round(($readIops * $blockSize) / 1MB, 1)
            ReadSamples    = $readSamples
        }
    } finally {
        if ($fs) { $fs.Dispose() } elseif ($handle) { $handle.Dispose() }
        if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
    }
}
#endregion

#region QUEUE DEPTH / MULTI-THREAD RANDOM 4K (mirrors CrystalDiskMark's RND4K Q32T1)
# The Q1T1 test above issues one 4K I/O at a time and waits for it to complete - that's realistic
# for things like app launch latency, but NVMe SSDs in particular have many parallel internal
# channels that a single outstanding request never saturates. CrystalDiskMark's "Q32T1" (and
# similarly Q8T8) figures use many simultaneous outstanding requests to show the drive's real
# ceiling - the gap between Q1T1 and Q32T1 IOPS is exactly what shows a modern NVMe drive's
# advantage over SATA SSD/HDD, which Q1T1 alone doesn't reveal. This reuses the same unbuffered
# file (FILE_FLAG_NO_BUFFERING) but spreads the random 4K reads across a RunspacePool with
# several worker threads, each with its own file handle into the same pre-sized file, to build up
# queue depth the same way CrystalDiskMark's multiple outstanding I/Os do.
function Get-DiskQueueDepthResult {
    param([string]$TargetDir = $null, [double]$DurationSeconds = 10, [int]$FileSizeMB = 256, [int]$Threads = 4, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null)
    if (-not $TargetDir) { $TargetDir = $Script:TempDir }
    if (-not $TargetDir -or -not (Test-Path $TargetDir)) { $TargetDir = [System.IO.Path]::GetTempPath() }
    if (-not (Initialize-DiskIoType)) { return $null }

    $testFile = Join-Path $TargetDir "SETTDash_DiskQD.tmp"
    $blockSize = 4096
    $fileSize = [int64]$FileSizeMB * 1MB
    $blocksInFile = [math]::Max(1, [int]($fileSize / $blockSize))

    try {
        Set-GuiProgress 5 "Preparing queue-depth test file ($FileSizeMB MB)..."
        $fsCreate = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        try { $fsCreate.SetLength($fileSize) } finally { $fsCreate.Dispose() }
    } catch {
        Write-GuiLog "Queue-depth disk test skipped: $($_.Exception.Message)" "WARN"
        if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
        return $null
    }

    # Each worker opens its own unbuffered handle on the same file and reads random 4K-aligned
    # blocks - independent handles let the OS/driver dispatch them concurrently, building queue
    # depth, instead of serializing on a single shared FileStream.
    $workloadScript = {
        param($FilePath, $BlocksInFile, $DurationSeconds, $Sync, $TypeDef)
        try {
            if (-not ([System.Management.Automation.PSTypeName]"SettDiskIo").Type) {
                Add-Type -TypeDefinition $TypeDef -ErrorAction Stop
            }
            $blockSize = 4096
            $handle = [SettDiskIo]::OpenUnbuffered($FilePath)
            $fs = [System.IO.FileStream]::new($handle, [System.IO.FileAccess]::ReadWrite, $blockSize, $false)
            $buf = [byte[]]::new($blockSize)
            $rnd = [System.Random]::new()
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $ops = 0L
            while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds -and -not $Sync.Cancel) {
                $offset = [int64]($rnd.Next(0, $BlocksInFile)) * $blockSize
                $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
                $fs.Read($buf, 0, $blockSize) | Out-Null
                $ops++
                if (($ops -band 0x3F) -eq 0) { $Sync.Ops = $ops }
            }
            $Sync.Ops = $ops
            $fs.Dispose()
            return $ops
        } catch {
            $Sync.Error = $_.Exception.Message
            return 0L
        }
    }

    $typeDef = @"
using System;
using System.IO;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;

public static class SettDiskIo
{
    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 0x1;
    const uint FILE_SHARE_WRITE = 0x2;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_NO_BUFFERING = 0x20000000;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern SafeFileHandle CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    public static SafeFileHandle OpenUnbuffered(string path)
    {
        // Each RunspacePool worker opens its own handle on the same file concurrently - without
        // also sharing WRITE, the first thread to open it blocks every other thread's open with
        // ERROR_SHARING_VIOLATION, silently collapsing the "queue depth" test down to 1 real
        // worker regardless of the requested $Threads count.
        SafeFileHandle h = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException("CreateFile (unbuffered) failed, Win32 error " + Marshal.GetLastWin32Error());
        return h;
    }
}
"@

    $pool = [runspacefactory]::CreateRunspacePool(1, $Threads)
    $pool.Open()
    try {
        $counters = for ($i = 0; $i -lt $Threads; $i++) { [PSCustomObject]@{ Ops = 0L; Cancel = $false; Error = $null } }
        Set-GuiProgress 15 "Random 4K read, queue depth $Threads ($DurationSeconds s)..."
        $jobs = for ($i = 0; $i -lt $Threads; $i++) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($workloadScript).AddArgument($testFile).AddArgument($blocksInFile).AddArgument($DurationSeconds).AddArgument($counters[$i]).AddArgument($typeDef)
            [PSCustomObject]@{ Shell = $ps; Handle = $ps.BeginInvoke() }
        }
        $samples = [System.Collections.Generic.List[double]]::new()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastTotal = 0L
        $lastSecond = 0
        while (($jobs | Where-Object { -not $_.Handle.IsCompleted } | Measure-Object).Count -gt 0) {
            Start-Sleep -Milliseconds 50
            if ($CancelCheck -and (& $CancelCheck)) { foreach ($c in $counters) { $c.Cancel = $true } }
            $curSecond = [int][math]::Floor($sw.Elapsed.TotalSeconds)
            if ($curSecond -gt $lastSecond) {
                $curTotal = ($counters | Measure-Object -Property Ops -Sum).Sum
                $sample = [double]($curTotal - $lastTotal)
                $samples.Add($sample) | Out-Null
                $lastTotal = $curTotal
                $lastSecond = $curSecond
                if ($OnSample) { & $OnSample $sample }
                Set-GuiProgress (15 + [math]::Min(80, [math]::Round($sw.Elapsed.TotalSeconds / $DurationSeconds * 80)))
            }
        }
        $totalOps = 0L
        foreach ($j in $jobs) {
            $totalOps += ($j.Shell.EndInvoke($j.Handle) | Select-Object -First 1)
            $j.Shell.Dispose()
        }
        $firstError = ($counters | Where-Object { $_.Error } | Select-Object -First 1).Error
        if ($totalOps -eq 0 -and $firstError) {
            Write-GuiLog "Queue-depth disk test skipped: $firstError" "WARN"
            return $null
        }
        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        $avgIops = if ($samples.Count -gt 0) { [math]::Round(($samples | Measure-Object -Average).Average) } else { [math]::Round($totalOps / $DurationSeconds) }
        Set-GuiProgress 100 $(if ($cancelled) { "Queue-depth disk test stopped." } else { "Queue-depth disk test complete." })
        [PSCustomObject]@{
            Cancelled = $cancelled
            Threads   = $Threads
            Iops      = $avgIops
            MBs       = [math]::Round(($avgIops * $blockSize) / 1MB, 1)
            Samples   = $samples
        }
    } finally {
        $pool.Close(); $pool.Dispose()
        if (Test-Path $testFile) { Remove-Item $testFile -Force -ErrorAction SilentlyContinue }
    }
}
#endregion
