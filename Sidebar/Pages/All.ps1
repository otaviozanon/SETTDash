function Show-PageAll {
    Clear-GuiContent
    Add-GuiPageTitle "One-Click Full Optimization"
    Add-GuiCard "Complete System Optimization" "Runs ALL 13 optimization steps in sequence: creates a Restore Point first, then optimizes Internet, Power, Game Mode, Memory, Services, System Tweaks, GPU, Integrations, Privacy, cleans caches, and optimizes network adapters. A system restart is recommended after completion." {
        param($p) Add-GuiBtn $p "OPTIMIZE ALL" "DangerButtonStyle" { Invoke-FullAutoOptimize }
    } "&#xE945;" -WrapButtons
}
