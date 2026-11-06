# GPU benchmark: creates a real Direct3D11 hardware device (DriverType.Hardware) via the embedded
# Vortice.Direct3D11/SharpGen chain and drives an animated fractal pixel-shader draw call against
# an off-screen render target as fast as the GPU/driver can retire it, reporting per-second FPS
# samples plus min/max/avg - see Start-GpuD3D11Benchmark below. Earlier revisions also had 2D/3D
# modes that stressed WPF's own compositor via RenderTargetBitmap (CPU-side software
# rasterization, not the GPU directly) - those were removed since they didn't measure real GPU
# throughput.

# Shared "score the collected per-second FPS samples" logic used by the Direct3D11 hardware loop
# (Start-GpuD3D11Benchmark) so results report a consistent Avg/Min/Max/throttle-detection shape.
function Get-GpuBenchmarkScoreResult {
    param([System.Collections.Generic.List[double]]$Samples, [long]$Frames, [double]$ElapsedSeconds, [bool]$Cancelled)

    $warmupSeconds = [math]::Min(2, [math]::Max(0, $Samples.Count - 1))
    $scored = $Samples
    if ($Samples.Count -gt $warmupSeconds) {
        $scored = [System.Collections.Generic.List[double]]::new($Samples.GetRange($warmupSeconds, $Samples.Count - $warmupSeconds))
    }

    $avgFps = if ($scored.Count -gt 0) { [math]::Round(($scored | Measure-Object -Average).Average, 1) } else { [math]::Round($Frames / [math]::Max($ElapsedSeconds, 0.001), 1) }
    $minFps = if ($scored.Count -gt 0) { [math]::Round(($scored | Measure-Object -Minimum).Minimum, 1) } else { $avgFps }
    $maxFps = if ($scored.Count -gt 0) { [math]::Round(($scored | Measure-Object -Maximum).Maximum, 1) } else { $avgFps }

    $half = [int][math]::Floor($scored.Count / 2)
    $firstHalfAvg = $avgFps; $secondHalfAvg = $avgFps; $throttlePct = 0
    if ($half -ge 2) {
        $firstHalfAvg = [math]::Round((($scored.GetRange(0, $half)) | Measure-Object -Average).Average, 1)
        $secondHalfAvg = [math]::Round((($scored.GetRange($scored.Count - $half, $half)) | Measure-Object -Average).Average, 1)
        if ($firstHalfAvg -gt 0) { $throttlePct = [math]::Round((($firstHalfAvg - $secondHalfAvg) / $firstHalfAvg) * 100, 1) }
    }

    return [PSCustomObject]@{
        Cancelled      = $Cancelled
        AvgFps         = $avgFps
        MinFps         = $minFps
        MaxFps         = $maxFps
        Samples        = $Samples
        FirstHalfFps   = $firstHalfAvg
        SecondHalfFps  = $secondHalfAvg
        ThrottlePct    = $throttlePct
        Throttling     = ($throttlePct -ge 10)
    }
}

# Raw D3DCompile interop (plain P/Invoke + COM, no extra embedded DLL - d3dcompiler_47.dll ships
# with Windows itself) used to turn the HLSL stress shader below into bytecode Vortice's
# CreateVertexShader/CreatePixelShader can consume. Defined once via Add-Type; safe to call
# Initialize-D3DShaderCompiler repeatedly (no-op after the type exists).
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

