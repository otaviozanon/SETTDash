# GPU benchmark: creates a real Direct3D11 hardware device (DriverType.Hardware) through the embedded
# Vortice.Direct3D11/SharpGen chain and scores three independent workloads:
#
#   ALU      - full-screen animated fractal pixel shader (fractal escape-time loop per pixel)
#   Texture  - 16 texture samples per pixel from a 2048x2048 randomly filled texture (bandwidth +
#              sampler throughput)
#   Compute  - compute shader over a 4M-element structured buffer (16 MB), 384 dependent
#              sin/sqrt iterations per element, dispatch of 16384 groups
#
# Scoring uses GPU timestamps (D3D11_QUERY_TIMESTAMP + D3D11_QUERY_TIMESTAMP_DISJOINT), not
# wall-clock frames: the previous revision reported "FPS" as Draw calls retired per wall-clock
# second, which on a real GPU was 80-95% CPU/driver issue overhead - measured on an RX 5700 XT it
# moved 1,225 -> 379 FPS just from 1080p to 4K while the shader itself was the same, and run-to-run
# variance was 25%. Timestamps measure what the GPU actually spent executing the block, which is
# driver- and scheduler-independent. The reported number per sub-test is the MEDIAN block fps
# (1000 / median GPU ms per frame) so one hiccup does not decide the score; the composite score is
# the geometric mean of the sub-test fps, so a GPU cannot hide a weak area behind one fast test.
#
# The preview image is a separate 480x270 render target filled by a downscale pass from the
# full-resolution target, then copied into a CPU-readable staging texture with Map(Read,
# DoNotWait) - a 10 Hz full-resolution CopyResource+Map(Read) inside the draw loop used to cost 13%
# of the measured throughput, so nothing here blocks the GPU inside a timed block.

$Script:GpuBenchmarkVersion = 1

