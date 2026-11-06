# CPU benchmark: three compiled (C#) kernels run for a fixed time budget, single-thread and
# all-core - Integer (xorshift/rotate ALU chain with a data-dependent branch), Float (eight
# independent mul/add chains plus a throughput sqrt) and Hash (FNV-style 64-bit mixing over a 4 MB
# cache-resident buffer).
#
# Why the kernels are C# instead of PowerShell loops: the previous revision timed interpreted
# PowerShell work units, and a unit was mostly the interpreter itself - measured on a Ryzen 7
# 5700X, the same trial-division math runs ~120x faster compiled, so ~99% of the old "Integer"
# score was PowerShell dispatch overhead rather than CPU work. A benchmark whose score is measured
# in interpreter calls cannot rank CPUs (two CPUs with equal interpreter speed tie even when their
# real throughput differs by 40%) and its multi-core ratio measured runspace-pool contention, not
# core scaling. The kernels below are a few hundred nanoseconds of native code per unit, so the
# score tracks the CPU.
#
# Method (mirrors how Cinebench/Geekbench score): each pass is a series of short, individually
# timed blocks of fixed duration; the reported score is the MEDIAN of the blocks, which rejects the
# odd block disturbed by a Windows service or the UI thread. Threads are pinned (one logical CPU
# per worker, single-core pass pinned to CPU 0) and raised to high priority with Windows power
# throttling disabled for the duration of the run, so the numbers reflect the CPU rather than the
# scheduler.
#
# Units: Integer = Mops/s (one op = one iteration of the mixed ALU block), Float = Mflop/s (25
# counted FLOPs per iteration), Hash = MB/s of buffer mixed. Units differ per kernel - compare a
# kernel against itself across machines/runs, never Integer against Float.

$Script:CpuKernelsReady = $false
$Script:CpuKernelVersion = 1

