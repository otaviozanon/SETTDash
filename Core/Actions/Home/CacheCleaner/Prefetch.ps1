
# ================================================
#region CACHE CLEANER - PREFETCH
# ================================================
# Used by: Home (Cache Cleaner > "Prefetch"); also called internally by Invoke-CleanAll
function Invoke-CleanPrefetch { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:windir "Prefetch") -Desc "Prefetch Files"; Write-GuiLog (T "Prefetch cleaned") "OK"; Set-GuiProgress 0 }
#endregion
