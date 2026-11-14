
# ================================================
#region PERFORMANCE - MEMORY MANAGEMENT
# ================================================
# Used by: Performance ("Apply Memory Optimizations"); also called internally by All ("OPTIMIZE ALL")
function Invoke-MemoryApply {
    Set-GuiProgress 10 "Applying memory optimizations..."
    Write-GuiLog (T "Applying memory optimizations...") "STEP"
    $reg = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="ClearPageFileAtShutdown"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="NonPagedPoolQuota"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="NonPagedPoolSize"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="PhysicalAddressExtension"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="EnergyDriverPolicyVideo"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="TimerBResolution"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="TimerMinResolution"; Value=1; Type="DWORD"}
    )
    Set-NavStatus "Memory" $true
    Invoke-RegistryApply -Settings $reg -Label "Memory Management"
    try {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-GuiLog (T "Memory compression disabled") "OK"
    } catch { Write-GuiLog (T "Memory compression was already disabled") "INFO" }
    try {
        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        $svcVal = switch ($ramGB) {
            {$_ -le 4}  { 4*1024*1024 }
            {$_ -le 8}  { 8*1024*1024 }
            {$_ -le 12} { 12*1024*1024 }
            {$_ -le 16} { 16*1024*1024 }
            {$_ -le 24} { 24*1024*1024 }
            {$_ -le 32} { 32*1024*1024 }
            {$_ -le 48} { 48*1024*1024 }
            {$_ -le 64} { 64*1024*1024 }
            default     { 128*1024*1024 }
        }
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $svcVal -Type DWord -Force -ErrorAction SilentlyContinue
        Write-GuiLog ((T "SvcHost configured for {0}GB RAM") -f $ramGB) "OK"
    } catch { }
    Write-GuiLog (T "Memory optimization completed") "OK"
    Set-GuiProgress 0
}

# Used by: Performance ("Revert Memory")
function Invoke-MemoryRevert {
    Set-GuiProgress 10 "Reverting memory optimizations..."
    Write-GuiLog (T "Reverting memory optimizations...") "STEP"
    $revert = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache"; Value=0; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $revert -Label "LargeSystemCache Revert"
    try {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "NonPagedPoolQuota" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "NonPagedPoolSize" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PhysicalAddressExtension" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "EnergyDriverPolicyVideo" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "TimerBResolution" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "TimerMinResolution" -Force -ErrorAction SilentlyContinue
        Write-GuiLog (T "Memory management keys reverted") "OK"
    } catch { }
    try {
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-GuiLog (T "Memory compression re-enabled") "OK"
    } catch { Write-GuiLog (T "Memory compression was already enabled") "INFO" }
    try {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Force -ErrorAction SilentlyContinue
        Write-GuiLog (T "SvcHostSplitThresholdInKB reset") "OK"
    } catch { Write-GuiLog (T "SvcHostSplitThresholdInKB was not set") "INFO" }
    Write-GuiLog (T "Memory optimizations reverted") "OK"
    Set-NavStatus "Memory" $false
    Set-GuiProgress 0
}
#endregion