# HLSL stress shader: a full-screen triangle (generated in the vertex shader purely from
# SV_VertexID - no vertex/index buffer needed) whose pixel shader iterates an animated Julia-set
# escape-time fractal ~96 times per pixel. This is deliberately GPU-bound (one Draw(3,0) call per
# frame, all the work is per-pixel math) so the interop/call overhead of driving D3D11 from managed
# PowerShell code stays negligible next to the actual shader cost - unlike many small per-frame
# draw calls, which would mostly measure API/marshaling overhead instead of the GPU.
$Script:GpuStressVertexShaderHlsl = @"
struct VSOut { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };
VSOut main(uint id : SV_VertexID) {
    VSOut o;
    float2 p = float2((id << 1) & 2, id & 2);
    o.uv = p;
    o.pos = float4(p * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return o;
}
"@
$Script:GpuStressPixelShaderHlsl = @"
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

# Real Direct3D11 hardware benchmark ("Opcao B" follow-up): unlike Start-GpuUncappedFrameLoop
# above (which measures WPF's own software/hardware compositor via RenderTargetBitmap - CPU
# rasterization, not the GPU directly), this creates an actual ID3D11Device (DriverType.Hardware)
# via the embedded Vortice.Direct3D11/SharpGen chain (Initialize-Vortice3D) and drives a real
# fractal-shader draw call against an off-screen render target as fast as the GPU/driver can
# retire it - same "frames per second" concept, but measuring genuine GPU/driver throughput
# (thermal/power throttling shows up here even when WPF's compositor path would mask it, since
# RenderTargetBitmap is capped by the CPU-side software rasterizer, not the GPU).
#
# Live preview without D3DImage/D3D9 interop: instead of wiring the D3D11 swapchain directly into
# the WPF visual tree (which would need that extra interop layer), each throttled preview tick
# copies the render target into a CPU-readable staging texture (CopyResource + Map(Read)) and
# blits the raw BGRA bytes into a WriteableBitmap shown in an Image control - slower than a true
# swapchain present, but gives real visual feedback that the fractal is actually rendering/animating.
#
# NOTE: this used to spawn a raw System.Threading.Thread (MTA by default) to drive the render
# loop off the WPF Dispatcher thread (STA), since there is no WPF rendering involved. That crashed
# the whole compiled exe outright (no managed exception, no error report - the process just died)
# instead of hitting any try/catch: SharpGen's dynamic COM proxy generation for the D3D11 device
# apparently doesn't tolerate being created/driven from a thread with a different COM apartment
# state than the one WPF itself runs on. Driving the loop via the same self-requeuing
# Dispatcher.BeginInvoke(Background) pattern as Start-GpuUncappedFrameLoop above (same STA thread,
# just not synced to vsync) avoids the apartment mismatch entirely and matches the existing pattern.
function Start-GpuD3D11Benchmark {
    param([double]$DurationSeconds = 30, [int]$Width = 1920, [int]$Height = 1080, [scriptblock]$OnComplete, [scriptblock]$OnSample = $null, [scriptblock]$CancelCheck = $null, [System.Windows.Controls.Image]$PreviewImage = $null)

    if (-not (Initialize-Vortice3D)) {
        throw "Vortice/Direct3D11 runtime could not be initialized (see log for details)."
    }
    if (-not (Initialize-D3DShaderCompiler)) {
        throw "D3DCompile (d3dcompiler_47.dll) could not be initialized (see log for details)."
    }

    $device = $null; $context = $null; $texture = $null; $rtv = $null
    $vs = $null; $ps = $null; $cb = $null
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

    $texDesc = New-Object Vortice.Direct3D11.Texture2DDescription
    $texDesc.Width = $Width; $texDesc.Height = $Height
    $texDesc.MipLevels = 1; $texDesc.ArraySize = 1
    $texDesc.Format = [Vortice.DXGI.Format]::B8G8R8A8_UNorm
    $texDesc.SampleDescription = New-Object Vortice.DXGI.SampleDescription(1, 0)
    $texDesc.Usage = [Vortice.Direct3D11.ResourceUsage]::Default
    $texDesc.BindFlags = [Vortice.Direct3D11.BindFlags]::RenderTarget
    $texture = $device.CreateTexture2D($texDesc)
    $rtv = $device.CreateRenderTargetView($texture)

    # CPU-readable staging copy of the render target, used only to blit a throttled preview into
    # $PreviewImage (see the comment above this function) - kept separate from $texture because the
    # render target itself (BindFlags=RenderTarget, Usage=Default) cannot be Map()'d directly.
    $staging = $null
    $bmp = $null
    if ($PreviewImage) {
        $stagingDesc = New-Object Vortice.Direct3D11.Texture2DDescription
        $stagingDesc.Width = $Width; $stagingDesc.Height = $Height
        $stagingDesc.MipLevels = 1; $stagingDesc.ArraySize = 1
        $stagingDesc.Format = [Vortice.DXGI.Format]::B8G8R8A8_UNorm
        $stagingDesc.SampleDescription = New-Object Vortice.DXGI.SampleDescription(1, 0)
        $stagingDesc.Usage = [Vortice.Direct3D11.ResourceUsage]::Staging
        $stagingDesc.BindFlags = [Vortice.Direct3D11.BindFlags]::None
        $stagingDesc.CPUAccessFlags = [Vortice.Direct3D11.CpuAccessFlags]::Read
        $staging = $device.CreateTexture2D($stagingDesc)
        $bmp = New-Object System.Windows.Media.Imaging.WriteableBitmap($Width, $Height, 96, 96, [System.Windows.Media.PixelFormats]::Bgra32, $null)
        $PreviewImage.Source = $bmp
    }

    # Real GPU workload: compile the full-screen fractal stress shader (see the HLSL strings and
    # the comment above this function) and build the minimal D3D11 pipeline needed to run it - a
    # vertex shader (no input layout/vertex buffer: positions come from SV_VertexID), a pixel
    # shader doing the actual heavy per-pixel math, and a small dynamic constant buffer carrying
    # elapsed time so the fractal animates frame to frame.
    $vsBytecode = [D3DShaderCompiler]::Compile($Script:GpuStressVertexShaderHlsl, "main", "vs_4_0")
    $psBytecode = [D3DShaderCompiler]::Compile($Script:GpuStressPixelShaderHlsl, "main", "ps_4_0")
    $vs = $device.CreateVertexShader($vsBytecode)
    $ps = $device.CreatePixelShader($psBytecode)

    # CreateBuffer has several overloads (by-description-struct, by-description+ref-out-param,
    # generic-with-initial-data, etc.) that PowerShell's overload binder cannot disambiguate
    # reliably from a single BufferDescription object (same overload-ambiguity root cause as the
    # ClearRenderTargetView/Thread issues noted above) - using the plain scalar-parameter overload
    # (size/bind/usage/cpuAccess/misc/stride) sidesteps the binder entirely.
    $cb = $device.CreateBuffer(16, [Vortice.Direct3D11.BindFlags]::ConstantBuffer, [Vortice.Direct3D11.ResourceUsage]::Dynamic, [Vortice.Direct3D11.CpuAccessFlags]::Write, [Vortice.Direct3D11.ResourceOptionFlags]::None, 0)

    # ID3D11DeviceContext.Map has two overloads differing only in whether the trailing parameter
    # is by-value vs by-ref (the managed-friendly convenience shape vs. the raw COM out-param
    # shape) - PowerShell can't disambiguate a plain argument/call against both and throws
    # "Multiple ambiguous overloads found" (same root cause as the earlier System.Threading.Thread
    # ctor and ClearRenderTargetView issues above). Resolving the by-value overload once via
    # reflection and invoking it directly sidesteps PowerShell's overload binder entirely.
    $ctxType = [Vortice.Direct3D11.ID3D11DeviceContext]
    $mapMethod = ($ctxType.GetMethods() | Where-Object {
        $_.Name -eq "Map" -and $_.GetParameters().Count -eq 4 -and -not $_.GetParameters()[3].ParameterType.IsByRef
    } | Select-Object -First 1)

    $state = [PSCustomObject]@{
        Frames = 0L; LastSecondFrames = 0L; LastSecond = 0; Completed = $false
        LastPreviewMs = -1000.0
        Samples = [System.Collections.Generic.List[double]]::new()
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }

    # Same $holder self-requeuing-closure trick as Start-GpuUncappedFrameLoop above (see the NOTE
    # there) - a plain recursive $Script:-scoped closure resolves to $null once invoked as an
    # async [Action] off the Dispatcher queue.
    $holder = [PSCustomObject]@{ Tick = $null }
    $cleanup = {
        if ($cb) { $cb.Dispose() }
        if ($ps) { $ps.Dispose() }
        if ($vs) { $vs.Dispose() }
        if ($staging) { $staging.Dispose() }
        if ($rtv) { $rtv.Dispose() }
        if ($texture) { $texture.Dispose() }
        if ($context) { $context.Dispose() }
        if ($device) { $device.Dispose() }
    }.GetNewClosure()

    $holder.Tick = {
        if ($state.Completed) { return }

        try {
            $time = [float]$state.Stopwatch.Elapsed.TotalSeconds

            $mapped = $mapMethod.Invoke($context, @($cb, 0, [Vortice.Direct3D11.MapMode]::WriteDiscard, [Vortice.Direct3D11.MapFlags]::None))
            [System.Runtime.InteropServices.Marshal]::WriteInt32($mapped.DataPointer, 0, [BitConverter]::ToInt32([BitConverter]::GetBytes($time), 0))
            $context.Unmap($cb, 0)

            $context.OMSetRenderTargets($rtv)
            $context.RSSetViewport((New-Object Vortice.Mathematics.Viewport(0, 0, $Width, $Height)))
            $context.IASetPrimitiveTopology([Vortice.Direct3D.PrimitiveTopology]::TriangleList)
            $context.VSSetShader($vs)
            $context.PSSetShader($ps)
            $context.PSSetConstantBuffer(0, $cb)
            $context.Draw(3, 0)
            $context.Flush()
            $state.Frames++

            # Throttled preview blit (see the comment above this function) - copying/mapping every
            # single frame would tank the measured FPS, so this only runs a few times per second,
            # independent of the frame-count/FPS accounting above.
            if ($bmp -and ($time * 1000.0 - $state.LastPreviewMs) -ge 100.0) {
                $state.LastPreviewMs = $time * 1000.0
                $context.CopyResource($staging, $texture)
                $mappedTex = $mapMethod.Invoke($context, @($staging, 0, [Vortice.Direct3D11.MapMode]::Read, [Vortice.Direct3D11.MapFlags]::None))
                $bmp.WritePixels((New-Object System.Windows.Int32Rect(0, 0, $Width, $Height)), $mappedTex.DataPointer, ($mappedTex.RowPitch * $Height), $mappedTex.RowPitch)
                $context.Unmap($staging, 0)
            }
        } catch {
            Write-GuiLog "GPU D3D11 benchmark frame error: $($_.Exception.Message)" "WARN"
        }

        $elapsed = $state.Stopwatch.Elapsed.TotalSeconds
        $curSecond = [int][math]::Floor($elapsed)
        if ($curSecond -gt $state.LastSecond) {
            $sample = [double]($state.Frames - $state.LastSecondFrames)
            $state.Samples.Add($sample) | Out-Null
            $state.LastSecondFrames = $state.Frames
            $state.LastSecond = $curSecond
            if ($OnSample) {
                try { & $OnSample $sample } catch { Write-GuiLog "GPU D3D11 benchmark sample callback error: $($_.Exception.Message)" "WARN" }
            }
        }

        $cancelled = [bool]($CancelCheck -and (& $CancelCheck))
        if ($elapsed -ge $DurationSeconds -or $cancelled) {
            $state.Completed = $true
            & $cleanup
            $result = Get-GpuBenchmarkScoreResult -Samples $state.Samples -Frames $state.Frames -ElapsedSeconds $elapsed -Cancelled $cancelled
            if ($OnComplete) { & $OnComplete $result }
            return
        }

        $Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]$holder.Tick) | Out-Null
    }.GetNewClosure()

    $Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]$holder.Tick) | Out-Null
}

