
# ================================================
#region PERFORMANCE - EXTRA GAME OPTIMIZATIONS
# ================================================
# Used by: Performance ("Apply Extra Optimizations"); also called internally by All ("OPTIMIZE ALL")
function Invoke-GameExtraApply {
    Set-GuiProgress 10 "Applying extra game optimizations..."
    Write-GuiLog "Applying extra game optimizations..." "STEP"
    $extra = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name="Win32PrioritySeparation"; Type="DWORD"; Value=38}
        @{Path="HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name="ConvertibleSlateMode"; Type="DWORD"; Value=0}
        @{Path="HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name="IRQ16Priority"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"; Type="DWORD"; Value=16}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="LazyModeTimeout"; Type="DWORD"; Value=10000}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="NetworkThrottlingIndex"; Type="DWORD"; Value=0xffffffff}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Affinity"; Type="DWORD"; Value=0}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"; Type="DWORD"; Value=14}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"; Type="DWORD"; Value=6}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SchedulingCategory"; Type="String"; Value="High"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="FSIO Priority"; Type="String"; Value="High"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Latency Sensitive"; Type="String"; Value="True"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="NoLazyMode"; Type="DWORD"; Value=1}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Background Only"; Type="String"; Value="False"}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Clock Rate"; Type="DWORD"; Value=10000}
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="BackgroundPriority"; Type="DWORD"; Value=0}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name="GlobalTimerResolutionRequests"; Type="DWORD"; Value=1}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name="TdrDelay"; Type="DWORD"; Value=6}
        @{Path="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Direct3D"; Name="MaxPreRenderedFrames"; Type="DWORD"; Value=1}
    )
    Invoke-RegistryApply -Settings $extra -Label "Extra Game Optimizations"
    Write-GuiLog "Extra game optimizations applied" "OK"
    Set-GuiProgress 0
}

# Used by: Performance ("Revert Extra")
function Invoke-GameExtraRevert {
    Set-GuiProgress 10 "Reverting extra game optimizations..."
    Write-GuiLog "Reverting extra game optimizations..." "STEP"
    $revert = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name="Win32PrioritySeparation"; Value=2; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $revert -Label "Win32PrioritySeparation Revert"
    try {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl" -Name "ConvertibleSlateMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl" -Name "IRQ16Priority" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "PriorityControl extras removed" "OK"
    } catch { }
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "LazyModeTimeout" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Multimedia SystemProfile reverted" "OK"
    } catch { }
    try {
        $gamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        if (Test-Path $gamesPath) { Remove-Item -Path $gamesPath -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "Games task entries removed" "OK" }
    } catch { }
    try {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "GlobalTimerResolutionRequests removed" "OK"
    } catch { }
    try {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "TdrDelay removed" "OK"
    } catch { }
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Direct3D" -Name "MaxPreRenderedFrames" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "MaxPreRenderedFrames removed" "OK"
    } catch { }
    Write-GuiLog "Extra game optimizations reverted" "OK"
    Set-GuiProgress 0
}
#endregion
