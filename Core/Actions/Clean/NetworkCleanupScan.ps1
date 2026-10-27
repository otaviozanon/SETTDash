
# ================================================
#region CLEAN TAB - NETWORK CLEANUP (scan/clean)
# ================================================
# Recreates Kudu's "Network Cleanup" (network-cleanup.ipc.ts) as native PowerShell:
# DNS resolver cache, Wi-Fi profiles, ARP cache, saved network history (NetworkList\Profiles).
# Used by: Sidebar\Pages\Clean.ps1

# Returns pscustomobjects: Label, Detail, Selected, Type ('dns-cache'|'wifi-profile'|'arp-cache'|'network-history'), Key
function Get-NetworkCleanupItems {
    $items = @()

    try {
        $dnsCount = (Get-DnsClientCache -ErrorAction SilentlyContinue | Measure-Object).Count
    } catch { $dnsCount = 0 }
    if ($dnsCount -gt 0) {
        $items += [pscustomobject]@{ Label="DNS Resolver Cache"; Detail="$dnsCount cached entries"; Selected=$true; Type='dns-cache'; Key='' }
    }

    try {
        $wifiOutput = netsh wlan show profiles 2>$null
        $wifiProfiles = $wifiOutput | Select-String ':\s*(.+)$' | ForEach-Object {
            if ($_ -match 'All User Profile\s*:\s*(.+)$') { $Matches[1].Trim() }
        }
        foreach ($p in $wifiProfiles) {
            $items += [pscustomobject]@{ Label=$p; Detail="Wi-Fi profile"; Selected=$false; Type='wifi-profile'; Key=$p }
        }
    } catch { }

    try {
        $arpLines = (arp -a) 2>$null | Select-String '\d+\.\d+\.\d+\.\d+'
        $arpCount = @($arpLines).Count
    } catch { $arpCount = 0 }
    if ($arpCount -gt 0) {
        $items += [pscustomobject]@{ Label="ARP Cache"; Detail="$arpCount entries"; Selected=$true; Type='arp-cache'; Key='' }
    }

    $profilesKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles'
    if (Test-Path $profilesKey) {
        Get-ChildItem $profilesKey -ErrorAction SilentlyContinue | ForEach-Object {
            $name = Get-SafeProp (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue) 'ProfileName'
            if ($name) {
                $items += [pscustomobject]@{ Label=$name; Detail="Saved network profile - $($_.PSChildName)"; Selected=$false; Type='network-history'; Key=$_.PSChildName }
            }
        }
    }

    return $items
}

# Cleans the given Network Cleanup items (array of objects returned by Get-NetworkCleanupItems).
function Invoke-NetworkCleanupClean {
    param([array]$Items)
    $total = $Items.Count
    $cleaned = 0; $failed = 0
    for ($i = 0; $i -lt $total; $i++) {
        $it = $Items[$i]
        Set-GuiProgress ([math]::Round(($i+1)/[math]::Max($total,1)*100)) "Cleaning: $($it.Label)"
        try {
            switch ($it.Type) {
                'dns-cache' { Clear-DnsClientCache -ErrorAction Stop; $cleaned++; Write-GuiLog "DNS cache flushed" "OK" }
                'wifi-profile' {
                    $null = netsh wlan delete profile name="$($it.Key)" 2>$null
                    $cleaned++; Write-GuiLog "Wi-Fi profile removed: $($it.Label)" "OK"
                }
                'arp-cache' {
                    $null = netsh interface ip delete arpcache 2>$null
                    $cleaned++; Write-GuiLog "ARP cache cleared" "OK"
                }
                'network-history' {
                    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\$($it.Key)" -Recurse -Force -ErrorAction Stop
                    $cleaned++; Write-GuiLog "Network history removed: $($it.Label)" "OK"
                }
            }
        } catch {
            $failed++
            Write-GuiLog "Failed to clean $($it.Label): $_" "ERR"
        }
    }
    Set-GuiProgress 0
    Write-GuiLog "Network Cleanup: $cleaned/$total items cleaned" "OK"
    return @{Cleaned=$cleaned; Failed=$failed}
}
#endregion
