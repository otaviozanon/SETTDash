
# ================================================
#region CACHE CLEANER - PREFETCH
# ================================================
# Used by: Home (Cache Cleaner > "Prefetch"); also called internally by Invoke-CleanAll
function Invoke-CleanPrefetch { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:windir "Prefetch") -Desc "Prefetch Files"; Write-GuiLog "Prefetch cleaned" "OK"; Set-GuiProgress 0 }
#endregion
