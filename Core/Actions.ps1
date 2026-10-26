# ================================================
#region 1. INTERNET OPTIMIZATION
# ================================================
# Used by: NetworkPrivacy ("Apply Optimization")
function Invoke-InternetOptimize {
    Set-GuiProgress 10 "Starting Internet optimization..."
    Clear-GuiLog
    try {
        netsh int tcp set global autotuning=disabled | Out-Null
        Write-GuiLog "TCP autotuning disabled" "OK"
        $reg = @(
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"; Name="FastSendDatagramThreshold"; Type="DWORD"; Value=64000}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Version"; Type="String"; Value="1.0"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Application Name"; Type="String"; Value="VALORANT.exe"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Protocol"; Type="String"; Value="*"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="DSCP Value"; Type="DWORD"; Value=46}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Throttle Rate"; Type="DWORD"; Value=-1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Version"; Type="String"; Value="1.0"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Application Name"; Type="String"; Value="csgo.exe"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Protocol"; Type="String"; Value="*"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="DSCP Value"; Type="DWORD"; Value=46}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Throttle Rate"; Type="DWORD"; Value=-1}
        )
        Invoke-RegistryApply -Settings $reg -Label "Internet QoS"
        Write-GuiLog "Internet optimization completed!" "OK"
    } catch { Write-GuiLog "Internet optimization failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Utilities ("MSI Util v3", "O&O AppBuster", "Autoruns", "sPowers")
function Invoke-LaunchApp {
    param([string]$ExeName, [string]$Label)
    $path = Join-Path $Script:TempDir "Programs\$ExeName"
    if (-not (Test-Path $path)) { Extract-EmbeddedPrograms }
    if (Test-Path $path) { Start-Process $path; Write-GuiLog "$Label launched" "OK" }
    else { Write-GuiLog "$ExeName not found" "ERR" }
}

# Used by: Utilities ("vibranceGUI", "TimerResolution")
function Invoke-LaunchToDesktop {
    param([string]$ExeName, [string]$Label)
    $src = Join-Path $Script:TempDir "Programs\$ExeName"
    if (-not (Test-Path $src)) { Extract-EmbeddedPrograms }
    if (-not (Test-Path $src)) { Write-GuiLog "$ExeName not found" "ERR"; return }
    $desktop = [Environment]::GetFolderPath("Desktop")
    $dest = Join-Path $desktop $ExeName
    try {
        Copy-Item $src $dest -Force
        Write-GuiLog "$Label copied to Desktop" "OK"
        Start-Process $dest
        Write-GuiLog "$Label launched from Desktop" "OK"
    } catch { Write-GuiLog "Failed to copy $Label to Desktop: $_" "ERR" }
}

# Used by: Utilities ("SETT UTILITY Extension" > "Download Extension")
function Invoke-CopySettUtility {
    $url = "https://raw.githubusercontent.com/setttz/settUtility/main/sett-utility-extension.zip"
    $zipPath = Join-Path $Script:TempDir "sett-utility-extension.zip"
    $dest = Join-Path (Join-Path $env:USERPROFILE "Downloads") "sett-utility-extension"
    Write-GuiLog "Downloading SETT UTILITY Extension from GitHub..." "STEP"
    Set-GuiProgress 10 "Connecting to GitHub..."
    try {
        (New-Object System.Net.WebClient).DownloadFile($url, $zipPath)
        $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Set-GuiProgress 50 "Downloaded ${sizeKB}KB"
        Write-GuiLog "Downloaded ${sizeKB}KB" "OK"
    } catch {
        Write-GuiLog "Download failed: $_" "ERR"
        Set-GuiProgress 0
        return
    }
    Write-GuiLog "Extracting to Downloads..." "STEP"
    try {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $zipPath -DestinationPath $dest -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 100 "Complete"
        Write-GuiLog "SETT UTILITY Extension ready at Downloads\sett-utility" "OK"
        Write-GuiLog "Open chrome://extensions, enable Developer Mode and load unpacked" "INFO"
    } catch {
        Write-GuiLog "Failed to extract extension: $_" "ERR"
        Set-GuiProgress 0
    }
}
#endregion

# ================================================
#region 2. POWER OPTIONS
# ================================================
# Used by: Performance ("Apply Power Plan")
function Invoke-PowerApply {
    Set-GuiProgress 10 "Looking for SETT power plan..."
    Extract-EmbeddedPrograms
    $powFile = Join-Path (Join-Path $Script:TempDir "Programs") "settPowerPlan.pow"
    if (Test-Path $powFile) {
        Set-GuiProgress 30 "Importing custom power plan..."
        $result = powercfg -import $powFile 2>&1
        $match = $result | Select-String -Pattern '([\w-]{36})'
        if ($match) {
            $guid = $match.Matches[0].Groups[1].Value
            powercfg -setactive $guid
            Write-GuiLog "SETT power plan activated ($guid)" "OK"
        } else { 
            $allOut = $result -join " "
            Write-GuiLog "Could not parse GUID from import. Output: $allOut" "WARN"
        }
    } else {
        Set-GuiProgress 30 "settPowerPlan.pow not found, using High Performance..."
        $guid = (powercfg -duplicatescheme "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" 2>&1 | Select-String '([\w-]{36})').Matches[0].Groups[1].Value
        powercfg -setactive $guid
        powercfg -change -monitor-timeout-ac 0
        powercfg -change -standby-timeout-ac 0
        powercfg -change -hibernate-timeout-ac 0
        Write-GuiLog "High Performance plan activated (fallback, $guid)" "OK"
    }
    Set-NavStatus "Power" $true
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 3. GAME MODE
# ================================================
# Used by: Performance ("Apply Game Mode")
function Invoke-GameModeApply {
    Set-GuiProgress 10 "Configuring Game Mode..."
    Write-GuiLog "Configuring Game Mode..." "STEP"
    $settings = @(
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AllowAutoGameMode"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AutoGameModeEnabled"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="ShowStartupPanel"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="GamePanelStartupTipIndex"; Value=3; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="UseNexusForGameBarEnabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKToggleGameBar"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKMToggleGameBar"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKToggleRecording"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKMToggleRecording"; Value=0; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"; Value=2; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_HonorUserFSEBehaviorMode"; Value=1; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_DXGIHonorFSEWindowsCompatible"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $settings -Label "Game Mode"
    Write-GuiLog "Game Mode configured" "OK"
    Set-NavStatus "GameMode" $true
    Set-GuiProgress 0
}

# Used by: Performance ("Apply Extra Optimizations")
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
#endregion



# ================================================
#region 4. MEMORY OPTIMIZATION
# ================================================
# Used by: Performance ("Apply Memory Optimizations")
function Invoke-MemoryApply {
    Set-GuiProgress 10 "Applying memory optimizations..."
    Write-GuiLog "Applying memory optimizations..." "STEP"
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
        Write-GuiLog "Memory compression disabled" "OK"
    } catch { Write-GuiLog "Memory compression was already disabled" "INFO" }
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
        Write-GuiLog "SvcHost configured for ${ramGB}GB RAM" "OK"
    } catch { }
    Write-GuiLog "Memory optimization completed" "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 5. DISABLE SERVICES
# ================================================
# Used by: SystemTweaksAll ("Disable Services")
function Invoke-ServicesApply {
    Set-GuiProgress 10 "Configuring services..."
    Write-GuiLog "Configuring services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TapiSrv";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2psvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Wecsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorDataService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensrSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\StiSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\icssvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DusmSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MapsBroker";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdate";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorService";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\shpamsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\svsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CscService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ssh-agent";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NfsClnt";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wisvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\defragsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\autotimesvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ALG";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\QWAVE";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RetailDemo";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lltdsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TrkWks";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Fax";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SCardSvr";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration";Name="Status";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Services"
    Write-GuiLog "$($svc.Count) services configured" "OK"
    Set-NavStatus "Services" $true
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 6. SYSTEM TWEAKS
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
            @{Path="HKCU:\Control";Name="MinAnimate";Type="String";Value=0}
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
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";Name="PriorityControl";Type="DWORD";Value=50}
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";Name="ThreadDpcEnable";Type="DWORD";Value=1}
            @{Path="HKCU:\Control";Name="AutoEndTasks";Type="String";Value=1}
            @{Path="HKCU:\Control";Name="HungAppTimeout";Type="String";Value=1000}
            @{Path="HKCU:\Control";Name="WaitToKillAppTimeout";Type="String";Value=2000}
            @{Path="HKCU:\Control";Name="MenuShowDelay";Type="String";Value=0}
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
#endregion

# ================================================
#region 7. GPU OPTIMIZATION
# ================================================
# Used by: Performance ("Detect & Optimize GPU")
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
            $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
            $amdReg = @(
                @{Path=$basePath;Name="DisableUVDPowerGatingDynamic";Type="DWORD";Value=1}
                @{Path=$basePath;Name="EnableUlps";Type="DWORD";Value=0}
                @{Path=$basePath;Name="DisableDMACopy";Type="DWORD";Value=1}
                @{Path=$basePath;Name="PP_GPUPowerDownEnabled";Type="DWORD";Value=0}
                @{Path=$basePath;Name="DisableBlockWrite";Type="DWORD";Value=0}
                @{Path=$basePath;Name="StutterMode";Type="DWORD";Value=0}
            )
            Invoke-RegistryApply -Settings $amdReg -Label "AMD Optimization"
            Write-GuiLog "AMD optimization completed" "OK"
        } else {
            Write-GuiLog "No NVIDIA or AMD GPU detected. Skipping GPU optimizations." "WARN"
        }
    } catch { Write-GuiLog "GPU detection failed: $_" "ERR" }
    Set-NavStatus "GPU" $true
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 8. INTEGRATIONS CLEANUP
# ================================================
# Used by: NetworkPrivacy ("Clean Integrations")
function Invoke-IntegrationsApply {
    Set-GuiProgress 10 "Cleaning integration keys..."
    Write-GuiLog "Cleaning integration keys..." "STEP"
    $Keys = @(
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
    )
    $removed = 0
    foreach ($k in $Keys) {
        if (Test-Path $k) { try { Remove-Item -Path $k -Recurse -Force -ErrorAction Stop; $removed++ } catch { } }
    }
    Write-GuiLog "Integration cleanup: $removed / $($Keys.Count) keys removed" "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 9. PRIVACY
# ================================================
# Used by: NetworkPrivacy ("Apply Privacy Settings")
function Invoke-PrivacyApply {
    Set-GuiProgress 10 "Applying privacy settings..."
    Write-GuiLog "Applying privacy settings..." "STEP"
    $priv = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo";Name="Enabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";Name="AllowCortana";Type="DWORD";Value=0}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo";Name="Enabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer";Name="HideRecentlyAddedApps";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent";Name="DisableThirdPartySuggestions";Type="DWORD";Value=1}
    )
    Invoke-RegistryApply -Settings $priv -Label "Privacy Protection"
    Write-GuiLog "Privacy settings applied" "OK"
    Set-NavStatus "Privacy" $true
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 10. WINDOWS 11 TWEAKS
# ================================================
# Used by: Windows ("Apply Old Menu")
function Invoke-W11OldMenu {
    Set-GuiProgress 50 "Applying old context menu..."
    try {
        $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $bp)) { New-Item -Path $bp -Force | Out-Null }
        Set-ItemProperty -Path $bp -Name "(default)" -Value "" -Force
        Write-GuiLog "Old context menu applied" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Old context menu failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Windows ("Revert to W11 Menu")
function Invoke-W11RevertMenu {
    Set-GuiProgress 50 "Reverting context menu..."
    try {
        $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
        if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
        Write-GuiLog "Context menu reverted to Windows 11 default" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Revert failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Windows ("Apply Classic Alt+Tab")
function Invoke-W11ClassicAltTab {
    Set-GuiProgress 50 "Applying Classic Alt+Tab..."
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "AltTabSettings" -PropertyType DWord -Value 1 -Force | Out-Null
        Write-GuiLog "Classic Alt+Tab applied" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Classic Alt+Tab failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Windows ("Revert to Modern Alt+Tab")
function Invoke-W11RevertAltTab {
    Set-GuiProgress 50 "Reverting Alt+Tab..."
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "AltTabSettings" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Alt+Tab reverted to modern style" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Revert Alt+Tab failed: $_" "ERR" }
    Set-GuiProgress 0
}
#endregion



# ================================================
#region 11. BROWSER TWEAKS
# ================================================
# Used by: Windows ("Optimize Brave")
function Invoke-BraveTweaks {
    Set-GuiProgress 10 "Optimizing Brave..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveRewardsDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveWalletDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveVPNDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveAIChatEnabled";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $reg -Label "Brave Tweaks"
    Write-GuiLog "Brave optimized" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Optimize Chrome")
function Invoke-ChromeTweaks {
    Set-GuiProgress 10 "Optimizing Chrome..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\Google\Chrome";Name="SearchSuggestEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Google\Chrome";Name="PromotionalTabsEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Google\Chrome";Name="MetricsReportingEnabled";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $reg -Label "Chrome Tweaks"
    Write-GuiLog "Chrome optimized" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Optimize Edge")
function Invoke-EdgeTweaks {
    Set-GuiProgress 10 "Optimizing Edge..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="SyncDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="WalletEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="HubsSidebarEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="WebWidgetEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="HideFirstRunExperience";Type="DWORD";Value=1}
    )
    Invoke-RegistryApply -Settings $reg -Label "Edge Tweaks"
    Write-GuiLog "Edge optimized" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Optimize Firefox")
function Invoke-FirefoxTweaks {
    Set-GuiProgress 10 "Optimizing Firefox..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="DisableTelemetry";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="DisablePocket";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="DisableFirefoxStudies";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="SearchSuggestEnabled";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $reg -Label "Firefox Tweaks"
    Write-GuiLog "Firefox optimized" "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 12. CONTEXT MENU TWEAKS
# ================================================
# Used by: Windows ("Apply Tweaks" in Context Menu Tweaks card)
function Invoke-ContextApply {
    Set-GuiProgress 10 "Applying context menu tweaks..."
    Write-GuiLog "Applying context menu tweaks..." "STEP"
    $reg = @(
        @{Path="HKCU:\Software\Classes\*\shell\runas";Name="HasLUAShield";Type="String";Value=""}
        @{Path="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32";Name="(default)";Type="String";Value=""}
    )
    Invoke-RegistryApply -Settings $reg -Label "Context Menu"
    Write-GuiLog "Context menu tweaks applied" "OK"
    Set-GuiProgress 80 "Restarting Explorer..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-GuiLog "Explorer restarted - changes active" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Revert Tweaks" in Context Menu Tweaks card)
function Invoke-ContextRevert {
    Set-GuiProgress 50 "Reverting context menu..."
    Write-GuiLog "Reverting context menu..." "STEP"
    $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
    Write-GuiLog "Context menu reverted" "OK"
    Set-GuiProgress 80 "Restarting Explorer..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-GuiLog "Explorer restarted - changes active" "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 13. CACHE CLEANER (merged from CacheCleaner.ps1)
# ================================================
function Remove-DirContent { param([string]$Path, [string]$Desc)
    if (-not (Test-Path $Path)) { Write-GuiLog "$Desc not found" "WARN"; return }
    Write-GuiLog "Cleaning: $Desc" "STEP"
    try { Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "$Desc cleaned" "OK" }
    catch { Write-GuiLog "Error cleaning $Desc" "ERR" }
}

# Used by: Home (Cache Cleaner > "Temp Files")
function Invoke-CleanTempFiles {
    Set-GuiProgress 20 "Cleaning temporary files..."
    Write-GuiLog "Cleaning temporary files..." "STEP"
    Remove-DirContent -Path $env:TEMP -Desc "User TEMP"
    Set-GuiProgress 60 "Cleaning Windows TEMP..."
    Remove-DirContent -Path (Join-Path $env:windir "Temp") -Desc "Windows TEMP"
    Write-GuiLog "Temporary files cleaned" "OK"
    Set-GuiProgress 0
}

# Used by: Home (Cache Cleaner > "Browser Cache")
function Invoke-CleanBrowserCache {
    Set-GuiProgress 10 "Cleaning browser caches..."
    Write-GuiLog "Cleaning browser caches..." "STEP"
    $browsers = @{
        "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        "Brave" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
        "Opera GX" = "$env:APPDATA\Opera Software\Opera GX Stable\Cache"
    }
    foreach ($b in $browsers.Keys) { Remove-DirContent -Path $browsers[$b] -Desc "$b Cache" }
    $ffPath = Join-Path $env:ProgramFiles "Mozilla Firefox\firefox.exe"
    if (Test-Path $ffPath) {
        try { Start-Process -FilePath $ffPath -ArgumentList '-P "default" -no-remote -safe-mode -clearcache' -Wait -WindowStyle Hidden; Write-GuiLog "Firefox cache cleaned" "OK" } catch { }
    }
    Write-GuiLog "Browser caches cleaned" "OK"
    Set-GuiProgress 0
}

# Used by: Home (Cache Cleaner > "Update Cache")
function Invoke-CleanUpdateCache {
    Set-GuiProgress 30 "Cleaning Windows Update cache..."
    Write-GuiLog "Cleaning Windows Update cache..." "STEP"
    try {
        Stop-Service -Name wuauserv, UsoSvc -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 60 "Removing update cache files..."
        Remove-DirContent -Path (Join-Path $env:windir "SoftwareDistribution\Download") -Desc "Update Cache"
        Start-Service -Name wuauserv, UsoSvc -ErrorAction SilentlyContinue
    } catch { Write-GuiLog "Update cache error: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Home (Cache Cleaner > "Prefetch")
function Invoke-CleanPrefetch { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:windir "Prefetch") -Desc "Prefetch Files"; Write-GuiLog "Prefetch cleaned" "OK"; Set-GuiProgress 0 }
# Used by: Home (Cache Cleaner > "Store Cache")
function Invoke-CleanStoreCache { Set-GuiProgress 50; Start-Process "wsreset.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue; Write-GuiLog "Store cache reset initiated" "OK"; Set-GuiProgress 0 }
# Used by: Home (Cache Cleaner > "Logs")
function Invoke-CleanLogFiles {
    Set-GuiProgress 30 "Cleaning log files..."
    Write-GuiLog "Cleaning log files..." "STEP"
    Remove-DirContent -Path (Join-Path $env:windir "Logs") -Desc "Windows Logs"
    Write-GuiLog "Log files cleaned" "OK"
    Set-GuiProgress 0
}
# Used by: Home (Cache Cleaner > "Minidumps")
function Invoke-CleanMemoryDumps { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:windir "Minidump") -Desc "Memory Dumps"; Write-GuiLog "Memory dumps cleaned" "OK"; Set-GuiProgress 0 }
# Used by: Home (Cache Cleaner > "Delivery Opt")
function Invoke-CleanDeliveryOpt {
    Set-GuiProgress 30 "Cleaning Delivery Optimization..."
    Write-GuiLog "Cleaning Delivery Optimization..." "STEP"
    try {
        Stop-Service -Name dosvc -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 60 "Removing delivery optimization files..."
        Remove-DirContent -Path (Join-Path $env:windir "SoftwareDistribution\DeliveryOptimization") -Desc "Delivery Optimization"
        Start-Service -Name dosvc -ErrorAction SilentlyContinue
    } catch { Write-GuiLog "Delivery opt error: $_" "ERR" }
    Set-GuiProgress 0
}
# Used by: Home (Cache Cleaner > "DX Shaders")
function Invoke-CleanShaderCache { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:LOCALAPPDATA "D3DSCache") -Desc "Shader Cache"; Write-GuiLog "Shader cache cleaned" "OK"; Set-GuiProgress 0 }

# Used by: Home (Cache Cleaner > "Full Cleanup"); also called internally by Playbooks ("Deep Clean" at line ~3048)
function Invoke-CleanAll {
    Set-GuiProgress 10 "Running ADVANCED SYSTEM CLEANUP..."
    Write-GuiLog "Running ADVANCED SYSTEM CLEANUP..." "STEP"
    $windir = $env:windir
    $paths = @(
        (Join-Path $windir "Prefetch"), (Join-Path $windir "Spool\Printers"),
        (Join-Path $windir "History"), (Join-Path $windir "Cookies"), (Join-Path $windir "Tmp")
    )
    $i = 0; $total = $paths.Count + 3
    foreach ($item in $paths) {
        $i++; Set-GuiProgress ([math]::Round($i/$total*80)) "Cleaning: $item"
        if (Test-Path $item) { Remove-Item -Path "$item\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "Cleaned: $item" "OK" }
    }
    $i++; Set-GuiProgress ([math]::Round($i/$total*80)) "Cleaning TEMP..."
    Remove-DirContent -Path $env:TEMP -Desc "User TEMP"
    $i++; Set-GuiProgress ([math]::Round($i/$total*80)) "Cleaning Windows TEMP..."
    Remove-DirContent -Path (Join-Path $env:windir "Temp") -Desc "Windows TEMP"
    $i++; Set-GuiProgress 85 "Cleaning event logs..."
    try {
        $logs = wevtutil el 2>$null
        if ($logs) { foreach ($log in $logs) { wevtutil cl "$log" 2>$null }; Write-GuiLog "Event logs cleaned" "OK" }
    } catch { }
    Write-GuiLog "Advanced cleanup completed!" "OK"
    Set-GuiProgress 0
}

# Used by: Home (Network Tools > "Device Cleanup")
function Invoke-CleanDeviceCleanup {
    Set-GuiProgress 50 "Launching DeviceCleanup..."
    $dc = Join-Path $Script:TempDir "Programs\DeviceCleanup.exe"
    if (-not (Test-Path $dc)) { Extract-EmbeddedPrograms }
    if (Test-Path $dc) { Start-Process $dc; Write-GuiLog "DeviceCleanup launched" "OK" }
    else { Write-GuiLog "DeviceCleanup.exe not found" "ERR" }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 14. NETWORK OPTIMIZER (merged from OptimizerEthernetWifi.ps1)
# ================================================
$Script:EthernetConfigs = @(
    @{Names=@("Flow Control","Controlo de Fluxo"); Value="Disabled"}
    @{Names=@("Jumbo Packet","Jumbo Frame"); Value="Disabled"}
    @{Names=@("Energy Efficient Ethernet","Energy-Efficient Ethernet","EEE","Energia Eficiente Ethernet"); Value="Disabled"}
    @{Names=@("Advanced EEE"); Value="Disabled"}
    @{Names=@("Power Saving Mode"); Value="Disabled"}
    @{Names=@("Auto Disable Gigabit"); Value="Disabled"}
    @{Names=@("Wake on Magic Packet","Pacote Wake on Magic"); Value="Disabled"}
    @{Names=@("Wake on pattern match","Wake on Pattern Match","CombinaÃ§Ã£o do padrÃ£o Wake on"); Value="Disabled"}
    @{Names=@("Shutdown Wake-On-Lan","Shutdown Wake-On-LAN","Desligar Despertar Aquando de Lan"); Value="Disabled"}
    @{Names=@("NS Offload","TransferÃªncia NS"); Value="Disabled"}
    @{Names=@("ARP Offload","TransferÃªncia ARP"); Value="Disabled"}
    @{Names=@("Receive Buffers","Receber MemÃ³rias IntermÃ©dias"); Value="Maximum"}
    @{Names=@("Transmit Buffers","Transmitir MemÃ³rias IntermÃ©dias"); Value="Maximum"}
    @{Names=@("Large Send Offload V2 (IPv4)","Large Send Offload v2 (IPv4)","Descarga Large Send v2 (IPv4)"); Value="Disabled"}
    @{Names=@("Large Send Offload V2 (IPv6)","Large Send Offload v2 (IPv6)","Descarga Large Send v2 (IPv6)"); Value="Disabled"}
    @{Names=@("IPv4 Checksum Offload","IPv4 Descarga de Checksum"); Value="Disabled"}
    @{Names=@("TCP Checksum Offload (IPv4)","TCP Descarga de Checksum (IPv4)"); Value="Disabled"}
    @{Names=@("TCP Checksum Offload (IPv6)","TCP Descarga de Checksum (IPv6)"); Value="Disabled"}
    @{Names=@("UDP Checksum Offload (IPv4)","UDP Descarga de Checksum (IPv4)"); Value="Disabled"}
    @{Names=@("UDP Checksum Offload (IPv6)","UDP Descarga de Checksum (IPv6)"); Value="Disabled"}
    @{Names=@("Interrupt Moderation","ModeraÃ§Ã£o de InterrupÃ§Ã£o"); Value="Disabled"}
    @{Names=@("Receive Side Scaling"); Value="Enabled"}
    @{Names=@("Speed & Duplex","Speed and Duplex","Velocidade & Duplex"); Value="Auto Negotiation"}
    @{Names=@("Green Ethernet","Ethernet Verde"); Value="Disabled"}
    @{Names=@("Priority & VLAN","Priority and VLAN","Prioridade & VLAN"); Value="Disabled"}
)

$Script:WiFiConfigs = @(
    @{Names=@("Beamforming"); Value="Disabled"}
    @{Names=@("MIMO Power Save Mode"); Value="No SMPS"}
    @{Names=@("Minimum Power Consumption"); Value="Disabled"}
    @{Names=@("Packet Coalescing"); Value="Disabled"}
    @{Names=@("Power Output","Transmit Power"); Value="Highest"}
    @{Names=@("Preferred Band"); Value="Prefer 5GHz band"}
    @{Names=@("Roaming Aggressiveness","Roaming Decision"); Value="Medium"}
    @{Names=@("Throughput Booster"); Value="Enabled"}
    @{Names=@("U-APSD support","WMM Power Save Mode","U-APSD"); Value="Disabled"}
    @{Names=@("Wireless Mode"); Value="Auto"}
    @{Names=@("WMM","WME"); Value="Enabled"}
    @{Names=@("Xpress Technology"); Value="Disabled"}
)

function Get-NetAdapters { param([string]$Type)
    try {
        $all = Get-NetAdapter -ErrorAction Stop | Where-Object {
            $_.InterfaceDescription -notlike "*Loopback*" -and $_.InterfaceDescription -notlike "*Virtual*" -and
            $_.InterfaceDescription -notlike "*Hyper-V*" -and $_.InterfaceDescription -notlike "*VPN*" -and
            $_.InterfaceDescription -notlike "*Bluetooth*" -and $_.Name -notlike "*vEthernet*"
        }
        if ($Type -eq "Ethernet") {
            @($all | Where-Object { $_.InterfaceDescription -notlike "*Wireless*" -and $_.InterfaceDescription -notlike "*Wi-Fi*" -and $_.InterfaceDescription -notlike "*802.11*" -and $_.Name -notlike "*Wi-Fi*" })
        } else {
            @($all | Where-Object { $_.InterfaceDescription -like "*Wireless*" -or $_.InterfaceDescription -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*802.11*" -or $_.Name -like "*Wi-Fi*" })
        }
    } catch { Write-GuiLog "Error detecting adapters: $_" "ERR"; return @() }
}

# Used by: Home (Network > "Optimize Ethernet" / "Optimize Wi-Fi"); also called internally by Playbooks (line ~3052)
function Invoke-NetworkOptimize { param([string]$Type)
    Set-GuiProgress 10 "Optimizing $Type adapters..."
    Write-GuiLog "Optimizing $Type adapters..." "STEP"
    $adapters = @(Get-NetAdapters -Type $Type)
    if ($adapters.Count -eq 0) { Write-GuiLog "No $Type adapters found!" "WARN"; return }
    $configs = if ($Type -eq "Ethernet") { $Script:EthernetConfigs } else { $Script:WiFiConfigs }
    $totalAdapters = $adapters.Count
    $adapterIdx = 0
    foreach ($adapter in $adapters) {
        $adapterIdx++
        Write-GuiLog "Optimizing: $($adapter.Name) ($($adapter.InterfaceDescription))" "STEP"
        try {
            $propCache = @{}
            Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction Stop | ForEach-Object { $propCache[$_.DisplayName] = $_ }
            $applied = 0; $skipped = 0; $failed = 0
            foreach ($config in $configs) {
                $found = $false
                foreach ($n in $config.Names) { if ($propCache.ContainsKey($n)) { $prop = $propCache[$n]; $found = $true; break } }
                if (-not $found) { $skipped++; continue }
                $effVal = $config.Value
                if ($effVal -eq "Maximum") {
                    $maxVal = $null
                    if ($prop.ValidDisplayValues) { $nums = @($prop.ValidDisplayValues | ForEach-Object { $x=0;if([int]::TryParse($_,[ref]$x)){$x} } | Where-Object { $_ -gt 0 } | Sort-Object -Descending); if ($nums.Count -gt 0) { $maxVal = $nums[0] } }
                    if (-not $maxVal) { $maxVal = $prop.DisplayValue }
                    $effVal = [string]$maxVal
                }
                $locVal = $effVal
                $cand = @($effVal)
                switch ($effVal) {
                    "Enabled" { $cand += @("Activado","Ativado","Enable","Rx & Tx Enabled","Rx & Tx Activados") }
                    "Disabled" { $cand += @("Desactivado","Desativado","Disable") }
                    "Auto" { $cand += @("AutomÃ¡tico") }
                    "Auto Negotiation" { $cand += @("Auto NegociaÃ§Ã£o") }
                }
                foreach ($c in $cand) { if ($prop.ValidDisplayValues -contains $c) { $locVal = $c; break } }
                if ($prop.DisplayValue -eq $locVal) { $skipped++; continue }
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $locVal -ErrorAction Stop -WarningAction SilentlyContinue
                    $applied++
                } catch {
                    $regCand = switch ($effVal) {
                        "Enabled" { @(@("1"),@("3")) }
                        "Disabled" { @(@("0")) }
                        "Auto" { @(@("0")) }
                        "Auto Negotiation" { @(@("0")) }
                        default { @(@($effVal)) }
                    }
                    $appliedReg = $false
                    foreach ($tryReg in $regCand) {
                        try { Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $prop.RegistryKeyword -RegistryValue $tryReg -ErrorAction Stop -WarningAction SilentlyContinue; $applied++; $appliedReg = $true; break } catch { }
                    }
                    if (-not $appliedReg) { $failed++ }
                }
            }
            Write-GuiLog "  $($adapter.Name): $applied changed, $skipped already optimal, $failed failed" "OK"
        } catch { Write-GuiLog "  Error processing $($adapter.Name): $_" "ERR" }
    }
    Write-GuiLog "$Type optimization completed! ($totalAdapters adapter(s))" "OK"
    Set-GuiProgress 0
}

# Used by: Home (Network > "Revert Ethernet" / "Revert Wi-Fi")
function Invoke-NetworkRestoreDefaults { param([string]$Type)
    Set-GuiProgress 10 "Restoring $Type defaults..."
    Write-GuiLog "Restoring $Type defaults..." "STEP"
    $adapters = @(Get-NetAdapters -Type $Type)
    if ($adapters.Count -eq 0) { Write-GuiLog "No $Type adapters found!" "WARN"; return }
    foreach ($adapter in $adapters) {
        Write-GuiLog "Restoring: $($adapter.Name)" "STEP"
        $changed = 0
        try {
            $props = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction Stop
            foreach ($prop in $props) {
                $defDisp = $null
                if ($prop.DefaultDisplayValue) { $defDisp = $prop.DefaultDisplayValue }
                else {
                    $guesses = @("Auto","Auto Negotiation","Default","Enabled","Activado","Desactivado","AutomÃ¡tico","Auto NegociaÃ§Ã£o")
                    foreach ($g in $guesses) { if ($prop.ValidDisplayValues -contains $g) { $defDisp = $g; break } }
                }
                if ($defDisp -and $prop.DisplayValue -ne $defDisp) {
                    try { Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.DisplayName -DisplayValue $defDisp -ErrorAction Stop -WarningAction SilentlyContinue; $changed++ } catch { }
                }
            }
        } catch { }
        Write-GuiLog "  $($adapter.Name): $changed properties restored" "OK"
    }
    Write-GuiLog "$Type defaults restored" "OK"
    Set-GuiProgress 0
}

# Used by: Home (Network Tools > "DNS Jumper")
function Invoke-DNSTool {
    Set-GuiProgress 50 "Launching DnsJumper..."
    $dnsJump = Join-Path $Script:TempDir "Programs\DnsJumper.exe"
    if (-not (Test-Path $dnsJump)) { Extract-EmbeddedPrograms }
    if (Test-Path $dnsJump) { Start-Process $dnsJump; Write-GuiLog "DnsJumper launched" "OK" }
    else { Write-GuiLog "DnsJumper.exe not found" "ERR" }
    Set-GuiProgress 0
}

# Used by: Home (Network Tools > "Filter Keys")
function Invoke-FilterKeysTool {
    Set-GuiProgress 50 "Launching FilterKeysSetter..."
    $fks = Join-Path $Script:TempDir "Programs\FilterKeysSetter.exe"
    if (-not (Test-Path $fks)) { Extract-EmbeddedPrograms }
    if (Test-Path $fks) { Start-Process $fks; Write-GuiLog "FilterKeysSetter launched" "OK" }
    else { Write-GuiLog "FilterKeysSetter.exe not found" "ERR" }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 1. RESTORE POINT
# ================================================
# Used by: Home ("Create Restore Point" button); also called internally by Playbooks (line ~3003)
function Invoke-RestorePoint {
    Set-GuiProgress 10 "Creating system restore point..."
    Write-GuiLog "Creating system restore point..." "STEP"
    $result = $false
    try {
        $enabled = $false
        try { $sr = Get-ComputerRestorePoint -ErrorAction SilentlyContinue; if ($sr -and $sr.Count -gt 0) { $enabled = $true } } catch { }
        if (-not $enabled) {
            Set-GuiProgress 30 "Enabling system restore..."
            Write-GuiLog "Enabling system restore via registry..." "WARN"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "DisableSR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" -Name "DisableConfig" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" -Name "DisableSR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            try { Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue | Out-Null } catch { }
        }
        Set-GuiProgress 60 "Creating checkpoint..."
        Checkpoint-Computer -Description "SETT Optimizer Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-GuiLog "Restore point created successfully" "OK"
        $result = $true
    } catch {
        Write-GuiLog "Failed to create restore point: $_" "ERR"
    }
    Set-GuiProgress 0
    return $result
}
#endregion

# ================================================
#region 2. GET SYSTEM INFO
# ================================================
# Used by: Home (specs panel), Show-SystemInfoPopup, and startup wiring (line ~4260)
function Get-SystemInfo {
    param([switch]$Force)
    if (-not $Force -and $Script:CachedSystemInfo) {
        return $Script:CachedSystemInfo
    }
    Write-GuiLog "Gathering system information..." "STEP"
    $info = @{}
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $info.CPUName = $cpu.Name.Trim()
        $info.CPUPhysicalCores = $cpu.NumberOfCores
        $info.CPULogicalCores = $cpu.NumberOfLogicalProcessors
        Write-GuiLog "CPU: $($info.CPUName)" "INFO"
    } catch { $info.CPUName = "Unknown"; Write-GuiLog "CPU detection failed" "WARN" }
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $info.RAMTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $info.RAMFreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $info.OSCaption = $os.Caption
        $info.OSBuild = $os.BuildNumber
        Write-GuiLog "RAM: $($info.RAMTotalGB) GB total | $($info.RAMFreeGB) GB free" "INFO"
        Write-GuiLog "OS: $($info.OSCaption) (Build $($info.OSBuild))" "INFO"
    } catch { Write-GuiLog "RAM/OS detection failed" "WARN" }
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        if ($disk -and $disk.Size) {
            $info.DiskTotalGB = [math]::Round($disk.Size / 1GB, 1)
            $info.DiskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
            Write-GuiLog "HD: $($info.DiskTotalGB) GB total | $($info.DiskFreeGB) GB free" "INFO"
        }
    } catch { Write-GuiLog "HD detection failed" "WARN" }
    try {
        # Exclude virtual/remote/basic display adapters (e.g. "Windows Video", "Microsoft Basic Display Adapter", RDP virtual displays)
        $allGpus = @(Get-CimInstance Win32_VideoController)
        $gpus = @($allGpus | Where-Object {
            $_.Name -and
            $_.Name -notmatch "Microsoft Basic|Remote Display|Virtual|Meta Virtual Monitor|Citrix|VMware|Windows Video"
        })
        # Fallback: if filtering removed everything, use the unfiltered list
        if (-not $gpus -or $gpus.Count -eq 0) { $gpus = $allGpus }

        if ($gpus -and $gpus.Count -gt 0) {
            $gpuEntries = @()
            $vendors = @()
            foreach ($g in $gpus) {
                $name = $g.Name.Trim()
                $nameLow = $name.ToLower()
                if ($nameLow -match "nvidia") { $vendor = "NVIDIA" }
                elseif ($nameLow -match "amd|radeon") { $vendor = "AMD" }
                elseif ($nameLow -match "intel") { $vendor = "Intel" }
                else { $vendor = "Unknown" }
                $vendors += $vendor
                $vramGB = if ($g.AdapterRAM) { [math]::Round($g.AdapterRAM / 1GB, 1) } else { 0 }
                $gpuEntries += [PSCustomObject]@{ Vendor = $vendor; Name = $name; VRAM = $vramGB }
                Write-GuiLog "GPU detected: $vendor - $name ($vramGB GB VRAM)" "INFO"
            }
            $info.GPUs = $gpuEntries
            $info.GPUVendor = ($vendors | Select-Object -Unique) -join " / "
            $info.GPUName = ($gpuEntries | ForEach-Object { $_.Name }) -join ", "
            $info.GPUVRAM = ($gpuEntries | Measure-Object -Property VRAM -Maximum).Maximum
        } else {
            $info.GPUs = @()
            $info.GPUVendor = "Unknown"
            $info.GPUName = "Unknown"
            $info.GPUVRAM = 0
            Write-GuiLog "No GPU detected" "WARN"
        }
    } catch {
        $info.GPUs = @()
        $info.GPUVendor = "Unknown"
        $info.GPUName = "Unknown"
        $info.GPUVRAM = 0
        Write-GuiLog "GPU detection failed" "WARN"
    }
    $Script:CachedSystemInfo = $info
    return $info
}
#endregion

# ================================================
#region 3. INTERNET REVERT
# ================================================
# Used by: NetworkPrivacy ("Revert Internet")
function Invoke-InternetRevert {
    Write-GuiLog "Reverting internet optimizations..." "STEP"
    Set-GuiProgress 10 "Restoring TCP autotuning..."
    try {
        netsh int tcp set global autotuning=normal | Out-Null
        Write-GuiLog "TCP autotuning restored to normal" "OK"
    } catch { Write-GuiLog "Failed to restore TCP autotuning: $_" "ERR" }
    Set-GuiProgress 40 "Removing FastSendDatagramThreshold..."
    try {
        $afdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        Remove-ItemProperty -Path $afdPath -Name "FastSendDatagramThreshold" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "FastSendDatagramThreshold removed" "OK"
    } catch { Write-GuiLog "Failed to remove FastSendDatagramThreshold: $_" "ERR" }
    Set-GuiProgress 70 "Removing QoS policies..."
    try {
        $qosValorant = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"
        if (Test-Path $qosValorant) { Remove-Item -Path $qosValorant -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "Valorant QoS policy removed" "OK" }
        else { Write-GuiLog "Valorant QoS policy not found" "INFO" }
    } catch { Write-GuiLog "Failed to remove Valorant QoS: $_" "ERR" }
    try {
        $qosCSGO = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"
        if (Test-Path $qosCSGO) { Remove-Item -Path $qosCSGO -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "CSGO QoS policy removed" "OK" }
        else { Write-GuiLog "CSGO QoS policy not found" "INFO" }
    } catch { Write-GuiLog "Failed to remove CSGO QoS: $_" "ERR" }
    Set-GuiProgress 0
    Write-GuiLog "Internet optimizations reverted" "OK"
}
#endregion

# ================================================
#region 4. POWER REVERT
# ================================================
# Used by: Performance ("Revert Power")
function Invoke-PowerRevert {
    Write-GuiLog "Restoring Balanced power plan..." "STEP"
    Set-GuiProgress 30 "Activating Balanced scheme..."
    try {
        $output = powercfg /l 2>&1
        $balancedGuid = $null
        $match = $output | Select-String -Pattern '381b4222-f694-41f0-9685-ff5bb260df2e'
        if ($match) {
            $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        } else {
            $lines = $output | Select-String -Pattern 'Balanced|Equilibrado'
            if ($lines) {
                $guidMatch = [regex]::Match($lines[0].Line, '([\w-]{36})')
                if ($guidMatch.Success) { $balancedGuid = $guidMatch.Groups[1].Value }
            }
        }
        if ($balancedGuid) {
            powercfg /setactive $balancedGuid
            Write-GuiLog "Balanced power plan activated ($balancedGuid)" "OK"
        } else {
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
            Write-GuiLog "Balanced power plan activated (hardcoded GUID)" "OK"
        }
    } catch { Write-GuiLog "Failed to restore power plan: $_" "ERR" }
    Set-NavStatus "Power" $false
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 5. GAME MODE REVERT
# ================================================
# Used by: Performance ("Revert Game Mode")
function Invoke-GameModeRevert {
    Set-GuiProgress 10 "Reverting Game Mode settings to defaults..."
    Write-GuiLog "Reverting Game Mode settings to defaults..." "STEP"
    $settings = @(
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AllowAutoGameMode"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AutoGameModeEnabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="ShowStartupPanel"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="UseNexusForGameBarEnabled"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $settings -Label "Game Mode Revert"
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKToggleGameBar" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKMToggleGameBar" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKToggleRecording" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKMToggleRecording" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Game Bar hotkey overrides removed" "OK"
    } catch { }
    try {
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "GameDVR overrides removed" "OK"
    } catch { }
    Write-GuiLog "Game Mode reverted to defaults" "OK"
    Set-NavStatus "GameMode" $false
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 6. GAME EXTRA REVERT
# ================================================
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

# ================================================
#region 7. MEMORY REVERT
# ================================================
# Used by: Performance ("Revert Memory")
function Invoke-MemoryRevert {
    Set-GuiProgress 10 "Reverting memory optimizations..."
    Write-GuiLog "Reverting memory optimizations..." "STEP"
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
        Write-GuiLog "Memory management keys reverted" "OK"
    } catch { }
    try {
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-GuiLog "Memory compression re-enabled" "OK"
    } catch { Write-GuiLog "Memory compression was already enabled" "INFO" }
    try {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "SvcHostSplitThresholdInKB reset" "OK"
    } catch { Write-GuiLog "SvcHostSplitThresholdInKB was not set" "INFO" }
    Write-GuiLog "Memory optimizations reverted" "OK"
    Set-NavStatus "Memory" $false
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 8. SERVICES REVERT
# ================================================
# Used by: SystemTweaksAll ("Revert Services")
function Invoke-ServicesRevert {
    Set-GuiProgress 10 "Re-enabling services to defaults..."
    Write-GuiLog "Re-enabling services to defaults..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TapiSrv"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2psvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Wecsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorDataService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensrSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\StiSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\icssvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DusmSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MapsBroker"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdate"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\shpamsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\svsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CscService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ssh-agent"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NfsClnt"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wisvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\defragsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\autotimesvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ALG"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\QWAVE"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RetailDemo"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lltdsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TrkWks"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Fax"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SCardSvr"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name="Status"; Type="DWORD"; Value=1}
    )
    Invoke-RegistryApply -Settings $svc -Label "Re-enabling Services"
    Write-GuiLog "$($svc.Count) services restored to Automatic" "OK"
    Set-NavStatus "Services" $false
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 9. TWEAKS REVERT
# ================================================
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
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "ConnectedSearchPrivacy" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "AllowCloudSearch" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "DisableWebSearch" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows" -Name "EnablingFeeds" -Force -ErrorAction SilentlyContinue
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
        Set-ItemProperty -Path "HKCU:\Control" -Name "MinAnimate" -Value 1 -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnablingTransparency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Visual effects and animations restored" "OK"
    } catch { }
    Set-GuiProgress 85 "Restoring kernel defaults..."
    try {
        Set-ItemProperty -Path "HKCU:\Control" -Name "AutoEndTasks" -Value 0 -Type String -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Control" -Name "HungAppTimeout" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Control" -Name "WaitToKillAppTimeout" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Control" -Name "MenuShowDelay" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Kernel/performance defaults restored" "OK"
    } catch { }
    Set-NavStatus "Tweaks" $false
    Set-GuiProgress 0
    Write-GuiLog "System tweaks reverted to defaults" "OK"
}
#endregion

# ================================================
#region 10. GPU REVERT
# ================================================
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
            $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
            $amdRevert = @(
                @{Path=$basePath; Name="EnableUlps"; Value=1; Type="DWORD"}
                @{Path=$basePath; Name="StutterMode"; Value=1; Type="DWORD"}
                @{Path=$basePath; Name="PP_GPUPowerDownEnabled"; Value=1; Type="DWORD"}
            )
            Invoke-RegistryApply -Settings $amdRevert -Label "AMD Revert"
            try {
                Remove-ItemProperty -Path $basePath -Name "DisableUVDPowerGatingDynamic" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $basePath -Name "DisableDMACopy" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $basePath -Name "DisableBlockWrite" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $basePath -Name "DisableVCEPowerGating" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $basePath -Name "DisableDrmdmaPowerGating" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $basePath -Name "DisablePowerGating" -Force -ErrorAction SilentlyContinue
                Write-GuiLog "AMD optimizations reverted" "OK"
            } catch { }
        } else {
            Write-GuiLog "No NVIDIA or AMD GPU detected. Nothing to revert." "WARN"
        }
    } catch { Write-GuiLog "GPU revert failed: $_" "ERR" }
    Set-NavStatus "GPU" $false
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 11. PRIVACY REVERT
# ================================================
# Used by: NetworkPrivacy ("Revert Privacy")
function Invoke-PrivacyRevert {
    Set-GuiProgress 10 "Reverting privacy settings..."
    Write-GuiLog "Reverting privacy settings..." "STEP"
    $revert = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name="Enabled"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name="Enabled"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name="AllowCortana"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $revert -Label "Privacy Revert"
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecentlyAddedApps" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Cortana and advertising re-enabled" "OK"
    } catch { }
    Write-GuiLog "Privacy settings reverted" "OK"
    Set-NavStatus "Privacy" $false
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 12. PLAYBOOK - AME WIZARD
# ================================================
# Used by: Playbooks ("Download AME Wizard")
function Invoke-PlaybookAME {
    Set-GuiProgress 20 "Fetching latest AME Wizard release..."
    Write-GuiLog "Fetching latest AME Wizard release..." "STEP"
    Write-GuiLog "Querying GitHub API: Ameliorated-io/ame-wizard-releases" "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/Ameliorated-io/ame-wizard-releases/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.zip") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog "Found: $($asset.name) ($size MB) - Tag: $($release.tag_name)" "OK"
                break
            }
        }
    } catch { Write-GuiLog "GitHub API lookup failed: $_" "WARN" }
    if (-not $url) {
        Write-GuiLog "Using fallback direct download URL" "WARN"
        $url = "https://download.ameliorated.io/AME%20Wizard%20Beta.zip"
    }
    Set-GuiProgress 80 "Opening browser..."
    Write-GuiLog "Opening AME Wizard download in browser: $url" "OK"
    try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    Write-GuiLog "AME Wizard download initiated" "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 13. PLAYBOOK - ReviOS
# ================================================
# Used by: Playbooks ("Download ReviOS")
function Invoke-PlaybookReviOS {
    Set-GuiProgress 20 "Fetching latest ReviOS playbook..."
    Write-GuiLog "Fetching latest ReviOS playbook..." "STEP"
    Write-GuiLog "Querying GitHub API: meetrevision/playbook" "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/meetrevision/playbook/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.apbx") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog "Found: $($asset.name) ($size MB) - Tag: $($release.tag_name)" "OK"
                break
            }
        }
    } catch { Write-GuiLog "GitHub API lookup failed: $_" "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog "Opening ReviOS playbook in browser..." "STEP"
        try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    } else {
        Write-GuiLog "No .apbx asset found in latest ReviOS release" "ERR"
    }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 14. PLAYBOOK - AtlasOS
