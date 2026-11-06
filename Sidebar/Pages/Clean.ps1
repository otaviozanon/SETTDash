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
    Add-GuiCard "System Cleaner" "Scan and remove temp files, caches, logs, Windows Update cache, Delivery Optimization, prefetch, memory dumps and more." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search category..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlCleanSystemList $s.Text
        })
        Add-GuiBtn $p "Scan" "RevertButtonStyle" {
            Set-GuiProgress 20 "Scanning system cache/temp locations..."
            # @(...): a scan that finds nothing returns $null from PowerShell, and $null.Count
            # throws "The property 'Count' cannot be found on this object" under StrictMode.
            $Script:CleanSystemItems = @(Get-SystemCleanerItems)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanSystemList $Script:CleanSystemItems "No cleanable items found." "size"
            Expand-GuiCard $Script:CleanSystemBox
            Set-GuiProgress 0
            Write-GuiLog "System Cleaner: $($Script:CleanSystemItems.Count) categories scanned" "OK"
        }
        Add-GuiBtn $p "Clean Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:CleanSystemItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            Invoke-SystemCleanerClean -Items $selected
        }
        Add-GuiBtn $p "Full Cleanup" "DangerButtonStyle" {
            Invoke-FullSystemCleanup
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
        Add-GuiBtn $p "Scan" "RevertButtonStyle" {
            Set-GuiProgress 20 "Scanning registry for broken entries..."
            $Script:CleanRegistryItems = @(Get-RegistryCleanerItems)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanRegistryList $Script:CleanRegistryItems "No registry issues found." "plain"
            Expand-GuiCard $Script:CleanRegistryBox
            Set-GuiProgress 0
            Write-GuiLog "Registry Cleaner: $($Script:CleanRegistryItems.Count) issues found" "OK"
        }
        Add-GuiBtn $p "Fix Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:CleanRegistryItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            Invoke-RegistryCleanerFix -Items $selected
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
