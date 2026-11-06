# Clean tab page: System Cleaner, Registry Cleaner, Device Cleanup.
# Startup management moved to its own sidebar page (Sidebar\Pages\Startup.ps1), below Network.
# Mirrors Kudu's cleanup sections, each as scan -> checklist -> apply, using
# Set-CleanChecklist/Get-CleanSelected (Core\Helpers\CleanList.ps1) and the scan/apply
# functions in Core\Actions\Clean\*.ps1.
function Show-PageClean {
    Clear-GuiContent
    Add-GuiPageTitle "Clean"

    # List containers stored in Script: scope (not plain locals): the Scan button
    # handlers execute later, inside Add-GuiBtn's GetNewClosure session state, where
    # page-local variables are not available (strict mode raises
    # "The variable cannot be retrieved because it has not been set" for them).
    # --- System Cleaner ---
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
    } "&#xE74D;" -WrapButtons -CollapseTarget $Script:CleanSystemBox
    $pnlContent.AddChild($Script:CleanSystemBox)

    # --- Registry Cleaner ---
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
    } "&#xE90F;" -WrapButtons -CollapseTarget $Script:CleanRegistryBox
    $pnlContent.AddChild($Script:CleanRegistryBox)

    # --- Device Cleanup (moved from Home > Tools) ---
    Add-GuiCard "Device Cleanup" "Launches the Windows Device Cleanup tool to remove unused device drivers and entries." {
        param($p)
        Add-GuiBtn $p "Run Device Cleanup" "ActionButtonStyle" { Invoke-CleanDeviceCleanup }
    } "&#xE90F;" -WrapButtons
}
