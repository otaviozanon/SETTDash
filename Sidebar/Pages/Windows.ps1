function Show-PageWindows {
    Clear-GuiContent
    Add-GuiPageTitle "Windows Tweaks"
    Add-GuiCard "Classic Context Menu" "Revert to the classic Windows 10-style right-click context menu." {
        param($p) Add-GuiBtn $p "Apply Old Menu" "ActionButtonStyle" { Invoke-W11OldMenu }; Add-GuiBtn $p "Revert to W11 Menu" "RevertButtonStyle" { Invoke-W11RevertMenu }
    } "&#xE770;" -WrapButtons
    Add-GuiCard "Alt+Tab" "Switch between classic and modern Alt+Tab behavior." {
        param($p) Add-GuiBtn $p "Apply Classic Alt+Tab" "ActionButtonStyle" { Invoke-W11ClassicAltTab }; Add-GuiBtn $p "Revert to Modern Alt+Tab" "RevertButtonStyle" { Invoke-W11RevertAltTab }
    } "&#xE770;" -WrapButtons
    Add-GuiCard "Context Menu Tweaks" "Apply or revert custom context menu tweaks." {
        param($p) Add-GuiBtn $p "Apply Tweaks" "ActionButtonStyle" { Invoke-ContextApply }; Add-GuiBtn $p "Revert Tweaks" "RevertButtonStyle" { Invoke-ContextRevert }
    } "&#xE712;" -WrapButtons
    Add-GuiCard "Brave" "Disable Brave Rewards, Wallet, VPN, and AI Chat." {
        param($p) Add-GuiBtn $p "Optimize Brave" "ActionButtonStyle" { Invoke-BraveTweaks }
    } "&#xE727;" -WrapButtons
    Add-GuiCard "Chrome" "Disable search suggestions, promotional tabs, and metrics reporting." {
        param($p) Add-GuiBtn $p "Optimize Chrome" "ActionButtonStyle" { Invoke-ChromeTweaks }
    } "&#xE727;" -WrapButtons
    Add-GuiCard "Edge" "Disable sync, wallet, sidebar, web widget, and first-run experience." {
        param($p) Add-GuiBtn $p "Optimize Edge" "ActionButtonStyle" { Invoke-EdgeTweaks }
    } "&#xE727;" -WrapButtons
    Add-GuiCard "Firefox" "Disable telemetry, Pocket, Firefox Studies, and search suggestions." {
        param($p) Add-GuiBtn $p "Optimize Firefox" "ActionButtonStyle" { Invoke-FirefoxTweaks }
    } "&#xE727;" -WrapButtons
}
