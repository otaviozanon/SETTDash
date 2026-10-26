
# ================================================
#region CACHE CLEANER - UPDATE CACHE
# ================================================
# Used by: Home (Cache Cleaner > "Update Cache"); also called internally by Invoke-CleanAll
function Invoke-CleanUpdateCache {
    Set-GuiProgress 30 "Cleaning Windows Update cache..."
    Write-GuiLog "Cleaning Windows Update cache..." "STEP"
    try {
        Stop-Service -Name wuauserv, UsoSvc -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 60 "Removing update cache files..."
        Remove-DirContent -Path (Join-Path $env:windir "SoftwareDistribution\Download") -Desc "Update Cache"
        Start-Service -Name wuauserv, UsoSvc -ErrorAction SilentlyContinue
    } catch { Write-GuiLog "Update cache error: $_" "ERR" }
    Set-GuiProgress 0
}
#endregion
