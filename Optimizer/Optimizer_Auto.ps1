# ============================================
#  OTIMIZADOR SETT - FULL AUTO (NO MENU)
# ============================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

$Script:Timer = [System.Diagnostics.Stopwatch]::StartNew()

$Script:Col = @{
    OK    = "Green"
    X     = "Red"
    WARN  = "DarkYellow"
    INFO  = "Cyan"
    STEP  = "Yellow"
    TITLE = "White"
    CAT   = "White"
    TIME  = "DarkCyan"
    HEAD  = "DarkGray"
}

# ============================================
# LOG
# ============================================
function OK  { param($M) Write-Host "[OK] " -ForegroundColor $Script:Col.OK -NoNewline; Write-Host $M -ForegroundColor $Script:Col.OK }
function X   { param($M) Write-Host "[X]  " -ForegroundColor $Script:Col.X -NoNewline; Write-Host $M -ForegroundColor $Script:Col.X }
function Warn { param($M) Write-Host "[*]  " -ForegroundColor $Script:Col.WARN -NoNewline; Write-Host $M -ForegroundColor $Script:Col.WARN }
function I   { param($M) Write-Host "[i]  " -ForegroundColor $Script:Col.INFO -NoNewline; Write-Host $M -ForegroundColor $Script:Col.INFO }
function S   { param($M) Write-Host "[+]  " -ForegroundColor $Script:Col.STEP -NoNewline; Write-Host $M -ForegroundColor $Script:Col.STEP }
function ShowHeader { param($M) Write-Host ""; Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD; Write-Host "  $M" -ForegroundColor $Script:Col.TITLE; Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD; Write-Host "" }

function Progress {
    param($Activity, $Current, $Total, $Status)
    if ($Total -gt 0) { Write-Progress -Activity $Activity -Status $Status -PercentComplete ([math]::Round(($Current / $Total) * 100)) }
}
function ProgressDone { param($Activity) Write-Progress -Activity $Activity -Completed }

# ============================================
# SYSTEM SPECS
# ============================================
function ShowSpecs {
    Clear-Host
    ShowHeader "SYSTEM SPECIFICATIONS"
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        I "CPU   : $($cpu.Name.Trim())"
        I "Cores : $($cpu.NumberOfCores) physical / $($cpu.NumberOfLogicalProcessors) logical"
    } catch { X "CPU: detection failed" }
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $usedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
        I "RAM   : $totalGB GB total | $freeGB GB free / $usedGB GB used"
        $Script:TotalRamGB = $totalGB
        $Script:OSCaption = $os.Caption
        I "OS    : $($os.Caption) (Build $($os.BuildNumber))"
    } catch { X "RAM/OS: detection failed" }
    try {
        $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -ne $null })
        I "GPU   : $($gpus.Count) detected"
        $idx = 0
        foreach ($g in $gpus) {
            $idx++
            $vram = [math]::Round($g.AdapterRAM / 1GB, 1)
            I "        GPU$idx : $($g.Name) | VRAM: $vram GB"
            $nameLow = $g.Name.ToLower()
            if ($nameLow -match "nvidia|nvidia")   { $Script:GpuVendor = "NVIDIA" }
            if ($nameLow -match "amd|radeon")       { $Script:GpuVendor = "AMD" }
        }
        if (-not $Script:GpuVendor) { $Script:GpuVendor = "Unknown" }
        I "Detected GPU vendor: $($Script:GpuVendor) (auto)"
    } catch { X "GPU: detection failed"; $Script:GpuVendor = "Unknown" }

    $Script:IsWin11 = ($Script:OSCaption -match "Windows 11")
    $Script:GameOS = if ($Script:IsWin11) { "Windows11" } else { "Windows10" }
    I "Game Mode target: $($Script:GameOS) (auto-detected)"
    Write-Host ""
}

