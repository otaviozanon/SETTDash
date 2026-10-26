
# ================================================
#region RESTORE POINT
# ================================================
# Used by: Home ("Create Restore Point" button); also called internally by All ("OPTIMIZE ALL")
function Invoke-RestorePoint {
    Set-GuiProgress 10 "Creating system restore point..."
    Write-GuiLog "Creating system restore point..." "STEP"
    $result = $false
    try {
        $enabled = $false
        try { $sr = Get-ComputerRestorePoint -ErrorAction SilentlyContinue; if ($sr -and $sr.Count -gt 0) { $enabled = $true } } catch { }
        if (-not $enabled) {
            Set-GuiProgress 30 "Enabling system restore..."
            Write-GuiLog "Enabling system restore via registry..." "WARN"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "DisableSR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" -Name "DisableConfig" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" -Name "DisableSR" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            try { Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue | Out-Null } catch { }
        }
        Set-GuiProgress 60 "Creating checkpoint..."
        Checkpoint-Computer -Description "SETT Optimizer Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-GuiLog "Restore point created successfully" "OK"
        $result = $true
    } catch {
        Write-GuiLog "Failed to create restore point: $_" "ERR"
    }
    Set-GuiProgress 0
    return $result
}
#endregion
