
# ================================================
#region CACHE CLEANER - TEMP FILES
# ================================================
# Used by: Home (Cache Cleaner > "Temp Files"); also called internally by Invoke-CleanAll
function Invoke-CleanTempFiles {
    Set-GuiProgress 20 "Cleaning temporary files..."
    Write-GuiLog "Cleaning temporary files..." "STEP"
    Remove-DirContent -Path $env:TEMP -Desc "User TEMP"
    Set-GuiProgress 60 "Cleaning Windows TEMP..."
    Remove-DirContent -Path (Join-Path $env:windir "Temp") -Desc "Windows TEMP"
    Write-GuiLog "Temporary files cleaned" "OK"
    Set-GuiProgress 0
}
#endregion
