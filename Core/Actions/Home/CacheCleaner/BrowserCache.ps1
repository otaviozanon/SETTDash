
# ================================================
#region CACHE CLEANER - BROWSER CACHE
# ================================================
# Used by: Home (Cache Cleaner > "Browser Cache"); also called internally by Invoke-CleanAll
function Invoke-CleanBrowserCache {
    Set-GuiProgress 10 "Cleaning browser caches..."
    Write-GuiLog "Cleaning browser caches..." "STEP"
    $browsers = @{
        "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        "Brave" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
        "Opera GX" = "$env:APPDATA\Opera Software\Opera GX Stable\Cache"
    }
    foreach ($b in $browsers.Keys) { Remove-DirContent -Path $browsers[$b] -Desc "$b Cache" }
    # $env:ProgramFiles is redirected to "Program Files (x86)" inside a 32-bit host, so the
    # 64-bit install would never be found; Get-InstalledProgramPath checks both roots.
    $ffPath = Get-InstalledProgramPath "Mozilla Firefox\firefox.exe"
    if ($ffPath) {
        try {
            Start-Process -FilePath $ffPath -ArgumentList '-P "default" -no-remote -safe-mode -clearcache' -Wait -WindowStyle Hidden -ErrorAction Stop
            Write-GuiLog "Firefox cache cleaned" "OK"
        } catch { Write-GuiLog "Firefox cache reset failed: $($_.Exception.Message)" "WARN" }
    }
    Write-GuiLog "Browser caches cleaned" "OK"
    Set-GuiProgress 0
}
#endregion
