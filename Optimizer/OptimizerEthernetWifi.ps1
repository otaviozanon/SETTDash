Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[X] Run as Administrator required!" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

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


$BackupPath = "$env:USERPROFILE\Desktop\NetworkOptimizer_Backup.json"
$LogPath = "$env:USERPROFILE\Desktop\NetworkOptimizer_Log.txt"
$global:ChangesLog = [System.Collections.ArrayList]::new()
$global:LogBuilder = [System.Text.StringBuilder]::new()

function Wait-KeyPress {
    param([string]$Message = "`nPress ENTER to continue...")
    Write-Host $Message -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Função para salvar log em arquivo
function Save-LogFile {
    if ($global:LogBuilder.Length -gt 0) {
        try {
            $global:LogBuilder.ToString() | Out-File -FilePath $LogPath -Append -Encoding UTF8
            I "Log saved: $LogPath"
        } catch {
            Warn "Could not save log: $_"
        }
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    [void]$global:LogBuilder.AppendLine($logEntry)

    switch ($Type) {
        "SUCCESS" { OK $Message }
        "ERROR"   { X $Message }
        "WARNING" { Warn $Message }
    }
}

# Função para criar backup das configurações atuais
function Backup-AdapterSettings {
    param([string]$AdapterName)

    Write-Log "Criando backup das configurações de: $AdapterName" "INFO"

    try {
        $currentSettings = Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop

        $backupData = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            AdapterName = $AdapterName
            Settings = @($currentSettings | ForEach-Object {
                @{
                    DisplayName = $_.DisplayName
                    RegistryKeyword = $_.RegistryKeyword
                    DisplayValue = $_.DisplayValue
                    RegistryValue = $_.RegistryValue
                }
            })
        }

        # Carrega backups existentes ou cria novo array
        $allBackups = [System.Collections.ArrayList]::new()
        if (Test-Path $BackupPath) {
            $existingBackups = Get-Content $BackupPath -Raw | ConvertFrom-Json
            if ($existingBackups -is [Array]) {
                foreach ($backup in $existingBackups) {
                    [void]$allBackups.Add($backup)
                }
            } else {
                [void]$allBackups.Add($existingBackups)
            }
        }

        # Adiciona novo backup ao array
        [void]$allBackups.Add($backupData)

        # Salva todos os backups
        $allBackups | ConvertTo-Json -Depth 10 -Compress | Set-Content $BackupPath -Force

        Write-Log "Backup created: $BackupPath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Backup error: $_" "ERROR"
        return $false
    }
}

# Função para aplicar configuração com log (otimizada)
function Set-NetworkProperty {
    param(
        [string]$AdapterName,
        [string[]]$PropertyNames,
        [string]$Value,
        [hashtable]$PropertyCache
    )

    foreach ($propName in $PropertyNames) {
        if (-not $PropertyCache.ContainsKey($propName)) { continue }
        $property = $PropertyCache[$propName]
        $effectiveValue = $Value

        # --- Resolve "Maximum" para o maximo suportado pelo adaptador ---
        if ($Value -eq "Maximum") {
            $maxVal = $null
            # Tenta ValidDisplayValues
            if ($property.ValidDisplayValues) {
                $nums = @($property.ValidDisplayValues | ForEach-Object {
                    $n = 0; if ([int]::TryParse($_, [ref]$n)) { $n }
                } | Where-Object { $_ -gt 0 } | Sort-Object -Descending)
                if ($nums.Count -gt 0) { $maxVal = $nums[0] }
            }
            # Tenta ValidRegistryValues
            if (-not $maxVal -and $property.ValidRegistryValues) {
                $nums = @($property.ValidRegistryValues | ForEach-Object {
                    $n = 0; if ([int]::TryParse($_, [ref]$n)) { $n }
                } | Where-Object { $_ -gt 0 } | Sort-Object -Descending)
                if ($nums.Count -gt 0) { $maxVal = $nums[0] }
            }
            # Ultimo recurso: tenta valor enorme e extrai range do erro
            if (-not $maxVal) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $property.RegistryKeyword -RegistryValue @("99999") -ErrorAction Stop
                    $maxVal = 99999
                } catch {
                    $err = $_.Exception.Message
                    if ($err -match '(\d+)\s*[-–]\s*(\d+)') {
                        $maxVal = [int]$Matches[2]
                    }
                }
            }
            $effectiveValue = [string]$maxVal
            # Fallback seguro: mantem valor atual se nao conseguiu resolver
            if (-not $effectiveValue -or $effectiveValue -eq '0') {
                $effectiveValue = $property.DisplayValue
            }
        }

        $oldValue = $property.DisplayValue

        # --- Encontra valor de exibicao localizado (ex: "Enabled" -> "Activado" em PT) ---
        $localizedValue = $effectiveValue
        $candidates = @($effectiveValue)
        switch ($effectiveValue) {
            "Enabled"  { $candidates += @("Activado", "Ativado", "Enable", "Rx & Tx Enabled", "Rx & Tx Activados") }
            "Disabled" { $candidates += @("Desactivado", "Desativado", "Disable", "Desactivados", "Desativados") }
            "Auto"     { $candidates += @("Automático") }
            "Auto Negotiation" { $candidates += @("Auto Negociação") }
            "10 Mbps First"    { $candidates += @("10 Mbps Primeiro") }
        }
        foreach ($c in $candidates) {
            if ($property.ValidDisplayValues -contains $c) { $localizedValue = $c; break }
        }
        # Correspondencia parcial para valores booleanos (ex: "Rx & Tx Activados")
        if ($localizedValue -eq $effectiveValue) {
            $subterms = switch ($effectiveValue) {
                "Enabled"  { @("*Activ*", "*Enabl*", "*activa*") }
                "Disabled" { @("*Desactiv*", "*Desativ*", "*Disabl*") }
                default    { @() }
            }
            foreach ($st in $subterms) {
                foreach ($dv in $property.ValidDisplayValues) {
                    if ($dv -like $st) { $localizedValue = $dv; break }
                }
                if ($localizedValue -ne $effectiveValue) { break }
            }
        }

        # Pula se ja estiver no valor desejado
        if ($property.DisplayValue -eq $localizedValue) {
            Write-Host "  - " -ForegroundColor DarkGray -NoNewline
            Write-Host "$propName : " -ForegroundColor DarkGray -NoNewline
            Write-Host "$oldValue -> $oldValue" -ForegroundColor DarkGray
            [void]$global:LogBuilder.AppendLine("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [INFO]   - $propName : $oldValue -> $oldValue")
            continue
        }

        # --- Tentativa 1: DisplayValue localizado ---
        try {
            Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $propName -DisplayValue $localizedValue -ErrorAction Stop -WarningAction SilentlyContinue
            [void]$global:ChangesLog.Add(@{
                Property = $propName; OldValue = $oldValue; NewValue = $effectiveValue; Status = "SUCCESS"
            })
            Write-Host "  [+] " -ForegroundColor Green -NoNewline
            Write-Host "$propName : " -ForegroundColor DarkGray -NoNewline
            Write-Host "$oldValue -> " -ForegroundColor Yellow -NoNewline
            Write-Host $effectiveValue -ForegroundColor Green
            [void]$global:LogBuilder.AppendLine("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [SUCCESS]   $propName : $oldValue -> $effectiveValue")
            return
        } catch { }

        # --- Tentativa 2: RegistryValue (com multiplos candidatos por adaptador) ---
        $regCandidates = switch ($effectiveValue) {
            "Enabled"           { @(@("1"), @("3")) }   # 1=padrao, 3=Realtek
            "Disabled"          { @(@("0")) }
            "Auto"              { @(@("0")) }
            "Auto Negotiation"  { @(@("0")) }
            "10 Mbps First"     { @(@("0")) }
            "10 Mbps Primeiro"  { @(@("0")) }
            "Highest"           { @(@("100")) }
            default             { @(@($effectiveValue)) }
        }
        foreach ($tryReg in $regCandidates) {
            $already = $true
            if ($property.RegistryValue.Count -eq $tryReg.Count) {
                for ($i = 0; $i -lt $tryReg.Count; $i++) {
                    if ($property.RegistryValue[$i] -ne $tryReg[$i]) { $already = $false; break }
                }
            } else { $already = $false }
            if ($already) { continue }
            try {
                Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $property.RegistryKeyword -RegistryValue $tryReg -ErrorAction Stop -WarningAction SilentlyContinue
                [void]$global:ChangesLog.Add(@{
                    Property = $propName; OldValue = $oldValue; NewValue = $effectiveValue; Status = "SUCCESS"
                })
                Write-Host "  [+] " -ForegroundColor Green -NoNewline
                Write-Host "$propName : " -ForegroundColor DarkGray -NoNewline
                Write-Host "$oldValue -> " -ForegroundColor Yellow -NoNewline
                Write-Host $effectiveValue -ForegroundColor Green
                [void]$global:LogBuilder.AppendLine("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [SUCCESS]   $propName : $oldValue -> $effectiveValue")
                return
            } catch { }
        }

        # Nao conseguiu aplicar de nenhuma forma
        Warn "$propName : Could not apply"
        [void]$global:LogBuilder.AppendLine("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [WARNING]   $propName : Could not apply")
    }
}

