# Clean tab page: System Cleaner, Registry Cleaner, Startup Manager, Network Cleanup.
# Mirrors Kudu's 4 cleanup sections, each as scan -> checklist -> apply, using
# Set-CleanChecklist/Get-CleanSelected (Core\Helpers\CleanList.ps1) and the scan/apply
# functions in Core\Actions\Clean\*.ps1.
function Show-PageClean {
    Clear-GuiContent
    Add-GuiPageTitle "Clean"

    # --- System Cleaner ---
    $Script:CleanSystemItems = @()
    $Script:pnlCleanSystemList = New-Object System.Windows.Controls.StackPanel
    $systemListBox = New-CleanListContainer $Script:pnlCleanSystemList
    Add-GuiCard "System Cleaner" "Scan and remove temp files, caches, logs, Windows Update cache, Delivery Optimization, prefetch, memory dumps and more." {
        param($p)
        Add-GuiBtn $p "Scan" "ActionButtonStyle" {
            Set-GuiProgress 20 "Scanning system cache/temp locations..."
            $Script:CleanSystemItems = Get-SystemCleanerItems
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanSystemList $Script:CleanSystemItems "No cleanable items found." "size"
            Expand-GuiCard $systemListBox
            Set-GuiProgress 0
            Write-GuiLog "System Cleaner: $($Script:CleanSystemItems.Count) categories scanned" "OK"
        }
        Add-GuiBtn $p "Clean Selected" "RevertButtonStyle" {
            $selected = Get-CleanSelected $Script:CleanSystemItems
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            Invoke-SystemCleanerClean -Items $selected
        }
        Add-GuiBtn $p "Full Cleanup" "RevertButtonStyle" {
            Invoke-CleanAll
        }
    } "&#xE74D;" -WrapButtons -CollapseTarget $systemListBox
    $pnlContent.AddChild($systemListBox)

    # --- Registry Cleaner ---
    $Script:CleanRegistryItems = @()
    $Script:pnlCleanRegistryList = New-Object System.Windows.Controls.StackPanel
    $registryListBox = New-CleanListContainer $Script:pnlCleanRegistryList
    Add-GuiCard "Registry Cleaner" "Scan for broken App Paths, SharedDLLs, Run entries, fonts, orphaned services and stale uninstall entries. A .reg backup is saved before any fix." {
        param($p)
        Add-GuiBtn $p "Scan" "ActionButtonStyle" {
            Set-GuiProgress 20 "Scanning registry for broken entries..."
            $Script:CleanRegistryItems = Get-RegistryCleanerItems
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanRegistryList $Script:CleanRegistryItems "No registry issues found." "plain"
            Expand-GuiCard $registryListBox
            Set-GuiProgress 0
            Write-GuiLog "Registry Cleaner: $($Script:CleanRegistryItems.Count) issues found" "OK"
        }
        Add-GuiBtn $p "Fix Selected" "RevertButtonStyle" {
            $selected = Get-CleanSelected $Script:CleanRegistryItems
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            Invoke-RegistryCleanerFix -Items $selected
        }
    } "&#xE90F;" -WrapButtons -CollapseTarget $registryListBox
    $pnlContent.AddChild($registryListBox)

    # --- Startup Manager ---
    $Script:CleanStartupItems = @()
    $Script:pnlCleanStartupList = New-Object System.Windows.Controls.StackPanel
    $startupListBox = New-CleanListContainer $Script:pnlCleanStartupList
    $Script:CleanStartupToggle = {
        param($it)
        return Set-StartupItemEnabled -Item $it -Enabled (-not [bool]$it.Selected)
    }
    Add-GuiCard "Startup Manager" "List Run/RunOnce entries (HKCU+HKLM), Startup folder shortcuts and Task Scheduler logon tasks. Enable, disable or delete selected items." {
        param($p)
        Add-GuiBtn $p "Scan" "ActionButtonStyle" {
            Set-GuiProgress 20 "Scanning startup entries..."
            $Script:CleanStartupItems = Get-StartupManagerItems
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlCleanStartupList $Script:CleanStartupItems "No startup items found." "toggle" $Script:CleanStartupToggle
            Expand-GuiCard $startupListBox
            Set-GuiProgress 0
            Write-GuiLog "Startup Manager: $($Script:CleanStartupItems.Count) entries found" "OK"
        }
        Add-GuiBtn $p "Delete Selected" "RevertButtonStyle" {
            $selected = Get-CleanSelected $Script:CleanStartupItems
            foreach ($it in $selected) { Remove-StartupItem -Item $it }
        }
    } "&#xE7B5;" -WrapButtons -CollapseTarget $startupListBox
    $pnlContent.AddChild($startupListBox)

    # --- Device Cleanup (moved from Home > Tools) ---
    Add-GuiCard "Device Cleanup" "Launches the Windows Device Cleanup tool to remove unused device drivers and entries." {
        param($p)
        Add-GuiBtn $p "Run Device Cleanup" "ActionButtonStyle" { Invoke-CleanDeviceCleanup }
    } "&#xE90F;" -WrapButtons
}
