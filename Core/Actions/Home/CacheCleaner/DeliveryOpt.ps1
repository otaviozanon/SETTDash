
# ================================================
#region CACHE CLEANER - DELIVERY OPTIMIZATION
# ================================================
# Used by: Home (Cache Cleaner > "Delivery Opt"); also called internally by Invoke-CleanAll
function Invoke-CleanDeliveryOpt {
    Set-GuiProgress 30 "Cleaning Delivery Optimization..."
    Write-GuiLog "Cleaning Delivery Optimization..." "STEP"
    try {
        Stop-Service -Name dosvc -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 60 "Removing delivery optimization files..."
        Remove-DirContent -Path (Join-Path $env:windir "SoftwareDistribution\DeliveryOptimization") -Desc "Delivery Optimization"
        Start-Service -Name dosvc -ErrorAction SilentlyContinue
    } catch { Write-GuiLog "Delivery opt error: $_" "ERR" }
    Set-GuiProgress 0
}
#endregion
