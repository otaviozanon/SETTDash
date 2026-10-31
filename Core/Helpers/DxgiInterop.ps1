#region DXGI INTEROP (dxgi.dll / d3d12.dll - both ship with Windows, no embedding needed)
# Mirrors ResetExplode's Dxgi.cs: enumerates adapters via IDXGIFactory1 to get the REAL dedicated
# VRAM (WMI's Win32_VideoController.AdapterRAM is a 32-bit field and wraps/truncates on cards with
# 4GB+ of VRAM) plus shared system memory, and probes the highest supported Direct3D 12 feature
# level via D3D12CreateDevice (works for NVIDIA/AMD/Intel alike - no vendor-specific driver lib).
$Script:DxgiTypesReady = $false

function Initialize-DxgiTypes {
    if ($Script:DxgiTypesReady) { return $true }
    try {
        if (-not ([System.Management.Automation.PSTypeName]"SettDxgi").Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct DXGI_ADAPTER_DESC1
{
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Description;
    public uint VendorId, DeviceId, SubSysId, Revision;
    public UIntPtr DedicatedVideoMemory, DedicatedSystemMemory, SharedSystemMemory;
    public uint LuidLow, LuidHigh;
    public uint Flags;
}

[ComImport, Guid("7b7166ec-21c7-44ae-b21a-c9ae321ae369"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDXGIFactory1
{
    void SetPrivateData(); void SetPrivateDataInterface(); void GetPrivateData(); void GetParent();
    void EnumAdapters(); void MakeWindowAssociation(); void GetWindowAssociation();
    void CreateSwapChain(); void CreateSoftwareAdapter();
    int EnumAdapters1(uint Adapter, out IntPtr ppAdapter);
    [PreserveSig] bool IsCurrent();
}

[ComImport, Guid("29038f61-3839-4626-91fd-086879011a05"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDXGIAdapter1
{
    void SetPrivateData(); void SetPrivateDataInterface(); void GetPrivateData(); void GetParent();
    void EnumOutputs(); void GetDesc(); void CheckInterfaceSupport();
    int GetDesc1(out DXGI_ADAPTER_DESC1 desc);
}

public static class SettDxgi
{
    [DllImport("dxgi.dll")]
    public static extern int CreateDXGIFactory1(ref Guid riid, out IntPtr ppFactory);

    [DllImport("d3d12.dll")]
    public static extern int D3D12CreateDevice(IntPtr pAdapter, int MinimumFeatureLevel, ref Guid riid, IntPtr ppDevice);

    public static readonly Guid IID_IDXGIFactory1 = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
    public static readonly Guid IID_ID3D12Device = new Guid("189819f1-1db6-4b57-be54-1821339b85f7");

    // D3D_FEATURE_LEVEL values, highest first.
    public static readonly int[] FeatureLevels = { 0xc200, 0xc100, 0xc000, 0xb100, 0xb000 };
    public static string FeatureLevelName(int fl)
    {
        switch (fl)
        {
            case 0xc200: return "12_2 (Ultimate)";
            case 0xc100: return "12_1";
            case 0xc000: return "12_0";
            case 0xb100: return "11_1";
            case 0xb000: return "11_0";
            default: return "Unknown";
        }
    }

    public static string ProbeFeatureLevel(IntPtr adapterPtr)
    {
        var riid = IID_ID3D12Device;
        foreach (var fl in FeatureLevels)
        {
            // ppDevice = IntPtr.Zero is valid: D3D12CreateDevice only checks support, doesn't create.
            int hr = D3D12CreateDevice(adapterPtr, fl, ref riid, IntPtr.Zero);
            if (hr == 0) return FeatureLevelName(fl);
        }
        return null;
    }
}
"@ -ErrorAction Stop
        }
        $Script:DxgiTypesReady = $true
        return $true
    } catch {
        return $false
    }
}

# Used by: Get-GpuInfoRows (YourPCGpu.ps1). Enumerates every DXGI adapter once and returns
# PSCustomObjects with the real (un-truncated) VRAM figures and the probed D3D12 feature level.
# Cheap enough to call per page-render (a handful of adapters, no polling loop).
function Get-DxgiAdapters {
    if (-not (Initialize-DxgiTypes)) { return @() }
    $list = @()
    $factoryPtr = [IntPtr]::Zero
    try {
        $riid = [SettDxgi]::IID_IDXGIFactory1
        if ([SettDxgi]::CreateDXGIFactory1([ref]$riid, [ref]$factoryPtr) -ne 0 -or $factoryPtr -eq [IntPtr]::Zero) { return @() }
        $factory = [System.Runtime.InteropServices.Marshal]::GetTypedObjectForIUnknown($factoryPtr, [IDXGIFactory1]) -as [IDXGIFactory1]
        $i = 0
        while ($true) {
            $adapterPtr = [IntPtr]::Zero
            $hr = $factory.EnumAdapters1([uint32]$i, [ref]$adapterPtr)
            if ($hr -ne 0 -or $adapterPtr -eq [IntPtr]::Zero) { break }
            try {
                $adapter = [System.Runtime.InteropServices.Marshal]::GetTypedObjectForIUnknown($adapterPtr, [IDXGIAdapter1]) -as [IDXGIAdapter1]
                $desc = New-Object DXGI_ADAPTER_DESC1
                if ($adapter.GetDesc1([ref]$desc) -eq 0) {
                    $fl = [SettDxgi]::ProbeFeatureLevel($adapterPtr)
                    $list += [PSCustomObject]@{
                        Description           = $desc.Description
                        VendorId              = $desc.VendorId
                        DeviceId              = $desc.DeviceId
                        DedicatedVideoMemory  = [uint64]$desc.DedicatedVideoMemory
                        DedicatedSystemMemory = [uint64]$desc.DedicatedSystemMemory
                        SharedSystemMemory    = [uint64]$desc.SharedSystemMemory
                        FeatureLevel          = $fl
                    }
                }
            } finally {
                [System.Runtime.InteropServices.Marshal]::Release($adapterPtr) | Out-Null
            }
            $i++
        }
    } catch {
    } finally {
        if ($factoryPtr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::Release($factoryPtr) | Out-Null }
    }
    return $list
}

# Matches a WMI Win32_VideoController entry (by VEN_xxxx&DEV_xxxx in PNPDeviceID) to its DXGI
# adapter, so the GPU page can show the real VRAM/shared-memory/feature-level instead of the
# WMI-truncated value. Returns $null when no match is found (integrated/software adapters, etc.).
function Get-DxgiAdapterForDevice {
    param([string]$PNPDeviceID)
    if (-not $PNPDeviceID -or $PNPDeviceID -notmatch "VEN_([0-9A-Fa-f]{4})&DEV_([0-9A-Fa-f]{4})") { return $null }
    try {
        $vendorId = [Convert]::ToUInt32($Matches[1], 16)
        $deviceId = [Convert]::ToUInt32($Matches[2], 16)
        return (Get-DxgiAdapters | Where-Object { $_.VendorId -eq $vendorId -and $_.DeviceId -eq $deviceId } | Select-Object -First 1)
    } catch { return $null }
}
#endregion
