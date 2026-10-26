
# ================================================
#region PERFORMANCE - SETT POWER PLAN
# ================================================
# Used by: Performance ("Apply Power Plan"); also called internally by All ("OPTIMIZE ALL")
function Invoke-PowerApply {
    Set-GuiProgress 10 "Looking for SETT power plan..."
    Extract-EmbeddedPrograms
    $powFile = Join-Path (Join-Path $Script:TempDir "Programs") "settPowerPlan.pow"
    if (Test-Path $powFile) {
        Set-GuiProgress 30 "Importing custom power plan..."
        $result = powercfg -import $powFile 2>&1
        $match = $result | Select-String -Pattern '([\w-]{36})'
        if ($match) {
            $guid = $match.Matches[0].Groups[1].Value
            powercfg -setactive $guid
            Write-GuiLog "SETT power plan activated ($guid)" "OK"
        } else { 
            $allOut = $result -join " "
            Write-GuiLog "Could not parse GUID from import. Output: $allOut" "WARN"
        }
    } else {
        Set-GuiProgress 30 "settPowerPlan.pow not found, using High Performance..."
        $guid = (powercfg -duplicatescheme "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" 2>&1 | Select-String '([\w-]{36})').Matches[0].Groups[1].Value
        powercfg -setactive $guid
        powercfg -change -monitor-timeout-ac 0
        powercfg -change -standby-timeout-ac 0
        powercfg -change -hibernate-timeout-ac 0
        Write-GuiLog "High Performance plan activated (fallback, $guid)" "OK"
    }
    Set-NavStatus "Power" $true
    Set-GuiProgress 0
}

# Used by: Performance ("Revert Power")
function Invoke-PowerRevert {
    Write-GuiLog "Restoring Balanced power plan..." "STEP"
    Set-GuiProgress 30 "Activating Balanced scheme..."
    try {
        $output = powercfg /l 2>&1
        $balancedGuid = $null
        $match = $output | Select-String -Pattern '381b4222-f694-41f0-9685-ff5bb260df2e'
        if ($match) {
            $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        } else {
            $lines = $output | Select-String -Pattern 'Balanced|Equilibrado'
            if ($lines) {
                $guidMatch = [regex]::Match($lines[0].Line, '([\w-]{36})')
                if ($guidMatch.Success) { $balancedGuid = $guidMatch.Groups[1].Value }
            }
        }
        if ($balancedGuid) {
            powercfg /setactive $balancedGuid
            Write-GuiLog "Balanced power plan activated ($balancedGuid)" "OK"
        } else {
            powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
            Write-GuiLog "Balanced power plan activated (hardcoded GUID)" "OK"
        }
    } catch { Write-GuiLog "Failed to restore power plan: $_" "ERR" }
    Set-NavStatus "Power" $false
    Set-GuiProgress 0
}
#endregion