# Compiles the SettCpuKernels type once (same Add-Type pattern as SettDiskIo/Initialize-Vortice3D)
# and reports failure instead of throwing, so the caller can surface a readable message.
function Initialize-CpuKernels {
    if ($Script:CpuKernelsReady) { return $true }
    if (([System.Management.Automation.PSTypeName]"SettCpuKernels").Type) {
        $Script:CpuKernelsReady = $true
        return $true
    }
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class SettCpuKernels
{
    public const int Version = 1;
    // Counted floating-point operations per Float-kernel iteration:
    // 4 x (mul+add) for a0..a7 = 16, plus 4 mul + 3 add + 1 sqrt + 1 add into acc = 9.
    public const int FlopsPerIteration = 25;

    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr GetCurrentThread();
    [DllImport("kernel32.dll", SetLastError = true)] private static extern UIntPtr SetThreadAffinityMask(IntPtr hThread, UIntPtr dwThreadAffinityMask);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetPriorityClass(IntPtr hProcess, uint dwPriorityClass);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetThreadPriority(IntPtr hThread, int nPriority);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetProcessInformation(IntPtr hProcess, int infoClass, ref POWER_THROTTLING_STATE state, int size);

    [StructLayout(LayoutKind.Sequential)]
    private struct POWER_THROTTLING_STATE { public uint Version; public uint ControlMask; public uint StateMask; }

    private const uint HIGH_PRIORITY_CLASS = 0x00000080;
    private const uint NORMAL_PRIORITY_CLASS = 0x00000020;
    private const int THREAD_PRIORITY_HIGHEST = 2;
    private const int ProcessPowerThrottling = 4;
    private const uint PROCESS_POWER_THROTTLING_EXECUTION_SPEED = 0x1;

    // Set by the GUI thread on Stop; checked between inner chunks (a few microseconds), so a run
    // aborts promptly instead of after the current multi-second pass.
    private static volatile bool s_cancel;
    // Written once per block so the JIT cannot prove the kernel results are dead and delete them.
    private static ulong s_sink;
    private static ulong[] s_hashData;

    public static void ResetCancel() { s_cancel = false; }
    public static void RequestCancel() { s_cancel = true; }

    public static int LogicalProcessors { get { return Environment.ProcessorCount; } }

    // Process-wide setup: high priority plus a disabled power-throttling execution-speed mask, so
    // Windows does not downclock the benchmark as a background workload (EcoQoS). Also allocates
    // the Hash kernel buffer here, never inside a timed block.
    public static void Prepare()
    {
        try { SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS); } catch { }
        try {
            var st = new POWER_THROTTLING_STATE();
            st.Version = 1; st.ControlMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED; st.StateMask = 0;
            SetProcessInformation(GetCurrentProcess(), ProcessPowerThrottling, ref st, Marshal.SizeOf(typeof(POWER_THROTTLING_STATE)));
        } catch { }
        if (s_hashData == null) {
            var data = new ulong[(4 * 1024 * 1024) / 8];
            ulong x = 0x243F6A8885A308D3UL;
            for (int i = 0; i < data.Length; i++) {
                x ^= x << 13; x ^= x >> 7; x ^= x << 17;
                data[i] = x;
            }
            s_hashData = data;
        }
    }

    public static void Restore()
    {
        try { SetPriorityClass(GetCurrentProcess(), NORMAL_PRIORITY_CLASS); } catch { }
    }

    public class BlockResult
    {
        public string Kernel;
        public int Threads;
        public double Units;
        public double Seconds;
        public double Score { get { return Seconds > 0.0 ? Units / Seconds : 0.0; } }
    }

    // Runs one timed block: spawns 'threads' workers (each pinned to one logical CPU), releases
    // them together and sums their units over the wall-clock time they were running. Thread
    // creation is ~1% of a 400 ms block and is deliberately included in the wall time, so the
    // reported score is what the machine actually delivered.
    public static BlockResult RunBlock(string kernel, int milliseconds, int threads)
    {
        if (threads < 1) threads = 1;
        int cpus = Environment.ProcessorCount;
        if (threads > cpus) threads = cpus;

        var units = new double[threads];
        var workers = new Thread[threads];
        var gate = new ManualResetEventSlim(false);

        for (int t = 0; t < threads; t++) {
            int index = t;
            workers[t] = new Thread(new ThreadStart(delegate {
                try { SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_HIGHEST); } catch { }
                // >62 logical CPUs means multiple processor groups; leave those unpinned (the
                // 64-bit affinity mask cannot address them anyway).
                if (index < 62) {
                    try { SetThreadAffinityMask(GetCurrentThread(), (UIntPtr)(1UL << index)); } catch { }
                }
                gate.Wait();
                units[index] = RunKernel(kernel, milliseconds);
            }));
            workers[t].IsBackground = true;
            workers[t].Start();
        }

        var sw = Stopwatch.StartNew();
        gate.Set();
        for (int t = 0; t < threads; t++) workers[t].Join();
        sw.Stop();

        double total = 0.0;
        for (int t = 0; t < threads; t++) total += units[t];

        var result = new BlockResult();
        result.Kernel = kernel;
        result.Threads = threads;
        result.Units = total;
        result.Seconds = sw.Elapsed.TotalSeconds;
        return result;
    }

    private static double RunKernel(string kernel, int ms)
    {
        if (kernel == "Float") return KernelFloat(ms);
        if (kernel == "Hash") return KernelHash(ms);
        return KernelInteger(ms);
    }

    // Integer: xorshift + 64-bit multiply + rotate, with one data-dependent branch taken ~12% of
    // the time. Mixes the integer ALU (mul/xor/shift/rotate) with the branch predictor, which is
    // what most scalar game/server code actually spends its integer cycles on.
    private static double KernelInteger(int ms)
    {
        ulong x = 0x9E3779B97F4A7C15UL;
        ulong acc = 0x1234567UL;
        long ops = 0;
        var sw = Stopwatch.StartNew();
        while (true) {
            for (int i = 0; i < 2048; i++) {
                x ^= x >> 12;
                x ^= x << 25;
                x ^= x >> 27;
                ulong m = x * 0x2545F4914F6CDD1DUL;
                if ((m & 0x1C000000UL) == 0) acc += m; else acc ^= m;
                acc = (acc << 9) | (acc >> 55);
                x += 0x9E3779B97F4A7C15UL;
            }
            ops += 2048;
            if (sw.ElapsedMilliseconds >= ms || s_cancel) break;
        }
        s_sink ^= acc;
        return (double)ops;
    }

    // Float: eight independent mul/add chains (so the FPU throughput is measured, not the latency
    // of one dependent chain) plus one sqrt per iteration from already-computed values, which
    // keeps sqrt throughput-bound as well. All values stay bounded (each chain converges to a
    // small constant, sqrt input is a sum of squares).
    private static double KernelFloat(int ms)
    {
        double a0 = 1.0, a1 = 1.1, a2 = 1.2, a3 = 1.3, a4 = 1.4, a5 = 1.5, a6 = 1.6, a7 = 1.7;
        double acc = 0.0;
        const double k = 1.0000000001;
        const double d = 0.0000000001;
        long iters = 0;
        var sw = Stopwatch.StartNew();
        while (true) {
            for (int i = 0; i < 1024; i++) {
                a0 = a0 * k + d; a1 = a1 * k + d; a2 = a2 * k + d; a3 = a3 * k + d;
                a4 = a4 * k + d; a5 = a5 * k + d; a6 = a6 * k + d; a7 = a7 * k + d;
                acc += Math.Sqrt(a0 * a0 + a1 * a1 + a2 * a2 + a3 * a3);
            }
            iters += 1024;
            if (sw.ElapsedMilliseconds >= ms || s_cancel) break;
        }
        s_sink ^= (ulong)BitConverter.DoubleToInt64Bits(acc + a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7);
        return (double)(iters * FlopsPerIteration);
    }

    // Hash: eight independent FNV-style lanes over a 4 MB buffer (larger than any consumer L2,
    // small enough to stay in L3 on most CPUs). Measures cache/L3 read throughput fused with the
    // integer multiply pipeline - the access pattern behind hashing, checksums and table lookups.
    private static double KernelHash(int ms)
    {
        ulong[] data = s_hashData;
        int n = data.Length;
        ulong h0 = 0x9E3779B97F4A7C15UL, h1 = 0xC2B2AE3D27D4EB4FUL;
        ulong h2 = 0x165667B19E3779F9UL, h3 = 0x85EBCA77C2B2AE63UL;
        ulong h4 = 0x27D4EB2F165667C5UL, h5 = 0x94D049BB133111EBUL;
        ulong h6 = 0xD6E8FEB86659FD93UL, h7 = 0xA0761D6478BD642FUL;
        long bytes = 0;
        var sw = Stopwatch.StartNew();
        while (true) {
            for (int i = 0; i < n; i += 8) {
                h0 = (h0 ^ data[i]) * 0x100000001B3UL;
                h1 = (h1 ^ data[i + 1]) * 0x9E3779B97F4A7C15UL;
                h2 = (h2 ^ data[i + 2]) * 0xC2B2AE3D27D4EB4FUL;
                h3 = (h3 ^ data[i + 3]) * 0x165667B19E3779F9UL;
                h4 = (h4 ^ data[i + 4]) * 0x85EBCA77C2B2AE63UL;
                h5 = (h5 ^ data[i + 5]) * 0x27D4EB2F165667C5UL;
                h6 = (h6 ^ data[i + 6]) * 0x94D049BB133111EBUL;
                h7 = (h7 ^ data[i + 7]) * 0xA0761D6478BD642FUL;
            }
            bytes += (long)n * 8L;
            if (sw.ElapsedMilliseconds >= ms || s_cancel) break;
        }
        s_sink ^= h0 ^ h1 ^ h2 ^ h3 ^ h4 ^ h5 ^ h6 ^ h7;
        return (double)bytes;
    }
}
'@ -ErrorAction Stop
        $Script:CpuKernelsReady = $true
        return $true
    } catch {
        Write-GuiLog "CPU benchmark kernels could not be compiled: $($_.Exception.Message)" "ERR"
        return $false
    }
}

