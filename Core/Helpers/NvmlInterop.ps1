#region NVML INTEROP (NVIDIA driver, nvml.dll - no embedding needed, ships with the NVIDIA driver)
# Mirrors ResetExplode's Nvml.cs: minimal P/Invoke over nvml.dll to expose the live metrics that
# LibreHardwareMonitor does not have (P-state, PerfCap/throttle reason, PCIe gen/width in use,
# encoder/decoder utilization, VBIOS, CUDA/compute capability, BAR1, power limit constraints...).
# Unlike LibreHardwareMonitorLib, nvml.dll is NOT bundled here - it already ships with every
# NVIDIA driver install, so this is pure interop, no Base64/GZip embedding required.
$Script:NvmlAvailable = $false
$Script:NvmlInitFailed = $false

# Used by: Show-PageYourPCGpu. Compiles the SettNvml P/Invoke wrapper once (via Add-Type) and calls
# nvmlInit_v2. Safe to call multiple times (no-op after the first success/failure) - returns $false
# without throwing on non-NVIDIA machines or old/missing drivers (DllNotFoundException).
function Initialize-Nvml {
    if ($Script:NvmlAvailable) { return $true }
    if ($Script:NvmlInitFailed) { return $false }
    try {
        if (-not ([System.Management.Automation.PSTypeName]"SettNvml").Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class SettNvml
{
    const string Dll = "nvml.dll";

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct PciInfo
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 16)] public string BusIdLegacy;
        public uint Domain, Bus, Device;
        public uint PciDeviceId;
        public uint PciSubSystemId;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string BusId;
    }
    public struct Memory { public ulong Total, Free, Used; }
    public struct Utilization { public uint Gpu, Memory; }

    public const int ClockGraphics = 0, ClockSm = 1, ClockMem = 2, ClockVideo = 3;

    [DllImport(Dll, EntryPoint = "nvmlInit_v2")] public static extern int Init();
    [DllImport(Dll, EntryPoint = "nvmlDeviceGetCount_v2")] public static extern int GetCount(out uint count);
    [DllImport(Dll, EntryPoint = "nvmlDeviceGetHandleByIndex_v2")] public static extern int GetHandleByIndex(uint index, out IntPtr device);
    [DllImport(Dll, EntryPoint = "nvmlDeviceGetPciInfo_v3")] public static extern int GetPciInfo(IntPtr device, out PciInfo pci);
    [DllImport(Dll, CharSet = CharSet.Ansi)] public static extern int nvmlDeviceGetVbiosVersion(IntPtr device, StringBuilder version, uint length);
    [DllImport(Dll, CharSet = CharSet.Ansi)] public static extern int nvmlSystemGetDriverVersion(StringBuilder version, uint length);
    [DllImport(Dll, EntryPoint = "nvmlSystemGetCudaDriverVersion_v2")] public static extern int GetCudaDriverVersion(out int version);
    [DllImport(Dll)] public static extern int nvmlDeviceGetMemoryInfo(IntPtr device, out Memory memory);
    [DllImport(Dll)] public static extern int nvmlDeviceGetBAR1MemoryInfo(IntPtr device, out Memory bar1);
    [DllImport(Dll)] public static extern int nvmlDeviceGetMemoryBusWidth(IntPtr device, out uint width);
    [DllImport(Dll)] public static extern int nvmlDeviceGetNumGpuCores(IntPtr device, out uint cores);
    [DllImport(Dll)] public static extern int nvmlDeviceGetCudaComputeCapability(IntPtr device, out int major, out int minor);
    [DllImport(Dll)] public static extern int nvmlDeviceGetMaxPcieLinkGeneration(IntPtr device, out uint gen);
    [DllImport(Dll)] public static extern int nvmlDeviceGetMaxPcieLinkWidth(IntPtr device, out uint width);
    [DllImport(Dll)] public static extern int nvmlDeviceGetCurrPcieLinkGeneration(IntPtr device, out uint gen);
    [DllImport(Dll)] public static extern int nvmlDeviceGetCurrPcieLinkWidth(IntPtr device, out uint width);
    [DllImport(Dll)] public static extern int nvmlDeviceGetMaxClockInfo(IntPtr device, int type, out uint mhz);
    [DllImport(Dll)] public static extern int nvmlDeviceGetClockInfo(IntPtr device, int type, out uint mhz);
    [DllImport(Dll)] public static extern int nvmlDeviceGetPowerManagementDefaultLimit(IntPtr device, out uint mw);
    [DllImport(Dll)] public static extern int nvmlDeviceGetEnforcedPowerLimit(IntPtr device, out uint mw);
    [DllImport(Dll)] public static extern int nvmlDeviceGetPowerManagementLimitConstraints(IntPtr device, out uint minMw, out uint maxMw);
    [DllImport(Dll)] public static extern int nvmlDeviceGetPowerUsage(IntPtr device, out uint mw);
    [DllImport(Dll)] public static extern int nvmlDeviceGetPerformanceState(IntPtr device, out int pstate);
    [DllImport(Dll)] public static extern int nvmlDeviceGetCurrentClocksThrottleReasons(IntPtr device, out ulong reasons);
    [DllImport(Dll)] public static extern int nvmlDeviceGetEncoderUtilization(IntPtr device, out uint util, out uint periodUs);
    [DllImport(Dll)] public static extern int nvmlDeviceGetDecoderUtilization(IntPtr device, out uint util, out uint periodUs);
    [DllImport(Dll)] public static extern int nvmlDeviceGetUtilizationRates(IntPtr device, out Utilization util);

    public static string GetVbios(IntPtr h) { var sb = new StringBuilder(64); return nvmlDeviceGetVbiosVersion(h, sb, (uint)sb.Capacity) == 0 ? sb.ToString() : null; }
    public static string GetDriverVersion() { var sb = new StringBuilder(96); return nvmlSystemGetDriverVersion(sb, (uint)sb.Capacity) == 0 ? sb.ToString() : null; }
}
"@ -ErrorAction Stop
        }
        $r = [SettNvml]::Init()
        if ($r -ne 0) { throw "nvmlInit returned $r" }
        $Script:NvmlAvailable = $true
        Write-GuiLog "NVML initialized (NVIDIA live GPU metrics enabled)" "OK"
        return $true
    } catch {
        $Script:NvmlInitFailed = $true
        return $false
    }
}

