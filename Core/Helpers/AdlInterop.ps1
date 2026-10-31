#region ADL INTEROP (AMD Display Library, atiadlxx.dll/atiadlxy.dll - ships with the AMD driver)
# AMD's equivalent of NVML: exposes the live telemetry LibreHardwareMonitor does not have, via the
# "PMLog" API (ADL2_New_QueryPMLogData_Get), supported on Vega/RDNA/RDNA2/RDNA3 drivers. Like NVML,
# the DLL is NOT embedded here - it ships with every AMD driver install, this is pure interop.
$Script:AdlAvailable = $false
$Script:AdlInitFailed = $false
$Script:AdlContext = [IntPtr]::Zero

function Initialize-Adl {
    if ($Script:AdlAvailable) { return $true }
    if ($Script:AdlInitFailed) { return $false }
    try {
        if (-not ([System.Management.Automation.PSTypeName]"SettAdl").Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class SettAdl
{
    const string Dll = "atiadlxx.dll";

    public delegate IntPtr ADL_Main_Memory_Alloc(int size);
    // Keep the delegate alive for the process lifetime (GC must not collect it while native code can call back).
    public static readonly ADL_Main_Memory_Alloc AllocDelegate = (size) => Marshal.AllocHGlobal(size);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct AdapterInfo
    {
        public int Size;
        public int AdapterIndex;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string UDID;
        public int BusNumber, DeviceNumber, FunctionNumber, VendorID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string AdapterName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string DisplayName;
        public int Present, Exist;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string DriverPath;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string DriverPathExt;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string PNPString;
        public int OSDisplayIndex;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PMLogSensor { public int SensorName; public int SensorValue; }

    [StructLayout(LayoutKind.Sequential)]
    public struct PMLogDataOutput
    {
        public int Size;
        public int ValidPoints;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public PMLogSensor[] Sensors;
    }

    [DllImport(Dll)] public static extern int ADL2_Main_Control_Create(ADL_Main_Memory_Alloc callback, int enumConnectedAdapters, out IntPtr context);
    [DllImport(Dll)] public static extern int ADL2_Main_Control_Destroy(IntPtr context);
    [DllImport(Dll)] public static extern int ADL2_Adapter_NumberOfAdapters_Get(IntPtr context, out int numAdapters);
    [DllImport(Dll)] public static extern int ADL2_Adapter_AdapterInfo_Get(IntPtr context, IntPtr info, int inputSize);
    [DllImport(Dll)] public static extern int ADL2_New_QueryPMLogData_Get(IntPtr context, int adapterIndex, ref PMLogDataOutput data);
}
"@ -ErrorAction Stop
        }
        $ctx = [IntPtr]::Zero
        $r = [SettAdl]::ADL2_Main_Control_Create([SettAdl]::AllocDelegate, 1, [ref]$ctx)
        if ($r -ne 0 -or $ctx -eq [IntPtr]::Zero) { throw "ADL2_Main_Control_Create returned $r" }
        $Script:AdlContext = $ctx
        $Script:AdlAvailable = $true
        Write-GuiLog "ADL initialized (AMD live GPU metrics enabled)" "OK"
        return $true
    } catch {
        $Script:AdlInitFailed = $true
        return $false
    }
}

# Returns @{AdapterIndex=int; VendorID=int; PNPString=string} for every ADL-visible adapter
# (Present/Exist = 1). Enumerated by allocating a native buffer sized for N AdapterInfo structs.
function Get-AdlAdapters {
    if (-not $Script:AdlAvailable) { return @() }
    $list = @()
    $buf = [IntPtr]::Zero
    try {
        $count = 0
        if ([SettAdl]::ADL2_Adapter_NumberOfAdapters_Get($Script:AdlContext, [ref]$count) -ne 0 -or $count -le 0) { return @() }
        $structSize = [System.Runtime.InteropServices.Marshal]::SizeOf([SettAdl+AdapterInfo])
        $buf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($structSize * $count)
        if ([SettAdl]::ADL2_Adapter_AdapterInfo_Get($Script:AdlContext, $buf, $structSize * $count) -ne 0) { return @() }
        for ($i = 0; $i -lt $count; $i++) {
            $ptr = [IntPtr]::Add($buf, $i * $structSize)
            $info = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][SettAdl+AdapterInfo])
            if ($info.Present -eq 1 -and $info.Exist -eq 1) {
                $list += [PSCustomObject]@{ AdapterIndex = $info.AdapterIndex; VendorID = $info.VendorID; PNPString = $info.PNPString }
            }
        }
    } catch {
    } finally {
        if ($buf -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($buf) }
    }
    return $list
}

# Matches a WMI Win32_VideoController entry (by VEN_1002&DEV_xxxx in PNPDeviceID) to its ADL
# adapter index, mirroring the NVML/DXGI device-matching helpers.
function Get-AdlAdapterIndexForDevice {
    param([string]$DeviceHex)
    if (-not $DeviceHex) { return $null }
    try {
        $match = Get-AdlAdapters | Where-Object { $_.PNPString -match "DEV_$DeviceHex" } | Select-Object -First 1
        if ($match) { return $match.AdapterIndex }
    } catch {}
    return $null
}

