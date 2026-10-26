
# ================================================
#region NETWORK TOOLS (DNS Jumper, Filter Keys, Device Cleanup)
# ================================================
# Used by: Home (Tools > "DNS Jumper")
function Invoke-DNSTool {
    Set-GuiProgress 50 "Launching DnsJumper..."
    $dnsJump = Join-Path $Script:TempDir "Programs\DnsJumper.exe"
    if (-not (Test-Path $dnsJump)) { Extract-EmbeddedPrograms }
    if (Test-Path $dnsJump) { Start-Process $dnsJump; Write-GuiLog "DnsJumper launched" "OK" }
    else { Write-GuiLog "DnsJumper.exe not found" "ERR" }
    Set-GuiProgress 0
}

# Used by: Home (Tools > "Filter Keys")
function Invoke-FilterKeysTool {
    Set-GuiProgress 50 "Launching FilterKeysSetter..."
    $fks = Join-Path $Script:TempDir "Programs\FilterKeysSetter.exe"
    if (-not (Test-Path $fks)) { Extract-EmbeddedPrograms }
    if (Test-Path $fks) { Start-Process $fks; Write-GuiLog "FilterKeysSetter launched" "OK" }
    else { Write-GuiLog "FilterKeysSetter.exe not found" "ERR" }
    Set-GuiProgress 0
}

# Used by: Home (Tools > "Device Cleanup")
function Invoke-CleanDeviceCleanup {
    Set-GuiProgress 50 "Launching DeviceCleanup..."
    $dc = Join-Path $Script:TempDir "Programs\DeviceCleanup.exe"
    if (-not (Test-Path $dc)) { Extract-EmbeddedPrograms }
    if (Test-Path $dc) { Start-Process $dc; Write-GuiLog "DeviceCleanup launched" "OK" }
    else { Write-GuiLog "DeviceCleanup.exe not found" "ERR" }
    Set-GuiProgress 0
}
#endregion
