function Show-PageNetworkPrivacy {
    Clear-GuiContent
    Add-GuiPageTitle "Network & Privacy"
    Add-GuiCard "TCP & QoS Optimization" "Disable TCP autotuning, apply QoS policies for Valorant and CSGO, and increase FastSendDatagramThreshold for lower latency." {
        param($p) Add-GuiBtn $p "Apply Optimization" "ActionButtonStyle" { Invoke-InternetOptimize }; Add-GuiBtn $p "Revert Internet" "RevertButtonStyle" { Invoke-InternetRevert }
    } "&#xE774;" -WrapButtons
    Add-GuiCard "Privacy Settings" "Disable advertising ID, Cortana, telemetry, recent apps, and third-party suggestions." {
        param($p) Add-GuiBtn $p "Apply Privacy Settings" "ActionButtonStyle" { Invoke-PrivacyApply }; Add-GuiBtn $p "Revert Privacy" "RevertButtonStyle" { Invoke-PrivacyRevert }
    } "&#xEA18;" -WrapButtons
    Add-GuiCard "Remove Integration Keys" "Remove leftover app integration registry keys for EclipseManager, Xbox, PPIProjection, and other pre-installed bloat." {
        param($p) Add-GuiBtn $p "Clean Integrations" "ActionButtonStyle" { Invoke-IntegrationsApply }; Add-GuiBtn $p "Revert Integrations" "RevertButtonStyle" { Invoke-IntegrationsRevert }
    } "&#xE71B;" -WrapButtons
}
