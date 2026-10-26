
# ================================================
#region CACHE CLEANER - MEMORY DUMPS
# ================================================
# Used by: Home (Cache Cleaner > "Minidumps"); also called internally by Invoke-CleanAll
function Invoke-CleanMemoryDumps { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:windir "Minidump") -Desc "Memory Dumps"; Write-GuiLog "Memory dumps cleaned" "OK"; Set-GuiProgress 0 }
#endregion