# Kernel catalogue (order matters - it is the run order and the UI order). Unit is the display unit
# and Divisor converts the raw C# units (ops / flops / bytes) into that unit.
$Script:CpuKernels = @(
    [PSCustomObject]@{ Kernel = 'Integer'; Label = 'Integer ALU + branch'; Unit = 'Mops/s'; Divisor = 1e6 }
    [PSCustomObject]@{ Kernel = 'Float';   Label = 'Float mul/add + sqrt'; Unit = 'Mflop/s'; Divisor = 1e6 }
    [PSCustomObject]@{ Kernel = 'Hash';    Label = 'Hash (cache + ALU)';  Unit = 'MB/s';    Divisor = 1MB }
)

# One telemetry reading (LibreHardwareMonitor), reduced to the figures that matter for a CPU
# benchmark. Returns $null when LHM is unavailable or reports no CPU sensor at all - the caller must
# treat that as "unknown", never as zero and never as another device's value.
function Get-CpuTelemetryReading {
    if (-not $Script:LHMAvailable) { return $null }
    $rows = @(Get-LHMSensorRows)
    if ($rows.Count -eq 0) { return $null }
    # HardwareType is "Cpu" for every CPU package; GPU hardware reports GpuAti/GpuNvidia/GpuIntel,
    # so an exact match here cannot pick up a GPU sensor by accident.
    $cpuRows = @($rows | Where-Object { $_.HardwareType -eq "Cpu" -and $null -ne $_.Value })
    if ($cpuRows.Count -eq 0) { return $null }

    $pick = {
        param([string]$Type, [string]$NamePattern)
        $hits = @($cpuRows | Where-Object { $_.SensorType -eq $Type -and $_.SensorName -match $NamePattern })
        if ($hits.Count -eq 0) { $hits = @($cpuRows | Where-Object { $_.SensorType -eq $Type }) }
        if ($hits.Count -eq 0) { return $null }
        return [double](($hits | Measure-Object -Property Value -Maximum).Maximum)
    }

    [PSCustomObject]@{
        Temperature = (& $pick "Temperature" "Package|Tctl|Core|CPU")
        Power       = (& $pick "Power" "Package|CPU")
        Clock       = (& $pick "Clock" "Cores|Core|Bus")
        Load        = (& $pick "Load" "CPU Total|Total")
    }
}

