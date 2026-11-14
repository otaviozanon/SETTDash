
# ================================================
#region CACHE CLEANER - FULL CLEANUP
# ================================================
# Used by: Home (Cache Cleaner > "Full Cleanup"); also called internally by Playbooks ("Deep Clean")
# Calls each individual cleanup function (no duplicated cleanup logic), then does the extra
# items that are specific to the full cleanup (spool, history, cookies, tmp, event logs).
function Invoke-CleanAll {
    Set-GuiProgress 5 "Running ADVANCED SYSTEM CLEANUP..."
    Write-GuiLog (T "Running ADVANCED SYSTEM CLEANUP...") "STEP"

    # Each category runs isolated: one failing step (missing tool, locked file, service that won't
    # stop) must not abort the rest of the cleanup. Before this, a single throw here - e.g. the
    # Store Cache step on a 32-bit host - stopped every category after it.
    $steps = @(
        @{ Name = "Temp files";            Action = { Invoke-CleanTempFiles } },
        @{ Name = "Browser cache";         Action = { Invoke-CleanBrowserCache } },
        @{ Name = "Windows Update cache";  Action = { Invoke-CleanUpdateCache } },
        @{ Name = "Prefetch";              Action = { Invoke-CleanPrefetch } },
        @{ Name = "Store cache";           Action = { Invoke-CleanStoreCache } },
        @{ Name = "Log files";             Action = { Invoke-CleanLogFiles } },
        @{ Name = "Memory dumps";          Action = { Invoke-CleanMemoryDumps } },
        @{ Name = "Delivery Optimization"; Action = { Invoke-CleanDeliveryOpt } },
        @{ Name = "Shader cache";          Action = { Invoke-CleanShaderCache } }
    )
    foreach ($step in $steps) {
        try { & $step.Action }
        catch { Write-GuiLog ((T "{0} step failed: {1}") -f $step.Name, $_.Exception.Message) "ERR" }
    }

    Set-GuiProgress 85 "Cleaning extra system paths..."
    $windir = $env:windir
    $extraPaths = @(
        (Join-Path $windir "Spool\Printers"),
        (Join-Path $windir "History"),
        (Join-Path $windir "Cookies"),
        (Join-Path $windir "Tmp")
    )
    foreach ($item in $extraPaths) {
        if (Test-Path $item) { Remove-Item -Path "$item\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog ((T "Cleaned: {0}") -f $item) "OK" }
    }

    Set-GuiProgress 95 "Cleaning event logs..."
    try {
        # wevtutil resolved through Get-SystemToolPath: in a 32-bit host PATH lookup lands in
        # SysWOW64 first, and a missing binary would otherwise throw a native-command error.
        $wevtutil = Get-SystemToolPath "wevtutil.exe"
        if ($wevtutil) {
            $logs = & $wevtutil el 2>$null
            if ($logs) { foreach ($log in $logs) { & $wevtutil cl "$log" 2>$null }; Write-GuiLog (T "Event logs cleaned") "OK" }
        } else { Write-GuiLog (T "Event logs skipped: wevtutil.exe was not found") "WARN" }
    } catch { Write-GuiLog ((T "Event log cleanup failed: {0}") -f $_.Exception.Message) "WARN" }

    Write-GuiLog (T "Advanced cleanup completed!") "OK"
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
    Write-GuiLog (T "  SETT CLEANER - FULL SYSTEM CLEANUP") "STEP"
    Write-GuiLog "============================================================" "STEP"
    Invoke-CleanAll

    # Full Cleanup means every System Cleaner category, whether or not it was left checked:
    # this is what also clears Recycle Bin, WER, thumbnail/shader caches, browser caches and
    # Windows logs that Invoke-CleanAll's own step list does not cover.
    $allItems = @(Get-SystemCleanerItems -SkipSize)
    if ($allItems.Count -gt 0) { Invoke-SystemCleanerClean -Items $allItems }

    Set-GuiProgress 100 "Full cleanup complete!"
    Write-GuiLog "============================================================" "OK"
    Write-GuiLog (T "  FULL SYSTEM CLEANUP COMPLETE!") "OK"
    Write-GuiLog (T "  A system restart is recommended for all cleanup to take effect.") "WARN"
    Write-GuiLog "============================================================" "OK"
}
#endregion
