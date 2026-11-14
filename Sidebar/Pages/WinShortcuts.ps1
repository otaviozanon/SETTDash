function Show-PageWinShortcuts {
    Clear-GuiContent
    Add-GuiPageTitle (T "Windows Config")
    Add-GuiCard (T "Settings Shortcuts") (T "Quick access to Windows 11 configuration panels.") {
        param($p)
        Add-GuiBtn $p "Accounts Info" "InstallButtonStyle" { Start-Process "ms-settings:yourinfo"; Write-GuiLog (T "Accounts Info opened") "OK" }
        # System32 tools must be launched through Start-SystemTool: in a 32-bit host System32 is
        # redirected to SysWOW64 and msconfig.exe (64-bit only) is not found there.
        Add-GuiBtn $p "Performance Options" "InstallButtonStyle" { Start-SystemTool "SystemPropertiesPerformance.exe" "Performance Options" }
        Add-GuiBtn $p "Advanced Graphics" "InstallButtonStyle" { Start-Process "ms-settings:display-advancedgraphics"; Write-GuiLog (T "Advanced Graphics opened") "OK" }
        Add-GuiBtn $p "Background Apps" "InstallButtonStyle" { Start-Process "ms-settings:privacy-backgroundapps"; Write-GuiLog (T "Background Apps opened") "OK" }
        Add-GuiBtn $p "Diagnostic Data" "InstallButtonStyle" { Start-Process "ms-settings:privacy-appdiagnostics"; Write-GuiLog (T "Diagnostics opened") "OK" }
        Add-GuiBtn $p "Game Bar" "InstallButtonStyle" { Start-Process "ms-settings:gaming-gamebar"; Write-GuiLog (T "Game Bar opened") "OK" }
        Add-GuiBtn $p "Game Mode" "InstallButtonStyle" { Start-Process "ms-settings:gaming-gamemode"; Write-GuiLog (T "Game Mode opened") "OK" }
        Add-GuiBtn $p "MSConfig" "InstallButtonStyle" { Start-SystemTool "msconfig.exe" "MSConfig" }
    } "&#xE713;" -WrapButtons
}
