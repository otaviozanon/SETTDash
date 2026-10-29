function Show-PageSystemTweaksAll {
    Clear-GuiContent
    Add-GuiPageTitle "System Tweaks"
    Add-GuiCard "Service Configuration" "Configure 50+ non-essential Windows services (telephony, maps, Xbox, NFC, fax, smart card, etc.) to Manual or Disabled to free up system resources." {
        param($p) Add-GuiBtn $p "Disable Services" "ActionButtonStyle" { Invoke-ServicesApply }; Add-GuiBtn $p "Revert Services" "RevertButtonStyle" { Invoke-ServicesRevert }
    } "&#xEA37;" -WrapButtons
    Add-GuiCard "Printer" "Enable or disable printing services (Print Spooler, Printer Extensions and Notifications, PrintScanBroker, Print Device Configuration, PrintWorkflow). Reboot required." {
        param($p) Add-GuiBtn $p "Enable Printer" "ActionButtonStyle" { Enable-Printer }; Add-GuiBtn $p "Disable Printer" "RevertButtonStyle" { Disable-Printer }
    } "&#xE749;" -WrapButtons
    Add-GuiCard "Notifications" "Enable or disable Windows Push Notifications System Service (toasts and app notifications). Reboot required." {
        param($p) Add-GuiBtn $p "Enable Notifications" "ActionButtonStyle" { Enable-Notifications }; Add-GuiBtn $p "Disable Notifications" "RevertButtonStyle" { Disable-Notifications }
    } "&#xEA8F;" -WrapButtons
    Add-GuiCard "Bluetooth" "Enable or disable Bluetooth Support, AVCTP, Audio Gateway, User Support and Radio Management services. Reboot required." {
        param($p) Add-GuiBtn $p "Enable Bluetooth" "ActionButtonStyle" { Enable-Bluetooth }; Add-GuiBtn $p "Disable Bluetooth" "RevertButtonStyle" { Disable-Bluetooth }
    } "&#xE702;" -WrapButtons
    Add-GuiCard "Game Pass / Xbox" "Enable or disable Xbox Live Auth Manager, Game Save and Networking services for Game Pass and Microsoft Store games. Reboot required." {
        param($p) Add-GuiBtn $p "Enable Game Pass" "ActionButtonStyle" { Enable-GamePass }; Add-GuiBtn $p "Disable Game Pass" "RevertButtonStyle" { Disable-GamePass }
    } "&#xE7FC;" -WrapButtons
    Add-GuiCard "Comprehensive System Tweaks" "Remove Edge scheduled tasks and apply 60+ registry tweaks across categories: Telemetry/Diagnostics, Settings Sync, Maintenance, Interface/Appearance, Search/Cortana/Bing, and Kernel/Performance." {
        param($p) Add-GuiBtn $p "Apply All System Tweaks" "ActionButtonStyle" { Invoke-TweaksApply }; Add-GuiBtn $p "Revert Tweaks" "RevertButtonStyle" { Invoke-TweaksRevert }
    } "&#xE713;" -WrapButtons
}