# Função para criar cache de propriedades (melhora performance)
function Get-PropertyCache {
    param([string]$AdapterName)

    $cache = @{}
    try {
        $properties = Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop
        foreach ($prop in $properties) {
            $cache[$prop.DisplayName] = $prop
        }
    } catch {
        Warn "Error creating property cache"
    }
    return $cache
}

# Função para reverter para configurações padrão
function Restore-DefaultSettings {
    param(
        [string]$AdapterName,
        [string]$AdapterDesc = ""
    )

    Clear-Host
    ShowHeader "REVERT TO DEFAULT SETTINGS"
    I "Adapter: $AdapterName - $AdapterDesc"
    Write-Host ""

    $global:ChangesLog.Clear()

    try {
        $allProperties = Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop
        $total = $allProperties.Count
        $count = 0

        foreach ($property in $allProperties) {
            $count++
            Write-Progress -Activity "Reverting settings" -Status "Processing $($property.DisplayName)..." -PercentComplete (($count / $total) * 100)

            try {
                $oldDisplay = $property.DisplayValue
                $oldReg    = $property.RegistryValue -join ','

                # Determina o valor padrao (registry ou display)
                $defaultReg = $null
                $defaultDisp = $null

                if ($property.DefaultRegistryValue) {
                    $defaultReg = $property.DefaultRegistryValue
                }
                if ($property.DefaultDisplayValue) {
                    $defaultDisp = $property.DefaultDisplayValue
                }

                # Se nao tem default definido, tenta adivinhar
                if (-not $defaultReg -and -not $defaultDisp) {
                    $guesses = @("Auto", "Auto Negotiation", "Default", "Enabled", "Not Configured",
                                 "Activado", "Desactivado", "Automático", "Auto Negociação")
                    foreach ($g in $guesses) {
                        if ($property.ValidDisplayValues -contains $g) {
                            $defaultDisp = $g; break
                        }
                    }
                }

                # Aplica o valor padrao
                $applied = $false
                if ($defaultReg) {
                    try {
                        Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $property.RegistryKeyword -RegistryValue $defaultReg -ErrorAction Stop -WarningAction SilentlyContinue
                        $applied = $true
                    } catch { }
                }
                if (-not $applied -and $defaultDisp) {
                    try {
                        Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $property.DisplayName -DisplayValue $defaultDisp -ErrorAction Stop -WarningAction SilentlyContinue
                        $applied = $true
                    } catch { }
                }

                if ($applied) {
                    $newProperty = Get-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $property.RegistryKeyword -ErrorAction SilentlyContinue
                    $newDisplay = if ($newProperty) { $newProperty.DisplayValue } else { $defaultDisp }
                    $newReg    = if ($newProperty) { ($newProperty.RegistryValue -join ',') } else { '' }

                    if ($newReg -ne $oldReg) {
                        Write-Host "  [+] " -ForegroundColor Green -NoNewline
                        Write-Host "$($property.DisplayName) : " -ForegroundColor DarkGray -NoNewline
                        Write-Host "$oldDisplay -> " -ForegroundColor Yellow -NoNewline
                        Write-Host $newDisplay -ForegroundColor Green
                        [void]$global:ChangesLog.Add(@{
                            Property = $property.DisplayName
                            OldValue = $oldDisplay
                            NewValue = $newDisplay
                            Status   = "SUCCESS"
                        })
                    } else {
                        Write-Host "  - " -ForegroundColor DarkGray -NoNewline
                        Write-Host "$($property.DisplayName) : $oldDisplay -> $oldDisplay" -ForegroundColor DarkGray
                    }
                } else {
                    Warn "$($property.DisplayName) : Could not revert"
                }
            } catch {
                # Propriedade nao suportada ou falha ao reverter
            }
        }

        Write-Progress -Activity "Reverting settings" -Completed
        Export-ChangeLog -IsDefaultRestore $true

    } catch {
        X "Error during revert: $_"
    }
}