# Median of the per-block scores - the robust "steady state" number used as the benchmark score.
function Get-CpuMedian {
    param([double[]]$Values)
    if ($null -eq $Values) { return 0 }
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { return 0 }
    $mid = [int][math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) { return [double]$sorted[$mid] }
    return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2.0
}

# Builds one kernel profile from its per-block sample lists (already converted to display units).
function New-CpuKernelProfile {
    param($Kernel, [System.Collections.Generic.List[double]]$SingleSamples, [System.Collections.Generic.List[double]]$MultiSamples)
    $singleScore = [math]::Round((Get-CpuMedian -Values $SingleSamples.ToArray()))
    $multiScore = [math]::Round((Get-CpuMedian -Values $MultiSamples.ToArray()))
    $singleMin = if ($SingleSamples.Count -gt 0) { [math]::Round(($SingleSamples | Measure-Object -Minimum).Minimum) } else { 0 }
    $singleMax = if ($SingleSamples.Count -gt 0) { [math]::Round(($SingleSamples | Measure-Object -Maximum).Maximum) } else { 0 }
    $multiMin = if ($MultiSamples.Count -gt 0) { [math]::Round(($MultiSamples | Measure-Object -Minimum).Minimum) } else { 0 }
    $multiMax = if ($MultiSamples.Count -gt 0) { [math]::Round(($MultiSamples | Measure-Object -Maximum).Maximum) } else { 0 }
    [PSCustomObject]@{
        Kernel        = $Kernel.Kernel
        Label         = $Kernel.Label
        Unit          = $Kernel.Unit
        SingleScore   = $singleScore
        SingleMin     = $singleMin
        SingleMax     = $singleMax
        SingleSamples = $SingleSamples
        MultiScore    = $multiScore
        MultiMin      = $multiMin
        MultiMax      = $multiMax
        MultiSamples  = $MultiSamples
        # multi/single ratio - how well this kernel scales with cores. ~x11-x13 on an 8C/16T CPU,
        # well below the thread count when SMT, power limits or P/E-core scheduling get in the way.
        MtStRatio     = if ($singleScore -gt 0) { [math]::Round($multiScore / $singleScore, 2) } else { 0 }
    }
}

