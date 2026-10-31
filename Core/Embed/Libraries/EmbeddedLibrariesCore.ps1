#region EMBEDDED LIBRARIES (LibreHardwareMonitorLib + HidSharp)
# Mirrors ResetExplode's SensorMonitor.cs: uses the same LibreHardwareMonitorLib (MPL 2.0) to read
# granular per-sensor CPU/GPU/motherboard/storage/network telemetry (temperature, power, per-core
# clock, fan speed, etc.) instead of generic WMI counters. HidSharp is a runtime dependency of
# LibreHardwareMonitorLib (USB HID access for some controllers/coolers).
$Script:EmbeddedLibraries = @{}
$Script:LHMAvailable = $false
$Script:LHMInitFailed = $false
$Script:LHMComputer = $null

# Used by: Show-PageYourPCSensors. Extracts the embedded DLLs to $Script:TempDir\Libraries (once),
# loads them via Add-Type and opens a LibreHardwareMonitor.Hardware.Computer instance with the same
# flags SensorMonitor.cs uses. Safe to call multiple times (no-op after the first success/failure).
function Initialize-LibreHardwareMonitor {
    if ($Script:LHMAvailable) { return $true }
    if ($Script:LHMInitFailed) { return $false }
    try {
        $libDir = Join-Path $Script:TempDir "Libraries"
        if (-not (Test-Path $libDir)) { New-Item -Path $libDir -ItemType Directory -Force | Out-Null }
        foreach ($key in @("HidSharp.dll", "LibreHardwareMonitorLib.dll")) {
            $outPath = Join-Path $libDir $key
            if (-not (Test-Path $outPath)) {
                $bytes = [Convert]::FromBase64String($Script:EmbeddedLibraries[$key])
                $ms = New-Object System.IO.MemoryStream(,$bytes)
                $gs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
                $fs = New-Object System.IO.FileStream($outPath, [System.IO.FileMode]::Create)
                $gs.CopyTo($fs)
                $fs.Close(); $gs.Close(); $ms.Close()
            }
            Add-Type -Path $outPath -ErrorAction Stop
        }
        $computer = New-Object -TypeName "LibreHardwareMonitor.Hardware.Computer"
        $computer.IsCpuEnabled = $true
        $computer.IsGpuEnabled = $true
        $computer.IsMemoryEnabled = $true
        $computer.IsMotherboardEnabled = $true
        $computer.IsStorageEnabled = $true
        $computer.IsNetworkEnabled = $true
        $computer.IsControllerEnabled = $true
        $computer.Open()
        $Script:LHMComputer = $computer
        $Script:LHMAvailable = $true
        Write-GuiLog "LibreHardwareMonitor initialized (granular CPU/GPU/storage sensors enabled)" "OK"
        return $true
    } catch {
        $Script:LHMInitFailed = $true
        Write-GuiLog "LibreHardwareMonitor init failed: $_" "WARN"
        return $false
    }
}

# Recursively walks one hardware node (and its sub-hardware), appending every sensor reading to $List.
function Walk-LHMHardwareInternal {
    param($Hw, $List)
    try { $Hw.Update() } catch {}
    foreach ($s in $Hw.Sensors) {
        # NOTE: rows are added even when Value is currently null (mirrors ResetExplode's Walk(), which
        # always creates the SensorRow and lets Format() render "—"). Many sensors (Fan/Voltage/Control/
        # Throughput) report null on the very first poll - skipping them here used to make their whole
        # category vanish from the pills until that exact sensor happened to have a value already.
        $List.Add([PSCustomObject]@{
            HardwareType = $Hw.HardwareType.ToString()
            HardwareName = $Hw.Name
            SensorType   = $s.SensorType.ToString()
            SensorName   = $s.Name
            Value        = $(if ($null -ne $s.Value) { [double]$s.Value } else { $null })
            Min          = $(if ($null -ne $s.Min) { [double]$s.Min } else { $null })
            Max          = $(if ($null -ne $s.Max) { [double]$s.Max } else { $null })
        }) | Out-Null
    }
    foreach ($sub in $Hw.SubHardware) { Walk-LHMHardwareInternal -Hw $sub -List $List }
}

# Returns every current sensor reading across all detected hardware, mirroring SensorMonitor.Refresh/Walk.
function Get-LHMSensorRows {
    if (-not $Script:LHMAvailable) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($hw in $Script:LHMComputer.Hardware) { Walk-LHMHardwareInternal -Hw $hw -List $list }
    return $list
}

# Formats a raw sensor value according to its LibreHardwareMonitor SensorType.
# $Value may be $null (e.g. Min/Max not yet sampled) -> renders as "—", mirroring SensorRow.Format.
function Format-LHMSensorValue {
    param([string]$Type, $Value)
    if ($null -eq $Value) { return "—" }
    $Value = [double]$Value
    switch ($Type) {
        "Temperature" { "$([math]::Round($Value,1)) °C" }
        "Load"        { "$([math]::Round($Value,1)) %" }
        "Power"       { "$([math]::Round($Value,2)) W" }
        "Clock"       { "$([math]::Round($Value,0)) MHz" }
        "Fan"         { "$([math]::Round($Value,0)) RPM" }
        "Voltage"     { "$([math]::Round($Value,3)) V" }
        "Current"     { "$([math]::Round($Value,2)) A" }
        "Data"        { "$([math]::Round($Value,1)) GB" }
        "SmallData"   { "$([math]::Round($Value,1)) MB" }
        "Throughput"  { "$([math]::Round($Value/1MB,2)) MB/s" }
        "Flow"        { "$([math]::Round($Value,1)) L/h" }
        "Control"     { "$([math]::Round($Value,0)) %" }
        "Level"       { "$([math]::Round($Value,1)) %" }
        "Factor"      { "$([math]::Round($Value,2))" }
        "Energy"      { "$([math]::Round($Value,1)) mWh" }
        "Noise"       { "$([math]::Round($Value,0)) dBA" }
        "Humidity"    { "$([math]::Round($Value,1)) %" }
        default       { "$Value" }
    }
}

# Returns display rows (grouped by hardware name, with headers when more than one device) for the
# given set of LibreHardwareMonitor HardwareType names - used to build each Sensors page category tab.
function Get-LHMCategoryRows {
    param([string[]]$HardwareTypes)
    $rows = @()
    $all = Get-LHMSensorRows | Where-Object { $HardwareTypes -contains $_.HardwareType }
    $groups = $all | Group-Object HardwareName
    foreach ($g in $groups) {
        if ($groups.Count -gt 1) { $rows += @{IsHeader=$true; Label=$g.Name} }
        foreach ($s in $g.Group) {
            $rows += @{Label=$s.SensorName; Value=(Format-LHMSensorValue $s.SensorType $s.Value)}
        }
    }
    return $rows
}
#endregion