# Função para restaurar de backup
function Restore-FromBackup {
    param(
        [string]$AdapterName,
        [string]$AdapterDesc = ""
    )

    Clear-Host

    if (-not (Test-Path $BackupPath)) {
        X "No backup file found!"
        return
    }

    try {
        $allBackups = Get-Content $BackupPath -Raw | ConvertFrom-Json
        $adapterBackups = @($allBackups | Where-Object { $_.AdapterName -eq $AdapterName })

        if ($adapterBackups.Count -eq 0) {
            X "No backup found for this adapter!"
            return
        }

        Write-Host "`nBackups disponíveis para $AdapterName :" -ForegroundColor Yellow
        for ($i = 0; $i -lt $adapterBackups.Count; $i++) {
            Write-Host "  [$($i+1)] Backup de $($adapterBackups[$i].Timestamp)" -ForegroundColor Cyan
        }

        $backupChoice = Read-Host "`nEscolha o backup para restaurar (número)"

        if (-not [int]::TryParse($backupChoice, [ref]$null)) {
            X "Invalid input! Enter a number."
            Wait-KeyPress
            return
        }

        $backupIndex = [int]$backupChoice - 1
        if ($backupIndex -lt 0 -or $backupIndex -ge $adapterBackups.Count) {
            X "Invalid backup!"
            Wait-KeyPress
            return
        }

        $selectedBackup = $adapterBackups[$backupIndex]

        Clear-Host
        ShowHeader "RESTORE BACKUP"
        I "Date: $($selectedBackup.Timestamp)"
        I "Adapter: $AdapterName - $AdapterDesc"
        Write-Host ""

        $global:ChangesLog.Clear()

        $total = $selectedBackup.Settings.Count
        $count = 0

        foreach ($setting in $selectedBackup.Settings) {
            $count++
            Write-Progress -Activity "Restoring backup" -Status "Processing $($setting.DisplayName)..." -PercentComplete (($count / $total) * 100)

            try {
                $currentProperty = Get-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $setting.DisplayName -ErrorAction SilentlyContinue
                if ($currentProperty) {
                    $oldValue = $currentProperty.DisplayValue
                    Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $setting.RegistryKeyword -RegistryValue $setting.RegistryValue -ErrorAction Stop -WarningAction SilentlyContinue

                    if ($oldValue.Trim() -ne $setting.DisplayValue.Trim()) {
                        Write-Host "  [+] " -ForegroundColor Green -NoNewline
                        Write-Host "$($setting.DisplayName) : " -ForegroundColor DarkGray -NoNewline
                        Write-Host "$oldValue -> " -ForegroundColor Yellow -NoNewline
                        Write-Host $setting.DisplayValue -ForegroundColor Green
                    } else {
                        Write-Host "  - " -ForegroundColor DarkGray -NoNewline
                        Write-Host "$($setting.DisplayName) : $oldValue -> $oldValue" -ForegroundColor DarkGray
                    }

                    [void]$global:ChangesLog.Add(@{
                        Property = $setting.DisplayName
                        OldValue = $oldValue
                        NewValue = $setting.DisplayValue
                        Status = "SUCCESS"
                    })
                }
            } catch {
                Warn "$($setting.DisplayName) : Could not restore"
            }
        }

        Write-Progress -Activity "Restoring backup" -Completed
        Export-ChangeLog -IsBackupRestore $true

    } catch {
        X "Error restoring backup: $_"
    }
}

