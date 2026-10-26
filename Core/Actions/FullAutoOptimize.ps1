
# ================================================
#region FULL AUTO OPTIMIZE
# ================================================
# Used by: All ("OPTIMIZE ALL" - One-Click Full Optimization)
function Invoke-FullAutoOptimize {
    Clear-GuiLog
    Write-GuiLog "============================================================" "STEP"
    Write-GuiLog "  SETT OPTIMIZER - FULL AUTO OPTIMIZATION" "STEP"
    Write-GuiLog "============================================================" "STEP"
    $totalSteps = 13
    $currentStep = 0

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Creating Restore Point"
    $rpOk = Invoke-RestorePoint
    if (-not $rpOk) { Write-GuiLog "Restore point failed, continuing anyway..." "WARN" }

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Internet Optimization"
    Invoke-InternetOptimize

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Power Options"
    Invoke-PowerApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Game Mode"
    Invoke-GameModeApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Game Extra Optimizations"
    Invoke-GameExtraApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Memory Optimization"
    Invoke-MemoryApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Disabling Services"
    Invoke-ServicesApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: System Tweaks"
    Invoke-TweaksApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: GPU Optimization"
    Invoke-GPUApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Integrations Cleanup"
    Invoke-IntegrationsApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Privacy"
    Invoke-PrivacyApply

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Cache Cleanup (All)"
    Invoke-CleanAll

    $currentStep++
    Set-GuiProgress ([math]::Round($currentStep/$totalSteps*100)) "Step $currentStep/${totalSteps}: Network Optimization (Ethernet + WiFi)"
    Invoke-NetworkOptimize "Ethernet"
    Invoke-NetworkOptimize "WiFi"

    Set-GuiProgress 100 "Full optimization complete!"
    Write-GuiLog "============================================================" "OK"
    Write-GuiLog "  FULL AUTO OPTIMIZATION COMPLETE!" "OK"
    Write-GuiLog "  A system restart is recommended for all changes to take effect." "WARN"
    Write-GuiLog "============================================================" "OK"
}
#endregion
