
# ================================================
#region NETWORK TOOLS (DNS Jumper, Filter Keys, Device Cleanup)
# ================================================
# Used by: Home (Tools > "DNS Jumper")
function Invoke-DNSTool {
    Set-GuiProgress 50 "Launching DnsJumper..."
    $dnsJump = Get-EmbeddedProgramPath "DnsJumper.exe"
    if ($dnsJump) { Start-Process $dnsJump; Write-GuiLog (T "DnsJumper launched") "OK" }
    else { Write-GuiLog (T "DnsJumper.exe not found") "ERR" }
    Set-GuiProgress 0
}

# Used by: Home (Tools > "Filter Keys")
function Invoke-FilterKeysTool {
    Set-GuiProgress 50 "Launching FilterKeysSetter..."
    $fks = Get-EmbeddedProgramPath "FilterKeysSetter.exe"
    if ($fks) { Start-Process $fks; Write-GuiLog (T "FilterKeysSetter launched") "OK" }
    else { Write-GuiLog (T "FilterKeysSetter.exe not found") "ERR" }
    Set-GuiProgress 0
}

# Used by: Home (Tools > "Device Cleanup")
function Invoke-CleanDeviceCleanup {
    Set-GuiProgress 50 "Launching DeviceCleanup..."
    $dc = Get-EmbeddedProgramPath "DeviceCleanup.exe"
    if ($dc) { Start-Process $dc; Write-GuiLog (T "DeviceCleanup launched") "OK" }
    else { Write-GuiLog (T "DeviceCleanup.exe not found") "ERR" }
    Set-GuiProgress 0
}
#endregion