# Função para exportar log de mudanças
function Export-ChangeLog {
    param(
        [bool]$IsBackupRestore = $false,
        [bool]$IsDefaultRestore = $false
    )

    if ($global:ChangesLog.Count -eq 0) {
        I "No changes were needed - already at target values."
        return
    }

    $changed = ($global:ChangesLog | Where-Object { $_.OldValue.Trim() -ne $_.NewValue.Trim() }).Count
    $unchanged = $global:ChangesLog.Count - $changed

    if ($IsBackupRestore) {
        OK "Backup restored: $changed/$($global:ChangesLog.Count) properties reverted"
    } elseif ($IsDefaultRestore) {
        OK "Reverted to default: $changed/$($global:ChangesLog.Count) properties changed"
    } else {
        OK "$changed/$($global:ChangesLog.Count) properties optimized"
    }
    if ($unchanged -gt 0) {
        I "$unchanged already at target value"
    }
}

# Configurações de Ethernet (centralizadas)
# Configurações de Ethernet (centralizadas)
$script:EthernetConfigs = @(
    @{Names=@("Flow Control", "Controlo de Fluxo"); Value="Disabled"},
    @{Names=@("Jumbo Packet", "Jumbo Frame"); Value="Disabled"},
    @{Names=@("Energy Efficient Ethernet", "Energy-Efficient Ethernet", "EEE", "Energia Eficiente Ethernet"); Value="Disabled"},
    @{Names=@("Advanced EEE"); Value="Disabled"},
    @{Names=@("Power Saving Mode"); Value="Disabled"},
    @{Names=@("Auto Disable Gigabit"); Value="Disabled"},
    @{Names=@("Wake on Magic Packet", "Pacote Wake on Magic"); Value="Disabled"},
    @{Names=@("Wake on pattern match", "Wake on Pattern Match", "Combinação do padrão Wake on"); Value="Disabled"},
    @{Names=@("Shutdown Wake-On-Lan", "Shutdown Wake-On-LAN", "Desligar Despertar Aquando de Lan"); Value="Disabled"},
    @{Names=@("NS Offload", "Transferência NS"); Value="Disabled"},
    @{Names=@("ARP Offload", "Transferência ARP"); Value="Disabled"},
    @{Names=@("Receive Buffers", "Receber Memórias Intermédias"); Value="Maximum"},
    @{Names=@("Transmit Buffers", "Transmitir Memórias Intermédias"); Value="Maximum"},
    @{Names=@("Large Send Offload V2 (IPv4)", "Large Send Offload v2 (IPv4)", "Descarga Large Send v2 (IPv4)"); Value="Disabled"},
    @{Names=@("Large Send Offload V2 (IPv6)", "Large Send Offload v2 (IPv6)", "Descarga Large Send v2 (IPv6)"); Value="Disabled"},
    @{Names=@("Large Receive Offload (IPv4)"); Value="Disabled"},
    @{Names=@("Large Receive Offload (IPv6)"); Value="Disabled"},
    @{Names=@("IPv4 Checksum Offload", "IPv4 Descarga de Checksum"); Value="Disabled"},
    @{Names=@("TCP Checksum Offload (IPv4)", "TCP Descarga de Checksum (IPv4)"); Value="Disabled"},
    @{Names=@("TCP Checksum Offload (IPv6)", "TCP Descarga de Checksum (IPv6)"); Value="Disabled"},
    @{Names=@("UDP Checksum Offload (IPv4)", "UDP Descarga de Checksum (IPv4)"); Value="Disabled"},
    @{Names=@("UDP Checksum Offload (IPv6)", "UDP Descarga de Checksum (IPv6)"); Value="Disabled"},
    @{Names=@("Recv Segment Coalescing (IPv4)"); Value="Disabled"},
    @{Names=@("Recv Segment Coalescing (IPv6)"); Value="Disabled"},
    @{Names=@("Gigabit Lite"); Value="Disabled"},
    @{Names=@("Interrupt Moderation", "Moderação de Interrupção"); Value="Disabled"},
    @{Names=@("Adaptive Inter-Frame Spacing"); Value="Disabled"},
    @{Names=@("Receive Side Scaling"); Value="Enabled"},
    @{Names=@("Log Link State Event"); Value="Disabled"},
    @{Names=@("Speed & Duplex", "Speed and Duplex", "Velocidade & Duplex"); Value="Auto Negotiation"},
    @{Names=@("Green Ethernet", "Ethernet Verde"); Value="Disabled"},
    @{Names=@("DMA Coalescing"); Value="Disabled"},
    @{Names=@("Enable PME"); Value="Disabled"},
    @{Names=@("Priority & VLAN", "Priority and VLAN", "Prioridade & VLAN"); Value="Disabled"},
    @{Names=@("PTP Hardware Timestamp"); Value="Disabled"},
    @{Names=@("Reduce Speed On Power Down"); Value="Disabled"},
    @{Names=@("Software Timestamp"); Value="Disabled"},
    @{Names=@("Wait for Link"); Value="Disabled"},
    @{Names=@("Wake on Link Settings"); Value="Disabled"},
    @{Names=@("WOL & Shutdown Link Speed", "WOL & Desligar Velocidade Ligação"); Value="10 Mbps First"}
)

