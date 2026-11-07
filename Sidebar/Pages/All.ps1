function Show-PageAll {
    Clear-GuiContent
    Add-GuiPageTitle "One-Click Full Optimization"
    Add-GuiCard "Complete System Optimization" "Runs ALL 13 optimization steps in sequence: creates a Restore Point first, then optimizes Internet, Power, Game Mode, Memory, Services, System Tweaks, GPU, Integrations, Privacy, cleans caches, and optimizes network adapters. A system restart is recommended after completion." {
        param($p) Add-GuiBackgroundBtn $p "OPTIMIZE ALL" { Invoke-FullAutoOptimize } @('Invoke-FullAutoOptimize') {
            param($result)
            Set-GuiProgress 100 "Full optimization complete!"
        } -Style "DangerButtonStyle" -ConfirmCheck {
            Show-GuiConfirm -Title "Optimize Everything" -Icon "&#xE945;" `
                -Message "This applies all 13 optimization steps at once (restore point first, then network, power, services, privacy, cleanup and more). Changes are not individually reversible. Continue?" `
                -ConfirmText "Optimize All"
        }
    } "&#xE945;" -WrapButtons
}
