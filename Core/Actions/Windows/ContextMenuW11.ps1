
# ================================================
#region WINDOWS - W11 CONTEXT MENU & ALT+TAB
# ================================================
# Used by: Windows ("Apply Old Menu")
function Invoke-W11OldMenu {
    Set-GuiProgress 50 "Applying old context menu..."
    try {
        $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $bp)) { New-Item -Path $bp -Force | Out-Null }
        Set-ItemProperty -Path $bp -Name "(default)" -Value "" -Force
        Write-GuiLog "Old context menu applied" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Old context menu failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Windows ("Revert to W11 Menu")
function Invoke-W11RevertMenu {
    Set-GuiProgress 50 "Reverting context menu..."
    try {
        $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
        if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
        Write-GuiLog "Context menu reverted to Windows 11 default" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Revert failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Windows ("Apply Classic Alt+Tab")
function Invoke-W11ClassicAltTab {
    Set-GuiProgress 50 "Applying Classic Alt+Tab..."
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "AltTabSettings" -PropertyType DWord -Value 1 -Force | Out-Null
        Write-GuiLog "Classic Alt+Tab applied" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Classic Alt+Tab failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Windows ("Revert to Modern Alt+Tab")
function Invoke-W11RevertAltTab {
    Set-GuiProgress 50 "Reverting Alt+Tab..."
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "AltTabSettings" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Alt+Tab reverted to modern style" "OK"
        Set-GuiProgress 80 "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-GuiLog "Explorer restarted - changes active" "OK"
    } catch { Write-GuiLog "Revert Alt+Tab failed: $_" "ERR" }
    Set-GuiProgress 0
}
#endregion
