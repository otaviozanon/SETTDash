
# Startup page (single consolidated page, below Network in the sidebar).
# Four categories, mirroring MSConfig's "Startup" tab + Task Scheduler, shown as category
# pills (like YourPCSensors.ps1) instead of stacked cards - each category returns many items,
# so it gets the whole page width/height instead of sharing scroll space with the other three:
#   1. Registry Run/RunOnce entries (HKCU+HKLM) - the actual MSConfig startup list.
#   2. Startup folder shortcuts (current user).
#   3. Logon tasks (Task Scheduler entries with a logon trigger, Microsoft tasks excluded).
#   4. Scheduled items (ALL Task Scheduler entries), with a toggle to show/hide Microsoft's own.
function Show-PageStartup {
    Clear-GuiContent
    Add-GuiPageTitle "Startup"

    # ---- Category pills (icon + label, same style as YourPCSensors) ----
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

    # Builds a pill Button with an icon glyph + text label, styled like CategoryPillStyle.
    function New-StartupPill {
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

    # --- Category 1: Registry (MSConfig-style) ---
    $Script:StartupRegItems = @()
    $Script:pnlStartupReg = New-Object System.Windows.Controls.StackPanel
    $Script:StartupRegBox = New-CleanListContainer $Script:pnlStartupReg
    $Script:StartupRegToggle = { param($it) return Set-StartupItemEnabled -Item $it -Enabled (-not [bool]$it.Selected) }
    $panelReg = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Registry (MSConfig)" "Run/RunOnce entries from HKCU and HKLM - same list shown by msconfig's Startup tab. Toggle items on/off (same behavior as msconfig: disabling keeps the original command so it can be re-enabled later)." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlStartupReg $s.Text
        })
        Add-GuiBackgroundBtn $p "Scan" { Get-StartupRegistryItems } @('Get-StartupRegistryItems') {
            param($items)
            $Script:StartupRegItems = @($items)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlStartupReg $Script:StartupRegItems "No registry startup entries found." "toggle" $Script:StartupRegToggle
            Set-GuiProgress 0
            Write-GuiLog "Registry startup: $($Script:StartupRegItems.Count) entries found" "OK"
        } -Style "RevertButtonStyle"
    } "&#xE74C;" -WrapButtons -TargetPanel $panelReg
    $panelReg.AddChild($Script:StartupRegBox)
    $panelReg.Visibility = "Collapsed"
    $pnlContent.AddChild($panelReg)
    $categoryPanels["Registry"] = $panelReg

    # --- Category 2: Startup folder ---
    $Script:StartupFolderItems = @()
    $Script:pnlStartupFolder = New-Object System.Windows.Controls.StackPanel
    $Script:StartupFolderBox = New-CleanListContainer $Script:pnlStartupFolder
    $panelFolder = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Startup Folder" "Shortcuts placed in the current user's Startup folder. These only support Delete (Windows has no enable/disable flag for folder shortcuts)." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlStartupFolder $s.Text
        })
        Add-GuiBackgroundBtn $p "Scan" { Get-StartupFolderItems } @('Get-StartupFolderItems') {
            param($items)
            $Script:StartupFolderItems = @($items)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlStartupFolder $Script:StartupFolderItems "No Startup folder shortcuts found." "plain"
            Set-GuiProgress 0
            Write-GuiLog "Startup folder: $($Script:StartupFolderItems.Count) shortcuts found" "OK"
        } -Style "RevertButtonStyle"
        Add-CleanSelectAllBtn $p $Script:pnlStartupFolder "ActionButtonStyle" { $Script:StartupFolderItems } | Out-Null
        Add-GuiBtn $p "Delete Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:StartupFolderItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            $ok = Show-GuiConfirm -Title "Delete Startup Shortcuts" -Icon "&#xE74D;" `
                -Message "This permanently deletes the $($selected.Count) selected shortcut(s) from the Startup folder. Continue?" `
                -ConfirmText "Delete"
            if (-not $ok) { return }
            foreach ($it in $selected) { Remove-StartupItem -Item $it }
            Write-GuiLog "Deleted $($selected.Count) Startup folder item(s)." "OK"
            Update-CleanChecklist $Script:pnlStartupFolder { Get-StartupFolderItems } {
                param($items) $Script:StartupFolderItems = @($items)
            } @('Get-StartupFolderItems') "No Startup folder shortcuts found." "plain"
        }
    } "&#xE7B5;" -WrapButtons -TargetPanel $panelFolder
    $panelFolder.AddChild($Script:StartupFolderBox)
    $panelFolder.Visibility = "Collapsed"
    $pnlContent.AddChild($panelFolder)
    $categoryPanels["Startup Folder"] = $panelFolder

    # --- Category 3: Logon tasks ---
    $Script:StartupLogonItems = @()
    $Script:pnlStartupLogon = New-Object System.Windows.Controls.StackPanel
    $Script:StartupLogonBox = New-CleanListContainer $Script:pnlStartupLogon
    $Script:StartupLogonToggle = { param($it) return Set-StartupItemEnabled -Item $it -Enabled (-not [bool]$it.Selected) }
    $panelLogon = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Logon Tasks" "Task Scheduler entries that run at logon (Microsoft's own tasks excluded). Enable, disable or delete selected tasks." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlStartupLogon $s.Text
        })
        Add-GuiBackgroundBtn $p "Scan" { Get-StartupLogonTaskItems } @('Get-StartupLogonTaskItems') {
            param($items)
            $Script:StartupLogonItems = @($items)
            Set-GuiProgress 90
            Set-CleanChecklist $Script:pnlStartupLogon $Script:StartupLogonItems "No logon tasks found." "toggle" $Script:StartupLogonToggle
            Set-GuiProgress 0
            Write-GuiLog "Logon tasks: $($Script:StartupLogonItems.Count) tasks found" "OK"
        } -Style "RevertButtonStyle"
        Add-GuiBtn $p "Delete Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:StartupLogonItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            $ok = Show-GuiConfirm -Title "Delete Logon Tasks" -Icon "&#xE74D;" `
                -Message "This permanently deletes the $($selected.Count) selected scheduled task(s). Continue?" `
                -ConfirmText "Delete"
            if (-not $ok) { return }
            foreach ($it in $selected) { Remove-StartupItem -Item $it }
            Write-GuiLog "Deleted $($selected.Count) logon task(s)." "OK"
            Update-CleanChecklist $Script:pnlStartupLogon { Get-StartupLogonTaskItems } {
                param($items) $Script:StartupLogonItems = @($items)
            } @('Get-StartupLogonTaskItems') "No logon tasks found." "toggle" $Script:StartupLogonToggle
        }
    } "&#xE7E8;" -WrapButtons -TargetPanel $panelLogon
    $panelLogon.AddChild($Script:StartupLogonBox)
    $panelLogon.Visibility = "Collapsed"
    $pnlContent.AddChild($panelLogon)
    $categoryPanels["Logon Tasks"] = $panelLogon

    # --- Category 4: Scheduled items (all tasks, with Microsoft show/hide toggle) ---
    $Script:SchedItems = @()
    $Script:ShowMicrosoftTasks = $false
    $Script:pnlSchedItems = New-Object System.Windows.Controls.StackPanel
    $Script:SchedItemsBox = New-CleanListContainer $Script:pnlSchedItems
    $Script:SchedItemsToggle = { param($it) return Set-ScheduledTaskEnabled -Item $it -Enabled (-not [bool]$it.Selected) }
    $Script:SchedScanWork = { Get-ScheduledTaskItems -IncludeMicrosoft:$Script:ShowMicrosoftTasks }
    $Script:SchedScanDone = {
        param($items)
        $Script:SchedItems = @($items)
        Set-GuiProgress 90
        Set-CleanChecklist $Script:pnlSchedItems $Script:SchedItems "No scheduled items found." "toggle" $Script:SchedItemsToggle
        Set-GuiProgress 0
        Write-GuiLog "Scheduled items: $($Script:SchedItems.Count) tasks found" "OK"
    }
    $Script:RescanSchedItems = {
        Start-GuiBackgroundJob -Work $Script:SchedScanWork -Functions @('Get-ScheduledTaskItems') `
            -Name "Scheduled items scan" -OnDone $Script:SchedScanDone | Out-Null
    }
    $panelSched = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Scheduled Items" "All Task Scheduler items, excluding Microsoft's own tasks by default. Enable, disable or delete selected items." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlSchedItems $s.Text
        })
        $chkMs = New-Object System.Windows.Controls.CheckBox
        $chkMs.Content = "Show Microsoft tasks"
        $chkMs.FontSize = 12
        $chkMs.VerticalAlignment = "Center"
        $chkMs.Margin = "0,0,10,0"
        $chkMs.SetResourceReference([System.Windows.Controls.CheckBox]::ForegroundProperty, "Brush_TextPrimary")
        $chkMs.SetResourceReference([System.Windows.Controls.CheckBox]::FontFamilyProperty, "Theme_FontFamily")
        $chkMs.IsChecked = $Script:ShowMicrosoftTasks
        # NOTE: no .GetNewClosure() here - it rebinds the scriptblock to a new, isolated
        # session state, so $Script:-scoped lookups inside it (RescanSchedItems,
        # ShowMicrosoftTasks) would resolve against an empty scope instead of the real
        # script scope ("& $null" -> "expression after '&' ... not valid"). Reading the
        # checked state off the event sender ($s) avoids needing a closure at all.
        $chkMs.Add_Click({
            param($s, $e)
            Clear-GuiLog; Set-GuiProgress 0
            $Script:ShowMicrosoftTasks = [bool]$s.IsChecked
            & $Script:RescanSchedItems
        })
        $p.AddChild($chkMs)
        Add-GuiBackgroundBtn $p "Scan" $Script:SchedScanWork @('Get-ScheduledTaskItems') $Script:SchedScanDone -Style "RevertButtonStyle"
        Add-GuiBtn $p "Delete Selected" "ActionButtonStyle" {
            $selected = @(Get-CleanSelected $Script:SchedItems)
            if ($selected.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
            $ok = Show-GuiConfirm -Title "Delete Scheduled Items" -Icon "&#xE74D;" `
                -Message "This permanently deletes the $($selected.Count) selected scheduled task(s). Continue?" `
                -ConfirmText "Delete"
            if (-not $ok) { return }
            foreach ($it in $selected) { Remove-ScheduledTaskItem -Item $it }
            Write-GuiLog "Deleted $($selected.Count) scheduled item(s)." "OK"
            & $Script:RescanSchedItems
        }
    } "&#xE823;" -WrapButtons -TargetPanel $panelSched
    $panelSched.AddChild($Script:SchedItemsBox)
    $panelSched.Visibility = "Collapsed"
    $pnlContent.AddChild($panelSched)
    $categoryPanels["Scheduled Items"] = $panelSched

    # ---- Wire pills + default selection ----
    $pillDefs = @(
        @{ Icon = "&#xE74C;"; Label = "Registry" },
        @{ Icon = "&#xE7B5;"; Label = "Startup Folder" },
        @{ Icon = "&#xE7E8;"; Label = "Logon Tasks" },
        @{ Icon = "&#xE823;"; Label = "Scheduled Items" }
    )
    foreach ($def in $pillDefs) {
        $btn = New-StartupPill $def.Icon $def.Label
        $btn.Add_Click({ & $setActiveCategory $def.Label }.GetNewClosure())
        $pillButtons[$def.Label] = $btn
        $pillsStack.AddChild($btn)
    }
    & $setActiveCategory "Registry"
}
