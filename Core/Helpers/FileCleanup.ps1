
# ================================================
#region FILE CLEANUP HELPER
# ================================================
# Used by: Core/Actions/Home/CacheCleaner/*.ps1 (generic directory content removal)
function Remove-DirContent { param([string]$Path, [string]$Desc)
    if (-not (Test-Path $Path)) { Write-GuiLog "$Desc not found" "WARN"; return }
    Write-GuiLog "Cleaning: $Desc" "STEP"
    try { Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "$Desc cleaned" "OK" }
    catch { Write-GuiLog "Error cleaning $Desc" "ERR" }
}
#endregion