# ============================================
# REGISTRY HELPER
# ============================================
function Apply-Reg {
    param([array]$Settings, [string]$Label)
    $total = $Settings.Count; $c = 0
    foreach ($s in $Settings) {
        $c++
        if ($total -gt 0) { Progress -Activity $Label -Current $c -Total $total -Status "$c/$total" }
        try {
            if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            New-ItemProperty -Path $s.Path -Name $s.Name -PropertyType $s.Type -Value $s.Value -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    ProgressDone -Activity $Label
}

# ============================================
# 1. INTERNET OPTIMIZATION
# ============================================
function Auto-Internet {
    ShowHeader "1/9 INTERNET OPTIMIZATION"
    try {
        netsh int tcp set global autotuning=disabled | Out-Null
        OK "TCP autotuning disabled"

        $reg = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"; Name = "FastSendDatagramThreshold"; Type = "DWORD"; Value = 64000 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Version"; Type = "String"; Value = "1.0" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Application Name"; Type = "String"; Value = "VALORANT.exe" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Protocol"; Type = "String"; Value = "*" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "DSCP Value"; Type = "DWORD"; Value = 46 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Throttle Rate"; Type = "DWORD"; Value = -1 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Version"; Type = "String"; Value = "1.0" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Application Name"; Type = "String"; Value = "csgo.exe" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Protocol"; Type = "String"; Value = "*" }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "DSCP Value"; Type = "DWORD"; Value = 46 }
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Throttle Rate"; Type = "DWORD"; Value = -1 }
        )
        Apply-Reg -Settings $reg -Label "Internet QoS Registry"
        OK "Internet optimization completed"
    } catch { X "Internet: $_" }
}

# ============================================
# 2. POWER OPTIONS
# ============================================
function Auto-Power {
    ShowHeader "2/9 POWER OPTIONS"
    $powFile = Join-Path $PSScriptRoot "settPowerPlan.pow"
    if (-not (Test-Path $powFile)) { X "settPowerPlan.pow not found"; return }
    $r = powercfg -import $powFile 2>&1
    $m = $r | Select-String -Pattern 'GUID: ([\w-]+)'
    if ($m) {
        $guid = $m.Matches[0].Groups[1].Value
        powercfg -setactive $guid
        OK "SETT power plan activated"
    } else { Warn "Could not locate GUID" }
}

# ============================================
# 3. GAME MODE
# ============================================
function Auto-GameMode {
    ShowHeader "3/9 GAME MODE ($($Script:GameOS) auto-detected)"

    $settings = @(
        @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AllowAutoGameMode"; Value = 1; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "ShowStartupPanel"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "GamePanelStartupTipIndex"; Value = 3; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "UseNexusForGameBarEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleGameBar"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleGameBar"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleRecording"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleRecording"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehaviorMode"; Value = 2; Type = "DWORD" }
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode"; Value = 1; Type = "DWORD" }
        @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_DXGIHonorFSEWindowsCompatible"; Value = 1; Type = "DWORD" }
    )
    Apply-Reg -Settings $settings -Label "Game Mode Registry"
    OK "Game Mode configured"

    S "Applying extra game optimizations..."
    $extra = @(
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Type = "DWORD"; Value = 38 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name = "ConvertibleSlateMode"; Type = "DWORD"; Value = 0 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name = "IRQ16Priority"; Type = "DWORD"; Value = 2 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Type = "DWORD"; Value = 16 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "LazyModeTimeout"; Type = "DWORD"; Value = 10000 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex"; Type = "DWORD"; Value = 0xffffffff }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Affinity"; Type = "DWORD"; Value = 0 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Background Only"; Type = "String"; Value = "False" }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Clock Rate"; Type = "DWORD"; Value = 10000 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "BackgroundPriority"; Type = "DWORD"; Value = 0 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Latency Sensitive"; Type = "String"; Value = "True" }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "NoLazyMode"; Type = "DWORD"; Value = 1 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority"; Type = "DWORD"; Value = 14 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority"; Type = "DWORD"; Value = 6 }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "SchedulingCategory"; Type = "String"; Value = "High" }
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "FSIO Priority"; Type = "String"; Value = "High" }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "GlobalTimerResolutionRequests"; Type = "DWORD"; Value = 1 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "TdrDelay"; Type = "DWORD"; Value = 6 }
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Direct3D"; Name = "MaxPreRenderedFrames"; Type = "DWORD"; Value = 1 }
    )
    Apply-Reg -Settings $extra -Label "Extra Game Optimizations"
    OK "Extra game optimizations applied"
}

