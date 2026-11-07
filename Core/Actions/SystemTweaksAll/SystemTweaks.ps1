
# ================================================
#region SYSTEMTWEAKSALL - COMPREHENSIVE SYSTEM TWEAKS
# ================================================
# Used by: SystemTweaksAll ("Apply All System Tweaks")
function Invoke-TweaksApply {
    Write-GuiLog "Applying system tweaks..." "STEP"
    Write-GuiLog "Removing Edge scheduled tasks..." "STEP"
    try {
        reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\MicrosoftEdgeUpdateTaskMachineCore" /f 2>$null | Out-Null
        reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\MicrosoftEdgeUpdateTaskMachineUA" /f 2>$null | Out-Null
        Write-GuiLog "Edge tasks removed" "OK"
    } catch { }
    $cats = @{
        "Telemetry" = @(
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack";Name="ShowedToastAtLevel";Type="DWORD";Value=1}
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy";Name="TailoredExperiencesWithDiagnosticDataEnabled";Type="DWORD";Value=0}
            @{Path="HKLM:\Software\Policies\Microsoft\Windows\System";Name="EnableActivityFeed";Type="DWORD";Value=0}
            @{Path="HKLM:\Software\Policies\Microsoft\Windows\AdvertisingInfo";Name="DisabledByGroupPolicy";Type="DWORD";Value=1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";Name="AllowTelemetry";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection";Name="AllowTelemetry";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows";Name="DoReport";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows";Name="LoggingDisabled";Type="DWORD";Value=1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting";Name="DoReport";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Microsoft\Windows";Name="LogEnabling";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent";Name="DisableThirdPartySuggestions";Type="DWORD";Value=1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";Name="DoNotShowFeedbackNotifications";Type="DWORD";Value=1}
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP";Name="CdpSessionUserAuthzPolicy";Type="DWORD";Value=0}
        )
        "Settings Sync" = @(
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync";Name="DisableSettingSync";Type="DWORD";Value=2}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync";Name="DisableWindowsSettingSync";Type="DWORD";Value=2}
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync";Name="SyncPolicy";Type="DWORD";Value=5}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive";Name="DisableFileSync";Type="DWORD";Value=1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive";Name="DisableFileSyncNGSC";Type="DWORD";Value=1}
        )
        "Maintenance" = @(
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FontCache";Name="Start";Type="DWORD";Value=4}
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WdiServiceHost";Name="Start";Type="DWORD";Value=4}
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WdiSystemHost";Name="Start";Type="DWORD";Value=4}
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Spooler";Name="Start";Type="DWORD";Value=4}
            @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance";Name="MaintenanceDisabled";Type="DWORD";Value=1}
        )
        "Interface" = @(
            @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects";Name="VisualFXSetting";Type="DWORD";Value=3}
            # Windows reads MinAnimate from WindowMetrics, not HKCU\Control (where it had no effect).
            @{Path="HKCU:\Control Panel\Desktop\WindowMetrics";Name="MinAnimate";Type="String";Value=0}
            @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="TaskbarAnimations";Type="DWORD";Value=0}
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize";Name="EnablingTransparency";Type="DWORD";Value=0}
            @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search";Name="SearchboxTaskbarMode";Type="DWORD";Value=0}
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize";Name="StartupDelayInMSec";Type="DWORD";Value=0}
            @{Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation";Name="DisableStartupSound";Type="DWORD";Value=1}
        )
        "Search/Cortana" = @(
            @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search";Name="BingSearchEnabled";Type="DWORD";Value=0}
            @{Path="HKLM:\Software\Policies\Microsoft\Windows\Windows";Name="AllowCloudSearch";Type="DWORD";Value=0}
            @{Path="HKLM:\Software\Policies\Microsoft\Windows\Windows";Name="DisableWebSearch";Type="DWORD";Value=1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows";Name="AllowCortana";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds";Name="EnableFeeds";Type="DWORD";Value=0}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Dsh";Name="AllowNewsAndInterests";Type="DWORD";Value=0}
        )
        "Kernel/Performance" = @(
            # Windows reads Win32PrioritySeparation from Control\PriorityControl; a value named
            # "PriorityControl" under Session Manager\kernel is ignored (it was a no-op).
            # 38 (0x26) = the documented "Programs" profile, same value GameExtra writes.
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl";Name="Win32PrioritySeparation";Type="DWORD";Value=38}
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";Name="ThreadDpcEnable";Type="DWORD";Value=1}
            # Windows reads these from "Control Panel\Desktop"; writing to HKCU\Control was a no-op.
            @{Path="HKCU:\Control Panel\Desktop";Name="AutoEndTasks";Type="String";Value=1}
            @{Path="HKCU:\Control Panel\Desktop";Name="HungAppTimeout";Type="String";Value=1000}
            @{Path="HKCU:\Control Panel\Desktop";Name="WaitToKillAppTimeout";Type="String";Value=2000}
            @{Path="HKCU:\Control Panel\Desktop";Name="MenuShowDelay";Type="String";Value=0}
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Control";Name="WaitToKillServiceTimeout";Type="String";Value=2000}
        )
    }
    $totalAll = 0; foreach ($c in $cats.Values) { $totalAll += $c.Count }
    $idx = 0
    foreach ($catName in $cats.Keys) {
        $catData = $cats[$catName]
        foreach ($s in $catData) {
            $idx++
            Set-GuiProgress ([math]::Round($idx/$totalAll*100)) "System Tweaks: $catName ($idx/$totalAll)"
            try {
                if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force -ErrorAction SilentlyContinue | Out-Null }
                if ($s.Type -eq "String") { Set-ItemProperty -Path $s.Path -Name $s.Name -Value ([string]$s.Value) -Force -ErrorAction SilentlyContinue }
                else { New-ItemProperty -Path $s.Path -Name $s.Name -PropertyType $s.Type -Value $s.Value -Force -ErrorAction SilentlyContinue | Out-Null }
            } catch { }
        }
    }
    Set-NavStatus "Tweaks" $true
    Set-GuiProgress 0
    Write-GuiLog "System tweaks applied ($totalAll keys)" "OK"
}

