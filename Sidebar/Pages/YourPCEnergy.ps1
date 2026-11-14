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
        1=(T "Discharging"); 2=(T "On AC (Not Charging)"); 3=(T "Fully Charged")
        4=(T "Low"); 5=(T "BATTERY_CRITICAL_STATUS"); 6=(T "Charging"); 7=(T "Charging (High)")
        8=(T "Charging (Low)"); 9=(T "Charging (Critical)"); 10=(T "Undefined"); 11=(T "Partially Charged")
    }
    $chemistryMap = @{3=(T "Lead Acid"); 4=(T "NiCd"); 5=(T "NiMH"); 6=(T "Li-ion"); 7=(T "Zinc Air"); 8=(T "Li-Polymer")}

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
        $verdict = "Good"; $label = T "HEALTHY_BADGE"
        if ($null -eq $wear) { $verdict = "Unknown"; $label = T "NO DATA"; $reasons += T "Windows did not report design or current full-charge capacity, so wear could not be calculated." }
        elseif ($wear -ge 50) { $verdict = "Critical"; $label = T "WORN OUT"; $reasons += "$(T 'Lost') $([math]::Round($wear))% $(T 'of original capacity: runtime is roughly half of what it used to be. Consider replacing the battery.')" }
        elseif ($wear -ge 30) { $verdict = "Warning"; $label = T "ATTENTION"; $reasons += "$(T 'Lost') $([math]::Round($wear))% $(T 'of original capacity. Still usable, but runtime has dropped noticeably.')" }
        elseif ($wear -ge 15) { $reasons += "$(T 'Wear of') $([math]::Round($wear))%$(T ', normal for a battery with some use.')" }
        else { $reasons += "$(T 'Wear of only') $([math]::Round($wear,1))%$(T ': battery in great condition.')" }
        if ($cycles -ge 1000 -and $verdict -eq "Good") { $verdict = "Warning"; $label = T "ATTENTION" }
        if ($cycles -ge 800) { $reasons += "$cycles $(T 'charge cycles: close to the typical end-of-life for Li-ion batteries (500-1000).')" }
        if ($pct -lt 20 -and -not $onAc) { $reasons += T "Low charge and unplugged." }

        $accent = switch ($verdict) { "Good" { "Brush_AccentGreen" } "Warning" { "Brush_AccentAmber" } "Critical" { "Brush_AccentRed" } default { "Brush_TextSecondary" } }

        $rows = @()
        $statusText = if ($statusMap.ContainsKey($bstat)) { $statusMap[$bstat] } elseif ($charging) { T "Charging" } elseif ($discharging) { T "Discharging" } else { T "Unknown" }
        $rows += @{Label=(T "Health"); Value=$label.ToUpper(); ValueColor=$accent}
        $rows += @{Label=(T "Current Charge"); Value="$pct %"}
        $rows += @{Label=(T "Status"); Value=$statusText}
        $run = if ($w.EstimatedRunTime) { [long]$w.EstimatedRunTime } else { $null }
        if ($run -gt 0 -and $run -lt 71582788 -and -not $onAc) { $rows += @{Label=(T "Estimated Runtime"); Value="$([math]::Floor($run/60))h $([string]::Format('{0:00}', $run % 60))min"} }
        if ($design -gt 0) { $rows += @{Label=(T "Design Capacity"); Value="$([math]::Round($design/1000.0,1)) Wh"} }
        if ($fullCap -gt 0) { $rows += @{Label=(T "Current Full-Charge Capacity"); Value="$([math]::Round($fullCap/1000.0,1)) Wh"} }
        if ($null -ne $wear) { $rows += @{Label=(T "Wear"); Value="$([math]::Round($wear,1)) %"} }
        if ($cycles) { $rows += @{Label=(T "Charge Cycles"); Value="$cycles"} }
        $volt = if ($lv -and $lv.Voltage -gt 0) { [long]$lv.Voltage } else { $null }
        if ($volt) { $rows += @{Label=(T "Voltage"); Value="$([math]::Round($volt/1000.0,2)) V"} }
        if ($charging -and $lv.ChargeRate -gt 0) { $rows += @{Label=(T "Charge Rate"); Value="$([math]::Round($lv.ChargeRate/1000.0,1)) W"} }
        if ($discharging -and $lv.DischargeRate -gt 0) { $rows += @{Label=(T "Discharge Rate"); Value="$([math]::Round($lv.DischargeRate/1000.0,1)) W"} }
        $manuf = if ($st -and $st.ManufactureName) { [string]$st.ManufactureName.Trim() } else { $null }
        if ($manuf) { $rows += @{Label=(T "Manufacturer"); Value=$manuf} }
        $model = if ($st -and $st.DeviceName) { [string]$st.DeviceName.Trim() } elseif ($w.Name) { [string]$w.Name.Trim() } else { $null }
        if ($model) { $rows += @{Label=(T "Model"); Value=$model} }
        $chem = if ($chemistryMap.ContainsKey([int]$w.Chemistry)) { $chemistryMap[[int]$w.Chemistry] } else { $null }
        if ($chem) { $rows += @{Label=(T "Chemistry"); Value=$chem} }
        if ($reasons.Count -gt 0) { $rows += @{Label=(T "Notes"); Value=($reasons -join " ")} }

        $title = if ($win.Count -gt 1) { "$(T 'Battery') $($i + 1)" } else { T "Battery" }
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
        $schemeName = if ($scheme -match '\(([^)]+)\)') { $Matches[1] } else { T "Unknown" }
    } catch { $schemeName = T "Unknown" }

    $onAc = $true
    if ($HasBattery) {
        try {
            $b = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
            $onAc = [int]$b.BatteryStatus -in 2,3,6,7,8,9
        } catch {}
    }
    $rows += @{Label=(T "Power Source"); Value=$(if (-not $HasBattery) { T "AC (Desktop)" } elseif ($onAc) { T "AC Power" } else { T "Battery" })}
    $rows += @{Label=(T "Active Power Plan"); Value=$schemeName}

    if ($LhmOk) {
        $powerSensors = @(Get-LHMSensorRows | Where-Object { $_.SensorType -eq "Power" -and $_.Value -gt 0 } | Select-Object -First 6)
        if ($powerSensors.Count -gt 0) {
            $rows += @{IsHeader=$true; Label=(T "LIVE POWER SENSORS")}
            foreach ($s in $powerSensors) { $rows += @{Label="$($s.HardwareName) - $($s.SensorName)"; Value="$([math]::Round($s.Value,1)) W"} }
        }
    }
    if (-not $HasBattery) { $rows += @{Label=(T "Note"); Value=(T "PSU power draw is not measured by Windows; the values above come from CPU/GPU sensors.")} }
    return $rows
}

# "Your PC > Energy" page: one health card per battery (wear/cycles/voltage/charge-rate with a
# color-coded verdict pill) followed by the always-present Energy card (power source, active
# plan, live power sensors) - full feature parity with ResetExplode's BatteryInfo.cs.
function Show-PageYourPCEnergy {
    Clear-GuiContent
    Add-GuiPageTitle (T "Energy")

    $lhmOk = Initialize-LibreHardwareMonitor
    $batteryCards = @(Get-BatteryHealthCards)
    foreach ($c in $batteryCards) {
        Add-GuiInfoCard -Title $c.Title -Icon "&#xE945;" -AccentColor $c.AccentColor -Rows $c.Rows
    }

    $energyRows = @(Get-EnergyInfoRows -HasBattery ($batteryCards.Count -gt 0) -LhmOk $lhmOk)
    Add-GuiInfoCard -Title (T "Energy") -Icon "&#xE83E;" -Rows $energyRows
}
