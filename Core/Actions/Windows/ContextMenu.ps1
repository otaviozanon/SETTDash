
# ================================================
#region WINDOWS - CONTEXT MENU TWEAKS
# ================================================
# Used by: Windows ("Apply Tweaks" in Context Menu Tweaks card)
function Invoke-ContextApply {
    Set-GuiProgress 10 "Applying context menu tweaks..."
    Write-GuiLog "Applying context menu tweaks..." "STEP"
    $reg = @(
        @{Path="HKCU:\Software\Classes\*\shell\runas";Name="HasLUAShield";Type="String";Value=""}
        @{Path="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32";Name="(default)";Type="String";Value=""}
    )
    Invoke-RegistryApply -Settings $reg -Label "Context Menu"
    Write-GuiLog "Context menu tweaks applied" "OK"
    Set-GuiProgress 80 "Restarting Explorer..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-GuiLog "Explorer restarted - changes active" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Revert Tweaks" in Context Menu Tweaks card)
function Invoke-ContextRevert {
    Set-GuiProgress 50 "Reverting context menu..."
    Write-GuiLog "Reverting context menu..." "STEP"
    $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
    Write-GuiLog "Context menu reverted" "OK"
    Set-GuiProgress 80 "Restarting Explorer..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-GuiLog "Explorer restarted - changes active" "OK"
    Set-GuiProgress 0
}
#endregion