# Full-screen triangle generated from SV_VertexID - no vertex/index buffer needed.
$Script:GpuVertexShaderHlsl = @"
struct VSOut { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };
VSOut main(uint id : SV_VertexID) {
    VSOut o;
    float2 p = float2((id << 1) & 2, id & 2);
    o.uv = p;
    o.pos = float4(p * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return o;
}
"@

# ALU: animated Julia-set escape-time loop, ~96 dependent iterations per pixel.
$Script:GpuAluPixelShaderHlsl = @"
cbuffer CB : register(b0) { float Time; float3 Pad; };
float4 main(float4 pos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET {
    float2 p = uv * 3.0 - float2(1.5, 1.5);
    float v = 0.0;
    [loop]
    for (int i = 0; i < 96; i++) {
        p = float2(p.x * p.x - p.y * p.y, 2.0 * p.x * p.y) + float2(sin(Time * 0.3), cos(Time * 0.37)) * 0.7;
        v += sin(length(p) + Time + i * 0.05);
    }
    float3 col = 0.5 + 0.5 * cos(v + Time + float3(0.0, 2.0, 4.0));
    return float4(col, 1.0);
}
"@

# Texture: 16 bilinear samples of a 2K texture per pixel with an animated offset per tap.
$Script:GpuTexturePixelShaderHlsl = @"
Texture2D tex0 : register(t0);
SamplerState samp0 : register(s0);
cbuffer CB : register(b0) { float Time; float3 Pad; };
float4 main(float4 pos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET {
    float4 acc = 0.0;
    [unroll]
    for (int i = 0; i < 16; i++) {
        float2 off = float2(sin(Time * 0.7 + i * 1.7), cos(Time * 0.9 + i * 2.3)) * 0.35;
        acc += tex0.Sample(samp0, uv + off);
    }
    return acc * 0.0625;
}
"@

# Preview downscale: bilinear sample of the full-resolution target into the small preview target.
$Script:GpuDownscalePixelShaderHlsl = @"
Texture2D src0 : register(t0);
SamplerState samp0 : register(s0);
float4 main(float4 pos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET {
    return src0.Sample(samp0, uv);
}
"@

# Compute: 384 dependent sin/sqrt iterations per element over a 4M-element float buffer.
$Script:GpuComputeShaderHlsl = @"
RWStructuredBuffer<float> buf : register(u0);
cbuffer CB : register(b0) { float Time; float3 Pad; };
[numthreads(256, 1, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    uint i = id.x;
    float v = buf[i] + Time;
    [loop]
    for (int k = 0; k < 384; k++) {
        v = sin(v * 1.0001 + k) * 0.5 + sqrt(abs(v) + 1.0);
    }
    buf[i] = v;
}
"@

# Raw D3DCompile interop (plain P/Invoke + COM, no extra embedded DLL - d3dcompiler_47.dll ships
# with Windows itself) used to turn the HLSL strings above into bytecode Vortice's
# CreateVertexShader/CreatePixelShader/CreateComputeShader can consume. Defined once via Add-Type;
# safe to call Initialize-D3DShaderCompiler repeatedly (no-op after the type exists).
function Initialize-D3DShaderCompiler {
    if ("D3DShaderCompiler" -as [type]) { return $true }
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class D3DShaderCompiler {
    [DllImport("d3dcompiler_47.dll", CharSet = CharSet.Ansi)]
    private static extern int D3DCompile(
        [MarshalAs(UnmanagedType.LPStr)] string pSrcData, UIntPtr srcDataSize,
        string pSourceName, IntPtr pDefines, IntPtr pInclude,
        [MarshalAs(UnmanagedType.LPStr)] string pEntrypoint,
        [MarshalAs(UnmanagedType.LPStr)] string pTarget,
        uint flags1, uint flags2, out IntPtr ppCode, out IntPtr ppErrorMsgs);

    [ComImport, Guid("8BA5FB08-5195-40E2-AC58-0D989C3A0102"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ID3DBlobCOM {
        [PreserveSig] IntPtr GetBufferPointer();
        [PreserveSig] UIntPtr GetBufferSize();
    }

    public static byte[] Compile(string hlsl, string entryPoint, string target) {
        IntPtr code = IntPtr.Zero, errors = IntPtr.Zero;
        int hr = D3DCompile(hlsl, (UIntPtr)hlsl.Length, "shader.hlsl", IntPtr.Zero, IntPtr.Zero, entryPoint, target, 0, 0, out code, out errors);
        if (hr != 0) {
            string msg = "D3DCompile failed (HRESULT 0x" + hr.ToString("X8") + ")";
            if (errors != IntPtr.Zero) {
                var blobErr = (ID3DBlobCOM)Marshal.GetObjectForIUnknown(errors);
                IntPtr p = blobErr.GetBufferPointer();
                int len = (int)blobErr.GetBufferSize();
                msg = Marshal.PtrToStringAnsi(p, len) + " (HRESULT 0x" + hr.ToString("X8") + ")";
                Marshal.Release(errors);
            }
            throw new Exception(msg);
        }
        var blob = (ID3DBlobCOM)Marshal.GetObjectForIUnknown(code);
        IntPtr bufPtr = blob.GetBufferPointer();
        int bufLen = (int)blob.GetBufferSize();
        byte[] result = new byte[bufLen];
        Marshal.Copy(bufPtr, result, 0, bufLen);
        Marshal.Release(code);
        return result;
    }
}
"@ -ErrorAction Stop
        return $true
    } catch {
        Write-GuiLog "D3DShaderCompiler init failed: $_" "WARN"
        return $false
    }
}

# Median of a block-sample list - the robust "steady state" number used as a sub-test score.
function Get-GpuMedian {
    param([double[]]$Values)
    if ($null -eq $Values) { return 0 }
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { return 0 }
    $mid = [int][math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) { return [double]$sorted[$mid] }
    return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2.0
}

# Turns the per-block GPU-milliseconds samples of one sub-test into the reported profile. FPS is
# derived from the MEDIAN milliseconds (not the mean of the per-block FPS) so a single stalled
# block cannot drag the score, and the first/second half split exposes clock throttling.
function New-GpuTestProfile {
    param([string]$Name, [string]$Label, [System.Collections.Generic.List[double]]$MsSamples)
    $medianMs = Get-GpuMedian -Values $MsSamples.ToArray()
    if ($medianMs -le 0) { return $null }
    $fpsSamples = @()
    foreach ($ms in $MsSamples) { if ($ms -gt 0) { $fpsSamples += (1000.0 / $ms) } }
    $half = [int][math]::Floor($fpsSamples.Count / 2)
    $firstHalf = 0.0; $secondHalf = 0.0; $deltaPct = 0.0
    if ($half -ge 2) {
        $firstHalf = ($fpsSamples[0..($half - 1)] | Measure-Object -Average).Average
        $secondHalf = ($fpsSamples[($fpsSamples.Count - $half)..($fpsSamples.Count - 1)] | Measure-Object -Average).Average
        if ($firstHalf -gt 0) { $deltaPct = (($firstHalf - $secondHalf) / $firstHalf) * 100.0 }
    }
    [PSCustomObject]@{
        Name          = $Name
        Label         = $Label
        Blocks        = $fpsSamples.Count
        MedianMs      = [math]::Round($medianMs, 4)
        Fps           = [math]::Round(1000.0 / $medianMs, 1)
        MinFps        = [math]::Round(($fpsSamples | Measure-Object -Minimum).Minimum, 1)
        MaxFps        = [math]::Round(($fpsSamples | Measure-Object -Maximum).Maximum, 1)
        FpsSamples    = $fpsSamples
        FirstHalfFps  = [math]::Round($firstHalf, 1)
        SecondHalfFps = [math]::Round($secondHalf, 1)
        DeltaPct      = [math]::Round($deltaPct, 1)
    }
}

# One telemetry reading (LibreHardwareMonitor), reduced to the figures that matter for a GPU
# benchmark. Returns $null when LHM is unavailable or reports no GPU sensor at all.
function Get-GpuTelemetryReading {
    if (-not $Script:LHMAvailable) { return $null }
    $rows = @(Get-LHMSensorRows)
    if ($rows.Count -eq 0) { return $null }
    # HardwareType is GpuAti/GpuNvidia/GpuIntel for graphics hardware, so an exact "-eq 'Gpu'"
    # would match nothing (and any fallback to "all rows" would report the CPU temperature as the
    # GPU temperature - the reason this match is explicit).
    $gpuRows = @($rows | Where-Object { $_.HardwareType -like "Gpu*" -and $null -ne $_.Value })
    if ($gpuRows.Count -eq 0) { return $null }

    $pick = {
        param([string]$Type, [string]$NamePattern)
        $hits = @($gpuRows | Where-Object { $_.SensorType -eq $Type -and $_.SensorName -match $NamePattern })
        if ($hits.Count -eq 0) { $hits = @($gpuRows | Where-Object { $_.SensorType -eq $Type }) }
        if ($hits.Count -eq 0) { return $null }
        return [double](($hits | Measure-Object -Property Value -Maximum).Maximum)
    }

    [PSCustomObject]@{
        Temperature = (& $pick "Temperature" "GPU Core|Hot ?Spot|Core")
        Power       = (& $pick "Power" "GPU Power|Package|Total")
        Clock       = (& $pick "Clock" "GPU Core|Core")
        Load        = (& $pick "Load" "GPU Core|Core")
    }
}

# Runs the whole GPU benchmark synchronously on the calling (WPF UI) thread and returns the result.
# The blocking loops pump the Dispatcher through Set-GuiProgress every few milliseconds, exactly
# like the CPU/RAM benchmarks, so the popup keeps painting the preview and the Stop button stays
# clickable while the run is in progress.
function Get-GpuBenchmarkResult {
    param(
        [double]$DurationSeconds = 30,
        [int]$Width = 1920,
        [int]$Height = 1080,
        [int]$PreviewWidth = 480,
        [int]$PreviewHeight = 270,
        [System.Windows.Controls.Image]$PreviewTarget = $null,
        [scriptblock]$OnStatus = $null,
        [scriptblock]$OnTelemetrySample = $null,
        [scriptblock]$CancelCheck = $null
    )

    if (-not (Initialize-Vortice3D)) {
        throw "Vortice/Direct3D11 runtime could not be initialized (see log for details)."
    }
    if (-not (Initialize-D3DShaderCompiler)) {
        throw "D3DCompile (d3dcompiler_47.dll) could not be initialized (see log for details)."
    }
    # LibreHardwareMonitor is optional: when it cannot be opened the run still scores normally and
    # simply reports Telemetry.Available = $false.
    try {
        if (-not $Script:LHMAvailable) { [void](Initialize-LibreHardwareMonitor) }
    } catch { }

    $device = $null; $context = $null
    $hr = [Vortice.Direct3D11.D3D11]::D3D11CreateDevice(
        [IntPtr]::Zero,
        [Vortice.Direct3D.DriverType]::Hardware,
        [Vortice.Direct3D11.DeviceCreationFlags]::BgraSupport,
        $null,
        [ref]$device,
        [ref]$context
    )
    if ($hr.Failure -or -not $device) {
        throw "D3D11CreateDevice failed (HRESULT $hr) - no hardware D3D11 driver available."
    }

    $featureLevel = [int]$device.FeatureLevel
    $featureLevelName = $device.FeatureLevel.ToString()
    $shaderModelTag = if ($featureLevel -ge 0xB000) { "5_0" } else { "4_0" }
    $shaderModel = $shaderModelTag.Replace("_", ".")
    $vsTarget = "vs_$shaderModelTag"; $psTarget = "ps_$shaderModelTag"; $csTarget = "cs_$shaderModelTag"
    # Compute needs feature level 11_0 (structured buffer UAV + cs_5_0). Older hardware still gets
    # the two render tests, and the composite is then the geometric mean of those two.
    $computeSupported = ($featureLevel -ge 0xB000)

    $status = {
        param([string]$Text, [double]$Percent)
        if ($OnStatus) { try { & $OnStatus $Text $Percent } catch { } }
        try { Set-GuiProgress $Percent $null } catch { }
    }
    $pump = { try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { } }

    $runSw = [System.Diagnostics.Stopwatch]::StartNew()
    $plannedTests = if ($computeSupported) { 3 } else { 2 }
    $perTestSeconds = $DurationSeconds / $plannedTests

    # ---- resources -------------------------------------------------------------------------
    # Render target: RenderTarget + ShaderResource so the preview downscale pass can sample it.
    $targetTexture = $device.CreateTexture2D(
        [Vortice.DXGI.Format]::B8G8R8A8_UNorm, $Width, $Height, 1, 1, $null,
        ([Vortice.Direct3D11.BindFlags]::RenderTarget -bor [Vortice.Direct3D11.BindFlags]::ShaderResource),
        [Vortice.Direct3D11.ResourceOptionFlags]::None,
        [Vortice.Direct3D11.ResourceUsage]::Default,
        [Vortice.Direct3D11.CpuAccessFlags]::None)
    $rtv = $device.CreateRenderTargetView($targetTexture, $null)
    $targetSrv = $device.CreateShaderResourceView($targetTexture, $null)

    $previewTexture = $device.CreateTexture2D(
        [Vortice.DXGI.Format]::B8G8R8A8_UNorm, $PreviewWidth, $PreviewHeight, 1, 1, $null,
        [Vortice.Direct3D11.BindFlags]::RenderTarget,
        [Vortice.Direct3D11.ResourceOptionFlags]::None,
        [Vortice.Direct3D11.ResourceUsage]::Default,
        [Vortice.Direct3D11.CpuAccessFlags]::None)
    $previewRtv = $device.CreateRenderTargetView($previewTexture, $null)
    $stagingTexture = $device.CreateTexture2D(
        [Vortice.DXGI.Format]::B8G8R8A8_UNorm, $PreviewWidth, $PreviewHeight, 1, 1, $null,
        [Vortice.Direct3D11.BindFlags]::None,
        [Vortice.Direct3D11.ResourceOptionFlags]::None,
        [Vortice.Direct3D11.ResourceUsage]::Staging,
        [Vortice.Direct3D11.CpuAccessFlags]::Read)

    $viewport = New-Object Vortice.Mathematics.Viewport(0, 0, $Width, $Height)
    $previewViewport = New-Object Vortice.Mathematics.Viewport(0, 0, $PreviewWidth, $PreviewHeight)

    $vs = $device.CreateVertexShader([D3DShaderCompiler]::Compile($Script:GpuVertexShaderHlsl, "main", $vsTarget))
    $psAlu = $device.CreatePixelShader([D3DShaderCompiler]::Compile($Script:GpuAluPixelShaderHlsl, "main", $psTarget))
    $psTexture = $device.CreatePixelShader([D3DShaderCompiler]::Compile($Script:GpuTexturePixelShaderHlsl, "main", $psTarget))
    $psDownscale = $device.CreatePixelShader([D3DShaderCompiler]::Compile($Script:GpuDownscalePixelShaderHlsl, "main", $psTarget))

    # Constant buffer (one float of elapsed time + padding) - the animated input that keeps the
    # shaders doing real work every frame.
    $constantBuffer = $device.CreateBuffer(16, [Vortice.Direct3D11.BindFlags]::ConstantBuffer,
        [Vortice.Direct3D11.ResourceUsage]::Dynamic, [Vortice.Direct3D11.CpuAccessFlags]::Write,
        [Vortice.Direct3D11.ResourceOptionFlags]::None, 0)

    # Sampleable 2048x2048 texture for the texture sub-test. Random bytes so no two samples hit the
    # same cache line and the sampler cannot shortcut a constant read.
    $texSize = 2048
    $pixels = New-Object byte[] ($texSize * $texSize * 4)
    (New-Object System.Random 7).NextBytes($pixels)
    $sourceTexture = $device.CreateTexture2D(
        [Vortice.DXGI.Format]::B8G8R8A8_UNorm, $texSize, $texSize, 1, 1, $null,
        [Vortice.Direct3D11.BindFlags]::ShaderResource,
        [Vortice.Direct3D11.ResourceOptionFlags]::None,
        [Vortice.Direct3D11.ResourceUsage]::Default,
        [Vortice.Direct3D11.CpuAccessFlags]::None)
    # NOTE: the byte[]-as-initial-data overload does not bind from PowerShell (it resolves to the
    # SubresourceData[] overload and fails), so the texture is created empty and uploaded with
    # UpdateSubresource, which does bind to the generic T[] overload.
    $context.UpdateSubresource($pixels, $sourceTexture, 0, ($texSize * 4), ($texSize * $texSize * 4), $null)
    $sourceSrv = $device.CreateShaderResourceView($sourceTexture, $null)
    $sampler = $device.CreateSamplerState([Vortice.Direct3D11.SamplerDescription]::LinearWrap)

    # Compute sub-test resources: 4M floats (16 MB) as a structured buffer, one UAV, 16384 groups.
    $groups = 16384
    $computeElements = $groups * 256
    $computeBuffer = $device.CreateBuffer(($computeElements * 4),
        [Vortice.Direct3D11.BindFlags]::UnorderedAccess,
        [Vortice.Direct3D11.ResourceUsage]::Default,
        [Vortice.Direct3D11.CpuAccessFlags]::None,
        [Vortice.Direct3D11.ResourceOptionFlags]::BufferStructured, 4)
    $uavDesc = New-Object Vortice.Direct3D11.UnorderedAccessViewDescription(
        $computeBuffer, [Vortice.DXGI.Format]::Unknown, 0, $computeElements,
        [Vortice.Direct3D11.BufferUnorderedAccessViewFlags]::None)
    $uav = $device.CreateUnorderedAccessView($computeBuffer, $uavDesc)
    $cs = $null
    if ($computeSupported) {
        $cs = $device.CreateComputeShader([D3DShaderCompiler]::Compile($Script:GpuComputeShaderHlsl, "main", $csTarget))
    }

    # Map's two overloads differ only in the by-ref/by-value last parameter and PowerShell cannot
    # disambiguate them; resolve the by-value one once (same trick as the previous revision).
    $mapMethod = ([Vortice.Direct3D11.ID3D11DeviceContext].GetMethods() | Where-Object {
        $_.Name -eq "Map" -and $_.GetParameters().Count -eq 4 -and -not $_.GetParameters()[3].ParameterType.IsByRef
    } | Select-Object -First 1)

    $queryDisjoint = $device.CreateQuery([Vortice.Direct3D11.QueryType]::TimestampDisjoint)
    $queryStart = $device.CreateQuery([Vortice.Direct3D11.QueryType]::Timestamp)
    $queryEnd = $device.CreateQuery([Vortice.Direct3D11.QueryType]::Timestamp)

    $cleanup = {
        if ($queryEnd) { $queryEnd.Dispose() }
        if ($queryStart) { $queryStart.Dispose() }
        if ($queryDisjoint) { $queryDisjoint.Dispose() }
        if ($uav) { $uav.Dispose() }
        if ($computeBuffer) { $computeBuffer.Dispose() }
        if ($cs) { $cs.Dispose() }
        if ($sampler) { $sampler.Dispose() }
        if ($sourceSrv) { $sourceSrv.Dispose() }
        if ($sourceTexture) { $sourceTexture.Dispose() }
        if ($constantBuffer) { $constantBuffer.Dispose() }
        if ($psDownscale) { $psDownscale.Dispose() }
        if ($psTexture) { $psTexture.Dispose() }
        if ($psAlu) { $psAlu.Dispose() }
        if ($vs) { $vs.Dispose() }
        if ($stagingTexture) { $stagingTexture.Dispose() }
        if ($previewRtv) { $previewRtv.Dispose() }
        if ($previewTexture) { $previewTexture.Dispose() }
        if ($targetSrv) { $targetSrv.Dispose() }
        if ($rtv) { $rtv.Dispose() }
        if ($targetTexture) { $targetTexture.Dispose() }
        if ($context) { $context.Dispose() }
        if ($device) { $device.Dispose() }
    }.GetNewClosure()

    # Binds the pipeline state for one sub-test (render target/state only - never inside a timed
    # region, so this CPU cost is not charged to the GPU score).
    $bindTest = {
        param([string]$Name)
        if ($Name -eq "Compute") {
            # Unbind the shader-visible copy of the render target first: the same texture must not
            # be bound as a pixel-shader resource while it is bound as a render target.
            $context.PSSetShaderResource(0, $null)
            $context.CSSetShader($cs)
            $context.CSSetConstantBuffer(0, $constantBuffer)
            $context.CSSetUnorderedAccessView(0, $uav, -1)
        } elseif ($Name -eq "Texture") {
            $context.OMSetRenderTargets($rtv)
            $context.RSSetViewport($viewport)
            $context.IASetPrimitiveTopology([Vortice.Direct3D.PrimitiveTopology]::TriangleList)
            $context.VSSetShader($vs)
            $context.PSSetShader($psTexture)
            $context.PSSetConstantBuffer(0, $constantBuffer)
            $context.PSSetShaderResource(0, $sourceSrv)
            $context.PSSetSampler(0, $sampler)
        } else {
            $context.OMSetRenderTargets($rtv)
            $context.RSSetViewport($viewport)
            $context.IASetPrimitiveTopology([Vortice.Direct3D.PrimitiveTopology]::TriangleList)
            $context.VSSetShader($vs)
            $context.PSSetShader($psAlu)
            $context.PSSetConstantBuffer(0, $constantBuffer)
            $context.PSSetShaderResource(0, $null)
        }
    }.GetNewClosure()

    # Issues the actual workload for one block. Everything here is inside the timestamp window.
    $issueFrames = {
        param([string]$Name, [int]$Frames)
        if ($Name -eq "Compute") {
            for ($i = 0; $i -lt $Frames; $i++) { $context.Dispatch($groups, 1, 1) }
        } else {
            for ($i = 0; $i -lt $Frames; $i++) { $context.Draw(3, 0) }
        }
    }.GetNewClosure()

    $writeTimeUniform = {
        param([float]$Time)
        $mapped = $mapMethod.Invoke($context, @($constantBuffer, 0, [Vortice.Direct3D11.MapMode]::WriteDiscard, [Vortice.Direct3D11.MapFlags]::None))
        [System.Runtime.InteropServices.Marshal]::WriteInt32($mapped.DataPointer, 0, [BitConverter]::ToInt32([BitConverter]::GetBytes($Time), 0))
        $context.Unmap($constantBuffer, 0)
    }.GetNewClosure()

    $tests = @(
        [PSCustomObject]@{ Name = "Alu";     Label = "ALU / fractal (pixel shader)" }
        [PSCustomObject]@{ Name = "Texture"; Label = "Texture fetch (2K, 16 taps/pixel)" }
    )
    if ($computeSupported) {
        $tests += [PSCustomObject]@{ Name = "Compute"; Label = "Compute (4M elements, 384 iters)" }
    }

    $bitmap = $null
    if ($PreviewTarget -and $PreviewWidth -gt 0 -and $PreviewHeight -gt 0) {
        $bitmap = New-Object System.Windows.Media.Imaging.WriteableBitmap($PreviewWidth, $PreviewHeight, 96, 96, [System.Windows.Media.PixelFormats]::Bgra32, $null)
        $PreviewTarget.Source = $bitmap
    }
    $previewRect = New-Object System.Windows.Int32Rect(0, 0, $PreviewWidth, $PreviewHeight)
    # NOTE: everything that needs to persist across separate "& $updatePreview" calls lives in this
    # hashtable, not in plain scalar variables. $updatePreview is a scriptblock invoked repeatedly
    # via "&", and each invocation runs in its OWN child scope - a plain "$x = ..." inside it creates
    # a local shadow that is discarded when the call returns (PowerShell variable writes do not walk
    # up the scope chain the way reads do), so a scalar "persisted" by GetNewClosure() still resets
    # every call. A hashtable is a reference type, so mutating its keys is visible on the next call
    # regardless of scope. (Confirmed bug: Attempts/CopyPending never advanced past 0 - "0/0 frame(s)
    # painted" every run after refactoring the inline code into this scriptblock.)
    $previewDiag = @{ Attempts = 0; Hits = 0; LastMs = -1000.0; CopyPending = $false }

    # Extracted so warm-up and calibration blocks can also paint a preview frame, not just the
    # measured blocks - previously the preview stayed black for the whole warm-up+calibration phase
    # of the FIRST test (shader JIT, texture/buffer fault-in), which is the single longest stretch
    # with no visual feedback in the whole run.
    $updatePreview = {
        if (-not $bitmap) { return }
        $nowMs = $runSw.Elapsed.TotalMilliseconds
        if (($nowMs - $previewDiag.LastMs) -lt 40.0) { return }

        # Read back whatever was copied into $stagingTexture on the PREVIOUS tick, not
        # the copy issued below in this same tick. A CopyResource is only *recorded*
        # on the immediate context - nothing actually executes on the GPU until a
        # Flush() happens. Mapping the staging texture right after issuing its own
        # copy therefore always raced the GPU and always failed with
        # DXGI_ERROR_WAS_STILL_DRAWING (confirmed: 0/256 frames painted). By the time
        # this tick runs, the PREVIOUS tick's copy has already been through a Flush()
        # and had time to complete, so DoNotWait succeeds here instead.
        if ($previewDiag.CopyPending) {
            $previewDiag.Attempts++
            try {
                $mapped = $mapMethod.Invoke($context, @($stagingTexture, 0, [Vortice.Direct3D11.MapMode]::Read, [Vortice.Direct3D11.MapFlags]::DoNotWait))
                if ($mapped -and $mapped.DataPointer -ne [IntPtr]::Zero) {
                    $bitmap.WritePixels($previewRect, $mapped.DataPointer, ($mapped.RowPitch * $PreviewHeight), $mapped.RowPitch)
                    $context.Unmap($stagingTexture, 0)
                    $previewDiag.LastMs = $nowMs
                    $previewDiag.Hits++
                }
            } catch {
                # DXGI_ERROR_WAS_STILL_DRAWING: the copy from the previous tick genuinely was not
                # ready yet (happens a few times during warm-up, before the pipeline builds up a
                # frame or two of slack between a copy and its readback). Expected and harmless -
                # skip this tick, the next one picks it back up.
            }
        }

        # Downscale the full-resolution target into the small preview target and copy
        # it to the staging texture for the NEXT tick to read back.
        $context.PSSetShaderResource(0, $null)
        $context.OMSetRenderTargets($previewRtv)
        $context.RSSetViewport($previewViewport)
        $context.IASetPrimitiveTopology([Vortice.Direct3D.PrimitiveTopology]::TriangleList)
        $context.VSSetShader($vs)
        $context.PSSetShader($psDownscale)
        $context.PSSetSampler(0, $sampler)
        $context.PSSetShaderResource(0, $targetSrv)
        $context.Draw(3, 0)
        $context.CopyResource($stagingTexture, $previewTexture)
        $previewDiag.CopyPending = $true
        # Leave the full-resolution target unbound from the pixel stage so the next
        # block can bind it as a render target again ($bindTest re-binds it, and
        # this also keeps the texture sub-test's SRV binding explicit).
        $context.PSSetShaderResource(0, $null)
    }.GetNewClosure()

    # Dimensions of the last successful block, re-used to calibrate the next block length.
    $profiles = @()
    $cancelled = $false
    $telemetry = [PSCustomObject]@{
        Available = $false
        Samples   = 0
        MaxTemp   = $null
        MaxPower  = $null
        MinClock  = $null
        MaxClock  = $null
        MaxLoad   = $null
    }
    # Hashtable, not a plain variable: the sampler below is invoked with '&', which runs in a child
    # scope, so a plain assignment inside it is discarded on return and the rate limit never applies.
    $telemetryState = @{ LastMs = -1000.0 }
    # Sampled between blocks and outside every timestamp window, so neither the sensor refresh
    # (LibreHardwareMonitor re-reads all hardware) nor the extra CPU work is charged to the score.
    $sampleTelemetry = {
        $nowMs = $runSw.Elapsed.TotalMilliseconds
        if (($nowMs - $telemetryState.LastMs) -lt 500.0) { return }
        $telemetryState.LastMs = $nowMs
        $reading = Get-GpuTelemetryReading
        if (-not $reading) { return }
        $telemetry.Available = $true
        $telemetry.Samples++
        if ($null -ne $reading.Temperature -and ($null -eq $telemetry.MaxTemp -or $reading.Temperature -gt $telemetry.MaxTemp)) { $telemetry.MaxTemp = [math]::Round($reading.Temperature, 1) }
        if ($null -ne $reading.Power -and ($null -eq $telemetry.MaxPower -or $reading.Power -gt $telemetry.MaxPower)) { $telemetry.MaxPower = [math]::Round($reading.Power, 1) }
        if ($null -ne $reading.Clock) {
            if ($null -eq $telemetry.MinClock -or $reading.Clock -lt $telemetry.MinClock) { $telemetry.MinClock = [math]::Round($reading.Clock, 0) }
            if ($null -eq $telemetry.MaxClock -or $reading.Clock -gt $telemetry.MaxClock) { $telemetry.MaxClock = [math]::Round($reading.Clock, 0) }
        }
        if ($null -ne $reading.Load -and ($null -eq $telemetry.MaxLoad -or $reading.Load -gt $telemetry.MaxLoad)) { $telemetry.MaxLoad = [math]::Round($reading.Load, 1) }
        if ($OnTelemetrySample) { try { & $OnTelemetrySample $telemetry } catch { } }
    }.GetNewClosure()

    try {
        & $sampleTelemetry
        foreach ($test in $tests) {
            if ($CancelCheck -and (& $CancelCheck)) { $cancelled = $true; break }

            # ---- warm-up (JITs the shader, faults in the texture/buffer, no scoring) --------
            & $status "$($test.Label): warm-up" 0
            $frames = 4
            for ($w = 0; $w -lt 3; $w++) {
                & $writeTimeUniform ([float]($runSw.Elapsed.TotalSeconds))
                & $bindTest $test.Name
                & $issueFrames $test.Name $frames
                $context.Flush()
                # Warm-up + calibration (below) is the single longest stretch with no scored block
                # yet - paint a preview frame here too, instead of only once measured blocks start,
                # so the popup isn't black while the shader JITs on the very first test.
                & $updatePreview
            }

            # ---- calibrate the block length so one block is ~45 ms of GPU work ------------
            $calMs = 0.0
            for ($c = 0; $c -lt 2; $c++) {
                $calFrames = 8
                & $writeTimeUniform ([float]($runSw.Elapsed.TotalSeconds))
                & $bindTest $test.Name
                $context.Begin($queryDisjoint); $context.End($queryStart)
                & $issueFrames $test.Name $calFrames
                $context.End($queryEnd); $context.End($queryDisjoint)
                $context.Flush()
                $t0 = [uint64]0; $t1 = [uint64]0
                $disc = [Vortice.Direct3D11.QueryDataTimestampDisjoint]::new()
                $calSw = [System.Diagnostics.Stopwatch]::StartNew()
                $ok = $false
                $calPollCount = 0
                while ($calSw.ElapsedMilliseconds -lt 5000) {
                    $okStart = $context.GetData($queryStart, [ref]$t0)
                    $okEnd = $false; $okDisc = $false
                    if ($okStart) { $okEnd = $context.GetData($queryEnd, [ref]$t1) }
                    if ($okEnd) { $okDisc = $context.GetData($queryDisjoint, [ref]$disc) }
                    if ($okStart -and $okEnd -and $okDisc) { $ok = $true; break }
                    [System.Threading.Thread]::Sleep(0)
                    $calPollCount++
                    if (($calPollCount % 64) -eq 0) { & $pump; & $updatePreview }
                }
                & $updatePreview
            }

            $frames = 1
            if ($calMs -gt 0.0001) {
                $frames = [int][math]::Round(45.0 / $calMs)
                if ($frames -lt 1) { $frames = 1 }
                if ($frames -gt 4096) { $frames = 4096 }
                if (($frames * $calMs) -gt 120.0) {
                    $frames = [int][math]::Floor(120.0 / $calMs)
                    if ($frames -lt 1) { $frames = 1 }
                }
            }

            # ---- measured blocks ----------------------------------------------------------
            $msSamples = [System.Collections.Generic.List[double]]::new()
            $testSw = [System.Diagnostics.Stopwatch]::StartNew()
            $block = 0
            while ($testSw.Elapsed.TotalSeconds -lt $perTestSeconds -or $msSamples.Count -lt 3) {
                if ($CancelCheck -and (& $CancelCheck)) { $cancelled = $true; break }
                if ($testSw.Elapsed.TotalSeconds -gt ($perTestSeconds * 2 + 2)) { break }  # safety net

                $block++
                $pct = 100.0 * (($profiles.Count + [math]::Min(1.0, $testSw.Elapsed.TotalSeconds / [math]::Max($perTestSeconds, 0.001))) / $plannedTests)
                & $status "$($test.Label): block $block ($frames frame(s))" ([math]::Round($pct, 1))

                & $writeTimeUniform ([float]($runSw.Elapsed.TotalSeconds))
                & $bindTest $test.Name
                $context.Begin($queryDisjoint); $context.End($queryStart)
                & $issueFrames $test.Name $frames
                $context.End($queryEnd); $context.End($queryDisjoint)
                $context.Flush()

                $t0 = [uint64]0; $t1 = [uint64]0
                $disc = [Vortice.Direct3D11.QueryDataTimestampDisjoint]::new()
                $pollSw = [System.Diagnostics.Stopwatch]::StartNew()
                $ok = $false
                $pollCount = 0
                while ($pollSw.ElapsedMilliseconds -lt 5000) {
                    # DoNotFlush keeps GetData from forcing the driver to submit, so the readback
                    # never changes the workload it is measuring.
                    $flags = [Vortice.Direct3D11.AsyncGetDataFlags]::DoNotFlush
                    $okStart = $context.GetData($queryStart, $flags, [ref]$t0)
                    $okEnd = $false; $okDisc = $false
                    if ($okStart) { $okEnd = $context.GetData($queryEnd, $flags, [ref]$t1) }
                    if ($okEnd) { $okDisc = $context.GetData($queryDisjoint, $flags, [ref]$disc) }
                    if ($okStart -and $okEnd -and $okDisc) { $ok = $true; break }
                    [System.Threading.Thread]::Sleep(0)
                    $pollCount++
                    if (($pollCount % 64) -eq 0) { & $pump }
                }

                $frequency = [double]$disc.Frequency
                $disjoint = ($disc.Disjoint.ToString() -eq "True")
                if ($ok -and $frequency -gt 0 -and -not $disjoint -and $t1 -gt $t0) {
                    $ms = (($t1 - $t0) * 1000.0) / $frequency
                    $msPerFrame = $ms / $frames
                    if ($msPerFrame -gt 0) { $msSamples.Add($msPerFrame) | Out-Null }
                }

                # ---- preview: outside every timestamp window --------------------------------
                & $updatePreview

                # ---- telemetry, twice a second ---------------------------------------------
                & $sampleTelemetry
            }

            if ($msSamples.Count -gt 0) {
                $profile = New-GpuTestProfile -Name $test.Name -Label $test.Label -MsSamples $msSamples
                if ($profile) { $profiles += $profile }
            }
            if ($cancelled) { break }
        }
    } finally {
        & $cleanup
    }

    $runSw.Stop()

    if ($bitmap -and $previewDiag.Hits -eq 0) {
        # Only worth a log line if nothing painted at all - a healthy run always misses a handful of
        # ticks (warm-up races, slow driver) and that is not worth surfacing to the user.
        Write-GuiLog "GPU benchmark preview: $($previewDiag.Hits)/$($previewDiag.Attempts) frame(s) painted." "WARN"
    }

    # Composite: geometric mean of the sub-test fps, so one strong test cannot mask a weak one.
    $composite = 0.0
    if ($profiles.Count -gt 0) {
        $logSum = 0.0
        foreach ($p in $profiles) { $logSum += [math]::Log([math]::Max($p.Fps, 0.001)) }
        $composite = [math]::Round([math]::Exp($logSum / $profiles.Count), 1)
    }

    $throttlePct = 0.0
    foreach ($p in $profiles) { if ($p.DeltaPct -gt $throttlePct) { $throttlePct = $p.DeltaPct } }

    $result = [PSCustomObject]@{
        Version         = $Script:GpuBenchmarkVersion
        Cancelled       = $cancelled
        DurationSeconds = $DurationSeconds
        ElapsedSeconds  = [math]::Round($runSw.Elapsed.TotalSeconds, 1)
        Width           = $Width
        Height          = $Height
        FeatureLevel    = $featureLevelName
        ShaderModel     = $shaderModel
        ComputeSupported = $computeSupported
        Tests           = $profiles
        CompositeFps    = $composite
        CompositeMs     = $(if ($composite -gt 0) { [math]::Round(1000.0 / $composite, 4) } else { 0 })
        Telemetry       = $telemetry
        ThrottlePct     = [math]::Round($throttlePct, 1)
        Throttling      = ($throttlePct -ge 8.0)
    }
    foreach ($p in $profiles) { $result | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p -Force }

    Set-GuiProgress 100 $(if ($cancelled) { "GPU benchmark stopped." } else { "GPU benchmark complete." })
    return $result
}

# Runs the GPU benchmark inside its own modal popup window instead of on the BenchGpu.ps1 page: the
# popup hosts the live preview + progress gauge while the test runs, and only the final result goes
# back to the page (Show-PageBenchGpu renders the tiles).
#
# This popup is a plain XamlReader Window (like the update-checker dialogs in UpdateChecker.ps1),
# not part of the main $Window visual tree, so it cannot use {DynamicResource} against
# $Window.Resources - all chrome/gauge colors are baked in as literal values from the current theme
# (same approach as Get-UpdatePopupXaml/Get-CurrentThemeColors).
# Returns the benchmark result object, or $null if the popup was closed before it finished.
function Show-GpuBenchmarkPopup {
    param([string]$Mode = "D3D11", [double]$DurationSeconds = 30)

    $t = Get-CurrentThemeColors
    $fontFamily = if ($t.FontFamily -eq "MONO") { "Consolas" } else { "Segoe UI" }
    $radius = $t.CornerRadius

    $body = @"
        <StackPanel>
            <TextBlock x:Name="txtLive" Text="GPU Temp: -- °C   |   Power: -- W   |   Clock: -- MHz   |   Load: -- %" Foreground="$($t.TextPrimary)" FontFamily="$fontFamily" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" TextAlignment="Center" Margin="0,0,0,8"/>
            <Border x:Name="renderHost" Height="450" Background="$($t.CardBg)" BorderBrush="$($t.CardBorder)" BorderThickness="1" CornerRadius="$radius" Margin="0,0,0,10"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Border x:Name="gaugeHost" Width="64" Height="64" VerticalAlignment="Center"/>
                <StackPanel Width="420" Margin="14,0,0,0" VerticalAlignment="Center">
                    <TextBlock x:Name="txtStatus" Text="Starting..." Foreground="$($t.TextSecondary)" FontFamily="$fontFamily" FontSize="11" TextAlignment="Left" TextTrimming="CharacterEllipsis"/>
                    <TextBlock x:Name="txtResult" Text="" Foreground="$($t.TextPrimary)" FontFamily="$fontFamily" FontSize="13" FontWeight="Bold" Margin="0,3,0,0" TextAlignment="Left" TextWrapping="Wrap"/>
                </StackPanel>
                <Button x:Name="btnAction" Content="Stop Benchmark" Style="{StaticResource DialogPrimaryButtonStyle}" Margin="14,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
        </StackPanel>
"@

    [xml]$xaml = Get-UpdatePopupXaml -Width 1000 -Title "GPU Benchmark - Direct3D11" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $renderHost = $dlg.FindName("renderHost")
    $gaugeHost = $dlg.FindName("gaugeHost")
    $txtStatus = $dlg.FindName("txtStatus")
    $txtResult = $dlg.FindName("txtResult")
    $txtLive = $dlg.FindName("txtLive")
    $btnAction = $dlg.FindName("btnAction")
    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar

    # Preview surface: Get-GpuBenchmarkResult blits a throttled 480x270 copy of the render target
    # into this WriteableBitmap (see the note at the top of this file).
    $previewImage = New-Object System.Windows.Controls.Image
    $previewImage.Stretch = "Uniform"
    $renderHost.Child = $previewImage

    # Literal-color circular gauge (track + arc + center value) - mirrors New-GuiCircularGauge's
    # structure (Core/Gauges/GuiGauges.ps1) but with baked colors instead of SetResourceReference,
    # since this popup has no live {DynamicResource} wiring to $Window.Resources.
    $gaugeSize = 64; $gaugeThickness = 7; $gaugeRadius = ($gaugeSize - $gaugeThickness) / 2.0
    $gaugeGrid = New-Object System.Windows.Controls.Grid
    $gaugeCanvas = New-Object System.Windows.Controls.Canvas
    $gaugeCanvas.Width = $gaugeSize; $gaugeCanvas.Height = $gaugeSize
    $gaugeGrid.AddChild($gaugeCanvas)
    $gaugeTrack = New-Object System.Windows.Shapes.Ellipse
    $gaugeTrack.Width = $gaugeRadius * 2; $gaugeTrack.Height = $gaugeRadius * 2
    $gaugeTrack.Stroke = $t.GaugeTrack
    $gaugeTrack.StrokeThickness = $gaugeThickness
    [System.Windows.Controls.Canvas]::SetLeft($gaugeTrack, $gaugeThickness / 2)
    [System.Windows.Controls.Canvas]::SetTop($gaugeTrack, $gaugeThickness / 2)
    $gaugeCanvas.AddChild($gaugeTrack)
    $gaugeArc = New-Object System.Windows.Shapes.Path
    $gaugeArc.Stroke = $t.Accent
    $gaugeArc.StrokeThickness = $gaugeThickness
    $gaugeArc.StrokeStartLineCap = "Round"; $gaugeArc.StrokeEndLineCap = "Round"
    $gaugeCanvas.AddChild($gaugeArc)
    $gaugeValueText = New-Object System.Windows.Controls.TextBlock
    $gaugeValueText.Text = "0%"
    $gaugeValueText.Foreground = $t.TextPrimary
    $gaugeValueText.FontFamily = $fontFamily
    $gaugeValueText.FontSize = 13
    $gaugeValueText.FontWeight = "Bold"
    $gaugeValueText.HorizontalAlignment = "Center"
    $gaugeValueText.VerticalAlignment = "Center"
    $gaugeGrid.AddChild($gaugeValueText)
    $gaugeHost.Child = $gaugeGrid

    $updateGauge = {
        param([double]$percent)
        $pct = [math]::Max(0, [math]::Min(100, $percent))
        $gaugeArc.Data = New-GuiGaugeArcGeometry -Radius $gaugeRadius -Cx ($gaugeSize / 2.0) -Cy ($gaugeSize / 2.0) -ValuePercent $pct
        $gaugeValueText.Text = "$([math]::Round($pct))%"
    }.GetNewClosure()

    $popupState = [PSCustomObject]@{ Cancelled = $false; Done = $false; Result = $null; LastStatus = "" }

    $actionHandler = {
        if ($popupState.Done) { $dlg.Close(); return }
        $popupState.Cancelled = $true
        $btnAction.Content = "Stopping..."
        $btnAction.IsEnabled = $false
    }.GetNewClosure()
    $btnAction.Add_Click($actionHandler)
    $btnClose.Add_Click($actionHandler)

    $onStatus = {
        param($text, $percent)
        if ($text -and $text -ne $popupState.LastStatus) {
            $popupState.LastStatus = $text
            $txtStatus.Text = $text
        }
        & $updateGauge $percent
    }.GetNewClosure()

    $cancelCheck = { $popupState.Cancelled }.GetNewClosure()

    $onTelemetry = {
        param($telemetry)
        $tempText = if ($null -ne $telemetry.MaxTemp -and $telemetry.MaxTemp -ne 0) { "$($telemetry.MaxTemp) °C" } else { "-- °C" }
        $powerText = if ($null -ne $telemetry.MaxPower -and $telemetry.MaxPower -ne 0) { "$($telemetry.MaxPower) W" } else { "-- W" }
        $clockText = if ($null -ne $telemetry.MaxClock -and $telemetry.MaxClock -ne 0) { "$($telemetry.MaxClock) MHz" } else { "-- MHz" }
        $loadText = if ($null -ne $telemetry.MaxLoad -and $telemetry.MaxLoad -ne 0) { "$($telemetry.MaxLoad) %" } else { "-- %" }
        $txtLive.Text = "GPU Temp: $tempText   |   Power: $powerText   |   Clock: $clockText   |   Load: $loadText"
    }.GetNewClosure()

    $dlg.Add_ContentRendered({
        # NOTE: this handler runs on a WPF event callback - in the compiled exe (ps2exe, no console
        # host) an unhandled exception here is invisible, so wrap it and surface the message in the
        # popup instead of leaving it stuck at "Starting...".
        try {
            $result = Get-GpuBenchmarkResult -DurationSeconds $DurationSeconds -PreviewTarget $previewImage `
                -OnStatus $onStatus -OnTelemetrySample $onTelemetry -CancelCheck $cancelCheck
            $popupState.Result = $result
            $popupState.Done = $true
            if ($result.Cancelled) {
                # Stop/close click already expressed the intent to finish: do not ask for a second one.
                $dlg.Close()
                return
            }
            & $updateGauge 100
            $txtStatus.Text = "Complete - $($result.ElapsedSeconds)s (D3D11, $($result.FeatureLevel), SM $($result.ShaderModel))"
            $stability = if ($result.Throttling) { "throttling -$($result.ThrottlePct)%" } else { "stable" }
            $parts = foreach ($p in $result.Tests) { "$($p.Name) $($p.Fps) FPS" }
            $txtResult.Text = "Composite: $($result.CompositeFps) FPS  ($($parts -join ' / ') - $stability)"
            $btnAction.Content = "Close"
            $btnAction.IsEnabled = $true
        } catch {
            Write-GuiLog "GPU benchmark failed: $($_.Exception.Message)" "ERR"
            $popupState.Done = $true
            $txtStatus.Text = "Error"
            $txtResult.Text = "$($_.Exception.Message)"
            $btnAction.Content = "Close"
            $btnAction.IsEnabled = $true
        }
    }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
    return $popupState.Result
}
