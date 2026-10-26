Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host

$Script:Col = @{
    OK    = "Green"
    X     = "Red"
    WARN  = "DarkYellow"
    INFO  = "Cyan"
    STEP  = "Yellow"
    TITLE = "White"
    CAT   = "White"
    HEAD  = "DarkGray"
}

function OK   { param($M) Write-Host "[OK] " -ForegroundColor $Script:Col.OK -NoNewline; Write-Host $M -ForegroundColor $Script:Col.OK }
function X    { param($M) Write-Host "[X]  " -ForegroundColor $Script:Col.X   -NoNewline; Write-Host $M -ForegroundColor $Script:Col.X }
function Warn { param($M) Write-Host "[*]  " -ForegroundColor $Script:Col.WARN -NoNewline; Write-Host $M -ForegroundColor $Script:Col.WARN }
function I    { param($M) Write-Host "[i]  " -ForegroundColor $Script:Col.INFO -NoNewline; Write-Host $M -ForegroundColor $Script:Col.INFO }
function S    { param($M) Write-Host "[+]  " -ForegroundColor $Script:Col.STEP -NoNewline; Write-Host $M -ForegroundColor $Script:Col.STEP }
function ShowHeader { param($M) Write-Host ""; Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD; Write-Host "  $M" -ForegroundColor $Script:Col.TITLE; Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD; Write-Host "" }

function Show-MenuUI {
    param(
        [string]$Title,
        [string[]]$Options
    )

    Clear-Host
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host ("  $Title") -ForegroundColor $Script:Col.TITLE
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD

    for ($i = 0; $i -lt $Options.Length; $i++) {
        $num = "[$($i + 1)]".PadRight(5)
        Write-Host "  $num" -ForegroundColor $Script:Col.STEP -NoNewline
        Write-Host $Options[$i] -ForegroundColor White
    }

    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
}