# Returns @{Handle=IntPtr; PciDeviceId=uint} for every NVML-visible device (skips devices NVML
# fails to enumerate - old drivers, permission issues, etc.).
function Get-NvmlDevices {
    if (-not $Script:NvmlAvailable) { return @() }
    $list = @()
    try {
        $count = 0
        if ([SettNvml]::GetCount([ref]$count) -ne 0) { return @() }
        for ($i = 0; $i -lt $count; $i++) {
            $h = [IntPtr]::Zero
            if ([SettNvml]::GetHandleByIndex($i, [ref]$h) -ne 0) { continue }
            $pci = New-Object SettNvml+PciInfo
            if ([SettNvml]::GetPciInfo($h, [ref]$pci) -ne 0) { continue }
            $list += [PSCustomObject]@{ Handle = $h; PciDeviceId = $pci.PciDeviceId }
        }
    } catch {}
    return $list
}

# Finds the NVML handle for the WMI GPU whose PNPDeviceID contains VEN_10DE&DEV_xxxx, matching by
# the same (device<<16 | vendor) PCI device id NVML reports - mirrors GpuInfoCollector.Build().
function Get-NvmlHandleForDevice {
    param([string]$DeviceHex)
    if (-not $DeviceHex) { return [IntPtr]::Zero }
    try {
        $pciId = ([Convert]::ToUInt32($DeviceHex, 16) -shl 16) -bor 0x10DE
        $match = Get-NvmlDevices | Where-Object { $_.PciDeviceId -eq $pciId } | Select-Object -First 1
        if ($match) { return $match.Handle }
    } catch {}
    return [IntPtr]::Zero
}

# Translates nvmlDeviceGetCurrentClocksThrottleReasons bitmask into a readable label, mirroring
# GpuInfo.PerfCap() in GpuInfoCollector.cs.
function Format-NvmlPerfCap {
    param([UInt64]$Reasons)
    $parts = @()
    if ($Reasons -band 0x4)  { $parts += "Power" }
    if ($Reasons -band 0x60) { $parts += "Thermal" }
    if ($Reasons -band 0x8)  { $parts += "HW slowdown" }
    if ($Reasons -band 0x80) { $parts += "Power brake" }
    if ($parts.Count -eq 0) { return $(if ($Reasons -band 0x1) { "Idle" } else { "None" }) }
    return ($parts -join " + ")
}

