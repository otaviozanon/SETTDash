function Show-PageUtilities {
    Clear-GuiContent
    Add-GuiPageTitle (T "Utilities")
    Add-GuiCard (T "Apps") (T "System tools and utilities.") {
        param($p)
        Add-GuiBtn $p "MSI Util v3" "InstallButtonStyle" { Invoke-LaunchApp "MSI_util_v3.exe" "MSI Util v3" }
        Add-GuiBtn $p "O&O AppBuster" "InstallButtonStyle" { Invoke-LaunchApp "OOAPB.exe" "O&O AppBuster" }
        Add-GuiBtn $p "Autoruns" "InstallButtonStyle" { Invoke-LaunchApp "Autoruns64.exe" "Autoruns" }
        Add-GuiBtn $p "sPowers" "InstallButtonStyle" { Invoke-LaunchApp "sPowers_x64.exe" "sPowers" }
        Add-GuiBtn $p "Filter Keys" "InstallButtonStyle" { Invoke-FilterKeysTool }
    } "&#xEA99;" -WrapButtons
    Add-GuiCard (T "Monitor") (T "Monitoring and display tools (copied to Desktop).") {
        param($p)
        Add-GuiBtn $p "vibranceGUI" "InstallButtonStyle" { Invoke-LaunchToDesktop "vibranceGUI.exe" "vibranceGUI" }
        Add-GuiBtn $p "TimerResolution" "InstallButtonStyle" { Invoke-LaunchToDesktop "TimerResolution.exe" "TimerResolution" }
    } "&#xEA99;" -WrapButtons
    Add-GuiCard "SETT Memory Cleaner" (T "Memory cleaning and optimization tool. Downloads to your Desktop and launches automatically.") {
        param($p)
        Add-GuiBtn $p (T "Download") "InstallButtonStyle" { Invoke-DownloadLatestRelease -RepoOwner "otaviozanon" -RepoName "SETTMemoryCleaner" -AssetPattern "*.exe" -Label "SETT Memory Cleaner" }
    } "&#xEA99;" -WrapButtons
    Add-GuiCard "SETT UTILITY Extension" (T "Chrome browser extension for enhanced utility features. Downloads to your Downloads folder, then load unpacked in chrome://extensions.") {
        param($p)
        Add-GuiBtn $p (T "Download Extension") "InstallButtonStyle" { Invoke-CopySettUtility }
    } "&#xEA99;" -WrapButtons
}
