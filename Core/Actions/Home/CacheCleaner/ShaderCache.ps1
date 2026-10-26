
# ================================================
#region CACHE CLEANER - SHADER CACHE
# ================================================
# Used by: Home (Cache Cleaner > "DX Shaders"); also called internally by Invoke-CleanAll
function Invoke-CleanShaderCache { Set-GuiProgress 50; Remove-DirContent -Path (Join-Path $env:LOCALAPPDATA "D3DSCache") -Desc "Shader Cache"; Write-GuiLog "Shader cache cleaned" "OK"; Set-GuiProgress 0 }
#endregion