# Runs the GPU benchmark (2D or 3D mode) inside its own modal popup window instead of in the
# BenchGpu.ps1 page itself: the popup hosts the render surface + a live FPS gauge while the test
# runs, and only the final Avg FPS result is reported back to the page (Show-PageBenchGpu adds
# just a result stat-tile - no render surface lives on the page anymore).
#
# This popup is a plain XamlReader Window (like the update-checker dialogs in UpdateChecker.ps1),
# not part of the main $Window visual tree, so it can't use {DynamicResource} against
# $Window.Resources - all chrome/gauge colors are baked in as literal values from the current
# theme (same approach as Get-UpdatePopupXaml/Get-CurrentThemeColors).
# Returns the benchmark $result (Cancelled/AvgFps/MinFps/MaxFps/Samples), or $null if the window
# was closed before a result was produced (shouldn't normally happen - Close only becomes
# available once the run completes).
function Show-GpuBenchmarkPopup {
    param([string]$Mode = "D3D11", [double]$DurationSeconds = 30)

    $modeName = "Direct3D11 Hardware"
    $t = Get-CurrentThemeColors
    $fontFamily = if ($t.FontFamily -eq "MONO") { "Consolas" } else { "Segoe UI" }
    $radius = $t.CornerRadius

    $body = @"
        <StackPanel>
            <Border x:Name="renderHost" Height="560" Background="$($t.CardBg)" BorderBrush="$($t.CardBorder)" BorderThickness="1" CornerRadius="$radius" Margin="0,0,0,14"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                <Border x:Name="gaugeHost" Width="60" Height="60" VerticalAlignment="Center"/>
                <StackPanel Width="220" Margin="14,0,0,0" VerticalAlignment="Center">
                    <TextBlock x:Name="txtStatus" Text="Running... 0 / ${DurationSeconds}s" Foreground="$($t.TextSecondary)" FontFamily="$fontFamily" FontSize="11" TextAlignment="Center"/>
                    <TextBlock x:Name="txtResult" Text="" Foreground="$($t.TextPrimary)" FontFamily="$fontFamily" FontSize="13" FontWeight="Bold" Margin="0,3,0,0" TextAlignment="Center"/>
                </StackPanel>
                <Button x:Name="btnAction" Content="Stop Benchmark" Style="{StaticResource DialogPrimaryButtonStyle}" Margin="14,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
        </StackPanel>
"@

    [xml]$xaml = Get-UpdatePopupXaml -Width 1000 -Title "GPU Benchmark - $modeName" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $renderHost = $dlg.FindName("renderHost")
    $gaugeHost = $dlg.FindName("gaugeHost")
    $txtStatus = $dlg.FindName("txtStatus")
    $txtResult = $dlg.FindName("txtResult")
    $btnAction = $dlg.FindName("btnAction")
    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar

    # Render surface: D3D11 mode has no live swapchain wired into the WPF visual tree (see
    # Start-GpuD3D11Benchmark's comment - that would need D3DImage/D3D9 interop) - instead an
    # Image control is bound to a WriteableBitmap that Start-GpuD3D11Benchmark blits a throttled
    # preview into, so the fractal is still visible.
    $d3d11PreviewImage = New-Object System.Windows.Controls.Image
    $d3d11PreviewImage.Stretch = "Uniform"
    $renderHost.Child = $d3d11PreviewImage

    # Literal-color circular gauge (track + arc + center value) - mirrors New-GuiCircularGauge's
    # structure (Core/Gauges/GuiGauges.ps1) but with baked colors instead of SetResourceReference,
    # since this popup has no live {DynamicResource} wiring to $Window.Resources.
    $gaugeSize = 60; $gaugeThickness = 7; $gaugeRadius = ($gaugeSize - $gaugeThickness) / 2.0
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
    $gaugeValueText.Text = "--"
    $gaugeValueText.Foreground = $t.TextPrimary
    $gaugeValueText.FontFamily = $fontFamily
    $gaugeValueText.FontSize = 12
    $gaugeValueText.FontWeight = "Bold"
    $gaugeValueText.HorizontalAlignment = "Center"
    $gaugeValueText.VerticalAlignment = "Center"
    $gaugeGrid.AddChild($gaugeValueText)
    $gaugeHost.Child = $gaugeGrid

    # Scales FPS to a 0-100 arc percentage and shows the raw FPS number (not a percent) in the
    # center, since FPS - not percent completion - is the meaningful unit here. The render loop
    # is no longer vsync-capped (see the note above Start-GpuUncappedFrameLoop), so FPS can climb
    # well past 60 on a fast GPU - 240 FPS is used as the "full ring" reference instead.
    $updateGauge = {
        param($fps)
        $pct = [math]::Max(0, [math]::Min(100, ($fps / 240.0) * 100))
        $gaugeArc.Data = New-GuiGaugeArcGeometry -Radius $gaugeRadius -Cx ($gaugeSize / 2.0) -Cy ($gaugeSize / 2.0) -ValuePercent $pct
        $gaugeValueText.Text = "$([math]::Round($fps))"
    }.GetNewClosure()

    $popupState = [PSCustomObject]@{ Cancelled = $false; Done = $false; Result = $null; SampleCount = 0 }

    $actionHandler = {
        if ($popupState.Done) { $dlg.Close(); return }
        $popupState.Cancelled = $true
        $btnAction.Content = "Stopping..."
        $btnAction.IsEnabled = $false
    }.GetNewClosure()
    $btnAction.Add_Click($actionHandler)
    $btnClose.Add_Click($actionHandler)

    $onSample = {
        param($v)
        $popupState.SampleCount++
        $txtStatus.Text = "Running... $($popupState.SampleCount) / ${DurationSeconds}s"
        & $updateGauge $v
    }.GetNewClosure()

    $onComplete = {
        param($result)
        $popupState.Done = $true
        $popupState.Result = $result
        if ($result.Cancelled) {
            # User already asked to stop (clicked "Stop Benchmark"/the X button once) - that click
            # is the intent to close, not just to freeze the run. Previously this only flipped the
            # button to "Close" (enabled) and waited for a *second* click, which from the user's
            # side looked exactly like "I clicked Stop, it says Stopping..., and the window never
            # closes" (they only clicked once). Auto-close here instead of waiting on an extra click.
            $dlg.Close()
            return
        }
        & $updateGauge $result.AvgFps
        $txtStatus.Text = "Complete ($modeName, ${DurationSeconds}s)"
        $throttleNote = if ($result.Throttling) { " - throttling detected (-$($result.ThrottlePct)%)" } else { "" }
        $txtResult.Text = "Average: $($result.AvgFps) FPS$throttleNote"
        $btnAction.Content = "Close"
        $btnAction.IsEnabled = $true
    }.GetNewClosure()

    # NOTE: -CancelCheck must carry its own .GetNewClosure() here, not just rely on the outer
    # ContentRendered scriptblock's closure. $Script:GpuLoopTick (Start-GpuUncappedFrameLoop) is
    # itself a separate, detached GetNewClosure() - a bare `{ $popupState.Cancelled }` scriptblock
    # invoked via "& $CancelCheck" from inside that detached closure can't see $popupState (same
    # closure-isolation issue documented in BenchCpu.ps1 for $Script: vars), so Cancelled always
    # read back as $null/false - the Stop button's click was never actually detected by the loop,
    # leaving the popup stuck on "Stopping..." with Close unresponsive.
    $cancelCheck = { $popupState.Cancelled }.GetNewClosure()
    $dlg.Add_ContentRendered({
        # NOTE: this handler runs on a WPF event callback - in the compiled exe (ps2exe, no
        # console host) an unhandled exception here doesn't surface anywhere visible, it just
        # silently aborts before Start-GpuUncappedFrameLoop ever kicks off the tick loop. That
        # left the popup permanently stuck at "Running... 0/Ns" with Stop/Close unresponsive
        # (nothing was ever listening for Cancelled, because the loop never started). Wrap it so
        # a scene-building failure is visible in the log and the popup becomes closable instead
        # of hanging forever.
        try {
            Start-GpuD3D11Benchmark -DurationSeconds $DurationSeconds -PreviewImage $d3d11PreviewImage `
                -OnSample $onSample -CancelCheck $cancelCheck -OnComplete $onComplete
        } catch {
            Write-GuiLog "GPU benchmark failed to start: $($_.Exception.Message)" "ERR"
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
