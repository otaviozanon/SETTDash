# Used by: Show-PageYourPCEnergy. Builds one health card per detected battery - mirrors
# BatteryInfo.cs's Read(): Win32_Battery (cimv2) for live status/charge, plus root\WMI's
# BatteryStaticData/BatteryFullChargedCapacity/BatteryCycleCount/BatteryStatus for design vs
# current capacity (wear %), cycle count, voltage and charge/discharge rate - then a verdict
# (Good/Warning/Critical/Unknown) derived from the same wear/cycle thresholds as ResetExplode.
function Get-BatteryHealthCards {
    $cards = @()
    try { $win = @(Get-CimInstance -Namespace "root\cimv2" -ClassName Win32_Battery -ErrorAction Stop) } catch { $win = @() }
    if ($win.Count -eq 0) { return @() }

    try { $stat = @(Get-CimInstance -Namespace "root\WMI" -ClassName BatteryStaticData -ErrorAction Stop) } catch { $stat = @() }
    try { $full = @(Get-CimInstance -Namespace "root\WMI" -ClassName BatteryFullChargedCapacity -ErrorAction Stop) } catch { $full = @() }
    try { $cyc = @(Get-CimInstance -Namespace "root\WMI" -ClassName BatteryCycleCount -ErrorAction Stop) } catch { $cyc = @() }
    try { $live = @(Get-CimInstance -Namespace "root\WMI" -ClassName BatteryStatus -ErrorAction Stop) } catch { $live = @() }

    $statusMap = @{
        1="Discharging"; 2="On AC (Not Charging)"; 3="Fully Charged"
        4="Low"; 5="Critical"; 6="Charging"; 7="Charging (High)"
        8="Charging (Low)"; 9="Charging (Critical)"; 10="Undefined"; 11="Partially Charged"
    }
    $chemistryMap = @{3="Lead Acid"; 4="NiCd"; 5="NiMH"; 6="Li-ion"; 7="Zinc Air"; 8="Li-Polymer"}

    for ($i = 0; $i -lt $win.Count; $i++) {
        $w = $win[$i]
        $st = if ($i -lt $stat.Count) { $stat[$i] } else { $null }
        $fu = if ($i -lt $full.Count) { $full[$i] } else { $null }
        $cy = if ($i -lt $cyc.Count) { $cyc[$i] } else { $null }
        $lv = if ($i -lt $live.Count) { $live[$i] } else { $null }

        $design = if ($st -and $st.DesignedCapacity) { [long]$st.DesignedCapacity } else { $null }
        $fullCap = if ($fu -and $fu.FullChargedCapacity) { [long]$fu.FullChargedCapacity } else { $null }
        $cycles = if ($cy -and $cy.CycleCount) { [long]$cy.CycleCount } else { $null }
        if ($cycles -eq 0) { $cycles = $null }
        $pct = [int]$w.EstimatedChargeRemaining
        $bstat = [int]$w.BatteryStatus
        $charging = $lv -and $lv.Charging -eq $true
        $discharging = $lv -and $lv.Discharging -eq $true
        $onAc = ($lv -and $lv.PowerOnline -eq $true) -or ($bstat -in 2,3,6,7,8,9)

        $wear = if ($design -gt 0 -and $fullCap -gt 0) { [math]::Max(0, 100.0 * (1 - ($fullCap / $design))) } else { $null }
        $reasons = @()
        $verdict = "Good"; $label = "HEALTHY"
        if ($null -eq $wear) { $verdict = "Unknown"; $label = "NO DATA"; $reasons += "Windows did not report design or current full-charge capacity, so wear could not be calculated." }
        elseif ($wear -ge 50) { $verdict = "Critical"; $label = "WORN OUT"; $reasons += "Lost $([math]::Round($wear))% of original capacity: runtime is roughly half of what it used to be. Consider replacing the battery." }
        elseif ($wear -ge 30) { $verdict = "Warning"; $label = "ATTENTION"; $reasons += "Lost $([math]::Round($wear))% of original capacity. Still usable, but runtime has dropped noticeably." }
        elseif ($wear -ge 15) { $reasons += "Wear of $([math]::Round($wear))%, normal for a battery with some use." }
        else { $reasons += "Wear of only $([math]::Round($wear,1))%: battery in great condition." }
        if ($cycles -ge 1000 -and $verdict -eq "Good") { $verdict = "Warning"; $label = "ATTENTION" }
        if ($cycles -ge 800) { $reasons += "$cycles charge cycles: close to the typical end-of-life for Li-ion batteries (500-1000)." }
        if ($pct -lt 20 -and -not $onAc) { $reasons += "Low charge and unplugged." }

        $accent = switch ($verdict) { "Good" { "#3FB950" } "Warning" { "#D29922" } "Critical" { "#F85149" } default { "#8B949E" } }

        $rows = @()
        $statusText = if ($statusMap.ContainsKey($bstat)) { $statusMap[$bstat] } elseif ($charging) { "Charging" } elseif ($discharging) { "Discharging" } else { "Unknown" }
        $rows += @{Label="Health"; Value=$label.ToUpper(); ValueColor=$accent}
        $rows += @{Label="Current Charge"; Value="$pct %"}
        $rows += @{Label="Status"; Value=$statusText}
        $run = if ($w.EstimatedRunTime) { [long]$w.EstimatedRunTime } else { $null }
        if ($run -gt 0 -and $run -lt 71582788 -and -not $onAc) { $rows += @{Label="Estimated Runtime"; Value="$([math]::Floor($run/60))h $([string]::Format('{0:00}', $run % 60))min"} }
        if ($design -gt 0) { $rows += @{Label="Design Capacity"; Value="$([math]::Round($design/1000.0,1)) Wh"} }
        if ($fullCap -gt 0) { $rows += @{Label="Current Full-Charge Capacity"; Value="$([math]::Round($fullCap/1000.0,1)) Wh"} }
        if ($null -ne $wear) { $rows += @{Label="Wear"; Value="$([math]::Round($wear,1)) %"} }
        if ($cycles) { $rows += @{Label="Charge Cycles"; Value="$cycles"} }
        $volt = if ($lv -and $lv.Voltage -gt 0) { [long]$lv.Voltage } else { $null }
        if ($volt) { $rows += @{Label="Voltage"; Value="$([math]::Round($volt/1000.0,2)) V"} }
        if ($charging -and $lv.ChargeRate -gt 0) { $rows += @{Label="Charge Rate"; Value="$([math]::Round($lv.ChargeRate/1000.0,1)) W"} }
        if ($discharging -and $lv.DischargeRate -gt 0) { $rows += @{Label="Discharge Rate"; Value="$([math]::Round($lv.DischargeRate/1000.0,1)) W"} }
        $manuf = if ($st -and $st.ManufactureName) { [string]$st.ManufactureName.Trim() } else { $null }
        if ($manuf) { $rows += @{Label="Manufacturer"; Value=$manuf} }
        $model = if ($st -and $st.DeviceName) { [string]$st.DeviceName.Trim() } elseif ($w.Name) { [string]$w.Name.Trim() } else { $null }
        if ($model) { $rows += @{Label="Model"; Value=$model} }
        $chem = if ($chemistryMap.ContainsKey([int]$w.Chemistry)) { $chemistryMap[[int]$w.Chemistry] } else { $null }
        if ($chem) { $rows += @{Label="Chemistry"; Value=$chem} }
        if ($reasons.Count -gt 0) { $rows += @{Label="Notes"; Value=($reasons -join " ")} }

        $title = if ($win.Count -gt 1) { "Battery $($i + 1)" } else { "Battery" }
        $cards += [PSCustomObject]@{Title=$title; AccentColor=$accent; Rows=$rows}
    }
    return $cards
}