# Orchestrates the whole CPU benchmark. $DurationSeconds is the TOTAL budget (~30/60/120/180/240 s),
# split across the <6 passes (3 kernels x single/all-core); blocks are ~400 ms each and their count
# is derived from that budget, so the run never exceeds it by more than one block.
function Get-CpuBenchmarkResult {
    param([double]$DurationSeconds = 30, [scriptblock]$OnSingleSample = $null, [scriptblock]$OnMultiSample = $null, [scriptblock]$OnTelemetrySample = $null, [scriptblock]$CancelCheck = $null)

    if (-not (Initialize-CpuKernels)) {
        throw "CPU benchmark kernels are unavailable on this system (see the log for the compiler error)."
    }

    $cpus = [SettCpuKernels]::LogicalProcessors
    $kernels = $Script:CpuKernels
    $blockMs = 400
    $warmupMs = 120

    # Budget per pass minus the one-off warm-up, in blocks of $blockMs. Clamped so a very short
    # budget still produces 3 samples (enough for a median) and a long one (240 s -> ~99 blocks
    # per pass) does not run past the requested budget.
    $perPassSeconds = $DurationSeconds / ($kernels.Count * 2)
    $blocks = [int][math]::Floor((($perPassSeconds - ($warmupMs / 1000.0)) * 1000.0) / $blockMs)
    if ($blocks -lt 3) { $blocks = 3 }
    if ($blocks -gt 120) { $blocks = 120 }

    $totalSteps = $kernels.Count * 2 * ($blocks + 1)
    # A hashtable (not a plain counter variable) so the progress state survives the child scope of
    # each '&' invocation below.
    $progress = @{ Step = 0; Total = $totalSteps }
    # Always calls Set-GuiProgress - even with no status text - because that is what pumps the WPF
    # dispatcher inside this blocking loop. Without the pump the window never repaints and the Stop
    # click is only processed after the whole benchmark finishes (the old revision had exactly that
    # bug during its single-core passes).
    $advance = {
        param([string]$Status)
        $progress.Step++
        $pct = 5 + [math]::Min(90, [math]::Round(($progress.Step / [double]$progress.Total) * 90))
        Set-GuiProgress $pct $Status
    }

    $profiles = @()
    $cancelled = $false
    $started = [System.Diagnostics.Stopwatch]::StartNew()

    # Telemetry: peak CPU temperature/power/clock/load observed while the benchmark runs. Sampled
    # BETWEEN blocks (never inside one), so the sampler's own CPU cost cannot compete with the
    # measured kernel threads. Unavailable when LibreHardwareMonitor cannot be opened - the result
    # then reports Available = $false instead of inventing a number.
    $telemetry = [PSCustomObject]@{
        Available = $false
        Samples   = 0
        MaxTemp   = $null
        MaxPower  = $null
        MaxClock  = $null
        MaxLoad   = $null
    }
    # Hashtable, not a plain variable: the sampler below is invoked with '&', which runs in a child
    # scope, so a plain $lastTelemetryMs assignment inside it would be discarded on return and the
    # rate limit would silently never apply (that bug sampled once per block instead of once a second).
    $telemetryState = @{ LastMs = -1000.0 }
    try {
        if (-not $Script:LHMAvailable) { [void](Initialize-LibreHardwareMonitor) }
    } catch { }
    $sampleTelemetry = {
        $nowMs = $started.Elapsed.TotalMilliseconds
        if (($nowMs - $telemetryState.LastMs) -lt 1200.0) { return }
        $telemetryState.LastMs = $nowMs
        $reading = Get-CpuTelemetryReading
        if (-not $reading) { return }
        $telemetry.Available = $true
        $telemetry.Samples++
        if ($null -ne $reading.Temperature -and ($null -eq $telemetry.MaxTemp -or $reading.Temperature -gt $telemetry.MaxTemp)) { $telemetry.MaxTemp = [math]::Round($reading.Temperature, 1) }
        if ($null -ne $reading.Power -and ($null -eq $telemetry.MaxPower -or $reading.Power -gt $telemetry.MaxPower)) { $telemetry.MaxPower = [math]::Round($reading.Power, 1) }
        if ($null -ne $reading.Clock -and ($null -eq $telemetry.MaxClock -or $reading.Clock -gt $telemetry.MaxClock)) { $telemetry.MaxClock = [math]::Round($reading.Clock, 0) }
        if ($null -ne $reading.Load -and ($null -eq $telemetry.MaxLoad -or $reading.Load -gt $telemetry.MaxLoad)) { $telemetry.MaxLoad = [math]::Round($reading.Load, 1) }
        if ($OnTelemetrySample) { & $OnTelemetrySample $telemetry }
    }.GetNewClosure()

    try {
        [SettCpuKernels]::Prepare()
        [SettCpuKernels]::ResetCancel()
        & $sampleTelemetry

        foreach ($kernel in $kernels) {
            if ($CancelCheck -and (& $CancelCheck)) { $cancelled = $true; break }

            # Warm-up: JITs the kernel and faults in the Hash buffer before any block is scored.
            & $advance "$($kernel.Kernel) kernel: warm-up"
            [void][SettCpuKernels]::RunBlock($kernel.Kernel, $warmupMs, 1)
            & $sampleTelemetry

            $singleSamples = [System.Collections.Generic.List[double]]::new()
            $multiSamples = [System.Collections.Generic.List[double]]::new()

            # The status text is only passed on the first block of each pass; the remaining blocks
            # call $advance with $null so Set-GuiProgress still pumps the dispatcher (keeping Stop
            # responsive) without writing a log line per block.
            for ($b = 0; $b -lt $blocks; $b++) {
                if ($CancelCheck -and (& $CancelCheck)) { $cancelled = $true; break }
                $label = if ($b -eq 0) { "$($kernel.Kernel) single-core ($blocks blocks, 1 thread)" } else { $null }
                & $advance $label
                $run = [SettCpuKernels]::RunBlock($kernel.Kernel, $blockMs, 1)
                if ($run.Seconds -gt 0) {
                    $value = [math]::Round(($run.Units / $run.Seconds) / $kernel.Divisor)
                    $singleSamples.Add($value) | Out-Null
                    if ($OnSingleSample) { & $OnSingleSample $kernel.Kernel $value }
                }
                & $sampleTelemetry
            }

            for ($b = 0; $b -lt $blocks; $b++) {
                if ($CancelCheck -and (& $CancelCheck)) { $cancelled = $true; break }
                $label = if ($b -eq 0) { "$($kernel.Kernel) all-core ($blocks blocks, $cpus threads)" } else { $null }
                & $advance $label
                $run = [SettCpuKernels]::RunBlock($kernel.Kernel, $blockMs, $cpus)
                if ($run.Seconds -gt 0) {
                    $value = [math]::Round(($run.Units / $run.Seconds) / $kernel.Divisor)
                    $multiSamples.Add($value) | Out-Null
                    if ($OnMultiSample) { & $OnMultiSample $kernel.Kernel $value }
                }
                & $sampleTelemetry
            }

            $profiles += New-CpuKernelProfile -Kernel $kernel -SingleSamples $singleSamples -MultiSamples $multiSamples
            if ($cancelled) { break }
        }
    } finally {
        [SettCpuKernels]::Restore()
    }

    if ($CancelCheck -and (& $CancelCheck)) { $cancelled = $true }
    $started.Stop()

    $result = @{
        Version         = $Script:CpuKernelVersion
        Threads         = $cpus
        Cancelled       = $cancelled
        DurationSeconds = $DurationSeconds
        ElapsedSeconds  = [math]::Round($started.Elapsed.TotalSeconds, 1)
        Blocks          = $blocks
        Telemetry       = $telemetry
        Integer         = $null
        Float           = $null
        Hash            = $null
    }
    foreach ($p in $profiles) { $result.($p.Kernel) = $p }

    Set-GuiProgress 100 $(if ($cancelled) { "CPU benchmark stopped." } else { "CPU benchmark complete." })
    return $result
}
