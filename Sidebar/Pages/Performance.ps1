function Show-PagePerformance {
    Clear-GuiContent
    Add-GuiPageTitle (T "Performance Optimization")
    Add-GuiCard (T "SETT Power Plan") (T "Import and activate the custom SETT high-performance power plan for maximum system responsiveness.") {
        param($p) Add-GuiBtn $p (T "Apply Power Plan") "ActionButtonStyle" { Invoke-PowerApply }; Add-GuiBtn $p (T "Revert Power") "RevertButtonStyle" { Invoke-PowerRevert }
    } "&#xE7E8;" -WrapButtons
    Add-GuiCard (T "Game Mode & Game Bar") (T "Enable Game Mode, disable Game Bar overlays, DVR capture, and recording hotkeys to reduce input lag.") {
        param($p) Add-GuiBtn $p (T "Apply Game Mode") "ActionButtonStyle" { Invoke-GameModeApply }; Add-GuiBtn $p (T "Revert Game Mode") "RevertButtonStyle" { Invoke-GameModeRevert }
    } "&#xE768;" -WrapButtons
    Add-GuiCard (T "Extra Game Optimizations") (T "Apply additional performance tweaks: priority control, multimedia scheduling, GPU priority, Direct3D pre-rendered frames, and timer resolution.") {
        param($p) Add-GuiBtn $p (T "Apply Extra Optimizations") "ActionButtonStyle" { Invoke-GameExtraApply }; Add-GuiBtn $p (T "Revert Extra") "RevertButtonStyle" { Invoke-GameExtraRevert }
    } "&#xE768;" -WrapButtons
    Add-GuiCard (T "Memory Management") (T "Configure memory management keys, disable memory compression, and dynamically configure SvcHost based on your installed RAM.") {
        param($p) Add-GuiBtn $p (T "Apply Memory Optimizations") "ActionButtonStyle" { Invoke-MemoryApply }; Add-GuiBtn $p (T "Revert Memory") "RevertButtonStyle" { Invoke-MemoryRevert }
    } "&#xE7F1;" -WrapButtons
    Add-GuiCard (T "Auto-Detect & Optimize GPU") (T "Automatically detect your NVIDIA or AMD GPU and apply vendor-specific registry tweaks: disable preemption, CUDA context preemption, power gating, ULPS, and stutter mode.") {
        param($p) Add-GuiBtn $p (T "Detect & Optimize GPU") "ActionButtonStyle" { Invoke-GPUApply }; Add-GuiBtn $p (T "Revert GPU") "RevertButtonStyle" { Invoke-GPURevert }
    } "&#xE7F4;" -WrapButtons
}
