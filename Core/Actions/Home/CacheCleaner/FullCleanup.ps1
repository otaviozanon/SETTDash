
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

# Button wrapper used by: Clean > System Cleaner ("Full Cleanup").
# Mirrors the UX of Invoke-FullAutoOptimize ("OPTIMIZE ALL"): banner in/out, run of
# every cache category, completion notice with restart warning. Kept SEPARATE from
# Invoke-CleanAll so old callers (Home > Cache Cleaner card, FullAutoOptimize step 12,
# Playbooks "Deep Clean") keep running the plain no-banner cleanup unchanged.
function Invoke-FullSystemCleanup {
    Clear-GuiLog
    Write-GuiLog "============================================================" "STEP"
    Write-GuiLog "  SETT CLEANER - FULL SYSTEM CLEANUP" "STEP"
    Write-GuiLog "============================================================" "STEP"
    Invoke-CleanAll
    Set-GuiProgress 100 "Full cleanup complete!"
    Write-GuiLog "============================================================" "OK"
    Write-GuiLog "  FULL SYSTEM CLEANUP COMPLETE!" "OK"
    Write-GuiLog "  A system restart is recommended for all cleanup to take effect." "WARN"
    Write-GuiLog "============================================================" "OK"
}
#endregion