function Get-NvmlPcieName {
    param([uint32]$Gen)
    switch ($Gen) {
        1 { "PCIe 1.1" }; 2 { "PCIe 2.0" }; 3 { "PCIe 3.0" }; 4 { "PCIe 4.0" }; 5 { "PCIe 5.0" }; 6 { "PCIe 6.0" }
        default { "PCIe gen $Gen" }
    }
}

# Used by: Get-GpuInfoRows (YourPCGpu.ps1). Builds extra Info-tab sections sourced from NVML only
# (memory bus/BAR1, PCIe max link, power limits, VBIOS, CUDA/compute capability) - everything the
# WMI-only path cannot see, mirroring the NVIDIA-specific sections of GpuInfoCollector.Build().
function Get-NvmlInfoRows {
    param([IntPtr]$Handle)
    if ($Handle -eq [IntPtr]::Zero) { return @() }
    $rows = @()

    $busWidth = 0; $memClock = 0; $bar1 = New-Object SettNvml+Memory
    $hasBus = [SettNvml]::nvmlDeviceGetMemoryBusWidth($Handle, [ref]$busWidth) -eq 0
    $hasMemClock = [SettNvml]::nvmlDeviceGetMaxClockInfo($Handle, [SettNvml]::ClockMem, [ref]$memClock) -eq 0
    $hasBar1 = [SettNvml]::nvmlDeviceGetBAR1MemoryInfo($Handle, [ref]$bar1) -eq 0
    if ($hasBus -or $hasMemClock -or $hasBar1) {
        $rows += @{IsHeader=$true; Label="MEMORY (NVML)"}
        if ($hasBus) { $rows += @{Label="Bus Width"; Value="$busWidth bits"} }
        if ($hasMemClock) {
            $gbps = [math]::Round($memClock * 2 / 1000.0, 1)
            $rows += @{Label="Memory Clock"; Value="$memClock MHz ($gbps Gbps effective)"}
            if ($hasBus) { $rows += @{Label="Bandwidth"; Value="$([math]::Round($gbps * $busWidth / 8, 1)) GB/s"} }
        }
        if ($hasBar1) { $rows += @{Label="Resizable BAR"; Value=$(if ($bar1.Total -gt 256MB) { "Enabled (BAR1 $([math]::Round($bar1.Total/1GB,1)) GB)" } else { "Disabled" })} }
    }

    $maxGen = 0; $maxW = 0; $curGen = 0; $curW = 0
    $hasMax = ([SettNvml]::nvmlDeviceGetMaxPcieLinkGeneration($Handle, [ref]$maxGen) -eq 0) -and ([SettNvml]::nvmlDeviceGetMaxPcieLinkWidth($Handle, [ref]$maxW) -eq 0)
    $hasCur = ([SettNvml]::nvmlDeviceGetCurrPcieLinkGeneration($Handle, [ref]$curGen) -eq 0) -and ([SettNvml]::nvmlDeviceGetCurrPcieLinkWidth($Handle, [ref]$curW) -eq 0)
    if ($hasMax -or $hasCur) {
        $rows += @{IsHeader=$true; Label="PCI EXPRESS (NVML)"}
        if ($hasMax) { $rows += @{Label="Max Link"; Value="$(Get-NvmlPcieName $maxGen) x$maxW"} }
        if ($hasCur) { $rows += @{Label="Current Link"; Value="$(Get-NvmlPcieName $curGen) x$curW$(if ($hasMax -and $maxGen -gt $curGen) { ' (power saving at idle)' } else { '' })"} }
    }

    $defMw = 0; $limMw = 0; $minMw = 0; $maxMw = 0
    $hasDef = [SettNvml]::nvmlDeviceGetPowerManagementDefaultLimit($Handle, [ref]$defMw) -eq 0
    $hasLim = [SettNvml]::nvmlDeviceGetEnforcedPowerLimit($Handle, [ref]$limMw) -eq 0
    $hasRange = [SettNvml]::nvmlDeviceGetPowerManagementLimitConstraints($Handle, [ref]$minMw, [ref]$maxMw) -eq 0
    if ($hasDef -or $hasLim -or $hasRange) {
        $rows += @{IsHeader=$true; Label="POWER (NVML)"}
        if ($hasLim) { $rows += @{Label="Current Limit"; Value="$([math]::Round($limMw/1000.0,0)) W"} }
        if ($hasDef) { $rows += @{Label="Default Board Limit"; Value="$([math]::Round($defMw/1000.0,0)) W"} }
        if ($hasRange) { $rows += @{Label="Adjustable Range"; Value="$([math]::Round($minMw/1000.0,0)) - $([math]::Round($maxMw/1000.0,0)) W"} }
    }

    $vbios = [SettNvml]::GetVbios($Handle)
    $drvVer = [SettNvml]::GetDriverVersion()
    $cudaVer = 0; $hasCuda = [SettNvml]::GetCudaDriverVersion([ref]$cudaVer) -eq 0
    $major = 0; $minor = 0; $hasCc = [SettNvml]::nvmlDeviceGetCudaComputeCapability($Handle, [ref]$major, [ref]$minor) -eq 0
    if ($vbios -or $drvVer -or $hasCuda -or $hasCc) {
        $rows += @{IsHeader=$true; Label="DRIVER AND BIOS (NVML)"}
        if ($vbios) { $rows += @{Label="VBIOS Version"; Value=$vbios} }
        if ($drvVer) { $rows += @{Label="NVIDIA Driver Version"; Value=$drvVer} }
        if ($hasCuda) { $rows += @{Label="CUDA Version"; Value="$([math]::Floor($cudaVer/1000)).$([math]::Floor(($cudaVer%1000)/10))"} }
        if ($hasCc) { $rows += @{Label="Compute Capability"; Value="$major.$minor"} }
    }
    return $rows
}