# Configurações de Wi-Fi (centralizadas)
$script:WiFiConfigs = @(
    @{Names=@("20/40 MHz Coexistence", "20/40 Coexistence"); Value="Enabled"},
    @{Names=@("40 MHz Intolerant", "Fat Channel Intolerant"); Value="Disabled"},
    @{Names=@("802.11n Preamble"); Value="Auto"},
    @{Names=@("Afterburner"); Value="Disabled"},
    @{Names=@("Antenna Diversity"); Value="Auto"},
    @{Names=@("Bandwidth Capability"); Value="Auto"},
    @{Names=@("Beamforming"); Value="Disabled"},
    @{Names=@("Bluetooth Collaboration", "Bluetooth Coexistence"); Value="Enabled"},
    @{Names=@("Channel Width", "Channel Width for 2.4GHz", "Channel Width for 5GHz"); Value="Auto"},
    @{Names=@("Fat Channel Intolerant"); Value="Disabled"},
    @{Names=@("Fragmentation Threshold"); Value="2346"},
    @{Names=@("Global BG Scan blocking"); Value="Always"},
    @{Names=@("GTK rekeying for WoWLAN"); Value="Enabled"},
    @{Names=@("HT Mode"); Value="Enabled"},
    @{Names=@("Intel Throughput Enhancement", "Throughput Enhancement"); Value="Enabled"},
    @{Names=@("MIMO Power Save Mode"); Value="No SMPS"},
    @{Names=@("Minimum Power Consumption"); Value="Disabled"},
    @{Names=@("Mixed Mode Protection"); Value="Auto"},
    @{Names=@("NS Offload"); Value="Disabled"},
    @{Names=@("Packet Coalescing"); Value="Disabled"},
    @{Names=@("Power Output", "Transmit Power"); Value="Highest"},
    @{Names=@("Preferred Band"); Value="Prefer 5GHz band"},
    @{Names=@("Priority & VLAN", "Priority and VLAN"); Value="Disabled"},
    @{Names=@("Roaming Aggressiveness", "Roaming Decision"); Value="Medium"},
    @{Names=@("Roam Tendency"); Value="Moderate"},
    @{Names=@("RTS Threshold"); Value="2347"},
    @{Names=@("Short GI", "Short Guard Interval"); Value="Enabled"},
    @{Names=@("Throughput Booster"); Value="Enabled"},
    @{Names=@("U-APSD support", "WMM Power Save Mode", "U-APSD"); Value="Disabled"},
    @{Names=@("WiFi Rekeying Offload", "GTK Rekeying Offload"); Value="Enabled"},
    @{Names=@("Wireless Mode"); Value="Auto"},
    @{Names=@("WMM", "WME"); Value="Enabled"},  # I noted WMM should be Enabled
    @{Names=@("Xpress Technology"); Value="Disabled"}
)

