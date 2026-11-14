function Show-PagePlaybooks {
    Clear-GuiContent
    Add-GuiPageTitle (T "Playbooks Download")
    Add-GuiCard "AME Wizard" (T "Download the latest AME Wizard from GitHub. Required to apply OS playbooks for debloating Windows.") {
        param($p) Add-GuiBtn $p (T "Download AME Wizard") "InstallButtonStyle" { Invoke-PlaybookAME }
    } "&#xE753;" -WrapButtons
    Add-GuiCard "FSOS-X (FrameSyncLabs)" (T "Lightweight gaming-focused Windows optimization playbook. Extracted from FSOSX.com.") {
        param($p) Add-GuiBtn $p (T "Download FSOS-X") "InstallButtonStyle" { Invoke-PlaybookFSOSX }
    } "&#xE753;" -WrapButtons
    Add-GuiCard "ReviOS" (T "Popular Windows debloating playbook with privacy improvements. From meetrevision/playbook.") {
        param($p) Add-GuiBtn $p (T "Download ReviOS") "InstallButtonStyle" { Invoke-PlaybookReviOS }
    } "&#xE753;" -WrapButtons
    Add-GuiCard "AtlasOS" (T "Open-source Windows optimization playbook focused on gaming performance. From Atlas-OS/Atlas.") {
        param($p) Add-GuiBtn $p (T "Download AtlasOS") "InstallButtonStyle" { Invoke-PlaybookAtlasOS }
    } "&#xE753;" -WrapButtons
}