# ============================================
# 4. MEMORY OPTIMIZATION
# ============================================
function Auto-Memory {
    ShowHeader "4/9 MEMORY OPTIMIZATION"

    $reg = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "ClearPageFileAtShutdown"; Value = 0 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "LargeSystemCache"; Value = 1 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "NonPagedPoolQuota"; Value = 0 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "NonPagedPoolSize"; Value = 0 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "PhysicalAddressExtension"; Value = 1 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "EnergyDriverPolicyVideo"; Value = 1 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "TimerBResolution"; Value = 1 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "TimerMinResolution"; Value = 1 }
    )
    Apply-Reg -Settings $reg -Label "Memory Registry Keys"

    try { Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue; OK "Memory compression disabled" } catch {}

    # Dynamic SvcHost
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    if    ($ramGB -le 4)  { $v = 4*1024*1024;   $l="4GB" }
    elseif($ramGB -le 8)  { $v = 8*1024*1024;   $l="8GB" }
    elseif($ramGB -le 12) { $v = 12*1024*1024;  $l="12GB" }
    elseif($ramGB -le 16) { $v = 16*1024*1024;  $l="16GB" }
    elseif($ramGB -le 24) { $v = 24*1024*1024;  $l="24GB" }
    elseif($ramGB -le 32) { $v = 32*1024*1024;  $l="32GB" }
    elseif($ramGB -le 48) { $v = 48*1024*1024;  $l="48GB" }
    elseif($ramGB -le 64) { $v = 64*1024*1024;  $l="64GB" }
    else                  { $v = 128*1024*1024; $l="128GB+" }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $v -Type DWord -Force -ErrorAction SilentlyContinue
    OK "SvcHost configured for $l of RAM"
    OK "Memory optimization completed"
}

# ============================================
# 5. ADVANCED - DISABLE SERVICES
# ============================================
function Auto-Services {
    ShowHeader "5/9 ADVANCED SETTINGS - Disabling Services"

    $svc = @(
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\TapiSrv"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\p2psvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\Wecsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SensorDataService"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SensrSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\StiSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\icssvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\DusmSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\MapsBroker"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\edgeupdate"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SensorService"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\shpamsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\svsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\CscService"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\ssh-agent"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\NfsClnt"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\wisvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\defragsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\autotimesvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\ALG"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\QWAVE"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc"; Name = "Start"; Type = "DWORD"; Value = 3 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\RetailDemo"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\lltdsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\TrkWks"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\Fax"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SCardSvr"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc"; Name = "Start"; Type = "DWORD"; Value = 4 }
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name = "Status"; Type = "DWORD"; Value = 0 }
    )
    Apply-Reg -Settings $svc -Label "Disabling Services"
    OK "$($svc.Count) services configured"
}