function Show-Menu {
    param(
        [string]$Title,
        [string[]]$Options,
        [scriptblock[]]$Actions
    )

    do {
        Show-MenuUI -Title $Title -Options $Options
        $choice = Read-Host "Escolha uma opção [1-$($Options.Length)]"

        $parsed = 0
        if ([int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $Options.Length) {
            $index = $parsed - 1
            $result = & $Actions[$index]

            if ($result -eq "BACK") {
                break   # sai do submenu
            }
        } else {
            X "Invalid option. Try again."
            Start-Sleep -Seconds 1
        }
    } while ($true)
}

# ============================================
# MENU PRINCIPAL
# ============================================

function Show-MainMenu {
    do {
        $options = @(
            "Otimizar Internet", 
            "Power Options", 
            "Game Mode", 
            "Memory Otimizations", 
            "Configurações Avançadas", 
            "Tweaks",
            "GPU Optimize",
            "Integrations",
            "Privacy",
            "Windows 11 Tweaks",
            "Browser Tweaks",
            "Improve Context Menu",
            "Otimizar Rede (Ethernet/Wi-Fi)",
            "Clean",
            "Sair"
        )

        $actions = @(
            { Show-OptimizeMenu },
            { Show-PowerOptionsMenu },
            { Show-GameModeMenu },
            { Show-MemoryOptimizationMenu },
            { Show-AdvancedSettingsMenu },
            { Show-SystemOptimizationMenu },
            { Show-GpuOptimizeMenu },
            { Show-IntegrationsMenu },
            { Show-PrivacyMenu },
            { Show-W11TweaksMenu },
            { Show-BrowserTweaksMenu },
            { Show-ImproveContextMenu },
            {
                $networkOptimizerPath = Join-Path $PSScriptRoot "OptimizerEthernetWifi.ps1"
                if (Test-Path $networkOptimizerPath) {
                    S "Launching Network Optimizer..."
                    Start-Sleep -Seconds 1
                    Start-Process powershell -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$networkOptimizerPath`""
                } else {
                    X "OptimizerEthernetWifi.ps1 not found in $networkOptimizerPath"
                    Read-Host "`nPress ENTER to return."
                }
            },
            {
                $cacheCleanerPath = Join-Path $PSScriptRoot "CacheCleaner.ps1"
                if (Test-Path $cacheCleanerPath) {
                    S "Launching Cache Cleaner..."
                    Start-Sleep -Seconds 1
                    Start-Process powershell -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$cacheCleanerPath`""
                } else {
                    X "CacheCleaner.ps1 not found in $cacheCleanerPath"
                    Read-Host "`nPress ENTER to return."
                }
            },
            {
                I "Exiting..."
                Start-Sleep -Seconds 1
                Stop-Process -Id $PID 
            }
        )

        Show-Menu -Title "OTIMIZADOR SETT" -Options $options -Actions $actions
    } while ($true)
}
# ===== SUBMENU DE CONTEXT MENU TWEAKS =====
function Show-ImproveContextMenu {
    Show-Menu -title "Context Menu Tweaks" `
        -options @("Aplicar", "Reverter", "Voltar ao Menu Anterior") `
        -actions @(
            { Invoke-ImproveContextTweakMenu },
            { Invoke-RevertContextMenu },
            { "BACK" }
        )
}

# ===== SUBMENU DE BROWSER TWEAKS =====
function Show-BrowserTweaksMenu {
    Show-Menu -title "Browser Bloatware Tweaks" `
        -options @("Brave", "Chrome", "Edge", "Firefox", "Voltar ao Menu Anterior") `
        -actions @(
            { Show-BraveMenu },
            { Show-ChromeMenu },
            { Show-EdgeMenu },
            { Show-FirefoxMenu },
            { "BACK" }
        )
}

# ===== SUBMENU - BRAVE ========
function Show-BraveMenu {
    Show-Menu -title "Brave Tweaks" `
        -options @("Aplicar Tweaks", "Reverter Tweaks", "Voltar") `
        -actions @(
            { Invoke-BraveBloatware },
            { Revert-BraveBloatware },
            { "BACK" }
        )
}

# ===== SUBMENU - CHROME =======
function Show-ChromeMenu {
    Show-Menu -title "Chrome Tweaks" `
        -options @("Aplicar Tweaks", "Reverter Tweaks", "Voltar") `
        -actions @(
            { Invoke-ChromeBloatware },
            { Revert-ChromeBloatware },
            { "BACK" }
        )
}

# ===== SUBMENU - EDGE =========
function Show-EdgeMenu {
    Show-Menu -title "Edge Tweaks" `
        -options @("Aplicar Tweaks", "Reverter Tweaks", "Voltar") `
        -actions @(
            { Invoke-EdgeBloatware },
            { Revert-EdgeBloatware },
            { "BACK" }
        )
}

# ===== SUBMENU - FIREFOX ======
function Show-FirefoxMenu {
    Show-Menu -title "Firefox Tweaks" `
        -options @("Aplicar Tweaks", "Reverter Tweaks", "Voltar") `
        -actions @(
            { Invoke-FirefoxBloatware },
            { Revert-FirefoxBloatware },
            { "BACK" }
        )
}

# ===== SUBMENU DE WINDOWS 11 TWEAKS =====
function Show-W11TweaksMenu {
    Show-Menu -title "Windows 11 Tweaks" `
        -options @("Aplicar Old Menu", "Aplicar Classic Alt Tab", "Reverter Old Menu", "Reverter Classic Alt Tab", "Voltar ao Menu Anterior") `
        -actions @(
            { Invoke-OldMenu; Read-Host "`nPress ENTER to return." },
			{ Invoke-OldClassicAltTab; Read-Host "`nPress ENTER to return." },
			{ Invoke-RevertOldMenu; Read-Host "`nPress ENTER to return." },
			{ Invoke-RevertClassicAltTab; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE PROTEÇÃO DE PRIVACIDADE =====
function Show-PrivacyMenu {
    Show-Menu -title "PRIVACIDADE" `
        -options @("Executar PRIVACIDADE", "Voltar ao Menu Anterior") `
        -actions @(
            { Invoke-ProtectPrivacy; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE INTEGRAÇÕES =====
function Show-IntegrationsMenu {
    Show-Menu -title "INTEGRAÇÕES" `
        -options @("Executar INTEGRAÇÕES", "Voltar ao Menu Anterior") `
        -actions @(
            { Invoke-AppIntegrationKeys; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE OTIMIZACAO DE GPU =====
function Show-GpuOptimizeMenu {
    Show-Menu -title "OTIMIZAR GPU" `
        -options @(
            "Aplicar OTIMIZACAO DE GPU (Auto-deteccao)",
            "Voltar ao Menu Principal"
        ) `
        -actions @(
            { Invoke-GpuOptimize; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE OTIMIZAÇÃO TWEAKS =====
function Show-SystemOptimizationMenu {
    Show-Menu -title "OTIMIZAÇÃO TWEAKS" `
        -options @("Aplicar OTIMIZAÇÃO DE TWEAKS", "Voltar ao Menu Anterior") `
        -actions @(
            { Optimize-SystemFunction; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE CONFIGURAÇÕES AVANÇADAS =====
function Show-AdvancedSettingsMenu {
    Show-Menu -title "CONFIGURAÇÕES AVANÇADAS" `
        -options @("Desativar Serviços", "Otimizar Teclado", "Voltar ao Menu Principal") `
        -actions @(
            { Disable-ServicesFunction; Read-Host "`nPress ENTER to return." },
            { 
                $filterKeysPath = Join-Path $PSScriptRoot "Programs\FilterKeysSetter.exe"
                if (Test-Path $filterKeysPath) {
                    Start-Process -FilePath $filterKeysPath
                } else {
                    X "Error: FilterKeysSetter.exe not found in $filterKeysPath"
                    Read-Host "`nPress ENTER to return."
                }
            },
            { "BACK" }
        )
}


# ===== SUBMENU DE OTIMIZAÇÃO DE MEMÓRIA =====
function Show-MemoryOptimizationMenu {
    Show-Menu -title "OTIMIZAÇÃO DE MEMÓRIA" `
        -options @("Aplicar OTIMIZAÇÃO DE MEMÓRIA", "Voltar ao Menu Principal") `
        -actions @(
            { Apply-MemoryOptimizations; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE OTIMIZAÇÃO DE INTERNET =====
function Show-OptimizeMenu {
    Show-Menu -title "OTIMIZAR INTERNET" `
        -options @(
            "Aplicar OTIMIZAÇÃO",
            "Restaurar Datagram Threshold",
            "Voltar ao Menu Principal"
        ) `
        -actions @(
            { Apply-InternetOptimization; Read-Host "`nPress ENTER to return." },
            { Restore-Default; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE POWER OPTIONS =====
function Show-PowerOptionsMenu {
    Show-Menu -title "POWER OPTIONS" `
        -options @("Aplicar POWER OPTIONS", "Voltar ao Menu Principal") `
        -actions @(
            { Apply-PowerOptions; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ===== SUBMENU DE GAME MODE =====
function Show-GameModeMenu {
    Show-Menu -title "GAME MODE" `
        -options @(
            "Windows 10",
            "Windows 11",
            "Aplicar OTIMIZAÇÕES DE GAME",
            "Voltar ao Menu Principal"
        ) `
        -actions @(
            { Configure-GameMode -os "Windows10"; Read-Host "`nPress ENTER to return." },
            { Configure-GameMode -os "Windows11"; Read-Host "`nPress ENTER to return." },
            { Apply-ExtraGameOptimizations; Read-Host "`nPress ENTER to return." },
            { "BACK" }
        )
}

# ============================================
########### AUTOMATIZACOES BY SETT ###########
# ============================================

# ===== APLICAR OTIMIZAÇÃO INTERNET =====
function Apply-InternetOptimization {
    Clear-Host
    I "Aplicando otimizações automáticas de Internet..."

    try {
        # --------------------------
        # -*- Otimizações TCP/AFD
        # --------------------------
        netsh int tcp set global autotuning=disabled | Out-Null

        # --------------------------
        # -*- Configurações de registro
        # --------------------------
        $regSettings = @(
            # FastSendDatagramThreshold
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"; Name = "FastSendDatagramThreshold"; Type = "DWORD"; Value = 64000 },

            # QoS Valorant
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Version"; Type = "String"; Value = "1.0" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Application Name"; Type = "String"; Value = "VALORANT.exe" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Protocol"; Type = "String"; Value = "*" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "DSCP Value"; Type = "DWORD"; Value = 46 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name = "Throttle Rate"; Type = "DWORD"; Value = -1 },

            # QoS CSGO
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Version"; Type = "String"; Value = "1.0" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Application Name"; Type = "String"; Value = "csgo.exe" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Protocol"; Type = "String"; Value = "*" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "DSCP Value"; Type = "DWORD"; Value = 46 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name = "Throttle Rate"; Type = "DWORD"; Value = -1 }
        )

        $total = $regSettings.Count
        $counter = 0

        foreach ($setting in $regSettings) {
            $counter++
            Write-Progress -Activity "Aplicando otimizações de Internet..." `
                           -Status "$counter de $total chaves de registro" `
                           -PercentComplete (($counter / $total) * 100)

            try {
                if (-not (Test-Path $setting.Path)) {
                    New-Item -Path $setting.Path -Force | Out-Null
                }
                New-ItemProperty -Path $setting.Path -Name $setting.Name -PropertyType $setting.Type -Value $setting.Value -Force -ErrorAction SilentlyContinue | Out-Null
            } catch {
                # Ignora erros sem exibir
            }
        }

        Write-Progress -Activity "Aplicações concluídas" -Completed
        OK "Todas as otimizações e QoS aplicadas com sucesso!"
    }
    catch {
        X "Erro geral ao aplicar otimizações: $_"
    }

    Read-Host "`nPress ENTER to return."
}

# ===== RESTAURAR PADRÃO =====
function Restore-Default {
    Clear-Host
    S "Restoring internet settings to default..."

    try {
        netsh int tcp set global autotuning=normal

        # Remove FastSendDatagramThreshold
        $afdParamsKey = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        if (Test-Path "$afdParamsKey\FastSendDatagramThreshold") {
            Remove-ItemProperty -Path $afdParamsKey -Name "FastSendDatagramThreshold" -Force
        }

        OK "Configuration restored successfully."
    } catch {
        X "Error restoring configuration: $_"
    }

    Read-Host "`nPress ENTER to return."
}

# ===== APLICAR POWER OPTIONS =====
function Apply-PowerOptions {
    Clear-Host
    S "Applying power plan SETT via .pow file..."

    # Caminho dinâmico: mesmo diretório do script
    $powFile = Join-Path $PSScriptRoot "settPowerPlan.pow"

    if (-not (Test-Path $powFile)) {
        X "Arquivo 'settPowerPlan.pow' não encontrado na pasta do script."
        Read-Host "`nPress ENTER to return."
        return
    }

    # Importa o plano .pow e captura o GUID
    $importResult = powercfg -import $powFile 2>&1
    $guidMatch = $importResult | Select-String -Pattern 'GUID: ([\w-]+)'

    if ($guidMatch) {
        $guid = $guidMatch.Matches[0].Groups[1].Value
        powercfg -setactive $guid
        OK "Plano 'SETT' ativado com sucesso."
    } else {
        Warn "Could not locate imported plan GUID."
    }

    OK "Settings applied successfully!"
    Read-Host "`nPress ENTER to return."
}

# ===== CONFIGURAR GAME MODE BASEADO NO SISTEMA =====
function Configure-GameMode {
    param (
        [string]$os
    )

    Clear-Host
    S "Configurando Game Mode para $os..."

    $gameModeSettings = @()

    if ($os -eq "Windows10") {
        # Ativar Game Mode
        $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AllowAutoGameMode"; Value = 1; Type = "DWORD" }
        $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled"; Value = 1; Type = "DWORD" }
    } elseif ($os -eq "Windows11") {
        # Desativar Game Mode
        $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AllowAutoGameMode"; Value = 1; Type = "DWORD" }
        $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "AutoGameModeEnabled"; Value = 1; Type = "DWORD" }
    }

    # Configurações adicionais para desativar Game Bar
    $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "ShowStartupPanel"; Value = 0; Type = "DWORD" }
    $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "GamePanelStartupTipIndex"; Value = 3; Type = "DWORD" }
    $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\GameBar"; Name = "UseNexusForGameBarEnabled"; Value = 0; Type = "DWORD" }
    $gameModeSettings += @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0; Type = "DWORD" }

    $counter = 0
    $total = $gameModeSettings.Count

    foreach ($setting in $gameModeSettings) {
        $counter++
        Write-Progress -Activity "Aplicando Game Mode..." `
                       -Status "$counter de $total ajustes" `
                       -PercentComplete (($counter / $total) * 100)
        try {
            if (-not (Test-Path $setting.Path)) { New-Item -Path $setting.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Force -ErrorAction SilentlyContinue
        } catch { }
    }

    Write-Progress -Activity "Aplicando Game Mode..." -Completed
    OK "Configurações de Game Mode aplicadas para $os."
    Read-Host "`nPress ENTER to return."
}

# ===== CONFIGURAR OTIMIZACAO PARA JOGOS =====
function Apply-ExtraGameOptimizations {
    Clear-Host
    S "Aplicando otimizações adicionais para jogos..."

    $settings = @(
        # PriorityControl
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Type = "DWORD"; Value = 38 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name = "ConvertibleSlateMode"; Type = "DWORD"; Value = 0 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\PriorityControl"; Name = "IRQ16Priority"; Type = "DWORD"; Value = 2 },

        # SystemProfile
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Type = "DWORD"; Value = 16 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "LazyModeTimeout"; Type = "DWORD"; Value = 10000 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex"; Type = "DWORD"; Value = 0xffffffff },

        # Games task
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Affinity"; Type = "DWORD"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Background Only"; Type = "String"; Value = "False" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Clock Rate"; Type = "DWORD"; Value = 10000 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "BackgroundPriority"; Type = "DWORD"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Latency Sensitive"; Type = "String"; Value = "True" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "NoLazyMode"; Type = "DWORD"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority"; Type = "DWORD"; Value = 14 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority"; Type = "DWORD"; Value = 6 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "SchedulingCategory"; Type = "String"; Value = "High" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "FSIO Priority"; Type = "String"; Value = "High" },

        # Timer Resolution
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "GlobalTimerResolutionRequests"; Type = "DWORD"; Value = 1 },

        # Graphics Drivers
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "TdrDelay"; Type = "DWORD"; Value = 6 },

        # Direct3D
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Direct3D"; Name = "MaxPreRenderedFrames"; Type = "DWORD"; Value = 1 }
    )

    $counter = 0
    $total = $settings.Count

    foreach ($setting in $settings) {
        $counter++
        Write-Progress -Activity "Aplicando otimizações adicionais" `
                       -Status "$counter de $total ajustes" `
                       -PercentComplete (($counter / $total) * 100)
        try {
            if (-not (Test-Path $setting.Path)) { New-Item -Path $setting.Path -Force -ErrorAction SilentlyContinue | Out-Null }

            New-ItemProperty -Path $setting.Path -Name $setting.Name -PropertyType $setting.Type -Value $setting.Value -Force -ErrorAction SilentlyContinue | Out-Null
        } catch { }
    }

    Write-Progress -Activity "Aplicando otimizações adicionais" -Completed
    OK "Todas as otimizações aplicadas com sucesso!"
    Read-Host "`nPress ENTER to return."
}

# ===== CONFIGURAR MEMORIA RAM =====
function Apply-MemoryOptimizations {
    Clear-Host
    S "Aplicando otimizações de memória..."

    # [*] Ajustes no gerenciamento de memória
    $regCommands = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "ClearPageFileAtShutdown"; Value = 0 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "LargeSystemCache"; Value = 1 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "NonPagedPoolQuota"; Value = 0 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "NonPagedPoolSize"; Value = 0 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "PhysicalAddressExtension"; Value = 1 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "EnergyDriverPolicyVideo"; Value = 1 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "TimerBResolution"; Value = 1 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "TimerMinResolution"; Value = 1 }
    )

    $counter = 0
    $total = $regCommands.Count

    foreach ($reg in $regCommands) {
        $counter++
        Write-Progress -Activity "Aplicando otimizações de memória" `
                       -Status "$counter de $total chaves" `
                       -PercentComplete (($counter / $total) * 100)
        try {
            if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Force -ErrorAction SilentlyContinue
        } catch { }
    }
    Write-Progress -Activity "Aplicando otimizações de memória" -Completed

    # [X] Desativar compactação de memória
    try {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    } catch { }

    OK "Otimizações de memória aplicadas com sucesso."

    # [i] Otimização do SvcHost com base na RAM
    try {
        Write-Host ""
        I "Detecting RAM amount for SvcHost optimization..."

        $totalRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
        switch ($totalRamGB) {
            {$_ -le 4}  { $value = 4 * 1024 * 1024; $label = "4GB"; break }
            {$_ -le 8}  { $value = 8 * 1024 * 1024; $label = "8GB"; break }
            {$_ -le 12} { $value = 12 * 1024 * 1024; $label = "12GB"; break }
            {$_ -le 16} { $value = 16 * 1024 * 1024; $label = "16GB"; break }
            {$_ -le 24} { $value = 24 * 1024 * 1024; $label = "24GB"; break }
            {$_ -le 32} { $value = 32 * 1024 * 1024; $label = "32GB"; break }
            {$_ -le 48} { $value = 48 * 1024 * 1024; $label = "48GB"; break }
            {$_ -le 64} { $value = 64 * 1024 * 1024; $label = "64GB"; break }
            default     { $value = 128 * 1024 * 1024; $label = "128GB ou mais"; break }
        }

        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" `
                         -Name "SvcHostSplitThresholdInKB" `
                         -Value $value -Type DWord -Force -ErrorAction SilentlyContinue

        OK "SvcHost configurado com base em $label de RAM."
    } catch { }

    Read-Host "`nPress ENTER to return."
}

# ===== DESABILITA SERVICOS INUTEIS =====
function Disable-ServicesFunction {
    $serviceSettings = @(
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\TapiSrv"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\p2psvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\Wecsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SensorDataService"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SensrSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\StiSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\icssvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\DusmSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\MapsBroker"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\edgeupdate"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SensorService"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\shpamsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\svsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\CscService"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\ssh-agent"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\NfsClnt"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\wisvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\defragsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\autotimesvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\ALG"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\QWAVE"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc"; Name = "Start"; Type = "DWORD"; Value = 3 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\RetailDemo"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\lltdsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\TrkWks"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\Fax"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\SCardSvr"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc"; Name = "Start"; Type = "DWORD"; Value = 4 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name = "Status"; Type = "DWORD"; Value = 0 }
    )

    S "Aplicando configurações de serviços..."

    $total = $serviceSettings.Count
    $counter = 0

    foreach ($setting in $serviceSettings) {
        $counter++
        Write-Progress -Activity "Desativando serviços..." `
                       -Status "$counter de $total serviços" `
                       -PercentComplete (($counter / $total) * 100)

        try {
            if (-not (Test-Path $setting.Path)) {
                New-Item -Path $setting.Path -Force -ErrorAction SilentlyContinue | Out-Null
            }

            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -ErrorAction SilentlyContinue
        } catch { }
    }

    Write-Progress -Activity "Desativando serviços..." -Completed
    OK "$total serviços configurados com sucesso."
}




# ===== OTIMIZA SISTEMA =====
function Optimize-SystemFunction {
    S "Aplicando otimizações de sistema..."

    # === REG DELETEs ===
    S "Removendo tarefas agendadas do Microsoft Edge..."
    $edgeTasks = @(
        "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\MicrosoftEdgeUpdateTaskMachineCore",
        "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\MicrosoftEdgeUpdateTaskMachineUA"
    )

    $count = 0
    foreach ($task in $edgeTasks) {
        $count++
        Write-Progress -Activity "Removendo Edge Tasks" -Status "$count de $($edgeTasks.Count)" -PercentComplete (($count / $edgeTasks.Count) * 100)
        try {
            reg.exe delete $task /f 2>$null | Out-Null
        } catch {
            # Erro ignorado silenciosamente
        }
    }
    Write-Progress -Activity "Removendo Edge Tasks" -Completed
    OK "Tarefas do Edge removidas."


    # === REGISTRY EDITS POR CATEGORIA ===

    $registryCategories = @{
        "Telemetria, Diagnóstico e Privacidade" = @(
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"; Name = "ShowedToastAtLevel"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\current\device\System"; Name = "AllowExperimentation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\default\System\AllowExperimentation"; Name = "value"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "DoReport"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "LoggingDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting"; Name = "DoReport"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"; Name = "CdpSessionUserAuthzPolicy"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"; Name = "ShowedToastAtLevel"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "LogEnabling"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableThirdPartySuggestions"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"; Name = "ShowedToastAtLevel"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey"; Name = "EnableEventTranscript"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Policies\Microsoft\Assistance\Client\1.0"; Name = "NoExplicitFeedback"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Assistance\Client\1.0\Settings"; Name = "ImplicitFeedback"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\Windows"; Name = "DontShowUI"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\Windows"; Name = "Disabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\Windows"; Name = "LoggingDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\Windows"; Name = "DefaultConsent"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\Windows"; Name = "DefaultOverrideBehavior"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\Windows"; Name = "DontShowUI"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "AutoApproveOSDumps"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "Disabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "DontShowUI"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "LoggingDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "DefaultConsent"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Microsoft\Windows\Windows"; Name = "DefaultOverrideBehavior"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome\Recommended"; Name = "MetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome\Recommended"; Name = "DeviceMetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Policies\Google\Chrome\Recommended"; Name = "MetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Policies\Google\Chrome\Recommended"; Name = "DeviceMetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DeviceMetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Policies\Google\Chrome"; Name = "DeviceMetricsReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\Software\Policies\Microsoft\Windows\WDI\{9c5a40da-b965-4fc3-8781-88dd50a6299d}"; Name = "ScenarioExecutionEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\Software\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\Software\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "TimeStampInterval"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "IoPriority"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AppModel"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Circular"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CloudExperienceHostOobe"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DataMarket"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common"; Name = "qmEnable"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU:\Control"; Name = "Flags"; Type = "REG_SZ"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\Common\ClientTelemetry"; Name = "DisableTelemetry"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\Common\ClientTelemetry"; Name = "SendTelemetry"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common"; Name = "sendcustomerdata"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common\Feedback"; Name = "includescreenshot"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common"; Name = "updatereliabilitydata"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common\General"; Name = "shownfirstrunoptin"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common\General"; Name = "skydrivesigninoption"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Word\Options"; Name = "EnableLogging"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Outlook\Options\Mail"; Name = "EnableLogging"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM"; Name = "Enablelogging"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM"; Name = "EnableUpload"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM"; Name = "EnableFileObfuscation"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "accesssolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "olksolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "onenotesolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "pptsolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "projectsolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "publishersolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "visiosolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "wdsolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedapplications"; Name = "xlsolution"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedsolutiontypes"; Name = "agave"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedsolutiontypes"; Name = "appaddins"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedsolutiontypes"; Name = "comaddins"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedsolutiontypes"; Name = "documentfiles"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\OSM\preventedsolutiontypes"; Name = "templatefiles"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\SQMClient\IE"; Name = "CEIPEnable"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\AppV\CEIP"; Name = "CEIPEnable"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Messenger\Client"; Name = "CEIP"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows"; Name = "CEIPEnable"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Internet"; Name = "DisableCustomerImprovementProgram"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\DeviceHealthAttestationService"; Name = "DisableSendGenericDriverNotFoundToWER"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings"; Name = "DisableSendGenericDriverNotFoundToWER"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\DriverDatabase\Policies\Settings"; Name = "DisableSendGenericDriverNotFoundToWER"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports"; Name = "PreventHandwritingErrorReports"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC"; Name = "PreventHandwritingDataSharing"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\PCHealth\ErrorReporting"; Name = "ShowUI"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "StartupBoostEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "BackgroundModeEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Multimedia\Audio"; Name = "UserDuckingPreference"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"; Name = "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\QuietHours"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.AutoPlay"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.LowDisk"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Print.Notification"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.WiFiNetworkManager"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "Install{8A69D345-D564-463C-AFF1-A69D9E530F96}"; Type = "REG_DWORD"; Value = 5 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "TargetChannel{8A69D345-D564-463C-AFF1-A69D9E530F96}"; Type = "REG_SZ"; Value = "stable" },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "Update{8A69D345-D564-463C-AFF1-A69D9E530F96}"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "Install{4CCED17F-7852-4AFC-9E9E-C89D8795BDD2}"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "AutoUpdateCheckPeriodMinutes"; Type = "REG_DWORD"; Value = 43200 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "DownloadPreference"; Type = "REG_SZ"; Value = "cacheable" },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "UpdatesSuppressedStartHour"; Type = "REG_DWORD"; Value = 23 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "UpdatesSuppressedStartMin"; Type = "REG_DWORD"; Value = 48 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Update"; Name = "UpdatesSuppressedDurationMin"; Type = "REG_DWORD"; Value = 55 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.CapabilityAccess"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 }
        )

        "Sincronização de Configurações" = @(
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSettingSync"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableDesktopThemeSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisablePersonalizationSettingSync"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisablePersonalizationSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableStartLayoutSettingSync"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableStartLayoutSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSyncOnPaidNetwork"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableWebBrowserSettingSync"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableWebBrowserSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableWindowsSettingSync"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableWindowsSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 2 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync"; Name = "SyncPolicy"; Type = "REG_DWORD"; Value = 5 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\AppSync"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\DesktopTheme"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\PackageState"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\StartLayout"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableAppSyncSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableAppSyncSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableAppSyncSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableAppSyncSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableApplicationSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableApplicationSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableCredentialsSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableCredentialsSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableDesktopThemeSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync"; Name = "SyncPolicy"; Type = "REG_DWORD"; Value = 5 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSync"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSyncNGSC"; Type = "REG_DWORD"; Value = 1 }
        )

        "Serviços Desativados / Manutenção do Sistema" = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\FontCache"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\InstallService"; Name = "Start"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\OSRSS"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\sedsvc"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\SENS"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Themes"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\GoogleChromeElevationService"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\gupdate"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\gupdatem"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\diagsvc"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\DPS"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\diagnosticshub.standardcollector.service"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\WdiServiceHost"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\WdiSystemHost"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Spooler"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\PrintNotify"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\MapsBroker"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\System\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\System\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"; Name = "MaintenanceDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\edgeupdate"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\edgeupdatem"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "MaintenanceDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "NoLazyMode"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\WbioSrvc"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Type = "REG_DWORD"; Value = 38 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "TimeStampInterval"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"; Name = "IoPriority"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "ExitLatency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "ExitLatencyCheckEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "Latency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceDefault"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceFSVP"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyTolerancePerfOverride"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceScreenOffIR"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceVSyncEnabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "RtlCapabilityCheckLatency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\edgeupdate"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\edgeupdatem"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "MaintenanceDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "NoLazyMode"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "AlwaysOn"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\HolographicDevice"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\iclsClient"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\iclsProxy"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\LwtNetLog"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Mellanox-Kernel"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Microsoft-Windows-AssignedAccess-Trace"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Microsoft-Windows-Setup"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\NBSMBLOGGER"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\PEAuthLog"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\RdrLog"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SetupPlatform"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SetupPlatformTel"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SocketHeciServer"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SpoolerLogger"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SQMLogger"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\TileStore"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Tpm"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\TPMProvisioningService"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\UBPM"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WdiContextLog"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WFP-IPsec"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverIHVSession"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverIHVSessionRepro"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiSession"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WinPhoneCritical"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "CacheHashTableBucketSize"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "CacheHashTableSize"; Type = "REG_DWORD"; Value = 180 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "MaxCacheEntryTtlLimit"; Type = "REG_DWORD"; Value = "0000FA00" },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "MaxSOACacheEntryTtlLimit"; Type = "REG_DWORD"; Value = "0000012D" },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "NegativeCacheTime"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "NetFailureCacheTime"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "NegativeSOACacheTime"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\BITS"; Name = "EnableBITSMaxBandwidth"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\PeerDist\Service"; Name = "Enable"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\NetCache"; Name = "PeerCachingLatencyThreshold"; Type = "REG_DWORD"; Value = 268435456 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Network"; Name = "NC_AllowNetBridge_NLA"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control"; Name = "Policies"; Type = "REG_BINARY"; Value = "01000000020000000100000000000000020000000000000000000000000000002c0100003232030304000000040000000000000000000000840300002c01000000000000840300000001646464640000" },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\W3SVC"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; Name = "NoAutoUpdate"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"; Name = "DownloadMode"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKU\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings"; Name = "DownloadMode"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSync"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSyncNGSC"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableMeteredNetworkFileSync"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableLibrariesDefaultSaveToOneDrive"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Origin Client Service"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\Origin Web Helper Service"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"; Name = "GlobalUserDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\NVIDIA Corporation\NvTray"; Name = "StartOnLogin"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"; Name = "SearchOrderConfig"; Type = "REG_DWORD"; Value = 0 }
        )

         "Localização e Permissões" = @(
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "AllowSearchToUseLocation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocationScripting"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableSensors"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultGeolocationSetting"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultCookiesSetting"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultFileHandlingGuardSetting"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultFileSystemReadGuardSetting"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultFileSystemnv11GuardSetting"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultImagesSetting"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultPopupsSetting"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultSensorsSetting"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultSerialGuardSetting"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultWebBluetoothGuardSetting"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultWebUsbGuardSetting"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"; Name = "Value"; Type = "REG_SZ"; Value = "Allow" },
            @{ Path = "HKCU\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps"; Name = "AgentActivationEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps"; Name = "AgentActivationLastUsed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\downloadsFolder"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Cellcore"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"; Name = "value"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\Maps"; Name = "AutoUpdateEnabled"; Type = "REG_DWORD"; Value = 0 }
         )

         "Configurações de Interface e Aparência" = @(
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKCU\Control"; Name = "MinAnimate"; Type = "REG_SZ"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\DWM"; Name = "AlwaysHibernateThumbnails"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnablingTransparency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarMn"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "IconsOnly"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewShadow"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnableTransparency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"; Name = "AcceptedPrivacyPolicy"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\DWM"; Name = "UseDpiScaling"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\DWM"; Name = "EnableAeroPeek"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control Panel\Accessibility"; Name = "Sound on Activation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control Panel\Accessibility"; Name = "Warning Sounds"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control Panel\Accessibility\SlateLaunch"; Name = "LaunchAT"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\ScreenMagnifier"; Name = "FollowCaret"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\ScreenMagnifier"; Name = "FollowNarrator"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\ScreenMagnifier"; Name = "FollowMouse"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\ScreenMagnifier"; Name = "FollowFocus"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "IntonationPause"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "ReadHints"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "ErrorNotificationType"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "EchoChars"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "EchoWords"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NarratorHome"; Name = "MinimizeType"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NarratorHome"; Name = "AutoStart"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NoRoam"; Name = "EchoToggleKeys"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NoRoam"; Name = "DuckAudio"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NoRoam"; Name = "WinEnterLaunchEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NoRoam"; Name = "ScriptingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator\NoRoam"; Name = "OnlineServicesEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "NarratorCursorHighlight"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Narrator"; Name = "CoupleNarratorCursorKeyboard"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "AlwaysOn"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Background"; Type = "REG_SZ"; Value = "False" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "BackgroundPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Priority"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Scheduling"; Type = "REG_SZ"; Value = "High" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "SFIO"; Type = "REG_SZ"; Value = "High" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Latency"; Type = "REG_SZ"; Value = "True" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GPU"; Type = "REG_DWORD"; Value = 8 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Background"; Type = "REG_SZ"; Value = "False" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "BackgroundPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Priority"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Scheduling"; Type = "REG_SZ"; Value = "High" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "SFIO"; Type = "REG_SZ"; Value = "High" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Latency"; Type = "REG_SZ"; Value = "True" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackProgs"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"; Name = "StartupDelayInMSec"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Name = "ctfmon"; Type = "REG_SZ"; Value = "C:\Windows\System32\ctfmon.exe" },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DisallowShaking"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableBalloonTips"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ExtendedUIHoverTime"; Type = "REG_DWORD"; Value = 196608 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "DontPrettyPath"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop"; Name = "FFlags"; Type = "REG_DWORD"; Value = 1075839525 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderDocuments"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderDocuments_ProviderSet"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderDownloads"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderDownloads_ProviderSet"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderPersonalFolder"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderPersonalFolder_ProviderSet"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderFileExplorer"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; Name = "AllowPinnedFolderFileExplorer_ProviderSet"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "HomepageIsNewTabPage"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "HomepageLocation"; Type = "REG_SZ"; Value = "google.com" },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "NewTabPageLocation"; Type = "REG_SZ"; Value = "google.com" },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "EnableAutoTray"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation"; Name = "DisableStartupSound"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarMn"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackProgs"; Type = "REG_DWORD"; Value = 0 }
         )

         "Pesquisa, Cortana, Bing e Feed de Notícias" = @(
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "CortanaCapabilities"; Type = "REG_SZ"; Value = "" },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "IsAssignedAccess"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "IsWindowsHelloActive"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "ConnectedSearchPrivacy"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "ConnectedSearchSafeSearch"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\Software\Microsoft\PolicyManager\default\Experience\AllowCortana"; Name = "value"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\SearchCompanion"; Name = "DisableContentFileUpdates"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "AllowCloudSearch"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "AllowCortanaAboveLock"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "ConnectedSearchUseWeb"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "ConnectedSearchUseWebOverMeteredConnections"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "DisableWebSearch"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "DoNotUseWebResults"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "EnablingFeeds"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnablingActivityFeed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "EnableFeeds"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft"; Name = "AllowNewsAndInterests"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Edge"; Name = "StartupBoostEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Edge"; Name = "BackgroundModeEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDeviceSearchHistoryEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\Software\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\Software\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"; Name = "value"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "AllowCortana"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows"; Name = "DisableWebSearch"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "BackgroundAppGlobalToggle"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338393Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353694Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353696Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BackgroundAppGlobalToggle"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name = "EnableFeeds"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "SafeSearchMode"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsAADCloudSearchEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsMSACloudSearchEnabled"; Type = "REG_DWORD"; Value = 0 }
         )

          "Privacidade, Publicidade e Personalização" = @(
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338393Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353694Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353696Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control Panel\International\User Profile"; Name = "HttpAcceptLanguageOptOut"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost"; Name = "ContentEvaluation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost"; Name = "EnableWebContentEvaluation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"; Name = "NearShareChannelUserAuthzPolicy"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Input\TIPC"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control"; Name = "HttpAcceptLanguageOptOut"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost"; Name = "ContentEvaluation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\AppHost"; Name = "EnableWebContentEvaluation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\Software\Microsoft\Input\TIPC"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control"; Name = "HttpAcceptLanguageOptOut"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"; Name = "NearShareChannelUserAuthzPolicy"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableAppSyncSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableAppSyncSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableApplicationSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableApplicationSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableCredentialsSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableCredentialsSettingSyncUserOverride"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync"; Name = "DisableDesktopThemeSettingSync"; Type = "Reg_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common\Feedback"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Common"; Name = "qmEnable"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Office\16.0\Firstrun"; Name = "Disablemovie"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Windows"; Name = "DontSendAdditionalData"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU:\Control"; Name = "HttpAcceptLanguageOptOut"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"; Name = "HasAccepted"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContentEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-280815Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-202914Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "ContentDeliveryAllowed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "FeatureManagementEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "OemPreInstalledAppsEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "PreInstalledAppsEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "PreInstalledAppsEverEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RemediationRequired"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SilentInstalledAppsEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-310093Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338388Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353698Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338387Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-314563Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-314559Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Policies\Microsoft\Windows\CloudContent"; Name = "ConfigureWindowsSpotlight"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKCU\Software\Policies\Microsoft\Windows\CloudContent"; Name = "DisableThirdPartySuggestions"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsSpotlightFeatures"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement"; Name = "ScoobeSystemSettingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "AllowOnlineTips"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\PushToInstall"; Name = "DisablePushToInstall"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy"; Name = "HasAccepted"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics"; Name = "Value"; Type = "REG_SZ"; Value = "Deny" },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SilentInstalledAppsEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SystemPaneSuggestionsEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SoftLandingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "UserFeedbackAllowed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "SpellCheckServiceEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "SpellcheckEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"; Name = "EnableFeeds"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "ShowOrHideMostUsedApps"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "HideRecentlyAddedApps"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "HideRecentlyAddedApps"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Personalization\Settings"; Name = "AcceptedPrivacyPolicy"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\SOFTWARE\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Type = "REG_DWORD"; Value = 0 }
         )

          "Fontes e Renderização" = @(
            @{ Path = "HKCU\Control"; Name = "FontSmoothing"; Type = "REG_SZ"; Value = 2 },
            @{ Path = "HKCU\Control"; Name = "FontSmoothingType"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKCU\CONSOLE"; Name = "VirtualTerminalLevel"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\CONSOLE"; Name = "VirtualTerminalLevel"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GPU"; Type = "REG_DWORD"; Value = 8 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences"; Name = "DirectXUserGlobalSettings"; Type = "REG_SZ"; Value = "VRROptimizeEnable=0;" },
            @{ Path = "HKCU\Control Panel\Desktop"; Name = "LogPixels"; Type = "REG_DWORD"; Value = 150 },
            @{ Path = "HKCU\Control Panel\Desktop"; Name = "Win8DpiScaling"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control Panel\Desktop"; Name = "EnablePerProcessSystemDPI"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_ENABLE_RUNTIME_DRIVER_OPTIMIZATIONS"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_RESOURCE_ALIGNMENT"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D11_MULTITHREADED"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_MULTITHREADED"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D11_DEFERRED_CONTEXTS"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_DEFERRED_CONTEXTS"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D11_ALLOW_TILING"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D11_ENABLE_DYNAMIC_CODEGEN"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_ALLOW_TILING"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_CPU_PAGE_TABLE_ENABLED"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_HEAP_SERIALIZATION_ENABLED"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_MAP_HEAP_ALLOCATIONS"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\DirectX"; Name = "D3D12_RESIDENCY_MANAGEMENT_ENABLED"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\Dwm"; Name = "OverlayTestMode"; Type = "REG_DWORD"; Value = 0 }
         )

          "Segurança e Antivirus" = @(
            @{ Path = "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "HideSCAHealth"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnablingSmartScreen"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\safer\codeidentifiers"; Name = "authenticodeenabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoLowDiskSpaceChecks"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "LinkResolveIgnoreLinkInfo"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoResolveSearch"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoResolveTrack"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoInternetOpenWith"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoInstrumentation"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\MRT"; Name = "DontOfferThroughWUAU"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"; Name = "SaveZoneInformation"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Biometrics"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\MRT"; Name = "DontOfferThroughWUAU"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Biometrics"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\WbioSrvc"; Name = "Start"; Type = "REG_DWORD"; Value = 4 },
            @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments"; Name = "SaveZoneInformation"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger"; Name = "Start"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Credssp"; Name = "DebugLogLevel"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\MSMQ\Parameters\Security"; Name = "SecureDSCommunication"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\FTH"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Remote"; Name = "fAllowToGetHelp"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "DefaultPluginsSetting"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "SafeBrowsingProtectionLevel"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Google\Chrome"; Name = "SafeBrowsingExtendedReportingEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance"; Name = "Enabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "DisableAutomaticRestartSignOn"; Type = "REG_DWORD"; Value = 1 }
         )

         "Gerenciamento de Energia" = @(
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "HighPerformance"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "HighestPerformance"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "MinimumThrottlePercent"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "MaximumThrottlePercent"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "MaximumPerformancePercent"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "Class1InitialUnparkCount"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "InitialUnparkCount"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "EventProcessorEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "CStates"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy"; Name = "fDisablePowerManagement"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\PDC\Activators\Default\VetoPolicy"; Name = "EA:EnergySaverEngaged"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\PDC\Activators\28\VetoPolicy"; Name = "EA:PowerStateDischarging"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Misc"; Name = "DeviceIdlePolicy"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "PerfEnergyPreference"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPMinCores"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPMaxCores"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPMinCores1"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPMaxCores1"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CpLatencyHintUnpark1"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPDistribution"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CpLatencyHintUnpark"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "MaxPerformance1"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "MaxPerformance"; Type = "REG_DWORD"; Value = 100 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPDistribution1"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPHEADROOM"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; Name = "PowerThrottlingOff"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power\Policy\Settings\Processor"; Name = "CPCONCURRENCY"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\VideoSettings"; Name = "VideoQualityOnBattery"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "HistoricalCaptureOnBatteryAllowed"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "HistoricalCaptureOnWirelessDisplayAllowed"; Type = "REG_DWORD"; Value = 1 }
         )

          "Kernel e Performance" = @(
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "PriorityControl"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "DisableOverlappedExecution"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "TimeIncrement"; Type = "REG_DWORD"; Value = 15 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "QuantumLength"; Type = "REG_DWORD"; Value = 20 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"; Name = "ThreadDpcEnable"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Type = "REG_DWORD"; Value = 38 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "ExitLatency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "ExitLatencyCheckEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "Latency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceDefault"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceFSVP"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyTolerancePerfOverride"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceScreenOffIR"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "LatencyToleranceVSyncEnabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Power"; Name = "RtlCapabilityCheckLatency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultD3TransitionLatencyActivelyUsed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultD3TransitionLatencyIdleLongTime"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultD3TransitionLatencyIdleMonitorOff"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultD3TransitionLatencyIdleNoContext"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultD3TransitionLatencyIdleShortTime"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultD3TransitionLatencyIdleVeryLongTime"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceIdle0"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceIdle0MonitorOff"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceIdle1"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceIdle1MonitorOff"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceMemory"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceNoContext"; Type = "REG_DWORD"; Value = 0 }
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceNoContextMonitorOff"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceOther"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultLatencyToleranceTimerPeriod"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultMemoryRefreshLatencyToleranceActivelyUsed"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultMemoryRefreshLatencyToleranceMonitorOff"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "DefaultMemoryRefreshLatencyToleranceNoContext"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "Latency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "MaxIAverageGraphicsLatencyInOneBucket"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "MiracastPerfTrackGraphicsLatency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "MonitorLatencyTolerance"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "MonitorRefreshLatencyTolerance"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"; Name = "TransitionLatency"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "contigfileallocsize"; Type = "reg_dword"; Value = 1536 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "disabledeletenotification"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "filenamecache"; Type = "reg_dword"; Value = 1024 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "longpathsenabled"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsallowextendedcharacter8dot3rename"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsbugcheckoncorrupt"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsdisable8dot3namecreation"; Type = "reg_dword"; Value = 1 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsdisablecompression"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsdisableencryption"; Type = "reg_dword"; Value = 1 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsencryptpagingfile"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "ntfsmftzonereservation"; Type = "reg_dword"; Value = 3 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "pathcache"; Type = "reg_dword"; Value = 128 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "refsdisablelastaccessupdate"; Type = "reg_dword"; Value = 1 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "udfssoftwaredefectmanagement"; Type = "reg_dword"; Value = 0 },
            @{ Path = "hklm\system\currentcontrolset\control\filesystem"; Name = "win31filesystem"; Type = "reg_dword"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\System"; Name = "HiberbootEnabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched"; Name = "MaxOutstandingSends"; Type = "REG_DWORD"; Value = 1073741824 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched"; Name = "NonBestEffortLimit"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched"; Name = "TimerResolution"; Type = "REG_DWORD"; Value = 4294967295 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingConforming"; Name = "ServiceTypeBestEffort"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingConforming"; Name = "ServiceTypeControlledLoad"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingConforming"; Name = "ServiceTypeGuaranteed"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingConforming"; Name = "ServiceTypeNetworkControl"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingConforming"; Name = "ServiceTypeQualitative"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingNonConforming"; Name = "ServiceTypeBestEffort"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingNonConforming"; Name = "ServiceTypeControlledLoad"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingNonConforming"; Name = "ServiceTypeGuaranteed"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingNonConforming"; Name = "ServiceTypeNetworkControl"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\DiffservByteMappingNonConforming"; Name = "ServiceTypeQualitative"; Type = "REG_DWORD"; Value = 99 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\UserPriorityMapping"; Name = "ServiceTypeNonConforming"; Type = "REG_DWORD"; Value = 7 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\UserPriorityMapping"; Name = "ServiceTypeBestEffort"; Type = "REG_DWORD"; Value = 7 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\UserPriorityMapping"; Name = "ServiceTypeControlledLoad"; Type = "REG_DWORD"; Value = 7 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\UserPriorityMapping"; Name = "ServiceTypeGuaranteed"; Type = "REG_DWORD"; Value = 7 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\UserPriorityMapping"; Name = "ServiceTypeNetworkControl"; Type = "REG_DWORD"; Value = 7 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\Psched\UserPriorityMapping"; Name = "ServiceTypeQualitative"; Type = "REG_DWORD"; Value = 7 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Processor"; Name = "AllowPepPerfStates"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Processor"; Name = "Cstates"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Processor"; Name = "Capabilities"; Type = "REG_DWORD"; Value = 516198 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters"; Name = "PriorityBoost"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Control"; Name = "AutoEndTasks"; Type = "REG_SZ"; Value = 1 },
            @{ Path = "HKCU\Control"; Name = "HungAppTimeout"; Type = "REG_SZ"; Value = 1000 },
            @{ Path = "HKCU\Control"; Name = "WaitToKillAppTimeout"; Type = "REG_SZ"; Value = 2000 },
            @{ Path = "HKCU\Control"; Name = "LowLevelHooksTimeout"; Type = "REG_SZ"; Value = 1000 },
            @{ Path = "HKCU\Control"; Name = "MenuShowDelay"; Type = "REG_SZ"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control"; Name = "WaitToKillServiceTimeout"; Type = "REG_SZ"; Value = 2000 },
            @{ Path = "HKCU:\SYSTEM\GameConfigStore\Children\fefe78e0-cf54-411d-9154-04b8f488bea2"; Name = "Flags"; Type = "REG_DWORD"; Value = 529 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Background"; Type = "REG_SZ"; Value = "True" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Clock"; Type = "REG_DWORD"; Value = 10000 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GPU"; Type = "REG_DWORD"; Value = 12 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "Scheduling"; Type = "REG_SZ"; Value = "Medium" },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "SFIO"; Type = "REG_SZ"; Value = "Normal" },
            @{ Path = "HKLM\System\CurrentControlSet\Control\Session"; Name = "ProtectionMode"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "PassiveIntRealTimeWorkerPriority"; Type = "REG_DWORD"; Value = 18 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\KernelVelocity"; Name = "DisableFGBoostDecay"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "DpcWatchdogProfileOffset"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "DisableExceptionChainValidation"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "KernelSEHOPEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "DisableAutoBoost"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "DpcTimeout"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "ThreadDpcEnable"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "DpcWatchdogPeriod"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "InterruptSteeringDisabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session"; Name = "DistributeTimers"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0"; Name = "CapPercentage"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\HardCap0"; Name = "SchedulingType"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\Paused"; Name = "CapPercentage"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\Paused"; Name = "SchedulingType"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapFull"; Name = "CapPercentage"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapFull"; Name = "SchedulingType"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapLow"; Name = "CapPercentage"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\SoftCapLow"; Name = "SchedulingType"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\BackgroundDefault"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\Frozen"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\FrozenDNCS"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\FrozenDNK"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\FrozenPPLE"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\Paused"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\PausedDNK"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\Pausing"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\PrelaunchForeground"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\ThrottleGPUInterference"; Name = "IsLowPriority"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "CpuPriority"; Type = "REG_DWORD"; Value = 42 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "PerformancePriority"; Type = "REG_DWORD"; Value = 8 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "CpuPriorityControl"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "CpuPrioritySeperation"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "PowerLimitEnabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "PerformanceSpread"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "UnlimitedPerformance"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "CpuPriorityClass"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "PowerThrottlingOff"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "MaximumPerformanceEnabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "CpuMaxPerformance"; Type = "REG_DWORD"; Value = 256 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "CpuPriorityClass"; Type = "REG_DWORD"; Value = 8 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Critical"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Critical"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\CriticalNoUi"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\CriticalNoUi"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\EmptyHostPPLE"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\EmptyHostPPLE"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\High"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\High"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Low"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Low"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Lowest"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Lowest"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Medium"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\Medium"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\MediumHigh"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\MediumHigh"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\StartHost"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\StartHost"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\VeryHigh"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\VeryHigh"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\VeryLow"; Name = "BasePriority"; Type = "REG_DWORD"; Value = 82 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\VeryLow"; Name = "OverTargetPriority"; Type = "REG_DWORD"; Value = 50 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\IO\NoCap"; Name = "IOBandwidth"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Memory\NoCap"; Name = "CommitLimit"; Type = "REG_DWORD"; Value = 4294967295 },
            @{ Path = "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Memory\NoCap"; Name = "CommitTarget"; Type = "REG_DWORD"; Value = 4294967295 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "IoPriority"; Type = "REG_DWORD"; Value = 3 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "IoPriority"; Type = "REG_DWORD"; Value = 8 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GpuPriorityClass"; Type = "REG_DWORD"; Value = 8 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GpuPriority"; Type = "REG_DWORD"; Value = 42 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "IOPriorityClass"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GpuMaxPerformance"; Type = "REG_DWORD"; Value = 256 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "GpuAccelerating"; Type = "REG_DWORD"; Value = 256 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "HwSchMode"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKLM\SOFTWARE\Microsoft\Windows"; Name = "UseLargePages"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "Application"; Type = "REG_SZ"; Value = "%%i.exe" },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "Version"; Type = "REG_SZ"; Value = "1.0" },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "Protocol"; Type = "REG_SZ"; Value = "*" },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "Local"; Type = "REG_SZ"; Value = "*" },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "Remote"; Type = "REG_SZ"; Value = "*" },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "DSCP"; Type = "REG_SZ"; Value = 46 },
            @{ Path = "HKLM\Software\Policies\Microsoft\Windows\QoS\%%i"; Name = "Throttle"; Type = "REG_SZ"; Value = -1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AudioEncodingBitrate"; Type = "REG_DWORD"; Value = 128000 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AudioCaptureEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "CustomVideoEncodingBitrate"; Type = "REG_DWORD"; Value = 4000000 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "CustomVideoEncodingHeight"; Type = "REG_DWORD"; Value = 720 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "CustomVideoEncodingWidth"; Type = "REG_DWORD"; Value = 1280 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "HistoricalBufferLength"; Type = "REG_DWORD"; Value = 30 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "HistoricalBufferLengthUnit"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "HistoricalCaptureEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VideoEncodingBitrateMode"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VideoEncodingResolutionMode"; Type = "REG_DWORD"; Value = 2 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VideoEncodingFrameRateMode"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "EchoCancellationEnabled"; Type = "REG_DWORD"; Value = 1 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "CursorCaptureEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleGameBar"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleGameBar"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKSaveHistoricalVideo"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMSaveHistoricalVideo"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleRecording"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleRecording"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKTakeScreenshot"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMTakeScreenshot"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleRecordingIndicator"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleRecordingIndicator"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleMicrophoneCapture"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleMicrophoneCapture"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleCameraCapture"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleCameraCapture"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKToggleBroadcast"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "VKMToggleBroadcast"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "MicrophoneCaptureEnabled"; Type = "REG_DWORD"; Value = 0 },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "SystemAudioGain"; Type = "REG_BINARY"; Value = "10,27,00,00,00,00,00,00" },
            @{ Path = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "MicrophoneGain"; Type = "REG_BINARY"; Value = "10,27,00,00,00,00,00,00" }
         )

    }

    ShowHeader "Settings by category"
    I "Answer (S) to apply or (N) to skip each category below"
    Write-Host ""

    foreach ($category in $registryCategories.Keys) {
        do {
            # Mostra a pergunta com destaque, com a categoria já no formato "Segurança e Antivirus (S/N)"
            $answer = Read-Host -Prompt ("$category (S/N)")
        } while ($answer -notmatch '^[SsNn]')

        if ($answer -match '^[Ss]') {
            Write-Host ""
            S "Applying: $category"
            Write-Host ""

            $edits = $registryCategories[$category]
            $counter = 0
            $total = $edits.Count
            foreach ($reg in $edits) {
                $counter++
                Write-Progress -Activity "Aplicando $category" -Status "$counter de $total" -PercentComplete (($counter / $total) * 100)
                try {
                    reg.exe add $reg.Path /v $reg.Name /t $reg.Type /d $reg.Value /f 2>$null | Out-Null
                } catch {
                    # Erro ignorado silenciosamente
                }
            }
            Write-Progress -Activity "Aplicando $category" -Completed
            OK "Configurações de '$category' aplicadas.`n"
        } else {
            I "Pulando categoria: $category`n"
        }
    }


    Write-Host ""
    OK "All system optimizations applied successfully!"
    Write-Host ""
}

# ===== OTIMIZA GPU (DETECCAO AUTOMATICA) =====
function Invoke-GpuOptimize {
    Clear-Host
    I "Detectando GPU..."

    $gpuInfo = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon' })

    if ($gpuInfo.Count -eq 0) {
        X "Nenhuma GPU NVIDIA ou AMD detectada neste sistema."
        return
    }

    $nvidiaCount = @($gpuInfo | Where-Object { $_.Name -match 'NVIDIA' }).Count
    $amdCount = @($gpuInfo | Where-Object { $_.Name -match 'AMD|Radeon' }).Count

    foreach ($gpu in $gpuInfo) {
        if ($gpu.Name -match 'NVIDIA') {
            OK "GPU NVIDIA detectada: $($gpu.Name)"
        } elseif ($gpu.Name -match 'AMD|Radeon') {
            OK "GPU AMD detectada: $($gpu.Name)"
        }
    }

    Write-Host ""

    if ($nvidiaCount -gt 0) {
        Invoke-NvidiaOptimize
    }

    if ($amdCount -gt 0) {
        Invoke-AmdOptimize
    }
}

# ===== OTIMIZA NVIDIA =====
function Invoke-NvidiaOptimize {
    Clear-Host
    S "Aplicando otimizações NVIDIA..."

    # ---------- ETAPA 1 ----------
    ShowHeader "Step 1/3: Configurações básicas via NVIDIA-SMI"
    $nvPath = "C:\Program Files\NVIDIA Corporation\NVSMI"
    if (-Not (Test-Path $nvPath)) {
        Write-Warning "Caminho NVIDIA NVSMI não encontrado: $nvPath"
    } else {
        Push-Location $nvPath
        try {
            & .\nvidia-smi.exe -acp 0
            & .\nvidia-smi.exe -e 1
            OK "NVIDIA-SMI configurado com sucesso!"
        } catch {
            Write-Error "[X] Erro ao executar NVIDIA-SMI: $_"
        }
        Pop-Location
    }

    Start-Sleep -Seconds 2  # Aguarda antes da próxima etapa

    # ---------- ETAPA 2 ----------
    ShowHeader "Step 2/3: Desabilitando DynamicPstate"
    $devices = (wmic path Win32_VideoController get PNPDeviceID | Select-String "PCI\\VEN_").Matches.Value

    foreach ($device in $devices) {
        $regPath = "HKLM:\SYSTEM\ControlSet001\Enum\$device"
        try {
            $driverValue = (Get-ItemProperty -Path $regPath -Name Driver -ErrorAction Stop).Driver
            if ($driverValue -match "^{.*}$") {
                $classRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$driverValue"
                New-ItemProperty -Path $classRegPath -Name "DisableDynamicPstate" -PropertyType DWord -Value 1 -Force | Out-Null
                OK "DisableDynamicPstate=1 aplicado em $classRegPath"
            }
        } catch {
            Write-Warning "[*] Não foi possível acessar o registro para $device"
        }
    }

    Start-Sleep -Seconds 2  # Aguarda antes da próxima etapa

    # ---------- ETAPA 3 ----------
    ShowHeader "Step 3/3: Otimizações avançadas de registro e tarefas agendadas"
    try {
        # Desabilitar tarefas de crash report
        $tasks = @(
            "NvTmRepCrashReport2{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvTmRepCrashReport3{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
            "NvTmRepCrashReport4{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"
        )
        foreach ($task in $tasks) { schtasks /change /disable /tn $task >$null 2>&1 }

        # Configurações de registro
        $regSettings = @(
            @{ Path = "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"; Name = "OptInOrOutPreference"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup"; Name = "SendTelemetryData"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "DisablePreemption"; Type = "DWORD"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "DisableCudaContextPreemption"; Type = "DWORD"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableCEPreemption"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "DisablePreemptionOnS3S4"; Type = "DWORD"; Value = 1 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "ComputePreemption"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidGfxPreemption"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidGfxPreemptionVGPU"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidBufferPreemptionForHighTdrTimeout"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableMidBufferPreemption"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Services\nvlddmkm"; Name = "EnableAsyncMidBufferPreemption"; Type = "DWORD"; Value = 0 },
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\GraphicsDrivers\Scheduler"; Name = "EnablePreemption"; Type = "DWORD"; Value = 0 }
        )

        $counter = 0
        $total = $regSettings.Count

        foreach ($setting in $regSettings) {
            $counter++
            if (-not (Test-Path $setting.Path)) { New-Item -Path $setting.Path -Force | Out-Null }
            New-ItemProperty -Path $setting.Path -Name $setting.Name -PropertyType $setting.Type -Value $setting.Value -Force | Out-Null
            Write-Progress -Activity "Aplicando otimizações NVIDIA..." `
                           -Status "$counter de $total chaves configuradas" `
                           -PercentComplete (($counter / $total) * 100)
        }

        Write-Progress -Activity "Aplicando otimizações NVIDIA..." -Completed
        OK "Otimizações NVIDIA aplicadas com sucesso!"

    } catch {
        X "Erro ao aplicar otimizações NVIDIA: $_"
    }

    Read-Host "`nPress ENTER to return."
}

# ===== OTIMIZA PROCESSADOR AMD =====
function Invoke-AmdOptimize {
    Clear-Host
    S "Aplicando otimizações AMD..."

    try {
        $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"

        # Lista de configurações de registro
        $regSettings = @(
            @{ Name = "DisableUVDPowerGatingDynamic"; Type = "DWORD"; Value = 1 },
            @{ Name = "AllowSnapshot"; Type = "DWORD"; Value = 0 },
            @{ Name = "DisableDrmdmaPowerGating"; Type = "DWORD"; Value = 1 },
            @{ Name = "EnableUlps"; Type = "DWORD"; Value = 0 },
            @{ Name = "AllowRSOverlay"; Type = "String"; Value = "false" },
            @{ Name = "AutoColorDepthReduction_NA"; Type = "DWORD"; Value = 0 },
            @{ Name = "AllowSubscription"; Type = "DWORD"; Value = 0 },
            @{ Name = "DisableVCEPowerGating"; Type = "DWORD"; Value = 1 },
            @{ Name = "DisableDMACopy"; Type = "DWORD"; Value = 1 },
            @{ Name = "AllowSkins"; Type = "String"; Value = "false" },
            @{ Name = "PP_GPUPowerDownEnabled"; Type = "DWORD"; Value = 0 },
            @{ Name = "DisableBlockWrite"; Type = "DWORD"; Value = 0 },
            @{ Name = "StutterMode"; Type = "DWORD"; Value = 0 },
            @{ Name = "DisablePowerGating"; Type = "DWORD"; Value = 1 }
        )

        # Criar o caminho do registro se não existir
        if (-not (Test-Path $basePath)) {
            New-Item -Path $basePath -Force | Out-Null
            I "Registry path created: $basePath"
        }

        $counter = 0
        $total = $regSettings.Count

        # Aplicar cada chave de registro com progresso
        foreach ($setting in $regSettings) {
            $counter++
            New-ItemProperty -Path $basePath -Name $setting.Name -PropertyType $setting.Type -Value $setting.Value -Force | Out-Null
            Write-Progress -Activity "Aplicando otimizações AMD..." `
                           -Status "$counter de $total chaves configuradas" `
                           -PercentComplete (($counter / $total) * 100)
        }

        Write-Progress -Activity "Aplicando otimizações AMD..." -Completed
        OK "Otimizações AMD aplicadas com sucesso!"
    }
    catch {
        X "Erro ao aplicar otimizações AMD: $_"
    }

    Read-Host "`nPress ENTER to return."
}


# ===== FUNÇÃO DE REMOÇÃO DE INTEGRAÇÕES =====
function Invoke-AppIntegrationKeys {
    # Lista consolidada de chaves de registro de integração de apps
    $Keys = @(
        # Background Tasks
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy",
        # Launch
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy",
        # PreInstalledConfigTask
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.PreInstalledConfigTask\PackageId\Microsoft.MicrosoftOfficeHub_17.7909.7600.0_x64__8wekyb3d8bbwe",
        # Protocol
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy",
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy",
        # Share Target
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
    )
    $total = $Keys.Count
    $counter = 0
    S "Starting app integration cleanup..."
    foreach ($Key in $Keys) {
        $counter++
        Write-Progress -Activity "Removendo chaves de integração..." `
                       -Status "$counter de $total" `
                       -PercentComplete (($counter / $total) * 100)
        if (Test-Path -Path $Key) {
            try {
                Remove-Item -Path $Key -Recurse -Force -ErrorAction Stop
                OK "Removido: $($Key)"
            }
            catch { # <--- Adicionei o bloco 'catch' aqui
                X "Erro ao remover $($Key): $($_.Exception.Message)"
            }
        }
    }
    Write-Progress -Activity "Removendo chaves de integração..." -Completed
    OK "Integration cleanup completed."
}


# ===== APLICA PRIVACIDADE =====
function Invoke-ProtectPrivacy {
    S "Aplicando proteções de privacidade..."

    try {
        # === Disable Windows Feedback Experience ===
        $Advertising = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (Test-Path $Advertising) { Set-ItemProperty -Path $Advertising -Name "Enabled" -Value 0 }

        # === Disable Cortana via Windows Search policy ===
        $Search = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        if (Test-Path $Search) { Set-ItemProperty -Path $Search -Name "AllowCortana" -Value 0 }

        # === Disable Cortana user data collection ===
        $Cortana1 = "HKCU:\SOFTWARE\Microsoft\Personalization\Settings"
        $Cortana2 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"
        $Cortana3 = "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore"

        if (!(Test-Path $Cortana1)) { New-Item -Path $Cortana1 | Out-Null }
        Set-ItemProperty -Path $Cortana1 -Name "AcceptedPrivacyPolicy" -Value 0

        if (!(Test-Path $Cortana2)) { New-Item -Path $Cortana2 | Out-Null }
        Set-ItemProperty -Path $Cortana2 -Name "RestrictImplicitTextCollection" -Value 1
        Set-ItemProperty -Path $Cortana2 -Name "RestrictImplicitInkCollection" -Value 1

        if (!(Test-Path $Cortana3)) { New-Item -Path $Cortana3 | Out-Null }
        Set-ItemProperty -Path $Cortana3 -Name "HarvestContacts" -Value 0

        # === Disable Web Search in Start Menu ===
        if (!(Test-Path $Search)) { New-Item -Path $Search | Out-Null }
        Set-ItemProperty -Path $Search -Name "DisableWebSearch" -Value 1
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0

        # === Disable telemetry & data collection ===
        $DataPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
        )
        foreach ($path in $DataPaths) {
            if (Test-Path $path) { Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 }
        }

        # === Disable location tracking ===
        $SensorState = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
        $LocationConfig = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"
        if (!(Test-Path $SensorState)) { New-Item -Path $SensorState | Out-Null }
        Set-ItemProperty -Path $SensorState -Name "SensorPermissionState" -Value 0
        if (!(Test-Path $LocationConfig)) { New-Item -Path $LocationConfig | Out-Null }
        Set-ItemProperty -Path $LocationConfig -Name "Status" -Value 0

        # === Disable live tiles ===
        $Live = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
        if (!(Test-Path $Live)) { New-Item -Path $Live | Out-Null }
        Set-ItemProperty -Path $Live -Name "NoTileApplicationNotification" -Value 1

        # === Disable People icon on Taskbar ===
        $People = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"
        if (Test-Path $People) { Set-ItemProperty -Path $People -Name "PeopleBand" -Value 0 }

        # === Disable scheduled tasks ===
        $tasks = @(
            "XblGameSaveTaskLogon",
            "XblGameSaveTask",
            "Consolidator",
            "UsbCeip",
            "DmClient",
            "DmClientOnScenarioDownload"
        )
        foreach ($task in $tasks) {
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
            schtasks /change /disable /tn $task 2>$null
        }

        # === Disable Diagnostics Tracking Service ===
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled

        # === Remove CloudStore ===
        $CloudStore = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore"
        if (Test-Path $CloudStore) {
            S "Reiniciando Explorer para remover CloudStore..."
            Stop-Process -Name "Explorer" -Force
            Remove-Item -Path $CloudStore -Recurse -Force
            Start-Process "Explorer.exe"
        }

        # === Prevent Edge from taking over as default PDF viewer ===
        $pdfPaths = @(
            "HKLM:\SOFTWARE\Classes\.pdf",
            "HKLM:\SOFTWARE\Classes\.pdf\OpenWithProgids",
            "HKLM:\SOFTWARE\Classes\.pdf\OpenWithList"
        )
        foreach ($path in $pdfPaths) {
            if (!(Get-ItemProperty -Path $path -Name "NoOpenWith" -ErrorAction SilentlyContinue)) {
                New-ItemProperty -Path $path -Name "NoOpenWith" -PropertyType DWord -Value 1 -Force | Out-Null
            }
            if (!(Get-ItemProperty -Path $path -Name "NoStaticDefaultVerb" -ErrorAction SilentlyContinue)) {
                New-ItemProperty -Path $path -Name "NoStaticDefaultVerb" -PropertyType DWord -Value 1 -Force | Out-Null
            }
        }

        $Edge = "HKLM:\SOFTWARE\Classes\AppXd4nrz8ff68srnhf9t5a8sbjyar1cr723_"
        if (Test-Path $Edge) {
            Set-ItemProperty -Path $Edge -Name "NoOpenWith" -Value 1 -Force
        }

        OK "Proteções de privacidade aplicadas com sucesso!"
    }
    catch {
        Write-Error "Erro ao aplicar proteções de privacidade: $_"
    }
}

# ====== FUNÇÕES WINDOWS 11 TWEAKS ======

function Invoke-OldMenu {
    Clear-Host
    I "Aplicando menu de contexto clássico (Old Menu)..."
    try {
        $basePath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"

        if (-not (Test-Path $basePath)) {
            New-Item -Path $basePath -Force | Out-Null
            I "Registry path created: $basePath"
        }

        # Definir valor padrão vazio
        Set-ItemProperty -Path $basePath -Name "(default)" -Value "" -Force
        OK "Old Menu aplicado com sucesso!"
    }
    catch {
        X "Erro ao aplicar Old Menu: $_"
    }
}

function Invoke-RevertOldMenu {
    Clear-Host
    S "Revertendo para menu de contexto padrão do Windows 11..."
    try {
        $basePath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
        if (Test-Path $basePath) {
            Remove-Item -Path $basePath -Recurse -Force
            I "Chave removida: $basePath"
        }
        OK "Menu revertido para padrão do Windows 11!"
    }
    catch {
        X "Erro ao reverter Old Menu: $_"
    }
}

function Invoke-OldClassicAltTab {
    Clear-Host
    S "Aplicando Alt+Tab clássico..."
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

        New-ItemProperty -Path $regPath -Name "AltTabSettings" -PropertyType DWord -Value 1 -Force | Out-Null
        OK "Classic Alt+Tab aplicado com sucesso!"
    }
    catch {
        X "Erro ao aplicar Classic Alt+Tab: $_"
    }
}

function Invoke-RevertClassicAltTab {
    Clear-Host
    S "Revertendo Alt+Tab para o estilo moderno..."
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

        if (Get-ItemProperty -Path $regPath -Name "AltTabSettings" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regPath -Name "AltTabSettings" -Force
            I "AltTabSettings value removed"
        }
        OK "Alt+Tab revertido para o padrão moderno!"
    }
    catch {
        X "Erro ao reverter Classic Alt+Tab: $_"
    }
}

# BRAVE ========
function Invoke-BraveBloatware {
    Clear-Host
    S "Aplicando otimizações no Brave..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveRewardsDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveWalletDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveVPNDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveAIChatEnabled"; Value = 0; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Brave"
}

function Revert-BraveBloatware {
    Clear-Host
    S "Revertendo otimizações no Brave..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveRewardsDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveWalletDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveAIChatEnabled"; Value = 1; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Brave (Reversão)"
}

# CHROME =======
function Invoke-ChromeBloatware {
    Clear-Host
    I "Aplicando otimizações no Chrome..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "SearchSuggestEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "PromotionalTabsEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Value = 0; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Chrome"
}

function Revert-ChromeBloatware {
    Clear-Host
    I "Reverting Chrome optimizations..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "SyncDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "TranslateEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "SearchSuggestEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "PromotionalTabsEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Value = 1; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Chrome (Reversão)"
}

# EDGE =========
function Invoke-EdgeBloatware {
    Clear-Host
    S "Aplicando otimizações no Edge..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SyncDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WalletEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WebWidgetEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HideFirstRunExperience"; Value = 1; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Edge"
}

function Revert-EdgeBloatware {
    Clear-Host
    S "Revertendo otimizações no Edge..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SyncDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WalletEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WebWidgetEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HideFirstRunExperience"; Value = 0; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Edge (Reversão)"
}

# FIREFOX ======
function Invoke-FirefoxBloatware {
    Clear-Host
    S "Aplicando otimizações no Firefox..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableTelemetry"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisablePocket"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableFirefoxStudies"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "SearchSuggestEnabled"; Value = 0; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Firefox"
}

function Revert-FirefoxBloatware {
    Clear-Host
    S "Revertendo otimizações no Firefox..."
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableTelemetry"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisablePocket"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableFirefoxStudies"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "SearchSuggestEnabled"; Value = 1; Type = "DWORD" }
    )
    Apply-RegistryTweaks -settings $settings -title "Firefox (Reversão)"
}

# ===== BROWSER GENERIC FUNCTION ========
function Apply-RegistryTweaks {
    param (
        [array]$settings,
        [string]$title
    )

    $counter = 0
    $total = $settings.Count

    foreach ($setting in $settings) {
        $counter++
        Write-Progress -Activity "Aplicando Tweaks no $title..." `
                       -Status "$counter de $total ajustes" `
                       -PercentComplete (($counter / $total) * 100)
        try {
            if (-not (Test-Path $setting.Path)) {
                New-Item -Path $setting.Path -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Force -ErrorAction SilentlyContinue
        } catch { }
    }

    Write-Progress -Activity "Aplicando Tweaks no $title..." -Completed
    OK "Operação concluída para $title."
    Read-Host "`nPress ENTER to return."
}

# ===== Função para aplicar menu de contexto com Tweaks =====
function Invoke-ImproveContextTweakMenu {
    Clear-Host
    S "Aplicando menus de contexto de Tweaks..."

    $base = "HKLM:\Software\Classes\Directory\Background\shell"

    # Remove menus antigos se existirem
    foreach ($menu in @("FlushDNS", "RestartExplorer", "PowerMode", "ExplorerTools")) {
        $path = "$base\$menu"
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ==== MENU FLUSH DNS ====
    $dns = "$base\FlushDNS"
    New-Item -Path $dns -Force | Out-Null
    Set-ItemProperty -Path $dns -Name "MUIVerb" -Value "Flush DNS Cache"
    Set-ItemProperty -Path $dns -Name "Icon" -Value "shell32.dll,31"
    New-ItemProperty -Path $dns -Name "HasLUAShield" -Value "" -PropertyType String -Force | Out-Null
    New-Item -Path "$dns\command" -Force | Out-Null
    Set-ItemProperty -Path "$dns\command" -Name "(Default)" -Value 'powershell.exe -WindowStyle Hidden -Command "ipconfig /flushdns"'

    # ==== MENU RESTART EXPLORER ====
    $expRestart = "$base\RestartExplorer"
    New-Item -Path $expRestart -Force | Out-Null
    Set-ItemProperty -Path $expRestart -Name "MUIVerb" -Value "Restart Explorer"
    Set-ItemProperty -Path $expRestart -Name "Icon" -Value "shell32.dll,137"
    New-ItemProperty -Path $expRestart -Name "HasLUAShield" -Value "" -PropertyType String -Force | Out-Null
    New-Item -Path "$expRestart\command" -Force | Out-Null
    Set-ItemProperty -Path "$expRestart\command" -Name "(Default)" -Value 'powershell.exe -WindowStyle Hidden -Command "taskkill /f /im explorer.exe; Start-Sleep -Seconds 1; Start-Process explorer.exe"'

    OK "Menus aplicados com sucesso!"

    # Reinicia o Explorer para refletir mudanças
    Write-Host ""
    S "Restarting Explorer to apply changes..."
    Start-Sleep -Seconds 1
    taskkill /f /im explorer.exe | Out-Null
    Start-Sleep -Seconds 1
    Start-Process explorer.exe
}

# ===== Função para reverter todos os menus de contexto de Tweaks =====
function Invoke-RevertContextMenu {
    Clear-Host
    S "Removendo menus de contexto de Tweaks..."

    $base = "HKLM:\Software\Classes\Directory\Background\shell"

    # Lista de todos os menus que foram criados
    $menus = @("FlushDNS", "PowerMode", "ExplorerTools")

    foreach ($menu in $menus) {
        $path = "$base\$menu"
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                OK "Menu '$menu' removido."
            } catch {
                Write-Warning "[*] Falha ao remover menu '$menu': $_"
            }
        } else {
            I "Menu $menu does not exist or was already removed."
        }
    }

    # Reinicia o Explorer para aplicar mudanças
    Write-Host ""
    S "Restarting Explorer to apply changes..."
    Start-Sleep -Seconds 1
    taskkill /f /im explorer.exe | Out-Null
    Start-Sleep -Seconds 1
    Start-Process explorer.exe
}

# ===== INICIAR SCRIPT =====
Show-MainMenu
