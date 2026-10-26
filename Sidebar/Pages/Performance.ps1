function Show-PagePerformance {
    Clear-GuiContent
    Add-GuiPageTitle "Performance Optimization"
    Add-GuiCard "SETT Power Plan" "Import and activate the custom SETT high-performance power plan for maximum system responsiveness." {
        param($p) Add-GuiBtn $p "Apply Power Plan" "ActionButtonStyle" { Invoke-PowerApply }; Add-GuiBtn $p "Revert Power" "RevertButtonStyle" { Invoke-PowerRevert }
    } "&#xE7E8;" -WrapButtons
    Add-GuiCard "Game Mode & Game Bar" "Enable Game Mode, disable Game Bar overlays, DVR capture, and recording hotkeys to reduce input lag." {
        param($p) Add-GuiBtn $p "Apply Game Mode" "ActionButtonStyle" { Invoke-GameModeApply }; Add-GuiBtn $p "Revert Game Mode" "RevertButtonStyle" { Invoke-GameModeRevert }
    } "&#xE768;" -WrapButtons
    Add-GuiCard "Extra Game Optimizations" "Apply additional performance tweaks: priority control, multimedia scheduling, GPU priority, Direct3D pre-rendered frames, and timer resolution." {
        param($p) Add-GuiBtn $p "Apply Extra Optimizations" "ActionButtonStyle" { Invoke-GameExtraApply }; Add-GuiBtn $p "Revert Extra" "RevertButtonStyle" { Invoke-GameExtraRevert }
    } "&#xE768;" -WrapButtons
    Add-GuiCard "Memory Management" "Configure memory management keys, disable memory compression, and dynamically configure SvcHost based on your installed RAM." {
        param($p) Add-GuiBtn $p "Apply Memory Optimizations" "ActionButtonStyle" { Invoke-MemoryApply }; Add-GuiBtn $p "Revert Memory" "RevertButtonStyle" { Invoke-MemoryRevert }
    } "&#xE7F1;" -WrapButtons
    Add-GuiCard "Auto-Detect & Optimize GPU" "Automatically detect your NVIDIA or AMD GPU and apply vendor-specific registry tweaks: disable preemption, CUDA context preemption, power gating, ULPS, and stutter mode." {
        param($p) Add-GuiBtn $p "Detect & Optimize GPU" "ActionButtonStyle" { Invoke-GPUApply }; Add-GuiBtn $p "Revert GPU" "RevertButtonStyle" { Invoke-GPURevert }
    } "&#xE7F4;" -WrapButtons
}