# Used by: Show-PageYourPCEnergy. Builds the always-present "Energy" card: active power
# source (battery present or not), active Windows power plan, and - when LibreHardwareMonitor
# is available - up to 6 live Power-type sensor readings (mirrors BatteryInfo.cs's energy card).
function Get-EnergyInfoRows {
    param([bool]$HasBattery, [bool]$LhmOk)
    $rows = @()
    try {
        $scheme = powercfg /getactivescheme
        $schemeName = if ($scheme -match '\(([^)]+)\)') { $Matches[1] } else { "Unknown" }
    } catch { $schemeName = "Unknown" }

    $onAc = $true
    if ($HasBattery) {
        try {
            $b = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
            $onAc = [int]$b.BatteryStatus -in 2,3,6,7,8,9
        } catch {}
    }
    $rows += @{Label="Power Source"; Value=$(if (-not $HasBattery) { "AC (Desktop)" } elseif ($onAc) { "AC Power" } else { "Battery" })}
    $rows += @{Label="Active Power Plan"; Value=$schemeName}

    if ($LhmOk) {
        $powerSensors = @(Get-LHMSensorRows | Where-Object { $_.SensorType -eq "Power" -and $_.Value -gt 0 } | Select-Object -First 6)
        if ($powerSensors.Count -gt 0) {
            $rows += @{IsHeader=$true; Label="LIVE POWER SENSORS"}
            foreach ($s in $powerSensors) { $rows += @{Label="$($s.HardwareName) - $($s.SensorName)"; Value="$([math]::Round($s.Value,1)) W"} }
        }
    }
    if (-not $HasBattery) { $rows += @{Label="Note"; Value="PSU power draw is not measured by Windows; the values above come from CPU/GPU sensors."} }
    return $rows
}

# "Your PC > Energy" page: one health card per battery (wear/cycles/voltage/charge-rate with a
# color-coded verdict pill) followed by the always-present Energy card (power source, active
# plan, live power sensors) - full feature parity with ResetExplode's BatteryInfo.cs.
function Show-PageYourPCEnergy {
    Clear-GuiContent
    Add-GuiPageTitle "Energy"

    $lhmOk = Initialize-LibreHardwareMonitor
    $batteryCards = @(Get-BatteryHealthCards)
    foreach ($c in $batteryCards) {
        Add-GuiInfoCard -Title $c.Title -Icon "&#xE945;" -AccentColor $c.AccentColor -Rows $c.Rows
    }

    $energyRows = @(Get-EnergyInfoRows -HasBattery ($batteryCards.Count -gt 0) -LhmOk $lhmOk)
    Add-GuiInfoCard -Title "Energy" -Icon "&#xE83E;" -Rows $energyRows
}
