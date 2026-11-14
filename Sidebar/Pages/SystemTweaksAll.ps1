function Show-PageSystemTweaksAll {
    Clear-GuiContent
    Add-GuiPageTitle (T "System Tweaks")
    Add-GuiCard (T "Service Configuration") (T "Configure 50+ non-essential Windows services (telephony, maps, Xbox, NFC, fax, smart card, etc.) to Manual or Disabled to free up system resources.") {
        param($p) Add-GuiBtn $p (T "Disable Services") "ActionButtonStyle" { Invoke-ServicesApply }; Add-GuiBtn $p (T "Revert Services") "RevertButtonStyle" { Invoke-ServicesRevert }
    } "&#xEA37;" -WrapButtons
    Add-GuiCard (T "Printer") (T "Enable or disable printing services (Print Spooler, Printer Extensions and Notifications, PrintScanBroker, Print Device Configuration, PrintWorkflow). Reboot required.") {
        param($p) Add-GuiBtn $p (T "Enable Printer") "ActionButtonStyle" { Enable-Printer }; Add-GuiBtn $p (T "Disable Printer") "RevertButtonStyle" { Disable-Printer }
    } "&#xE749;" -WrapButtons
    Add-GuiCard (T "Notifications") (T "Enable or disable Windows Push Notifications System Service (toasts and app notifications). Reboot required.") {
        param($p) Add-GuiBtn $p (T "Enable Notifications") "ActionButtonStyle" { Enable-Notifications }; Add-GuiBtn $p (T "Disable Notifications") "RevertButtonStyle" { Disable-Notifications }
    } "&#xEA8F;" -WrapButtons
    Add-GuiCard (T "Bluetooth") (T "Enable or disable Bluetooth Support, AVCTP, Audio Gateway, User Support and Radio Management services. Reboot required.") {
        param($p) Add-GuiBtn $p (T "Enable Bluetooth") "ActionButtonStyle" { Enable-Bluetooth }; Add-GuiBtn $p (T "Disable Bluetooth") "RevertButtonStyle" { Disable-Bluetooth }
    } "&#xE702;" -WrapButtons
    Add-GuiCard (T "Game Pass / Xbox") (T "Enable or disable Xbox Live Auth Manager, Game Save and Networking services for Game Pass and Microsoft Store games. Reboot required.") {
        param($p) Add-GuiBtn $p (T "Enable Game Pass") "ActionButtonStyle" { Enable-GamePass }; Add-GuiBtn $p (T "Disable Game Pass") "RevertButtonStyle" { Disable-GamePass }
    } "&#xE7FC;" -WrapButtons
    Add-GuiCard (T "Comprehensive System Tweaks") (T "Remove Edge scheduled tasks and apply 60+ registry tweaks across categories: Telemetry/Diagnostics, Settings Sync, Maintenance, Interface/Appearance, Search/Cortana/Bing, and Kernel/Performance.") {
        param($p) Add-GuiBtn $p (T "Apply All System Tweaks") "ActionButtonStyle" { Invoke-TweaksApply }; Add-GuiBtn $p (T "Revert Tweaks") "RevertButtonStyle" { Invoke-TweaksRevert }
    } "&#xE713;" -WrapButtons
}