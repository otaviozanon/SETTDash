function Show-PagePlaybooks {
    Clear-GuiContent
    Add-GuiPageTitle "Playbooks Download"
    Add-GuiCard "AME Wizard" "Download the latest AME Wizard from GitHub. Required to apply OS playbooks for debloating Windows." {
        param($p) Add-GuiBtn $p "Download AME Wizard" "InstallButtonStyle" { Invoke-PlaybookAME }
    } "&#xE753;" -WrapButtons
    Add-GuiCard "FSOS-X (FrameSyncLabs)" "Lightweight gaming-focused Windows optimization playbook. Extracted from FSOSX.com." {
        param($p) Add-GuiBtn $p "Download FSOS-X" "InstallButtonStyle" { Invoke-PlaybookFSOSX }
    } "&#xE753;" -WrapButtons
    Add-GuiCard "ReviOS" "Popular Windows debloating playbook with privacy improvements. From meetrevision/playbook." {
        param($p) Add-GuiBtn $p "Download ReviOS" "InstallButtonStyle" { Invoke-PlaybookReviOS }
    } "&#xE753;" -WrapButtons
    Add-GuiCard "AtlasOS" "Open-source Windows optimization playbook focused on gaming performance. From Atlas-OS/Atlas." {
        param($p) Add-GuiBtn $p "Download AtlasOS" "InstallButtonStyle" { Invoke-PlaybookAtlasOS }
    } "&#xE753;" -WrapButtons
}
