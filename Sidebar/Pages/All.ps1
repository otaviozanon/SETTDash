function Show-PageAll {
    Clear-GuiContent
    Add-GuiPageTitle (T "One-Click Full Optimization")
    Add-GuiCard (T "Complete System Optimization") (T "Runs ALL 13 optimization steps in sequence: creates a Restore Point first, then optimizes Internet, Power, Game Mode, Memory, Services, System Tweaks, GPU, Integrations, Privacy, cleans caches, and optimizes network adapters. A system restart is recommended after completion.") {
        param($p) Add-GuiBackgroundBtn $p (T "OPTIMIZE_ALL_BTN") { Invoke-FullAutoOptimize } @('Invoke-FullAutoOptimize') {
            param($result)
            Set-GuiProgress 100 (T "Full optimization complete!")
        } -Style "DangerButtonStyle" -ConfirmCheck {
            Show-GuiConfirm -Title (T "Optimize Everything") -Icon "&#xE945;" `
                -Message (T "This applies all 13 optimization steps at once (restore point first, then network, power, services, privacy, cleanup and more). Changes are not individually reversible. Continue?") `
                -ConfirmText (T "Optimize All")
        }
    } "&#xE945;" -WrapButtons
}
