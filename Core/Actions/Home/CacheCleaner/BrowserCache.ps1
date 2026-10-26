
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
    $ffPath = Join-Path $env:ProgramFiles "Mozilla Firefox\firefox.exe"
    if (Test-Path $ffPath) {
        try { Start-Process -FilePath $ffPath -ArgumentList '-P "default" -no-remote -safe-mode -clearcache' -Wait -WindowStyle Hidden; Write-GuiLog "Firefox cache cleaned" "OK" } catch { }
    }
    Write-GuiLog "Browser caches cleaned" "OK"
    Set-GuiProgress 0
}
#endregion
