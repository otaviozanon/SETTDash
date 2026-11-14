
# ================================================
#region FILE CLEANUP HELPER
# ================================================
# Used by: Core/Actions/Home/CacheCleaner/*.ps1 (generic directory content removal)
function Remove-DirContent { param([string]$Path, [string]$Desc)
    if (-not (Test-Path $Path)) { Write-GuiLog ((T "{0} not found") -f $Desc) "WARN"; return }
    Write-GuiLog ((T "Cleaning: {0}") -f $Desc) "STEP"
    try { Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog ((T "{0} cleaned") -f $Desc) "OK" }
    catch { Write-GuiLog ((T "Error cleaning {0}") -f $Desc) "ERR" }
}
#endregion
