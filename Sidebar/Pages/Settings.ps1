# Settings page: lets the user pick the dashboard's visual theme.
function Show-PageSettings {
    Clear-GuiContent
    Add-GuiPageTitle (T "Settings")

    Add-GuiCard (T "About / Updates") "$(T 'SETTDash v')$($Script:AppVersion). $(T 'Check for a newer release right now.')" {
        param($p)
        Add-GuiBtn $p (T "Check for Updates Now") "InstallButtonStyle" { Invoke-CheckForUpdates }
    } "&#xE946;" -WrapButtons

    # 2x2 tile grid: Theme / Minimize to Tray / Auto-Start / Check for Updates all share the same
    # width AND height (Add-GuiCardGrid), instead of each sizing to its own content.
    $tiles = @(Add-GuiCardGrid -Columns 2 -Rows 2)
    Add-GuiCard (T "Theme") (T "Choose the dashboard's visual style. Changes apply instantly and are remembered.") {
        param($p)
        Add-GuiBtn $p (T "Default (Dark)") "InstallButtonStyle" { Set-GuiTheme "Default"; Write-GuiLog (T "Theme set to Default (Dark)") "OK" }
        Add-GuiBtn $p (T "Terminal Retro") "InstallButtonStyle" { Set-GuiTheme "TerminalRetro"; Write-GuiLog (T "Theme set to Terminal Retro") "OK" }
    } "&#xE713;" -WrapButtons -TargetPanel $tiles[0]

    Add-GuiToggleCard -Title (T "Minimize to Tray") `
        -Description (T "Choose what happens when you close the main window.") `
        -GetState { Get-GuiMinimizeToTrayPref } `
        -OnToggle { param($isOn) if ($isOn) { Invoke-MinimizeToTrayApply } else { Invoke-MinimizeToTrayRevert } } `
        -OnStatus (T "closing the program will minimize it to the system tray.") `
        -OffStatus (T "closing the program will close it.") `
        -Icon "&#xE740;" -TargetPanel $tiles[1]

    Add-GuiToggleCard -Title (T "Auto-Start with Windows") `
        -Description (T "Launch SETTDash automatically in the background when Windows starts.") `
        -GetState { Test-GuiAutoStartEnabled } `
        -OnToggle { param($isOn) if ($isOn) { Invoke-AutoStartApply } else { Invoke-AutoStartRevert } } `
        -OnStatus (T "closing the program will keep SETTDash starting with Windows.") `
        -OffStatus (T "SETTDash will not start automatically with Windows.") `
        -Icon "&#xE7E8;" -TargetPanel $tiles[2]

    Add-GuiToggleCard -Title (T "Check for Updates Automatically") `
        -Description (T "Look for a newer SETTDash release on GitHub every time the app starts.") `
        -GetState { Get-GuiAutoUpdateCheckPref } `
        -OnToggle { param($isOn) Save-GuiAutoUpdateCheckPref $isOn; Write-GuiLog $(if ($isOn) { "Automatic update checks enabled" } else { "Automatic update checks disabled" }) "OK" } `
        -OnStatus (T "SETTDash will check for updates automatically on startup.") `
        -OffStatus (T "SETTDash will not check for updates automatically. Use the button below to check manually.") `
        -Icon "&#xE895;" -TargetPanel $tiles[3]

    Add-GuiCard (T "Language") (T "Choose the dashboard's display language. Applies the next time a page is opened.") {
        param($p)
        $enBtn = New-Object System.Windows.Controls.Button
        $enBtn.Content = "English"
        $enBtn.Style = if ($Script:CurrentLanguage -eq "EN") { $Window.FindResource("CategoryPillActiveStyle") } else { $Window.FindResource("CategoryPillStyle") }
        $enBtn.Add_Click({
            Set-GuiLanguage "EN"
            Update-SidebarLanguage
            Write-GuiLog (T "Language set to English") "OK"
            Show-PageSettings
        }.GetNewClosure())
        $p.AddChild($enBtn)

        $ptBtn = New-Object System.Windows.Controls.Button
        $ptBtn.Content = "Português"
        $ptBtn.Style = if ($Script:CurrentLanguage -eq "PT") { $Window.FindResource("CategoryPillActiveStyle") } else { $Window.FindResource("CategoryPillStyle") }
        $ptBtn.Add_Click({
            Set-GuiLanguage "PT"
            Update-SidebarLanguage
            Write-GuiLog "Idioma definido para Português" "OK"
            Show-PageSettings
        }.GetNewClosure())
        $p.AddChild($ptBtn)
    } "&#xE774;" -WrapButtons

    $currentStartupKey = Get-GuiDefaultStartupPagePref
    Add-GuiCard (T "Default Startup Page") (T "Choose which page SETTDash opens on when it starts.") {
        param($p)
        foreach ($displayName in $Script:StartupPageOptions.Keys) {
            $navKey = $Script:StartupPageOptions[$displayName]
            $btn = New-Object System.Windows.Controls.Button
            $btn.Content = (T $displayName)
            $btn.Style = if ($navKey -eq $currentStartupKey) { $Window.FindResource("CategoryPillActiveStyle") } else { $Window.FindResource("CategoryPillStyle") }
            $btn.Add_Click({
                Save-GuiDefaultStartupPagePref $navKey
                Write-GuiLog ((T "Default startup page set to: {0}") -f (T $displayName)) "OK"
                Show-PageSettings
            }.GetNewClosure())
            $p.AddChild($btn)
        }
    } "&#xE7C5;" -WrapButtons
}
