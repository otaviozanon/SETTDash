function Show-PageUtilities {
    Clear-GuiContent
    Add-GuiPageTitle "Utilities"
    Add-GuiCard "Apps" "System tools and utilities." {
        param($p)
        Add-GuiBtn $p "MSI Util v3" "ActionButtonStyle" { Invoke-LaunchApp "MSI_util_v3.exe" "MSI Util v3" }
        Add-GuiBtn $p "O&O AppBuster" "ActionButtonStyle" { Invoke-LaunchApp "OOAPB.exe" "O&O AppBuster" }
        Add-GuiBtn $p "Autoruns" "ActionButtonStyle" { Invoke-LaunchApp "Autoruns64.exe" "Autoruns" }
        Add-GuiBtn $p "sPowers" "ActionButtonStyle" { Invoke-LaunchApp "sPowers_x64.exe" "sPowers" }
    } "&#xEA99;" -WrapButtons
    Add-GuiCard "Monitor" "Monitoring and display tools (copied to Desktop)." {
        param($p)
        Add-GuiBtn $p "vibranceGUI" "ActionButtonStyle" { Invoke-LaunchToDesktop "vibranceGUI.exe" "vibranceGUI" }
        Add-GuiBtn $p "TimerResolution" "ActionButtonStyle" { Invoke-LaunchToDesktop "TimerResolution.exe" "TimerResolution" }
    } "&#xEA99;" -WrapButtons
    Add-GuiCard "SETT Memory Cleaner" "Memory cleaning and optimization tool. Downloads to your Desktop and launches automatically." {
        param($p)
        Add-GuiBtn $p "Download" "ActionButtonStyle" { Invoke-DownloadLatestRelease -RepoOwner "otaviozanon" -RepoName "SETTMemoryCleaner" -AssetPattern "*.exe" -Label "SETT Memory Cleaner" }
    } "&#xEA99;" -WrapButtons
    Add-GuiCard "SETT UTILITY Extension" "Chrome browser extension for enhanced utility features. Downloads to your Downloads folder, then load unpacked in chrome://extensions." {
        param($p)
        Add-GuiBtn $p "Download Extension" "ActionButtonStyle" { Invoke-CopySettUtility }
    } "&#xEA99;" -WrapButtons
}