# ================================================
# Used by: Playbooks ("Download AtlasOS")
function Invoke-PlaybookAtlasOS {
    Set-GuiProgress 20 "Fetching latest AtlasOS playbook..."
    Write-GuiLog "Fetching latest AtlasOS playbook..." "STEP"
    Write-GuiLog "Querying GitHub API: Atlas-OS/Atlas" "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/Atlas-OS/Atlas/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.apbx") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog "Found: $($asset.name) ($size MB) - Tag: $($release.tag_name)" "OK"
                break
            }
        }
    } catch { Write-GuiLog "GitHub API lookup failed: $_" "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog "Opening AtlasOS playbook in browser..." "STEP"
        try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    } else {
        Write-GuiLog "No .apbx asset found in latest AtlasOS release" "ERR"
    }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 15. PLAYBOOK - FSOS-X
# ================================================
# Used by: Playbooks ("Download FSOS-X")
function Invoke-PlaybookFSOSX {
    Set-GuiProgress 20 "Scraping FSOS-X for latest playbook..."
    Write-GuiLog "Scraping FSOS-X for latest playbook..." "STEP"
    $siteUrl = "https://fsosx.com/"
    $url = $null
    try {
        $web = Invoke-WebRequest -Uri $siteUrl -TimeoutSec 15 -UseBasicParsing
        $matches = [regex]::Matches($web.Content, 'https?://[^"''\s<>]+\.apbx')
        if ($matches -and $matches.Count -gt 0) {
            $url = $matches[0].Value
            Write-GuiLog "Found: $url" "OK"
        } else {
            $altMatch = [regex]::Match($web.Content, 'href="([^"]*\.apbx)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($altMatch.Success) {
                $relativePath = $altMatch.Groups[1].Value
                if ($relativePath -match '^https?://') { $url = $relativePath }
                else { $uri = [System.Uri]::new($siteUrl); $url = "$($uri.Scheme)://$($uri.Host)/$relativePath" }
                Write-GuiLog "Found: $url" "OK"
            }
        }
    } catch { Write-GuiLog "Failed to scrape FSOSX: $_" "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog "Opening FSOS-X playbook in browser..." "STEP"
        try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    } else {
        Write-GuiLog "No .apbx link found on FSOSX site" "ERR"
    }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 16. FULL AUTO OPTIMIZE
# ================================================
# Used by: All ("OPTIMIZE ALL" - One-Click Full Optimization)
function Invoke-FullAutoOptimize {
    Clear-GuiLog
    Write-GuiLog "============================================================" "STEP"
    Write-GuiLog "  SETT OPTIMIZER - FULL AUTO OPTIMIZATION" "STEP"
    Write-GuiLog "============================================================" "STEP"
    $totalSteps = 13
    $currentStep = 0

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Creating Restore Point"
    $rpOk = Invoke-RestorePoint
    if (-not $rpOk) { Write-GuiLog "Restore point failed, continuing anyway..." "WARN" }

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Internet Optimization"
    Invoke-InternetOptimize

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Power Options"
    Invoke-PowerApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Game Mode"
    Invoke-GameModeApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Game Extra Optimizations"
    Invoke-GameExtraApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Memory Optimization"
    Invoke-MemoryApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Disabling Services"
    Invoke-ServicesApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: System Tweaks"
    Invoke-TweaksApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: GPU Optimization"
    Invoke-GPUApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Integrations Cleanup"
    Invoke-IntegrationsApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Privacy"
    Invoke-PrivacyApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Cache Cleanup (All)"
    Invoke-CleanAll

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Network Optimization (Ethernet + WiFi)"
    Invoke-NetworkOptimize "Ethernet"
    Invoke-NetworkOptimize "WiFi"

    Set-GuiProgress 100 "Full optimization complete!"
    Write-GuiLog "============================================================" "OK"
    Write-GuiLog "  FULL AUTO OPTIMIZATION COMPLETE!" "OK"
    Write-GuiLog "  A system restart is recommended for all changes to take effect." "WARN"
    Write-GuiLog "============================================================" "OK"
}
#endregion

# ================================================
#region 17. INTEGRATIONS REVERT
# ================================================
# Used by: NetworkPrivacy ("Revert Integrations")
function Invoke-IntegrationsRevert {
    Set-GuiProgress 50
    Write-GuiLog "Integration keys cannot be restored - they were permanently removed" "WARN"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 18. SYSTEM INFO POPUP
# ================================================
# Used by: (currently not wired to any page/button - orphan helper, available for future use)
function Show-SystemInfoPopup {
    Write-GuiLog "Gathering system information..." "STEP"
    $info = Get-SystemInfo
    $msg = @"
=== SYSTEM INFORMATION ===

CPU    : $($info.CPUName)
Cores  : $($info.CPUPhysicalCores) physical / $($info.CPULogicalCores) logical
RAM    : $($info.RAMTotalGB) GB total / $($info.RAMFreeGB) GB free
OS     : $($info.OSCaption) (Build $($info.OSBuild))
GPU    : $($info.GPUVendor) - $($info.GPUName) ($($info.GPUVRAM) GB VRAM)
"@
    Write-GuiLog $msg "INFO"
    Write-GuiLog "System info gathered successfully" "OK"
}
#endregion
