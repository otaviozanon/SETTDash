function Show-PageWinShortcuts {
    Clear-GuiContent
    Add-GuiPageTitle "Windows Config"
    Add-GuiCard "Settings Shortcuts" "Quick access to Windows 11 configuration panels." {
        param($p)
        Add-GuiBtn $p "Accounts Info" "InstallButtonStyle" { Start-Process "ms-settings:yourinfo"; Write-GuiLog "Accounts Info opened" "OK" }
        Add-GuiBtn $p "Performance Options" "InstallButtonStyle" { Start-Process "SystemPropertiesPerformance.exe"; Write-GuiLog "Performance Options opened" "OK" }
        Add-GuiBtn $p "Advanced Graphics" "InstallButtonStyle" { Start-Process "ms-settings:display-advancedgraphics"; Write-GuiLog "Advanced Graphics opened" "OK" }
        Add-GuiBtn $p "Background Apps" "InstallButtonStyle" { Start-Process "ms-settings:privacy-backgroundapps"; Write-GuiLog "Background Apps opened" "OK" }
        Add-GuiBtn $p "Diagnostic Data" "InstallButtonStyle" { Start-Process "ms-settings:privacy-appdiagnostics"; Write-GuiLog "Diagnostics opened" "OK" }
        Add-GuiBtn $p "Game Bar" "InstallButtonStyle" { Start-Process "ms-settings:gaming-gamebar"; Write-GuiLog "Game Bar opened" "OK" }
        Add-GuiBtn $p "Game Mode" "InstallButtonStyle" { Start-Process "ms-settings:gaming-gamemode"; Write-GuiLog "Game Mode opened" "OK" }
        Add-GuiBtn $p "MSConfig" "InstallButtonStyle" { Start-Process "msconfig.exe"; Write-GuiLog "MSConfig opened" "OK" }
    } "&#xE713;" -WrapButtons
}