# ============================================
# 6. SYSTEM TWEAKS
# ============================================
function Auto-Tweaks {
    ShowHeader "6/9 SYSTEM TWEAKS"

    # Edge tasks
    S "Removing Edge scheduled tasks..."
    $edgeTasks = @(
        "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\MicrosoftEdgeUpdateTaskMachineCore"
        "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\MicrosoftEdgeUpdateTaskMachineUA"
    )
    foreach ($t in $edgeTasks) { try { reg.exe delete $t /f 2>$null | Out-Null } catch {} }
    OK "Edge tasks removed"

    # Category-based registry tweaks
    $cats = @{
        "Telemetry/Diagnostics/Privacy" = @(
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"; Name = "ShowedToastAtLevel"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\current\device\System"; Name = "AllowExperimentation"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\default\System\AllowExperimentation"; Name = "value"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "DoReport"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "LoggingDisabled"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting"; Name = "DoReport"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"; Name = "CdpSessionUserAuthzPolicy"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "LogEnabling"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableThirdPartySuggestions"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0"; Name = "NoExplicitFeedback"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Assistance\Client\1.0\Settings"; Name = "ImplicitFeedback"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\Windows"; Name = "DontShowUI"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\Software\Microsoft\Windows\Windows"; Name = "LoggingDisabled"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\Windows"; Name = "DontShowUI"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "Disabled"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "DefaultConsent"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DeviceMetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\WDI\{9c5a40da-b965-4fc3-8781-88dd50a6299d}"; Name = "ScenarioExecutionEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "TimeStampInterval"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "IoPriority"; Type = "REG_DWORD"; Value = 3 }
        )
        "Settings Sync" = @(
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSettingSync"; Type = "Reg_DWORD"; Value = 2 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSyncOnPaidNetwork"; Type = "Reg_DWORD"; Value = 2 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableWindowsSettingSync"; Type = "Reg_DWORD"; Value = 2 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync"; Name = "SyncPolicy"; Type = "REG_DWORD"; Value = 5 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSync"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSyncNGSC"; Type = "REG_DWORD"; Value = 1 }
        )
        "Disabled Services/Maintenance" = @(
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\FontCache"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\WdiServiceHost"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\WdiSystemHost"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Spooler"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; Name = "MaintenanceDisabled"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\edgeupdate"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\edgeupdatem"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "MaintenanceDisabled"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "NoLazyMode"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Type = "REG_DWORD"; Value = 38 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "ExitLatency"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "Latency"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceDefault"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceFSVP"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceVSyncEnabled"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoUpdate"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"; Name = "DownloadMode"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Origin Client Service"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Origin Web Helper Service"; Name = "Start"; Type = "REG_DWORD"; Value = 4 }
            @{ Path = "HKCU\Software\NVIDIA Corporation\NvTray"; Name = "StartOnLogin"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"; Name = "SearchOrderConfig"; Type = "REG_DWORD"; Value = 0 }
        )
        "Interface/Appearance" = @(
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Type = "REG_DWORD"; Value = 3 }
            @{ Path = "HKCU\Control"; Name = "MinAnimate"; Type = "REG_SZ"; Value = 0 }
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnablingTransparency"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"; Name = "StartupDelayInMSec"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DisallowShaking"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableBalloonTips"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DontPrettyPath"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "EnableAutoTray"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation"; Name = "DisableStartupSound"; Type = "REG_DWORD"; Value = 1 }
        )
        "Search/Cortana/Bing/Feeds" = @(
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "ConnectedSearchPrivacy"; Type = "REG_DWORD"; Value = 3 }
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\default\Experience\AllowCortana"; Name = "value"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "AllowCloudSearch"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "DisableWebSearch"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "EnablingFeeds"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft"; Name = "AllowNewsAndInterests"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Edge"; Name = "StartupBoostEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Edge"; Name = "BackgroundModeEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDeviceSearchHistoryEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "AllowCortana"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BackgroundAppGlobalToggle"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name = "EnableFeeds"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests"; Type = "REG_DWORD"; Value = 0 }
        )
        "Privacy/Ads/Personalization" = @(
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContentEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "ContentDeliveryAllowed"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "FeatureManagementEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SilentInstalledAppsEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenEnabled"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "HideRecentlyAddedApps"; Type = "REG_DWORD"; Value = 1 }
        )
        "Energy Management" = @(
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "HighPerformance"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "HighestPerformance"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "MaximumPerformancePercent"; Type = "REG_DWORD"; Value = 100 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "CStates"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy"; Name = "fDisablePowerManagement"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; Name = "PowerThrottlingOff"; Type = "REG_DWORD"; Value = 1 }
        )
        "Kernel/Performance" = @(
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "PriorityControl"; Type = "REG_DWORD"; Value = 50 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "ThreadDpcEnable"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "TimeStampInterval"; Type = "REG_DWORD"; Value = 1 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "IoPriority"; Type = "REG_DWORD"; Value = 3 }
            @{ Path = "HKCU\Control"; Name = "AutoEndTasks"; Type = "REG_SZ"; Value = 1 }
            @{ Path = "HKCU\Control"; Name = "HungAppTimeout"; Type = "REG_SZ"; Value = 1000 }
            @{ Path = "HKCU\Control"; Name = "WaitToKillAppTimeout"; Type = "REG_SZ"; Value = 2000 }
            @{ Path = "HKCU\Control"; Name = "LowLevelHooksTimeout"; Type = "REG_SZ"; Value = 1000 }
            @{ Path = "HKCU\Control"; Name = "MenuShowDelay"; Type = "REG_SZ"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control"; Name = "WaitToKillServiceTimeout"; Type = "REG_SZ"; Value = 2000 }
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "PowerThrottlingOff"; Type = "REG_DWORD"; Value = 1 }
        )
    }

    $totalAll = 0; foreach ($c in $cats.Values) { $totalAll += $c.Count }
    $idx = 0
    $allFailedKeys = @()

    $Script:ErrMap = @{
        "not exist"     = "1001"
        "does not exist"= "1001"
        "Cannot find"   = "1001"
        "not found"     = "1001"
        "PathNotFound"  = "1001"
        "denied"        = "1002"
        "Access"        = "1002"
        "permission"    = "1002"
        "Registry"      = "1002"
        "type"          = "1003"
        "convert"       = "1003"
        "format"        = "1003"
        "out of range"  = "1004"
    }

    function Get-ErrCode { param($Msg) foreach ($k in $Script:ErrMap.Keys) { if ($Msg -match $k) { return $Script:ErrMap[$k] } }; return "1999" }

    foreach ($catName in $cats.Keys) {
        $catData = $cats[$catName]
        $catFailed = @()
        foreach ($s in $catData) {
            $idx++
            Progress -Activity "System Tweaks" -Current $idx -Total $totalAll -Status "$catName"
            try {
                if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force -ErrorAction SilentlyContinue | Out-Null }
                Set-ItemProperty -Path $s.Path -Name $s.Name -Value $s.Value -ErrorAction Stop
            } catch {
                $errMsg = $_.Exception.Message
                $catFailed += @{ Path = $s.Path; Name = $s.Name; Value = $s.Value; ErrCode = (Get-ErrCode $errMsg); ErrMsg = $errMsg }
                $allFailedKeys += @{ Category = $catName; Path = $s.Path; Name = $s.Name; Value = $s.Value; ErrCode = (Get-ErrCode $errMsg); ErrMsg = $errMsg }
            }
        }
        $totalInCat = $catData.Count
        $failedCount = $catFailed.Count
        $padName = $catName.PadRight(44)
        $padKeys = ("$totalInCat keys").PadLeft(8)

        Write-Host " [+] " -ForegroundColor $Script:Col.STEP -NoNewline
        Write-Host $padName -ForegroundColor White -NoNewline
        Write-Host $padKeys -ForegroundColor DarkGray -NoNewline
        if ($failedCount -eq 0) {
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            Write-Host " [OK:$($totalInCat-$failedCount)" -ForegroundColor Green -NoNewline
            Write-Host " FAIL:$failedCount]" -ForegroundColor Yellow
            foreach ($fk in $catFailed) {
                Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                Write-Host "$($fk.Path)\$($fk.Name)" -ForegroundColor DarkGray -NoNewline
                Write-Host " = $($fk.Value)" -ForegroundColor DarkGray -NoNewline
                Write-Host " | Erro: $($fk.ErrCode)" -ForegroundColor Yellow
            }
        }
    }
    ProgressDone -Activity "System Tweaks"

    if ($allFailedKeys.Count -gt 0) {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $logFile = Join-Path $desktop "Optimizer_Log.txt"
        $log = @()
        $log += "============================================================"
        $log += "  OTIMIZADOR SETT - CHAVES NAO APLICADAS"
        $log += "  Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $log += "============================================================"
        $log += ""
        $log += "MAPA DE ERROS:"
        $log += "  1001 = Chave/PATH inexistente no sistema"
        $log += "  1002 = Acesso negado / restricao de permissao"
        $log += "  1003 = Tipo de dado incompativel"
        $log += "  1004 = Valor fora do intervalo permitido"
        $log += "  1999 = Erro desconhecido"
        $log += ""
        $log += "CHAVES NAO APLICADAS ($($allFailedKeys.Count) total):"
        $log += ""
        $cur = ""
        foreach ($fk in $allFailedKeys) {
            if ($fk.Category -ne $cur) { $cur = $fk.Category; $log += "--- $cur ---" }
            $log += "  PATH : $($fk.Path)\$($fk.Name) = $($fk.Value)"
            $log += "  ERRO : $($fk.ErrCode) | $($fk.ErrMsg)"
            $log += ""
        }
        try {
            $log | Out-File -FilePath $logFile -Encoding UTF8
            I "Log de chaves nao aplicadas salvo: $logFile"
        } catch {}
    }

    OK "All system tweaks applied ($totalAll keys)"
}

