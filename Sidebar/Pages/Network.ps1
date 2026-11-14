# Network tab page: Network Cleanup (moved from Clean) + Network Optimizer (moved from Home).
# Shown as category pills (same pattern as Sidebar\Pages\Startup.ps1 / Clean.ps1).
function Show-PageNetwork {
    Clear-GuiContent
    Add-GuiPageTitle (T "Network")

    # ---- Category pills (icon + label, same style as Startup/Clean) ----
    $pillsCard = New-Object System.Windows.Controls.Border
    $cardStyle = $Window.FindResource("CardStyle"); if ($cardStyle) { $pillsCard.Style = $cardStyle }
    $pillsCard.Padding = "8"
    $pillsCard.Margin = "0,0,0,14"
    $pillsStack = New-Object System.Windows.Controls.WrapPanel
    $pillsStack.Orientation = "Horizontal"
    $pillsStack.HorizontalAlignment = "Center"
    $pillsCard.Child = $pillsStack
    $pnlContent.AddChild($pillsCard)

    $activeStyle = $Window.FindResource("CategoryPillActiveStyle")
    $normalStyle = $Window.FindResource("CategoryPillStyle")
    $pillButtons = @{}
    $categoryPanels = @{}

    function New-NetworkPill {
        param([string]$Icon, [string]$Label)
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $normalStyle
        $content = New-Object System.Windows.Controls.StackPanel
        $content.Orientation = "Horizontal"
        $iconBlock = New-Object System.Windows.Controls.TextBlock
        $iconBlock.Text = [regex]::Replace($Icon, '&#x([0-9A-Fa-f]+);', { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
        $iconBlock.FontFamily = "Segoe MDL2 Assets"
        $iconBlock.FontSize = 13
        $iconBlock.Margin = "0,0,8,0"
        $iconBlock.VerticalAlignment = "Center"
        $content.AddChild($iconBlock)
        $textBlock = New-Object System.Windows.Controls.TextBlock
        $textBlock.Text = $Label
        $textBlock.VerticalAlignment = "Center"
        $content.AddChild($textBlock)
        $btn.Content = $content
        return $btn
    }

    $setActiveCategory = {
        param($name)
        foreach ($bn in $pillButtons.Keys) { $pillButtons[$bn].Style = if ($bn -eq $name) { $activeStyle } else { $normalStyle } }
        foreach ($cn in $categoryPanels.Keys) { $categoryPanels[$cn].Visibility = if ($cn -eq $name) { "Visible" } else { "Collapsed" } }
    }.GetNewClosure()

    # --- Category 1: Network Cleanup ---
    $panelCleanup = New-Object System.Windows.Controls.StackPanel
    $Script:CleanNetworkItems = @()
    $Script:pnlCleanNetworkList = New-Object System.Windows.Controls.StackPanel
    $Script:CleanNetworkBox = New-CleanListContainer $Script:pnlCleanNetworkList
    Add-GuiCard (T "Network Cleanup") (T "Flush DNS resolver cache, clear ARP cache, remove saved Wi-Fi profiles and stale network history entries.") {
        param($p)
        Add-GuiBackgroundBtn $p (T "Scan") { Get-NetworkCleanupItems } @('Get-NetworkCleanupItems') {
            param($items)
            # Same $null-vs-empty-array trap as the Clean page: wrap so .Count is always valid.
            $Script:CleanNetworkItems = @($items)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanNetworkList $Script:CleanNetworkItems (T "Nothing to clean.") "plain"
            Expand-GuiCard $Script:CleanNetworkBox
            Set-GuiProgress 0
            Write-GuiLog ((T "Network Cleanup: {0} items found") -f $Script:CleanNetworkItems.Count) "OK"
        } -Style "RevertButtonStyle"
        Add-CleanSelectAllBtn $p $Script:pnlCleanNetworkList "ActionButtonStyle" { $Script:CleanNetworkItems } | Out-Null
        Add-GuiBtn $p (T "Clean Selected") "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:CleanNetworkItems)
            if ($selected.Count -eq 0) { Write-GuiLog (T "No items selected.") "WARN"; return }
            Invoke-NetworkCleanupClean -Items $selected
            # Rescan so removed profiles/history disappear without a manual Scan.
            Update-CleanChecklist $Script:pnlCleanNetworkList { Get-NetworkCleanupItems } {
                param($items) $Script:CleanNetworkItems = @($items)
            } @('Get-NetworkCleanupItems') (T "Nothing to clean.") "plain"
        }
    } "&#xE968;" -WrapButtons -CollapseTarget $Script:CleanNetworkBox -TargetPanel $panelCleanup
    $panelCleanup.AddChild($Script:CleanNetworkBox)
    $panelCleanup.Visibility = "Collapsed"
    $pnlContent.AddChild($panelCleanup)
    $categoryPanels[(T "Network Cleanup")] = $panelCleanup

    # --- Category 2: Network Optimizer (moved from Home) ---
    $panelOptimizer = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard (T "Network Optimizer") (T "Apply or revert network adapter tweaks for Ethernet and Wi-Fi to improve throughput and reduce latency.") {
        param($p)
        # Adapter tweaks take seconds per NIC; run them in background so the button reads "Cancel".
        $done = { Set-GuiProgress 0 }
        Add-GuiBackgroundBtn $p (T "Optimize Ethernet") { Invoke-NetworkOptimize "Ethernet" } @('Invoke-NetworkOptimize') $done
        Add-GuiBackgroundBtn $p (T "Optimize Wi-Fi") { Invoke-NetworkOptimize "WiFi" } @('Invoke-NetworkOptimize') $done
        Add-GuiBackgroundBtn $p (T "Revert Ethernet") { Invoke-NetworkRestoreDefaults "Ethernet" } @('Invoke-NetworkRestoreDefaults') $done -Style "RevertButtonStyle"
        Add-GuiBackgroundBtn $p (T "Revert Wi-Fi") { Invoke-NetworkRestoreDefaults "WiFi" } @('Invoke-NetworkRestoreDefaults') $done -Style "RevertButtonStyle"
    } "&#xE839;" -WrapButtons -TargetPanel $panelOptimizer
    $panelOptimizer.Visibility = "Collapsed"
    $pnlContent.AddChild($panelOptimizer)
    $categoryPanels[(T "Network Optimizer")] = $panelOptimizer

    # --- Category 3: DNS Jumper (moved from Home > Tools) ---
    $panelDns = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard (T "DNS Jumper") (T "Switch DNS servers quickly (Google, Cloudflare, OpenDNS, etc).") {
        param($p)
        Add-GuiBtn $p (T "Open DNS Jumper") "InstallButtonStyle" { Invoke-DNSTool }
    } "&#xE968;" -WrapButtons -TargetPanel $panelDns
    $panelDns.Visibility = "Collapsed"
    $pnlContent.AddChild($panelDns)
    $categoryPanels[(T "DNS Jumper")] = $panelDns

    # ---- Wire pills + default selection ----
    $pillDefs = @(
        @{ Icon = "&#xE968;"; Label = (T "Network Cleanup") },
        @{ Icon = "&#xE839;"; Label = (T "Network Optimizer") },
        @{ Icon = "&#xE968;"; Label = (T "DNS Jumper") }
    )
    foreach ($def in $pillDefs) {
        $btn = New-NetworkPill $def.Icon $def.Label
        $btn.Add_Click({ & $setActiveCategory $def.Label }.GetNewClosure())
        $pillButtons[$def.Label] = $btn
        $pillsStack.AddChild($btn)
    }
    & $setActiveCategory (T "Network Cleanup")
}