# Função consolidada para aplicar configurações (elimina duplicação)
function Apply-NetworkSettings {
    param(
        [string]$AdapterName,
        [string]$Type,
        [string]$AdapterDesc = ""
    )

    Clear-Host
    $typeUpper = $Type.ToUpper()
    ShowHeader "APPLY $typeUpper SETTINGS"
    I "Adapter: $AdapterName - $AdapterDesc"
    Write-Host ""

    $createBackup = Read-Host "Create backup before applying? (Y/N)"
    if ($createBackup -match '^[Yy]$') {
        Write-Host ""
        Backup-AdapterSettings -AdapterName $AdapterName
        Write-Host ""
    }

    [void]$global:LogBuilder.Clear()
    Write-Log "`n========== $typeUpper OPTIMIZATION ==========" "INFO"
    Write-Log "Adapter: $AdapterName - $AdapterDesc" "INFO"
    Write-Log "Date/Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"

    $global:ChangesLog.Clear()

    S "Loading adapter properties..."
    $propertyCache = Get-PropertyCache -AdapterName $AdapterName
    OK "Cache created with $($propertyCache.Count) properties"
    Write-Host ""

    $configs = if ($Type -eq "Ethernet") { $script:EthernetConfigs } else { $script:WiFiConfigs }

    $total = $configs.Count
    $count = 0

    foreach ($config in $configs) {
        Set-NetworkProperty -AdapterName $AdapterName -PropertyNames $config.Names -Value $config.Value -PropertyCache $propertyCache
        $count++
        Write-Progress -Activity "Applying $Type settings" -Status "Processing..." -PercentComplete (($count / $total) * 100)
    }

    Write-Progress -Activity "Applying $Type settings" -Completed
    OK "$Type settings applied successfully!"
    [void]$global:LogBuilder.AppendLine("[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [SUCCESS] $Type optimization completed!")


    Export-ChangeLog
    Save-LogFile
}

