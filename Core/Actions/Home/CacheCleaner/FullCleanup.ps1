
# ================================================
#region CACHE CLEANER - FULL CLEANUP
# ================================================
# Used by: Home (Cache Cleaner > "Full Cleanup"); also called internally by Playbooks ("Deep Clean")
# Calls each individual cleanup function (no duplicated cleanup logic), then does the extra
# items that are specific to the full cleanup (spool, history, cookies, tmp, event logs).
function Invoke-CleanAll {
    Set-GuiProgress 5 "Running ADVANCED SYSTEM CLEANUP..."
    Write-GuiLog "Running ADVANCED SYSTEM CLEANUP..." "STEP"

    Invoke-CleanTempFiles
    Invoke-CleanBrowserCache
    Invoke-CleanUpdateCache
    Invoke-CleanPrefetch
    Invoke-CleanStoreCache
    Invoke-CleanLogFiles
    Invoke-CleanMemoryDumps
    Invoke-CleanDeliveryOpt
    Invoke-CleanShaderCache

    Set-GuiProgress 85 "Cleaning extra system paths..."
    $windir = $env:windir
    $extraPaths = @(
        (Join-Path $windir "Spool\Printers"),
        (Join-Path $windir "History"),
        (Join-Path $windir "Cookies"),
        (Join-Path $windir "Tmp")
    )
    foreach ($item in $extraPaths) {
        if (Test-Path $item) { Remove-Item -Path "$item\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "Cleaned: $item" "OK" }
    }

    Set-GuiProgress 95 "Cleaning event logs..."
    try {
        $logs = wevtutil el 2>$null
        if ($logs) { foreach ($log in $logs) { wevtutil cl "$log" 2>$null }; Write-GuiLog "Event logs cleaned" "OK" }
    } catch { }

    Write-GuiLog "Advanced cleanup completed!" "OK"
    Set-GuiProgress 0
}
#endregion
