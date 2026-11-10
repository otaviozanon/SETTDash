# Clean tab page: System Cleaner, Registry Cleaner, Device Cleanup.
# Startup management moved to its own sidebar page (Sidebar\Pages\Startup.ps1), below Network.
# Mirrors Kudu's cleanup sections, each as scan -> checklist -> apply, using
# Set-CleanChecklist/Get-CleanSelected (Core\Helpers\CleanList.ps1) and the scan/apply
# functions in Core\Actions\Clean\*.ps1.
# Shown as category pills (same pattern as Sidebar\Pages\Startup.ps1) instead of stacked
# cards, since each section can grow large (checklists) and benefits from the full page.
function Show-PageClean {
    Clear-GuiContent
    Add-GuiPageTitle "Clean"

    # ---- Category pills (icon + label, same style as Startup/YourPCSensors) ----
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

    function New-CleanPill {
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

    # --- Category 1: System Cleaner ---
    $panelSystem = New-Object System.Windows.Controls.StackPanel
    $Script:CleanSystemItems = @()
    $Script:pnlCleanSystemList = New-Object System.Windows.Controls.StackPanel
    $Script:CleanSystemBox = New-CleanListContainer $Script:pnlCleanSystemList
    Add-GuiCard "System Cleaner" "Scan and remove temp files, caches, logs, Windows Update cache, Delivery Optimization, prefetch, memory dumps and more. Selected files are permanently deleted, not moved to the Recycle Bin." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search category..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlCleanSystemList $s.Text
        })
        Add-GuiBackgroundBtn $p "Scan" { Get-SystemCleanerItems } @('Get-SystemCleanerItems') {
            param($items)
            $Script:CleanSystemItems = @($items)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanSystemList $Script:CleanSystemItems "No cleanable items found." "size"
            Expand-GuiCard $Script:CleanSystemBox
            Set-GuiProgress 0
            Write-GuiLog "System Cleaner: $($Script:CleanSystemItems.Count) categories scanned" "OK"
        } -Style "RevertButtonStyle"
        Add-CleanSelectAllBtn $p $Script:pnlCleanSystemList "ActionButtonStyle" { $Script:CleanSystemItems } | Out-Null
        Add-GuiBtn $p "Clean Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:CleanSystemItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            Invoke-SystemCleanerClean -Items $selected
            # Rescan so cleaned rows show their real remaining size instead of the stale scan value.
            Update-CleanChecklist $Script:pnlCleanSystemList { Get-SystemCleanerItems } {
                param($items) $Script:CleanSystemItems = @($items)
            } @('Get-SystemCleanerItems') "No cleanable items found." "size"
        }
        Add-GuiBackgroundBtn $p "Full Cleanup" { Invoke-FullSystemCleanup } @('Invoke-FullSystemCleanup') {
            param($result)
            Set-GuiProgress 100 "Full cleanup complete!"
            # Only refresh if a scan produced a list; otherwise leave the collapsed card alone.
            if ($Script:CleanSystemItems.Count -gt 0) {
                Update-CleanChecklist $Script:pnlCleanSystemList { Get-SystemCleanerItems } {
                    param($items) $Script:CleanSystemItems = @($items)
                } @('Get-SystemCleanerItems') "No cleanable items found." "size"
            }
        } -Style "DangerButtonStyle" -ConfirmCheck {
            Show-GuiConfirm -Title "Full Cleanup" -Icon "&#xE74D;" `
                -Message "This permanently deletes temp files, browser caches, logs, prefetch, Windows Update cache and memory dumps, and empties the Recycle Bin (nothing goes to the Recycle Bin first). Running apps keep their files locked - those are reported, not deleted. Continue?" `
                -ConfirmText "Run Full Cleanup"
        }
    } "&#xE74D;" -WrapButtons -CollapseTarget $Script:CleanSystemBox -TargetPanel $panelSystem
    $panelSystem.AddChild($Script:CleanSystemBox)
    $panelSystem.Visibility = "Collapsed"
    $pnlContent.AddChild($panelSystem)
    $categoryPanels["System Cleaner"] = $panelSystem

    # --- Category 2: Registry Cleaner ---
    $panelRegistry = New-Object System.Windows.Controls.StackPanel
    $Script:CleanRegistryItems = @()
    $Script:pnlCleanRegistryList = New-Object System.Windows.Controls.StackPanel
    $Script:CleanRegistryBox = New-CleanListContainer $Script:pnlCleanRegistryList
    Add-GuiCard "Registry Cleaner" "Scan for broken App Paths, SharedDLLs, Run entries, fonts, orphaned services and stale uninstall entries. A .reg backup is saved before any fix." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlCleanRegistryList $s.Text
        })
        Add-GuiBackgroundBtn $p "Scan" { Get-RegistryCleanerItems } @('Get-RegistryCleanerItems') {
            param($items)
            $Script:CleanRegistryItems = @($items)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanRegistryList $Script:CleanRegistryItems "No registry issues found." "plain"
            Expand-GuiCard $Script:CleanRegistryBox
            Set-GuiProgress 0
            Write-GuiLog "Registry Cleaner: $($Script:CleanRegistryItems.Count) issues found" "OK"
        } -Style "RevertButtonStyle"
        Add-CleanSelectAllBtn $p $Script:pnlCleanRegistryList "ActionButtonStyle" { $Script:CleanRegistryItems } | Out-Null
        Add-GuiBtn $p "Fix Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:CleanRegistryItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            $ok = Show-GuiConfirm -Title "Fix Registry Entries" -Icon "&#xE90F;" `
                -Message "This removes the $($selected.Count) selected registry entries. A .reg backup of every key is saved to %LOCALAPPDATA%\SETTDash\Backups\Registry before the change. Continue?" `
                -ConfirmText "Fix Entries"
            if (-not $ok) { return }
            # Each fix runs reg.exe export + delete; doing it on the UI thread froze the window for
            # every selected entry. OnDone re-scans so fixed entries disappear without a manual Scan.
            [void](Start-GuiBackgroundJob -Work { Invoke-RegistryCleanerFix -Items $FixItems } `
                -Functions @('Invoke-RegistryCleanerFix') -Name "Registry fix" `
                -Arguments @{ FixItems = $selected } -OnDone {
                    param($result)
                    Set-GuiProgress 100
                    Update-CleanChecklist $Script:pnlCleanRegistryList { Get-RegistryCleanerItems } {
                        param($items) $Script:CleanRegistryItems = @($items)
                    } @('Get-RegistryCleanerItems') "No registry issues found." "plain"
                })
        }
    } "&#xE90F;" -WrapButtons -CollapseTarget $Script:CleanRegistryBox -TargetPanel $panelRegistry
    $panelRegistry.AddChild($Script:CleanRegistryBox)
    $panelRegistry.Visibility = "Collapsed"
    $pnlContent.AddChild($panelRegistry)
    $categoryPanels["Registry Cleaner"] = $panelRegistry

    # --- Category 3: Device Cleanup (moved from Home > Tools) ---
    $panelDevice = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Device Cleanup" "Launches the Windows Device Cleanup tool to remove unused device drivers and entries." {
        param($p)
        Add-GuiBtn $p "Run Device Cleanup" "ActionButtonStyle" { Invoke-CleanDeviceCleanup }
    } "&#xE90F;" -WrapButtons -TargetPanel $panelDevice
    $panelDevice.Visibility = "Collapsed"
    $pnlContent.AddChild($panelDevice)
    $categoryPanels["Device Cleanup"] = $panelDevice

    # ---- Wire pills + default selection ----
    $pillDefs = @(
        @{ Icon = "&#xE74D;"; Label = "System Cleaner" },
        @{ Icon = "&#xE90F;"; Label = "Registry Cleaner" },
        @{ Icon = "&#xE90F;"; Label = "Device Cleanup" }
    )
    foreach ($def in $pillDefs) {
        $btn = New-CleanPill $def.Icon $def.Label
        $btn.Add_Click({ & $setActiveCategory $def.Label }.GetNewClosure())
        $pillButtons[$def.Label] = $btn
        $pillsStack.AddChild($btn)
    }
    & $setActiveCategory "System Cleaner"
}
