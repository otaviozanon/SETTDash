
# ================================================
#region CACHE CLEANER - STORE CACHE
# ================================================
# Used by: Home (Cache Cleaner > "Store Cache"); also called internally by Invoke-CleanAll
function Invoke-CleanStoreCache {
    Set-GuiProgress 50
    # Start-Process throws a terminating Win32Exception ("Unable to find the specified file")
    # when the target executable can't be resolved (e.g. wsreset.exe missing from PATH on some
    # installs) - this is NOT a normal PowerShell error record, so -ErrorAction SilentlyContinue
    # does not suppress it, and an uncaught exception here closes the whole app. Wrap in try/catch.
    try {
        Start-Process "wsreset.exe" -WindowStyle Hidden -ErrorAction Stop
        Write-GuiLog "Store cache reset initiated" "OK"
    } catch {
        Write-GuiLog "Store cache reset failed: wsreset.exe not found" "ERR"
    }
    Set-GuiProgress 0
}
#endregion
