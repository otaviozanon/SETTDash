
# ================================================
#region NETWORK OPTIMIZER (Ethernet + Wi-Fi adapter tweaks)
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

# Used by: Home (Network Optimizer > "Optimize Ethernet" / "Optimize Wi-Fi"); also called internally by All ("OPTIMIZE ALL")
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

# Used by: Home (Network Optimizer > "Revert Ethernet" / "Revert Wi-Fi")
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
#endregion