# Used by: SystemTweaksAll ("Revert Tweaks")
function Invoke-TweaksRevert {
    Write-GuiLog "Reverting system tweaks to defaults..." "STEP"
    Set-GuiProgress 10 "Restoring telemetry..."
    $telemetry = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name="AllowTelemetry"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="AllowTelemetry"; Value=1; Type="DWORD"}
        @{Path="HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name="AllowTelemetry"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $telemetry -Label "Telemetry Restore"
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "DoReport" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "LoggingDisabled" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "AllowCloudSearch" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "DisableWebSearch" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "AllowCortana" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting" -Name "DoReport" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableThirdPartySuggestions" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows" -Name "LogEnabling" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Telemetry/diagnostics reverted" "OK"
    } catch { }
    Set-GuiProgress 25 "Restoring settings sync..."
    $sync = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name="DisableSettingSync"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name="DisableWindowsSettingSync"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name="DisableSyncOnPaidNetwork"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name="DisableFileSync"; Value=0; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name="DisableFileSyncNGSC"; Value=0; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $sync -Label "Settings Sync Restore"
    try {
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync" -Name "SyncPolicy" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Settings sync re-enabled" "OK"
    } catch { }
    Set-GuiProgress 45 "Restoring search/Cortana..."
    try {
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Search features re-enabled" "OK"
    } catch { }
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Feeds and news re-enabled" "OK"
    } catch { }
    Set-GuiProgress 65 "Restoring interface..."
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 1 -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnablingTransparency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Visual effects and animations restored" "OK"
    } catch { }
    Set-GuiProgress 85 "Restoring kernel defaults..."
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Value 0 -Type String -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Kernel/performance defaults restored" "OK"
    } catch { }
    # Values the tweaks above CREATE. Removing them is what restores the Windows default; without
    # this block a user who reverted still had telemetry/DPC/boot-sound tweaks applied.
    try {
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" -Name "CdpSessionUserAuthzPolicy" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "ShowedToastAtLevel" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" -Name "DisableStartupSound" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "ThreadDpcEnable" -Force -ErrorAction SilentlyContinue
        # Services the tweaks DISABLE (Start=4). These must be written back to their Windows default
        # startup type instead of being deleted - a service with no Start value does not boot.
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\FontCache" -Name "Start" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdiServiceHost" -Name "Start" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WdiSystemHost" -Name "Start" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Diagnostics, kernel and service tweaks restored" "OK"
    } catch { }
    Set-NavStatus "Tweaks" $false
    Set-GuiProgress 0
    Write-GuiLog "System tweaks reverted to defaults" "OK"
}
#endregion
