
# Startup page (single consolidated page, below Network in the sidebar).
# Four categories, each mirroring the tool Windows users normally open to manage it, shown as
# category pills (like YourPCSensors.ps1) instead of stacked cards - each category returns many
# items, so it gets the whole page width/height instead of sharing scroll space with the others:
#   1. Registry (MSConfig/Task Manager Startup) - Run/RunOnce entries + StartupApproved state.
#   2. Startup folders - user and all users.
#   3. Services - Windows services, the same list MSConfig's Services tab shows.
#   4. Scheduled items - Task Scheduler.
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
    Add-GuiCard "Registry (MSConfig)" "Run/RunOnce entries from HKCU and HKLM, with the same enabled/disabled state Task Manager's Startup tab uses (StartupApproved). Disabling keeps the command in place, exactly like msconfig/Task Manager." {
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
    $Script:StartupFolderToggle = { param($it) return Set-StartupItemEnabled -Item $it -Enabled (-not [bool]$it.Selected) }
    $panelFolder = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Startup Folder" "Shortcuts in the current user's and the all-users Startup folders. Enable/disable uses the same state Task Manager writes (StartupApproved), so the shortcut stays on disk; Delete removes it." {
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
            Set-CleanChecklist $Script:pnlStartupFolder $Script:StartupFolderItems "No Startup folder shortcuts found." "toggle" $Script:StartupFolderToggle
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
            } @('Get-StartupFolderItems') "No Startup folder shortcuts found." "toggle" $Script:StartupFolderToggle
        }
    } "&#xE7B5;" -WrapButtons -TargetPanel $panelFolder
    $panelFolder.AddChild($Script:StartupFolderBox)
    $panelFolder.Visibility = "Collapsed"
    $pnlContent.AddChild($panelFolder)
    $categoryPanels["Startup Folder"] = $panelFolder

    # --- Category 3: Services (MSConfig's Services tab) ---
    $Script:ServiceItems = @()
    $Script:ShowMicrosoftServices = $false
    $Script:pnlServices = New-Object System.Windows.Controls.StackPanel
    $Script:ServicesBox = New-CleanListContainer $Script:pnlServices
    $Script:ServicesToggle = { param($it) return Set-ServiceItemEnabled -Item $it -Enabled (-not [bool]$it.Selected) }
    $Script:ServicesScanWork = { Get-ServiceItems -IncludeMicrosoft:$Script:ShowMicrosoftServices }
    $Script:ServicesScanDone = {
        param($items)
        $Script:ServiceItems = @($items)
        Set-GuiProgress 90
        Set-CleanChecklist $Script:pnlServices $Script:ServiceItems "No services found." "toggle" $Script:ServicesToggle
        Set-GuiProgress 0
        Write-GuiLog "Services: $($Script:ServiceItems.Count) services found" "OK"
    }
    $Script:RescanServices = {
        Start-GuiBackgroundJob -Work $Script:ServicesScanWork -Functions @('Get-ServiceItems') `
            -Name "Services scan" -OnDone $Script:ServicesScanDone | Out-Null
    }
    $panelServices = New-Object System.Windows.Controls.StackPanel
    Add-GuiCard "Services" "Windows services, the same list MSConfig's Services tab shows. Microsoft's own services are hidden by default. Disable sets the start type to Disabled; Enable restores Automatic/Manual. Disabling does not stop a service that is already running." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search service name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlServices $s.Text
        })
        $chkMs = New-Object System.Windows.Controls.CheckBox
        $chkMs.Content = "Show Microsoft services"
        $chkMs.FontSize = 12
        $chkMs.VerticalAlignment = "Center"
        $chkMs.Margin = "0,0,10,0"
        $chkMs.SetResourceReference([System.Windows.Controls.CheckBox]::ForegroundProperty, "Brush_TextPrimary")
        $chkMs.SetResourceReference([System.Windows.Controls.CheckBox]::FontFamilyProperty, "Theme_FontFamily")
        $chkMs.IsChecked = $Script:ShowMicrosoftServices
        $chkMs.Add_Click({
            param($s, $e)
            Clear-GuiLog; Set-GuiProgress 0
            $Script:ShowMicrosoftServices = [bool]$s.IsChecked
            & $Script:RescanServices
        })
        $p.AddChild($chkMs)
        Add-GuiBackgroundBtn $p "Scan" $Script:ServicesScanWork @('Get-ServiceItems') $Script:ServicesScanDone -Style "RevertButtonStyle"
    } "&#xE7F4;" -WrapButtons -TargetPanel $panelServices
    $panelServices.AddChild($Script:ServicesBox)
    $panelServices.Visibility = "Collapsed"
    $pnlContent.AddChild($panelServices)
    $categoryPanels["Services"] = $panelServices

    # --- Category 4: Scheduled items (Task Scheduler, Microsoft's tasks excluded) ---
    $Script:SchedItems = @()
    $Script:pnlSchedItems = New-Object System.Windows.Controls.StackPanel
    $Script:SchedItemsBox = New-CleanListContainer $Script:pnlSchedItems
    $Script:SchedItemsToggle = { param($it) return Set-ScheduledTaskEnabled -Item $it -Enabled (-not [bool]$it.Selected) }
    $Script:SchedScanWork = { Get-ScheduledTaskItems }
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
    Add-GuiCard "Scheduled Items" "Task Scheduler items that do not belong to Windows. Microsoft's own tasks are never listed, so they cannot be disabled or deleted here. Enable, disable or delete the selected third-party tasks." {
        param($p)
        $p.AddChild((New-CleanSearchBox "Search name or path..."))
        $p.Children[0].Tag.Add_TextChanged({
            param($s, $e)
            Set-CleanFilter $Script:pnlSchedItems $s.Text
        })
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
        @{ Icon = "&#xE823;"; Label = "Scheduled Items" },
        @{ Icon = "&#xE7F4;"; Label = "Services" }
    )
    foreach ($def in $pillDefs) {
        $btn = New-StartupPill $def.Icon $def.Label
        $btn.Add_Click({ & $setActiveCategory $def.Label }.GetNewClosure())
        $pillButtons[$def.Label] = $btn
        $pillsStack.AddChild($btn)
    }
    & $setActiveCategory "Registry"
}
