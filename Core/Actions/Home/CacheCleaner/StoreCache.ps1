
# ================================================
#region CACHE CLEANER - STORE CACHE
# ================================================
# Used by: Home (Cache Cleaner > "Store Cache"); also called internally by Invoke-CleanAll
function Invoke-CleanStoreCache {
    Set-GuiProgress 50
    # wsreset.exe only exists in the 64-bit System32 folder. In a 32-bit host (e.g. running
    # SETTDash.ps1 from 32-bit PowerShell) System32 is redirected to SysWOW64 and a bare
    # Start-Process "wsreset.exe" fails with "The system cannot find the file specified" - the
    # error that broke Clean > Full Cleanup. Resolve the real 64-bit path via Get-SystemToolPath.
    $wsreset = Get-SystemToolPath "wsreset.exe"
    if (-not $wsreset) {
        Write-GuiLog (T "Store cache reset skipped: wsreset.exe was not found") "WARN"
        Set-GuiProgress 0
        return
    }
    try {
        Start-Process -FilePath $wsreset -WindowStyle Hidden -ErrorAction Stop
        Write-GuiLog (T "Store cache reset initiated") "OK"
    } catch {
        Write-GuiLog ((T "Store cache reset failed: {0}") -f $_.Exception.Message) "ERR"
    }
    Set-GuiProgress 0
}
#endregion
