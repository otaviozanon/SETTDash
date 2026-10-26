function Show-PageSystemTweaksAll {
    Clear-GuiContent
    Add-GuiPageTitle "System Tweaks"
    Add-GuiCard "Service Configuration" "Configure 50+ non-essential Windows services (telephony, maps, Xbox, NFC, fax, smart card, etc.) to Manual or Disabled to free up system resources." {
        param($p) Add-GuiBtn $p "Disable Services" "ActionButtonStyle" { Invoke-ServicesApply }; Add-GuiBtn $p "Revert Services" "RevertButtonStyle" { Invoke-ServicesRevert }
    } "&#xEA37;" -WrapButtons
    Add-GuiCard "Comprehensive System Tweaks" "Remove Edge scheduled tasks and apply 60+ registry tweaks across categories: Telemetry/Diagnostics, Settings Sync, Maintenance, Interface/Appearance, Search/Cortana/Bing, and Kernel/Performance." {
        param($p) Add-GuiBtn $p "Apply All System Tweaks" "ActionButtonStyle" { Invoke-TweaksApply }; Add-GuiBtn $p "Revert Tweaks" "RevertButtonStyle" { Invoke-TweaksRevert }
    } "&#xE713;" -WrapButtons
}
