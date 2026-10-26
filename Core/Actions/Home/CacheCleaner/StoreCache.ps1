
# ================================================
#region CACHE CLEANER - STORE CACHE
# ================================================
# Used by: Home (Cache Cleaner > "Store Cache"); also called internally by Invoke-CleanAll
function Invoke-CleanStoreCache { Set-GuiProgress 50; Start-Process "wsreset.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue; Write-GuiLog "Store cache reset initiated" "OK"; Set-GuiProgress 0 }
#endregion
