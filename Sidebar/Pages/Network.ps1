# Network tab page: Network Cleanup (moved from Clean) + Network Optimizer (moved from Home).
function Show-PageNetwork {
    Clear-GuiContent
    Add-GuiPageTitle "Network"

    # --- Network Cleanup ---
    $Script:CleanNetworkItems = @()
    $Script:pnlCleanNetworkList = New-Object System.Windows.Controls.StackPanel
    $Script:CleanNetworkBox = New-CleanListContainer $Script:pnlCleanNetworkList
    Add-GuiCard "Network Cleanup" "Flush DNS resolver cache, clear ARP cache, remove saved Wi-Fi profiles and stale network history entries." {
        param($p)
        Add-GuiBtn $p "Scan" "RevertButtonStyle" {
            Set-GuiProgress 20 "Scanning network cache and profiles..."
            $Script:CleanNetworkItems = Get-NetworkCleanupItems
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanNetworkList $Script:CleanNetworkItems "Nothing to clean." "plain"
            Expand-GuiCard $Script:CleanNetworkBox
            Set-GuiProgress 0
            Write-GuiLog "Network Cleanup: $($Script:CleanNetworkItems.Count) items found" "OK"
        }
        Add-GuiBtn $p "Clean Selected" "ActionButtonStyle" {
            $selected = Get-CleanSelected $Script:CleanNetworkItems
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            Invoke-NetworkCleanupClean -Items $selected
        }
    } "&#xE968;" -WrapButtons -CollapseTarget $Script:CleanNetworkBox
    $pnlContent.AddChild($Script:CleanNetworkBox)

    # --- Network Optimizer (moved from Home) ---
    Add-GuiCard "Network Optimizer" "Apply or revert network adapter tweaks for Ethernet and Wi-Fi to improve throughput and reduce latency." {
        param($p)
        Add-GuiBtn $p "Optimize Ethernet" "ActionButtonStyle" { Invoke-NetworkOptimize "Ethernet" }
        Add-GuiBtn $p "Optimize Wi-Fi" "ActionButtonStyle" { Invoke-NetworkOptimize "WiFi" }
        Add-GuiBtn $p "Revert Ethernet" "RevertButtonStyle" { Invoke-NetworkRestoreDefaults "Ethernet" }
        Add-GuiBtn $p "Revert Wi-Fi" "RevertButtonStyle" { Invoke-NetworkRestoreDefaults "WiFi" }
    } "&#xE839;" -WrapButtons

    # --- DNS Jumper (moved from Home > Tools) ---
    Add-GuiCard "DNS Jumper" "Switch DNS servers quickly (Google, Cloudflare, OpenDNS, etc)." {
        param($p)
        Add-GuiBtn $p "Open DNS Jumper" "InstallButtonStyle" { Invoke-DNSTool }
    } "&#xE968;" -WrapButtons
}
