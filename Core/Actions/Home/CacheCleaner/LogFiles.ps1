
# ================================================
#region CACHE CLEANER - LOG FILES
# ================================================
# Used by: Home (Cache Cleaner > "Logs"); also called internally by Invoke-CleanAll
function Invoke-CleanLogFiles {
    Set-GuiProgress 30 "Cleaning log files..."
    Write-GuiLog "Cleaning log files..." "STEP"
    Remove-DirContent -Path (Join-Path $env:windir "Logs") -Desc "Windows Logs"
    Write-GuiLog "Log files cleaned" "OK"
    Set-GuiProgress 0
}
#endregion