# Função para listar adaptadores
function Get-AdaptersByType {
    param([string]$Type)

    Write-Host "`nDetectando adaptadores de rede..." -ForegroundColor Yellow

    try {
        # Remove filtro de Status - pega TODOS os adaptadores (conectados ou não)
        # Exclui apenas adaptadores virtuais/loopback comuns
        $allAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object {
            $_.InterfaceDescription -notlike "*Loopback*" -and
            $_.InterfaceDescription -notlike "*Virtual*" -and
            $_.InterfaceDescription -notlike "*Hyper-V*" -and
            $_.InterfaceDescription -notlike "*VPN*" -and
            $_.InterfaceDescription -notlike "*Bluetooth*" -and
            $_.Name -notlike "*vEthernet*"
        }

        if ($Type -eq "Ethernet") {
            # Filtra adaptadores Ethernet (exclui wireless)
            $filtered = @($allAdapters | Where-Object {
                $_.InterfaceDescription -notlike "*Wireless*" -and
                $_.InterfaceDescription -notlike "*Wi-Fi*" -and
                $_.InterfaceDescription -notlike "*802.11*" -and
                $_.Name -notlike "*Wi-Fi*"
            })
        } else {
            # Filtra adaptadores Wi-Fi
            $filtered = @($allAdapters | Where-Object {
                $_.InterfaceDescription -like "*Wireless*" -or
                $_.InterfaceDescription -like "*Wi-Fi*" -or
                $_.InterfaceDescription -like "*802.11*" -or
                $_.Name -like "*Wi-Fi*"
            })
        }

        return $filtered
    }
    catch {
        X "Error detecting adapters: $_"
        return @()
    }
}

function Select-Adapter {
    param([string]$Type)

    $adapters = @(Get-AdaptersByType -Type $Type)

    if ($adapters.Count -eq 0) {
        X "No $Type adapter found!"
        Wait-KeyPress
        return $null
    }

    I "Available $Type adapters:"

    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $adapter = $adapters[$i]
        $statusColor = if ($adapter.Status -eq "Up") { "Green" } else { "DarkGray" }
        $statusText = "[$($adapter.Status)]"
        Write-Host "  [$($i+1)] " -NoNewline -ForegroundColor $Script:Col.STEP
        Write-Host "$statusText " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($adapter.Name) - $($adapter.InterfaceDescription)" -ForegroundColor White
    }

    $adapterChoice = Read-Host "`nChoose adapter (number)"

    if ([string]::IsNullOrWhiteSpace($adapterChoice)) {
        X "No option selected!"
        Wait-KeyPress
        return $null
    }

    if (-not [int]::TryParse($adapterChoice, [ref]$null)) {
        X "Invalid input! Enter a number."
        Wait-KeyPress
        return $null
    }

    $index = [int]$adapterChoice - 1

    if ($index -ge 0 -and $index -lt $adapters.Count) {
        return $adapters[$index]
    } else {
        X "Invalid adapter!"
        Wait-KeyPress
        return $null
    }
}