# ADL_PMLOG_* sensor IDs (OverdriveN PMLog API, stable across Vega/RDNA/RDNA2/RDNA3 drivers).
$Script:AdlPmLogIds = @{
    GfxClock = 1; MemClock = 2; SocClock = 3
    TempEdge = 4; TempMem = 5; TempHotspot = 23; TempGfx = 24; TempSoc = 25
    FanRpm = 10; FanPercent = 11
    SocPower = 13; SocCurrent = 14
    GfxActivity = 15; MemActivity = 16
    GfxVoltage = 17; MemVoltage = 18
    AsicPower = 19
    GfxPower = 26; GfxCurrent = 27
    Throttler = 31
    BusSpeed = 46; BusLanes = 47
}

# Used by: Get-GpuSensorRows (YourPCGpu.ps1). Builds the "AMD LIVE DATA" group for the Sensors tab
# from the PMLog snapshot - the AMD counterpart of Get-NvmlLiveRows (clocks, temps, power, fan,
# engine activity, PCIe link in use). Returns @() when the adapter/driver doesn't expose PMLog.
function Get-AdlLiveRows {
    param([int]$AdapterIndex)
    if (-not $Script:AdlAvailable -or $null -eq $AdapterIndex) { return @() }
    try {
        $data = New-Object SettAdl+PMLogDataOutput
        $data.Sensors = New-Object 'SettAdl+PMLogSensor[]' 256
        $data.Size = [System.Runtime.InteropServices.Marshal]::SizeOf($data)
        if ([SettAdl]::ADL2_New_QueryPMLogData_Get($Script:AdlContext, $AdapterIndex, [ref]$data) -ne 0) { return @() }
        if ($data.ValidPoints -le 0) { return @() }

        $values = @{}
        for ($i = 0; $i -lt $data.ValidPoints; $i++) { $values[$data.Sensors[$i].SensorName] = $data.Sensors[$i].SensorValue }
        if ($values.Count -eq 0) { return @() }

        $rows = @()
        $id = $Script:AdlPmLogIds
        if ($values.ContainsKey($id.GfxClock))  { $rows += @{Label="GFX Clock"; Value="$($values[$id.GfxClock]) MHz"} }
        if ($values.ContainsKey($id.MemClock))  { $rows += @{Label="Memory Clock"; Value="$($values[$id.MemClock]) MHz"} }
        if ($values.ContainsKey($id.SocClock))  { $rows += @{Label="SoC Clock"; Value="$($values[$id.SocClock]) MHz"} }
        if ($values.ContainsKey($id.TempHotspot)) { $rows += @{Label="Hotspot Temperature"; Value="$($values[$id.TempHotspot]) °C"} }
        elseif ($values.ContainsKey($id.TempGfx)) { $rows += @{Label="GFX Temperature"; Value="$($values[$id.TempGfx]) °C"} }
        if ($values.ContainsKey($id.TempEdge))   { $rows += @{Label="Edge Temperature"; Value="$($values[$id.TempEdge]) °C"} }
        if ($values.ContainsKey($id.TempMem))    { $rows += @{Label="Memory Temperature"; Value="$($values[$id.TempMem]) °C"} }
        if ($values.ContainsKey($id.GfxPower))   { $rows += @{Label="GFX Power"; Value="$($values[$id.GfxPower]) W"} }
        elseif ($values.ContainsKey($id.AsicPower)) { $rows += @{Label="ASIC Power"; Value="$($values[$id.AsicPower]) W"} }
        if ($values.ContainsKey($id.SocPower))   { $rows += @{Label="SoC Power"; Value="$($values[$id.SocPower]) W"} }
        if ($values.ContainsKey($id.GfxVoltage)) { $rows += @{Label="GFX Voltage"; Value="$([math]::Round($values[$id.GfxVoltage]/1000.0,3)) V"} }
        if ($values.ContainsKey($id.GfxActivity)) { $rows += @{Label="GPU Activity"; Value="$($values[$id.GfxActivity]) %"} }
        if ($values.ContainsKey($id.MemActivity)) { $rows += @{Label="Memory Controller Load"; Value="$($values[$id.MemActivity]) %"} }
        if ($values.ContainsKey($id.FanRpm))     { $rows += @{Label="Fan Speed"; Value="$($values[$id.FanRpm]) RPM"} }
        elseif ($values.ContainsKey($id.FanPercent)) { $rows += @{Label="Fan Speed"; Value="$($values[$id.FanPercent]) %"} }
        if ($values.ContainsKey($id.BusSpeed) -and $values.ContainsKey($id.BusLanes)) {
            $rows += @{Label="PCIe In Use"; Value="Gen $($values[$id.BusSpeed]) x$($values[$id.BusLanes])"}
        }
        if ($values.ContainsKey($id.Throttler) -and $values[$id.Throttler] -ne 0) {
            $rows += @{Label="Throttle Status"; Value="Active (code $($values[$id.Throttler]))"}
        }

        if ($rows.Count -eq 0) { return @() }
        return (@(@{IsHeader=$true; Label="AMD LIVE DATA"}) + $rows)
    } catch {
        return @()
    }
}
#endregion
