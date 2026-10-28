# ================================================
#region PERFORMANCE - GPU AUTO-DETECT & OPTIMIZE
# ================================================
function Get-AmdGpuKeys {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    Get-ChildItem $base -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^\d{4}$' } |
        Where-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $p.ProviderName -match 'Advanced Micro Devices' -and $p.DriverDesc -match 'Radeon|AMD'
        } | ForEach-Object { $_.PSPath }
}

# Used by: Performance ("Detect & Optimize GPU"); also called internally by All ("OPTIMIZE ALL")
function Invoke-GPUApply {
    Set-GuiProgress 10 "Detecting GPU vendor..."
    Write-GuiLog "Detecting GPU vendor..." "STEP"
    try {
        $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -ne $null } | Select-Object -First 1
        $nameLow = $gpu.Name.ToLower()
        $vendor = if ($nameLow -match "nvidia") { "NVIDIA" } elseif ($nameLow -match "amd|radeon") { "AMD" } else { "Unknown" }
        Write-GuiLog "Detected GPU vendor: $vendor ($($gpu.Name.Trim()))" "INFO"

        if ($vendor -eq "NVIDIA") {
            Set-GuiProgress 40 "Optimizing NVIDIA..."
            $nvPath = "C:\Program Files\NVIDIA Corporation\NVSMI"
            if (Test-Path $nvPath) {
                Push-Location $nvPath
                try { & .\nvidia-smi.exe -acp 0 | Out-Null; & .\nvidia-smi.exe -e 1 | Out-Null; Write-GuiLog "NVIDIA-SMI settings applied" "OK" } catch { }
                Pop-Location
            }
            $nvidiaReg = @(
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm";Name="DisablePreemption";Type="DWORD";Value=1}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm";Name="DisableCudaContextPreemption";Type="DWORD";Value=1}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm";Name="EnableCEPreemption";Type="DWORD";Value=0}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm";Name="ComputePreemption";Type="DWORD";Value=0}
                @{Path="HKLM:\SYSTEM\ControlSet001\Control\GraphicsDrivers\Scheduler";Name="EnablePreemption";Type="DWORD";Value=0}
            )
            Invoke-RegistryApply -Settings $nvidiaReg -Label "NVIDIA Registry"
            Write-GuiLog "NVIDIA optimization completed" "OK"
        } elseif ($vendor -eq "AMD") {
            $keys = @(Get-AmdGpuKeys)
            if ($keys.Count -eq 0) {
                Write-GuiLog "AMD registry key not found." "WARN"
            } else {
                foreach ($basePath in $keys) {
                    $amdReg = @(
                        @{Path=$basePath;Name="DisableUVDPowerGatingDynamic";Type="DWORD";Value=1}
                        @{Path=$basePath;Name="EnableUlps";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="DisableDMACopy";Type="DWORD";Value=1}
                        @{Path=$basePath;Name="PP_GPUPowerDownEnabled";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="StutterMode";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="KMD_ChillEnabled";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="KMD_RadeonBoostEnabled";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="KMD_DeLagEnabled";Type="DWORD";Value=1}
                        # Telemetria/avisos
                        @{Path=$basePath;Name="ReportAnalytics";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="NotifySubscription";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="AllowSubscription";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="ShowReleaseNotes";Type="DWORD";Value=0}
                        # ASPM
                        @{Path=$basePath;Name="EnableAspmL0s";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="EnableAspmL1";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="EnableAspmL1SS";Type="DWORD";Value=0}
                        @{Path=$basePath;Name="DisableAspmL0s";Type="DWORD";Value=1}
                        @{Path=$basePath;Name="DisableAspmL1";Type="DWORD";Value=1}
                        # Anti-Lag global (descomente só se quiser)
                        # @{Path=$basePath;Name="KMD_DeLagEnabled";Type="DWORD";Value=1}
                    )
                    Invoke-RegistryApply -Settings $amdReg -Label "AMD Optimization"
                }
                Write-GuiLog "AMD optimization completed. Restart required." "OK"
            }
        } else {
            Write-GuiLog "No NVIDIA or AMD GPU detected. Skipping GPU optimizations." "WARN"
        }
    } catch { Write-GuiLog "GPU detection failed: $_" "ERR" }
    Set-NavStatus "GPU" $true
    Set-GuiProgress 0
}

# Used by: Performance ("Revert GPU")
function Invoke-GPURevert {
    Set-GuiProgress 10 "Reverting GPU optimizations..."
    Write-GuiLog "Reverting GPU optimizations..." "STEP"
    try {
        $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -ne $null } | Select-Object -First 1
        $nameLow = $gpu.Name.ToLower()
        $vendor = if ($nameLow -match "nvidia") { "NVIDIA" } elseif ($nameLow -match "amd|radeon") { "AMD" } else { "Unknown" }
        Write-GuiLog "Detected GPU vendor: $vendor" "INFO"
        if ($vendor -eq "NVIDIA") {
            $nvidiaRevert = @(
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="DisablePreemption"; Value=0; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="DisableCudaContextPreemption"; Value=0; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="EnableCEPreemption"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="ComputePreemption"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="DisablePreemptionOnS3S4"; Value=0; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="EnableMidGfxPreemption"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="EnableMidGfxPreemptionVGPU"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="EnableMidBufferPreemptionForHighTdrTimeout"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="EnableMidBufferPreemption"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name="EnableAsyncMidBufferPreemption"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\ControlSet001\Control\GraphicsDrivers\Scheduler"; Name="EnablePreemption"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup"; Name="SendTelemetryData"; Value=1; Type="DWORD"}
                @{Path="HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"; Name="OptInOrOutPreference"; Value=1; Type="DWORD"}
            )
            Invoke-RegistryApply -Settings $nvidiaRevert -Label "NVIDIA Revert"
            Write-GuiLog "NVIDIA optimizations reverted" "OK"
        } elseif ($vendor -eq "AMD") {
            $names = "DisableUVDPowerGatingDynamic","EnableUlps","DisableDMACopy","PP_GPUPowerDownEnabled","StutterMode",
                     "KMD_ChillEnabled","KMD_RadeonBoostEnabled","KMD_DeLagEnabled",
                     "ReportAnalytics","NotifySubscription","AllowSubscription","ShowReleaseNotes",
                     "EnableAspmL0s","EnableAspmL1","EnableAspmL1SS","DisableAspmL0s","DisableAspmL1"
            foreach ($basePath in @(Get-AmdGpuKeys)) {
                foreach ($n in $names) {
                    Remove-ItemProperty -Path $basePath -Name $n -Force -ErrorAction SilentlyContinue
                }
            }
            Write-GuiLog "AMD optimizations reverted. Restart required." "OK"
        } else {
            Write-GuiLog "No NVIDIA or AMD GPU detected. Nothing to revert." "WARN"
        }
    } catch { Write-GuiLog "GPU revert failed: $_" "ERR" }
    Set-NavStatus "GPU" $false
    Set-GuiProgress 0
}
#endregion