function Show-Menu {
    Clear-Host
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host "  NETWORK ADAPTER OPTIMIZER - by SETT" -ForegroundColor $Script:Col.TITLE
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host ""
    Write-Host "  OPTIMIZE:" -ForegroundColor $Script:Col.STEP
    Write-Host "  [1] Ethernet Adapter" -ForegroundColor White
    Write-Host "  [2] Wi-Fi Adapter" -ForegroundColor White
    Write-Host "  [3] DNS Optimization" -ForegroundColor White
    Write-Host ""
    Write-Host "  REVERT:" -ForegroundColor $Script:Col.STEP
    Write-Host "  [4] Ethernet to Default/Auto" -ForegroundColor White
    Write-Host "  [5] Wi-Fi to Default/Auto" -ForegroundColor White
    Write-Host ""
    Write-Host "  RESTORE BACKUP:" -ForegroundColor $Script:Col.STEP
    Write-Host "  [6] Restore Ethernet from Backup" -ForegroundColor White
    Write-Host "  [7] Restore Wi-Fi from Backup" -ForegroundColor White
    Write-Host ""
    Write-Host "  [8] Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
}

# Loop principal (consolidado e otimizado)
do {
    Show-Menu
    $choice = Read-Host "`nEscolha uma opção"

    Clear-Host
    $adapter = $null

    switch ($choice) {
        "1" {
            $adapter = Select-Adapter -Type "Ethernet"
            if ($adapter) {
                Apply-NetworkSettings -AdapterName $adapter.Name -Type "Ethernet" -AdapterDesc $adapter.InterfaceDescription
            }
        }
        "2" {
            $adapter = Select-Adapter -Type "WiFi"
            if ($adapter) {
                Apply-NetworkSettings -AdapterName $adapter.Name -Type "WiFi" -AdapterDesc $adapter.InterfaceDescription
            }
        }
        "3" {
            $dnsJumperPath = Join-Path $PSScriptRoot "Programs\DnsJumper.exe"
            if (Test-Path $dnsJumperPath) {
                S "Launching DnsJumper..."
                Start-Process -FilePath $dnsJumperPath -Wait
            } else {
                X "DnsJumper.exe not found: $dnsJumperPath"
                Start-Sleep -Seconds 2
            }
        }
        "4" {
            $adapter = Select-Adapter -Type "Ethernet"
            if ($adapter) {
                [void]$global:LogBuilder.Clear()
                Restore-DefaultSettings -AdapterName $adapter.Name -AdapterDesc $adapter.InterfaceDescription
            }
        }
        "5" {
            $adapter = Select-Adapter -Type "WiFi"
            if ($adapter) {
                [void]$global:LogBuilder.Clear()
                Restore-DefaultSettings -AdapterName $adapter.Name -AdapterDesc $adapter.InterfaceDescription
            }
        }
        "6" {
            $adapter = Select-Adapter -Type "Ethernet"
            if ($adapter) {
                [void]$global:LogBuilder.Clear()
                Restore-FromBackup -AdapterName $adapter.Name -AdapterDesc $adapter.InterfaceDescription
            }
        }
        "7" {
            $adapter = Select-Adapter -Type "WiFi"
            if ($adapter) {
                [void]$global:LogBuilder.Clear()
                Restore-FromBackup -AdapterName $adapter.Name -AdapterDesc $adapter.InterfaceDescription
            }
        }
        "8" {
            I "Exiting..."
            Start-Sleep -Seconds 1
            exit 0
        }
        default {
            X "Invalid option!"
            Start-Sleep -Seconds 2
            continue
        }
    }

    if ($choice -match '^[1-7]$' -and $adapter) {
        Wait-KeyPress
    }

} while ($choice -ne "8")
