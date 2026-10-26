function Show-PageWinShortcuts {
    Clear-GuiContent
    Add-GuiPageTitle "Windows Config"
    Add-GuiCard "Settings Shortcuts" "Quick access to Windows 11 configuration panels." {
        param($p)
        Add-GuiBtn $p "Accounts Info" "ActionButtonStyle" { Start-Process "ms-settings:yourinfo"; Write-GuiLog "Accounts Info opened" "OK" }
        Add-GuiBtn $p "Performance Options" "ActionButtonStyle" { Start-Process "SystemPropertiesPerformance.exe"; Write-GuiLog "Performance Options opened" "OK" }
        Add-GuiBtn $p "Advanced Graphics" "ActionButtonStyle" { Start-Process "ms-settings:display-advancedgraphics"; Write-GuiLog "Advanced Graphics opened" "OK" }
        Add-GuiBtn $p "Background Apps" "ActionButtonStyle" { Start-Process "ms-settings:privacy-backgroundapps"; Write-GuiLog "Background Apps opened" "OK" }
        Add-GuiBtn $p "Diagnostic Data" "ActionButtonStyle" { Start-Process "ms-settings:privacy-appdiagnostics"; Write-GuiLog "Diagnostics opened" "OK" }
        Add-GuiBtn $p "Game Bar" "ActionButtonStyle" { Start-Process "ms-settings:gaming-gamebar"; Write-GuiLog "Game Bar opened" "OK" }
        Add-GuiBtn $p "Game Mode" "ActionButtonStyle" { Start-Process "ms-settings:gaming-gamemode"; Write-GuiLog "Game Mode opened" "OK" }
        Add-GuiBtn $p "MSConfig" "ActionButtonStyle" { Start-Process "msconfig.exe"; Write-GuiLog "MSConfig opened" "OK" }
    } "&#xE713;" -WrapButtons
}
