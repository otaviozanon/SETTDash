# Settings page: lets the user pick the dashboard's visual theme.
function Show-PageSettings {
    Clear-GuiContent
    Add-GuiPageTitle "Settings"

    Add-GuiCard "About / Updates" "SETTDash v$($Script:AppVersion). Check for a newer release right now." {
        param($p)
        Add-GuiBtn $p "Check for Updates Now" "InstallButtonStyle" { Invoke-CheckForUpdates }
    } "&#xE946;" -WrapButtons

    # 2x2 tile grid: Theme / Minimize to Tray / Auto-Start / Check for Updates all share the same
    # width AND height (Add-GuiCardGrid), instead of each sizing to its own content.
    $tiles = Add-GuiCardGrid -Columns 2 -Rows 2
    Add-GuiCard "Theme" "Choose the dashboard's visual style. Changes apply instantly and are remembered." {
        param($p)
        Add-GuiBtn $p "Default (Dark)" "InstallButtonStyle" { Set-GuiTheme "Default"; Write-GuiLog "Theme set to Default (Dark)" "OK" }
        Add-GuiBtn $p "Terminal Retro" "InstallButtonStyle" { Set-GuiTheme "TerminalRetro"; Write-GuiLog "Theme set to Terminal Retro" "OK" }
    } "&#xE713;" -WrapButtons -TargetPanel $tiles[0]

    Add-GuiToggleCard -Title "Minimize to Tray" `
        -Description "Choose what happens when you close the main window." `
        -GetState { Get-GuiMinimizeToTrayPref } `
        -OnToggle { param($isOn) if ($isOn) { Invoke-MinimizeToTrayApply } else { Invoke-MinimizeToTrayRevert } } `
        -OnStatus "closing the program will minimize it to the system tray." `
        -OffStatus "closing the program will close it." `
        -Icon "&#xE740;" -TargetPanel $tiles[1]

    Add-GuiToggleCard -Title "Auto-Start with Windows" `
        -Description "Launch SETTDash automatically in the background when Windows starts." `
        -GetState { Test-GuiAutoStartEnabled } `
        -OnToggle { param($isOn) if ($isOn) { Invoke-AutoStartApply } else { Invoke-AutoStartRevert } } `
        -OnStatus "closing the program will keep SETTDash starting with Windows." `
        -OffStatus "SETTDash will not start automatically with Windows." `
        -Icon "&#xE7E8;" -TargetPanel $tiles[2]

    Add-GuiToggleCard -Title "Check for Updates Automatically" `
        -Description "Look for a newer SETTDash release on GitHub every time the app starts." `
        -GetState { Get-GuiAutoUpdateCheckPref } `
        -OnToggle { param($isOn) Save-GuiAutoUpdateCheckPref $isOn; Write-GuiLog $(if ($isOn) { "Automatic update checks enabled" } else { "Automatic update checks disabled" }) "OK" } `
        -OnStatus "SETTDash will check for updates automatically on startup." `
        -OffStatus "SETTDash will not check for updates automatically. Use the button below to check manually." `
        -Icon "&#xE895;" -TargetPanel $tiles[3]

    $currentStartupKey = Get-GuiDefaultStartupPagePref
    Add-GuiCard "Default Startup Page" "Choose which page SETTDash opens on when it starts." {
        param($p)
        foreach ($displayName in $Script:StartupPageOptions.Keys) {
            $navKey = $Script:StartupPageOptions[$displayName]
            $btn = New-Object System.Windows.Controls.Button
            $btn.Content = $displayName
            $btn.Style = if ($navKey -eq $currentStartupKey) { $Window.FindResource("CategoryPillActiveStyle") } else { $Window.FindResource("CategoryPillStyle") }
            $btn.Add_Click({
                Save-GuiDefaultStartupPagePref $navKey
                Write-GuiLog "Default startup page set to: $displayName" "OK"
                Show-PageSettings
            }.GetNewClosure())
            $p.AddChild($btn)
        }
    } "&#xE7C5;" -WrapButtons
}
