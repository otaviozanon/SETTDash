function Show-PageWindows {
    Clear-GuiContent
    Add-GuiPageTitle (T "Windows Tweaks")
    Add-GuiCard (T "Classic Context Menu") (T "Revert to the classic Windows 10-style right-click context menu.") {
        param($p) Add-GuiBtn $p (T "Apply Old Menu") "ActionButtonStyle" { Invoke-W11OldMenu }; Add-GuiBtn $p (T "Revert to W11 Menu") "RevertButtonStyle" { Invoke-W11RevertMenu }
    } "&#xE770;" -WrapButtons
    Add-GuiCard (T "Alt+Tab") (T "Switch between classic and modern Alt+Tab behavior.") {
        param($p) Add-GuiBtn $p (T "Apply Classic Alt+Tab") "ActionButtonStyle" { Invoke-W11ClassicAltTab }; Add-GuiBtn $p (T "Revert to Modern Alt+Tab") "RevertButtonStyle" { Invoke-W11RevertAltTab }
    } "&#xE770;" -WrapButtons
    Add-GuiCard (T "Context Menu Tweaks") (T "Apply or revert custom context menu tweaks.") {
        param($p) Add-GuiBtn $p (T "Apply Tweaks") "ActionButtonStyle" { Invoke-ContextApply }; Add-GuiBtn $p (T "Revert Tweaks") "RevertButtonStyle" { Invoke-ContextRevert }
    } "&#xE712;" -WrapButtons
    Add-GuiCard (T "Brave") (T "Disable Brave Rewards, Wallet, VPN, and AI Chat.") {
        param($p) Add-GuiBtn $p (T "Optimize Brave") "ActionButtonStyle" { Invoke-BraveTweaks }
    } "&#xE727;" -WrapButtons
    Add-GuiCard (T "Chrome") (T "Disable search suggestions, promotional tabs, and metrics reporting.") {
        param($p) Add-GuiBtn $p (T "Optimize Chrome") "ActionButtonStyle" { Invoke-ChromeTweaks }
    } "&#xE727;" -WrapButtons
    Add-GuiCard (T "Edge") (T "Disable sync, wallet, sidebar, web widget, and first-run experience.") {
        param($p) Add-GuiBtn $p (T "Optimize Edge") "ActionButtonStyle" { Invoke-EdgeTweaks }
    } "&#xE727;" -WrapButtons
    Add-GuiCard (T "Firefox") (T "Disable telemetry, Pocket, Firefox Studies, and search suggestions.") {
        param($p) Add-GuiBtn $p (T "Optimize Firefox") "ActionButtonStyle" { Invoke-FirefoxTweaks }
    } "&#xE727;" -WrapButtons
}
