function Show-PageNetworkPrivacy {
    Clear-GuiContent
    Add-GuiPageTitle (T "Network & Privacy")
    Add-GuiCard (T "TCP & QoS Optimization") (T "Disable TCP autotuning, apply QoS policies for Valorant and CSGO, and increase FastSendDatagramThreshold for lower latency.") {
        param($p) Add-GuiBtn $p (T "Apply Optimization") "ActionButtonStyle" { Invoke-InternetOptimize }; Add-GuiBtn $p (T "Revert Internet") "RevertButtonStyle" { Invoke-InternetRevert }
    } "&#xE774;" -WrapButtons
    Add-GuiCard (T "Privacy Settings") (T "Disable advertising ID, Cortana, telemetry, recent apps, and third-party suggestions.") {
        param($p) Add-GuiBtn $p (T "Apply Privacy Settings") "ActionButtonStyle" { Invoke-PrivacyApply }; Add-GuiBtn $p (T "Revert Privacy") "RevertButtonStyle" { Invoke-PrivacyRevert }
    } "&#xEA18;" -WrapButtons
    Add-GuiCard (T "Remove Integration Keys") (T "Remove leftover app integration registry keys for EclipseManager, Xbox, PPIProjection, and other pre-installed bloat.") {
        param($p) Add-GuiBtn $p (T "Clean Integrations") "ActionButtonStyle" { Invoke-IntegrationsApply }; Add-GuiBtn $p (T "Revert Integrations") "RevertButtonStyle" { Invoke-IntegrationsRevert }
    } "&#xE71B;" -WrapButtons
}