# Used by: Get-GpuSensorRows (YourPCGpu.ps1). Builds the "NVIDIA LIVE DATA" group for the Sensors
# tab: readings LibreHardwareMonitor does not expose (P-state, throttle/PerfCap reason, power
# usage vs limit %, encoder/decoder engine load, PCIe link actually in use) - mirrors
# GpuInfo.LiveExtras() in GpuInfoCollector.cs.
function Get-NvmlLiveRows {
    param([IntPtr]$Handle)
    if ($Handle -eq [IntPtr]::Zero) { return @() }
    $rows = @()

    $pstate = 0
    if ([SettNvml]::nvmlDeviceGetPerformanceState($Handle, [ref]$pstate) -eq 0) { $rows += @{Label="Performance State"; Value="P$pstate"} }

    $reasons = [UInt64]0
    if ([SettNvml]::nvmlDeviceGetCurrentClocksThrottleReasons($Handle, [ref]$reasons) -eq 0) { $rows += @{Label="Throttle Reason (PerfCap)"; Value=(Format-NvmlPerfCap $reasons)} }

    $pwMw = 0; $limMw = 0
    $hasPw = [SettNvml]::nvmlDeviceGetPowerUsage($Handle, [ref]$pwMw) -eq 0
    $hasLim = [SettNvml]::nvmlDeviceGetEnforcedPowerLimit($Handle, [ref]$limMw) -eq 0
    if ($hasPw -and $hasLim -and $limMw -gt 0) {
        $rows += @{Label="Power Draw / Limit"; Value="$([math]::Round($pwMw/1000.0,1)) W . $([math]::Round(100.0*$pwMw/$limMw,0)) %"}
    } elseif ($hasPw) {
        $rows += @{Label="Power Draw"; Value="$([math]::Round($pwMw/1000.0,1)) W"}
    }

    $util = New-Object SettNvml+Utilization
    if ([SettNvml]::nvmlDeviceGetUtilizationRates($Handle, [ref]$util) -eq 0) { $rows += @{Label="Memory Controller Load"; Value="$($util.Memory) %"} }

    $encU = 0; $encP = 0
    if ([SettNvml]::nvmlDeviceGetEncoderUtilization($Handle, [ref]$encU, [ref]$encP) -eq 0) { $rows += @{Label="Encoder (NVENC)"; Value="$encU %"} }
    $decU = 0; $decP = 0
    if ([SettNvml]::nvmlDeviceGetDecoderUtilization($Handle, [ref]$decU, [ref]$decP) -eq 0) { $rows += @{Label="Decoder (NVDEC)"; Value="$decU %"} }

    $curGen = 0; $curW = 0
    if (([SettNvml]::nvmlDeviceGetCurrPcieLinkGeneration($Handle, [ref]$curGen) -eq 0) -and ([SettNvml]::nvmlDeviceGetCurrPcieLinkWidth($Handle, [ref]$curW) -eq 0)) {
        $rows += @{Label="PCIe In Use"; Value="$(Get-NvmlPcieName $curGen) x$curW"}
    }

    if ($rows.Count -eq 0) { return @() }
    return (@(@{IsHeader=$true; Label="NVIDIA LIVE DATA"}) + $rows)
}
#endregion