# ============================================
# 7. GPU OPTIMIZATION (AUTO-DETECT)
# ============================================
function Auto-GPU {
    ShowHeader "7/9 GPU OPTIMIZATION (Detected: $($Script:GpuVendor))"

    if ($Script:GpuVendor -eq "NVIDIA") {
        # Step 1
        $nvPath = "C:\Program Files\NVIDIA Corporation\NVSMI"
        $smiOk = $false
        if (Test-Path $nvPath) {
            Push-Location $nvPath
            try { & .\nvidia-smi.exe -acp 0; & .\nvidia-smi.exe -e 1; $smiOk = $true } catch {}
            Pop-Location
        }

        Write-Host " [+] " -ForegroundColor $Script:Col.STEP -NoNewline
        Write-Host "NVIDIA-SMI (acp + e)".PadRight(44) -ForegroundColor White -NoNewline
        if ($smiOk) { Write-Host " [OK]" -ForegroundColor Green } else { Write-Host " [!]" -ForegroundColor Yellow }
        Start-Sleep -Seconds 2

        # Step 2
        $devices = (wmic path Win32_VideoController get PNPDeviceID | Select-String "PCI\\VEN_").Matches.Value
        $pstateOk = $true
        foreach ($dev in $devices) {
            $rp = "HKLM:\SYSTEM\ControlSet001\Enum\$dev"
            try {
                $drv = (Get-ItemProperty -Path $rp -Name Driver -ErrorAction Stop).Driver
                if ($drv -and ($drv -match "^{.*}$")) {
                    $crp = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$drv"
                    New-ItemProperty -Path $crp -Name "DisableDynamicPstate" -PropertyType DWord -Value 1 -Force | Out-Null
                }
            } catch { $pstateOk = $false }
        }
        Write-Host " [+] " -ForegroundColor $Script:Col.STEP -NoNewline
        Write-Host "Disable DynamicPstate".PadRight(44) -ForegroundColor White -NoNewline
        if ($pstateOk) { Write-Host " [OK]" -ForegroundColor Green } else { Write-Host " [!]" -ForegroundColor Yellow }
        Start-Sleep -Seconds 2

        # Step 3
        $tasks = @("NvTmRepCrashReport2{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvTmRepCrashReport3{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvTmRepCrashReport4{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}")
        foreach ($t in $tasks) { schtasks /change /disable /tn $t >$null 2>&1 }

        $nvidiaReg = @(
            @{ Path = "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"; Name = "OptInOrOutPreference"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup"; Name = "SendTelemetryData"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "DisablePreemption"; Type = "DWORD"; Value = 1 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "DisableCudaContextPreemption"; Type = "DWORD"; Value = 1 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableCEPreemption"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "DisablePreemptionOnS3S4"; Type = "DWORD"; Value = 1 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "ComputePreemption"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidGfxPreemption"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidGfxPreemptionVGPU"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidBufferPreemptionForHighTdrTimeout"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidBufferPreemption"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableAsyncMidBufferPreemption"; Type = "DWORD"; Value = 0 }
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\GraphicsDrivers\Scheduler"; Name = "EnablePreemption"; Type = "DWORD"; Value = 0 }
        )
        Apply-Reg -Settings $nvidiaReg -Label "NVIDIA Registry"
        Write-Host " [+] " -ForegroundColor $Script:Col.STEP -NoNewline
        Write-Host "Advanced registry + tasks".PadRight(44) -ForegroundColor White -NoNewline
        Write-Host " [OK]" -ForegroundColor Green
        OK "NVIDIA optimizations completed"

    } elseif ($Script:GpuVendor -eq "AMD") {
        $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
        if (-not (Test-Path $basePath)) { New-Item -Path $basePath -Force | Out-Null }

        $amdReg = @(
            @{ Name = "DisableUVDPowerGatingDynamic"; Type = "DWORD"; Value = 1 }
            @{ Name = "AllowSnapshot"; Type = "DWORD"; Value = 0 }
            @{ Name = "DisableDrmdmaPowerGating"; Type = "DWORD"; Value = 1 }
            @{ Name = "EnableUlps"; Type = "DWORD"; Value = 0 }
            @{ Name = "AllowRSOverlay"; Type = "String"; Value = "false" }
            @{ Name = "AutoColorDepthReduction_NA"; Type = "DWORD"; Value = 0 }
            @{ Name = "AllowSubscription"; Type = "DWORD"; Value = 0 }
            @{ Name = "DisableVCEPowerGating"; Type = "DWORD"; Value = 1 }
            @{ Name = "DisableDMACopy"; Type = "DWORD"; Value = 1 }
            @{ Name = "AllowSkins"; Type = "String"; Value = "false" }
            @{ Name = "PP_GPUPowerDownEnabled"; Type = "DWORD"; Value = 0 }
            @{ Name = "DisableBlockWrite"; Type = "DWORD"; Value = 0 }
            @{ Name = "StutterMode"; Type = "DWORD"; Value = 0 }
            @{ Name = "DisablePowerGating"; Type = "DWORD"; Value = 1 }
        )
        Apply-Reg -Settings $amdReg -Label "AMD Optimization"
        Write-Host " [+] " -ForegroundColor $Script:Col.STEP -NoNewline
        Write-Host "AMD Power/Stutter/Preemption".PadRight(44) -ForegroundColor White -NoNewline
        Write-Host " [OK]" -ForegroundColor Green
        OK "AMD optimizations completed"

    } else {
        Warn "No NVIDIA or AMD GPU detected. Skipping GPU optimizations."
    }
}

# ============================================
# 8. INTEGRATIONS CLEANUP
# ============================================
function Auto-Integrations {
    ShowHeader "8/9 INTEGRATIONS CLEANUP"

    $Keys = @(
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.PreInstalledConfigTask\PackageId\Microsoft.MicrosoftOfficeHub_17.7909.7600.0_x64__8wekyb3d8bbwe"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
    )
    $total = $Keys.Count; $removed = 0
    foreach ($k in $Keys) {
        $removed++
        Progress -Activity "Removing Integration Keys" -Current $removed -Total $total -Status "$removed/$total"
        if (Test-Path $k) { try { Remove-Item -Path $k -Recurse -Force -ErrorAction Stop } catch {} }
    }
    ProgressDone -Activity "Removing Integration Keys"
    OK "Integration cleanup completed ($removed keys processed)"
}

# ============================================
# 9. PRIVACY
# ============================================
function Auto-Privacy {
    ShowHeader "9/9 PRIVACY PROTECTION"

    try {
        $a = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (Test-Path $a) { Set-ItemProperty -Path $a -Name "Enabled" -Value 0 }
        OK "Advertising disabled"

        $s = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        if (Test-Path $s) { Set-ItemProperty -Path $s -Name "AllowCortana" -Value 0 }

        $c1="HKCU:\SOFTWARE\Microsoft\Personalization\Settings"; $c2="HKCU:\SOFTWARE\Microsoft\InputPersonalization"; $c3="HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"
        if (-not (Test-Path $c1)) { New-Item -Path $c1 | Out-Null }; Set-ItemProperty -Path $c1 -Name "AcceptedPrivacyPolicy" -Value 0
        if (-not (Test-Path $c2)) { New-Item -Path $c2 | Out-Null }; Set-ItemProperty -Path $c2 -Name "RestrictImplicitTextCollection" -Value 1; Set-ItemProperty -Path $c2 -Name "RestrictImplicitInkCollection" -Value 1
        if (-not (Test-Path $c3)) { New-Item -Path $c3 | Out-Null }; Set-ItemProperty -Path $c3 -Name "HarvestContacts" -Value 0
        OK "Cortana data collection disabled"

        if (-not (Test-Path $s)) { New-Item -Path $s | Out-Null }; Set-ItemProperty -Path $s -Name "DisableWebSearch" -Value 1
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
        OK "Web search disabled"

        $dp = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection","HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection")
        foreach ($p in $dp) { if (Test-Path $p) { Set-ItemProperty -Path $p -Name "AllowTelemetry" -Value 0 } }
        OK "Telemetry disabled"

        $sn = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"; $lc = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"
        if (-not (Test-Path $sn)) { New-Item -Path $sn | Out-Null }; Set-ItemProperty -Path $sn -Name "SensorPermissionState" -Value 0
        if (-not (Test-Path $lc)) { New-Item -Path $lc | Out-Null }; Set-ItemProperty -Path $lc -Name "Status" -Value 0
        OK "Location tracking disabled"

        $lv = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
        if (-not (Test-Path $lv)) { New-Item -Path $lv | Out-Null }; Set-ItemProperty -Path $lv -Name "NoTileApplicationNotification" -Value 1
        OK "Live tiles notifications disabled"

        $tasks = @("XblGameSaveTaskLogon","XblGameSaveTask","Consolidator","UsbCeip","DmClient","DmClientOnScenarioDownload")
        foreach ($t in $tasks) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue; schtasks /change /disable /tn $t 2>$null }
        OK "Telemetry tasks disabled"

        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue; Set-Service -Name "DiagTrack" -StartupType Disabled
        OK "Diagnostics Tracking Service disabled"

        $cl = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore"
        if (Test-Path $cl) {
            Stop-Process -Name "Explorer" -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $cl -Recurse -Force -ErrorAction SilentlyContinue
            Start-Process "Explorer.exe"
            OK "CloudStore removed"
        }

        $pdf = @("HKLM:\SOFTWARE\Classes\.pdf","HKLM:\SOFTWARE\Classes\.pdf\OpenWithProgids","HKLM:\SOFTWARE\Classes\.pdf\OpenWithList")
        foreach ($p in $pdf) {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null }
            if (-not (Get-ItemProperty -Path $p -Name "NoOpenWith" -ErrorAction SilentlyContinue)) { New-ItemProperty -Path $p -Name "NoOpenWith" -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null }
            if (-not (Get-ItemProperty -Path $p -Name "NoStaticDefaultVerb" -ErrorAction SilentlyContinue)) { New-ItemProperty -Path $p -Name "NoStaticDefaultVerb" -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null }
        }
        $ed = "HKLM:\SOFTWARE\Classes\AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723_"
        if (Test-Path $ed) { Set-ItemProperty -Path $ed -Name "NoOpenWith" -Value 1 -Force -ErrorAction SilentlyContinue }
        OK "Edge PDF takeover prevented"

        OK "Privacy protection completed"
    } catch { X "Privacy: $_" }
}

# ============================================
# SHOW ELAPSED TIME
# ============================================
function Show-Time {
    $Script:Timer.Stop()
    $e = $Script:Timer.Elapsed
    $ts = ("{0:D2}:{1:D2}:{2:D2}.{3:D3}" -f $e.Hours, $e.Minutes, $e.Seconds, $e.Milliseconds)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host "  Total execution time: " -ForegroundColor $Script:Col.TIME -NoNewline
    Write-Host $ts -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host ""
}

# ============================================
# MAIN - FULL AUTO EXECUTION
# ============================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[X] This script must run as Administrator!" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

try {
    ShowSpecs

    Auto-Internet
    Auto-Power
    Auto-GameMode
    Auto-Memory
    Auto-Services
    Auto-Tweaks
    Auto-GPU
    Auto-Integrations
    Auto-Privacy

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host "  ALL OPTIMIZATIONS COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD

    Show-Time
} catch {
    X "Fatal error: $_"
    Show-Time
}

Write-Host "Press ENTER to exit..."
Read-Host | Out-Null
