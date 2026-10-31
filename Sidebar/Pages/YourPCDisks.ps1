# Converts a byte count into a human-readable string, matching DiskHealth.cs/DriveMap.cs's Fmt/FmtSize.
function Format-DiskBytes {
    param([double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -le 0) { return "0 B" }
    $units = @("B","KB","MB","GB","TB")
    $i = 0; $v = [double]$Bytes
    while ($v -ge 1024 -and $i -lt ($units.Count - 1)) { $v /= 1024; $i++ }
    return "{0:0.#} {1}" -f $v, $units[$i]
}

# Maps a Win32_DiskDriveToDiskPartition/Win32_LogicalDiskToPartition association reference string
# (e.g. Win32_DiskDrive.DeviceID="\\.\PHYSICALDRIVE0") to the bare DeviceID value - mirrors
# DiskHealth.cs/DriveMap.cs's RefId().
function Get-DiskAssocRefId {
    param([string]$Reference)
    $m = [regex]::Match($Reference, 'DeviceID="(.*)"')
    if ($m.Success) { return $m.Groups[1].Value.Replace('\\', '\') }
    return $null
}

# Used by: Show-PageYourPCDisks. Builds one health "card" per physical disk - mirrors DiskHealth.cs's
# Read()/ToCard(): base identity from Win32_DiskDrive, health/media/bus/reliability counters from the
# MSFT_PhysicalDisk / MSFT_StorageReliabilityCounter storage WMI namespace, SMART predicted-failure
# flag, drive letters via the disk->partition->logicaldisk association chain, then a verdict
# (Good/Warning/Critical/Unknown) derived from thresholds on wear/temperature/predicted failure/health,
# falling back to LibreHardwareMonitor Storage sensors for temperature/wear/written/read when the
# storage WMI classes don't expose them (older Windows / some controllers).
function Get-DiskHealthCards {
    param([bool]$LhmOk)
    $raws = @{}

    try {
        foreach ($d in (Get-CimInstance Win32_DiskDrive)) {
            $pnp = [string]$d.PNPDeviceID
            $raws[[int]$d.Index] = [PSCustomObject]@{
                Index = [int]$d.Index
                Model = if ($d.Model) { $d.Model.Trim() } else { "Disk $($d.Index)" }
                Serial = if ($d.SerialNumber) { $d.SerialNumber.Trim() } else { "" }
                Firmware = if ($d.FirmwareRevision) { $d.FirmwareRevision.Trim() } else { "" }
                Bus = if ($pnp -match '^USBSTOR') { "USB" } else { [string]$d.InterfaceType }
                Size = [long]$d.Size
                Pnp = $pnp
                Health = 5       # 0 healthy, 1 warning, 2 unhealthy, 5 unknown
                Media = ""
                PredictFail = $null
                Temp = $null; TempMax = $null; Wear = $null
                PowerOnHours = $null; ReadErr = $null; WriteErr = $null
                ReadErrUncorrected = $null; WriteErrUncorrected = $null; StartStop = $null
                WrittenGb = $null; ReadGb = $null
                Letters = ""
            }
        }
    } catch { return @([PSCustomObject]@{Title="Could not read disks"; Verdict="Unknown"; AccentColor="#8B949E"; Rows=@(@{Label="Error"; Value="$_"})}) }

    # Storage API: media type, overall health, reliability counters (temp/wear/hours/errors).
    try {
        $idByDeviceId = @{}
        foreach ($d in (Get-CimInstance -Namespace "root\Microsoft\Windows\Storage" -ClassName MSFT_PhysicalDisk -ErrorAction Stop)) {
            $devId = [string]$d.DeviceId
            $idx = 0
            if (-not [int]::TryParse($devId, [ref]$idx)) { continue }
            if (-not $raws.ContainsKey($idx)) { continue }
            $idByDeviceId[$devId] = $idx
            $r = $raws[$idx]
            $r.Health = [int]$d.HealthStatus
            $r.Media = switch ([int]$d.MediaType) { 3 { "HDD" } 4 { "SSD" } 5 { "SCM" } default { "" } }
            $bus = [int]$d.BusType
            $r.Bus = switch ($bus) { 17 { "NVMe" } 11 { "SATA" } 7 { "USB" } 10 { "SAS" } 8 { "RAID" } default { $r.Bus } }
        }
        foreach ($c in (Get-CimInstance -Namespace "root\Microsoft\Windows\Storage" -ClassName MSFT_StorageReliabilityCounter -ErrorAction Stop)) {
            $devId = [string]$c.DeviceId
            if (-not $idByDeviceId.ContainsKey($devId)) { continue }
            $r = $raws[$idByDeviceId[$devId]]
            $num = { param($v) if ($null -eq $v) { return $null }; try { $d = [double]$v; if ($d -lt 0 -or $d -gt 1e12) { return $null }; return $d } catch { return $null } }
            $r.Temp = & $num $c.Temperature
            $r.TempMax = & $num $c.TemperatureMax
            $r.Wear = & $num $c.Wear
            $r.PowerOnHours = & $num $c.PowerOnHours
            $r.ReadErr = & $num $c.ReadErrorsTotal
            $r.WriteErr = & $num $c.WriteErrorsTotal
            $r.ReadErrUncorrected = & $num $c.ReadErrorsUncorrected
            $r.WriteErrUncorrected = & $num $c.WriteErrorsUncorrected
            $r.StartStop = & $num $c.StartStopCycleCount
        }
    } catch {}

    # SMART "predicted failure" flag.
    try {
        foreach ($p in (Get-CimInstance -Namespace "root\wmi" -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop)) {
            $inst = [string]$p.InstanceName
            $fail = [bool]$p.PredictFailure
            foreach ($r in $raws.Values) {
                if ($r.Pnp.Length -gt 0 -and $inst.StartsWith($r.Pnp, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $r.PredictFail = ($r.PredictFail -eq $true) -or $fail
                }
            }
        }
    } catch {}

    # Drive letters per physical disk, via disk->partition->logicaldisk association chain.
    try {
        $diskOfPart = @{}
        foreach ($a in (Get-CimInstance -Query "SELECT Antecedent, Dependent FROM Win32_DiskDriveToDiskPartition")) {
            $disk = Get-DiskAssocRefId $a.Antecedent; $part = Get-DiskAssocRefId $a.Dependent
            if ($disk -and $part) { $diskOfPart[$part] = $disk }
        }
        $letters = @{}
        foreach ($a in (Get-CimInstance -Query "SELECT Antecedent, Dependent FROM Win32_LogicalDiskToPartition")) {
            $part = Get-DiskAssocRefId $a.Antecedent; $letter = Get-DiskAssocRefId $a.Dependent
            if ($part -and $letter -and $diskOfPart.ContainsKey($part)) {
                $m = [regex]::Match($diskOfPart[$part], 'PHYSICALDRIVE(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($m.Success) {
                    $idx = [int]$m.Groups[1].Value
                    if (-not $letters.ContainsKey($idx)) { $letters[$idx] = New-Object System.Collections.Generic.List[string] }
                    $letters[$idx].Add($letter)
                }
            }
        }
        foreach ($idx in $letters.Keys) {
            if ($raws.ContainsKey($idx)) { $raws[$idx].Letters = (($letters[$idx] | Select-Object -Unique | Sort-Object) -join " ") }
        }
    } catch {}

    # Fill gaps (temp/wear/written/read) from LibreHardwareMonitor Storage sensors when available.
    if ($LhmOk) {
        $storageSensors = @(Get-LHMSensorRows | Where-Object { $_.HardwareType -eq "Storage" })
        foreach ($r in $raws.Values) {
            $mine = @($storageSensors | Where-Object { $_.HardwareName -like "*$($r.Model)*" -or $r.Model -like "*$($_.HardwareName)*" })
            if ($mine.Count -eq 0) { continue }
            $tempHit = @($mine | Where-Object { $_.SensorType -eq "Temperature" -and $_.Value -gt 0 } | Select-Object -First 1)
            if ($null -eq $r.Temp -and $tempHit.Count -gt 0) { $r.Temp = $tempHit[0].Value }
            if ($null -eq $r.Wear) {
                $usedHit = @($mine | Where-Object { $_.SensorName -like "*Percentage Used*" } | Select-Object -First 1)
                $leftHit = @($mine | Where-Object { $_.SensorName -like "*Remaining Life*" } | Select-Object -First 1)
                if ($usedHit.Count -gt 0) { $r.Wear = $usedHit[0].Value } elseif ($leftHit.Count -gt 0) { $r.Wear = 100 - $leftHit[0].Value }
            }
            $wHit = @($mine | Where-Object { $_.SensorName -like "*Data Written*" -or $_.SensorName -like "*Host Writes*" } | Select-Object -First 1)
            if ($wHit.Count -gt 0) { $r.WrittenGb = $wHit[0].Value }
            $rdHit = @($mine | Where-Object { $_.SensorName -like "*Data Read*" -or $_.SensorName -like "*Host Reads*" } | Select-Object -First 1)
            if ($rdHit.Count -gt 0) { $r.ReadGb = $rdHit[0].Value }
        }
    }

    # Build the final cards (verdict + reasons + metrics), mirroring DiskHealth.cs's ToCard().
    $cards = @()
    foreach ($r in ($raws.Values | Sort-Object Index)) {
        $isSsd = $r.Media -eq "SSD" -or $r.Bus -eq "NVMe"
        $isUsb = $r.Bus -eq "USB"
        $crit = @(); $warn = @()
        $anyData = $r.Health -ne 5 -or $null -ne $r.PredictFail -or $null -ne $r.Wear -or $null -ne $r.Temp -or $null -ne $r.PowerOnHours

        if ($r.PredictFail -eq $true) { $crit += "The disk itself reports (S.M.A.R.T.) that it is likely to fail soon. Back up now." }
        if ($r.Health -eq 2) { $crit += "Windows classifies this disk as NOT healthy." }
        elseif ($r.Health -eq 1) { $warn += "Windows classifies this disk's health as `"warning`"." }

        if ($null -ne $r.Wear) {
            $w = [double]$r.Wear
            if ($w -ge 95) { $crit += "Wear at $([math]::Round($w))%: the SSD is at end of life. Replace it and back up now." }
            elseif ($w -ge 80) { $warn += "Wear at $([math]::Round($w))%: the SSD has used up a large part of its lifespan. Plan a replacement." }
        }
        if ($null -ne $r.Temp) {
            $t = [double]$r.Temp
            $okMax = if ($isSsd) { 70 } else { 55 }
            $critMax = if ($isSsd) { 85 } else { 65 }
            if ($t -ge $critMax) { $crit += "Temperature of $([math]::Round($t)) °C is too high for this disk." }
            elseif ($t -ge $okMax) { $warn += "Temperature of $([math]::Round($t)) °C is high. Improve ventilation." }
        }
        if (($r.ReadErrUncorrected -gt 0) -or ($r.WriteErrUncorrected -gt 0)) {
            $warn += "Uncorrected errors: $([int]($r.ReadErrUncorrected)) read and $([int]($r.WriteErrUncorrected)) write."
        }

        $verdict = if ($crit.Count -gt 0) { "Critical" } elseif ($warn.Count -gt 0) { "Warning" } elseif ($anyData) { "Good" } else { "Unknown" }
        if ($isUsb -and -not $anyData) { $verdict = "Unknown" }

        $reasons = @($crit) + @($warn)
        if ($reasons.Count -eq 0) {
            $reasons += if ($verdict -eq "Good") { "No problems found in the available readings." } else { "This disk doesn't report health data (common on pen drives and some external HDDs)." }
        }

        $accent = switch ($verdict) { "Good" { "#3FB950" } "Warning" { "#D29922" } "Critical" { "#F85149" } default { "#8B949E" } }

        $kind = if ($r.Media.Length -gt 0) { $r.Media } elseif ($isSsd) { "SSD" } else { "" }
        $metaParts = @($kind, $r.Bus, (Format-DiskBytes $r.Size), $(if ($r.Letters.Length -gt 0) { "Drives: $($r.Letters)" } else { "" })) | Where-Object { $_ }

        $rows = @()
        $rows += @{Label="Verdict"; Value=$verdict.ToUpper(); ValueColor=$accent}
        $rows += @{Label="Details"; Value=($metaParts -join " · ")}
        if ($r.Serial) { $rows += @{Label="Serial"; Value=$r.Serial} }
        $rows += @{Label="Notes"; Value=($reasons -join " ")}
        $rows += @{IsHeader=$true; Label="METRICS"}
        if ($null -ne $r.Temp) {
            $tv = "$([math]::Round($r.Temp)) °C"
            if ($r.TempMax -gt 0) { $tv += " (max recorded $([math]::Round($r.TempMax)))" }
            $rows += @{Label="Temperature"; Value=$tv}
        }
        if ($null -ne $r.Wear) {
            $rows += @{Label="Wear"; Value="$([math]::Round($r.Wear))%"}
            $rows += @{Label="Remaining life"; Value="$([math]::Max(0, 100 - $r.Wear))%"}
        }
        if ($null -ne $r.PowerOnHours) {
            $hoursText = ([math]::Round($r.PowerOnHours)).ToString('N0')
            $daysText = ([math]::Round($r.PowerOnHours / 24.0)).ToString('N0')
            $rows += @{Label="Power-on hours"; Value="$hoursText h ($daysText days)"}
        }
        if ($null -ne $r.StartStop) { $rows += @{Label="Start/stop cycles"; Value=([int64]$r.StartStop).ToString('N0')} }
        if ($null -ne $r.ReadErr) {
            $v = ([int64]$r.ReadErr).ToString('N0')
            if ($r.ReadErrUncorrected -gt 0) { $v += " ($([int64]$r.ReadErrUncorrected) uncorrected)" }
            $rows += @{Label="Read errors"; Value=$v}
        }
        if ($null -ne $r.WriteErr) {
            $v = ([int64]$r.WriteErr).ToString('N0')
            if ($r.WriteErrUncorrected -gt 0) { $v += " ($([int64]$r.WriteErrUncorrected) uncorrected)" }
            $rows += @{Label="Write errors"; Value=$v}
        }
        if ($r.WrittenGb -gt 0) { $rows += @{Label="Total written"; Value="$([math]::Round($r.WrittenGb).ToString('N0')) GB"} }
        if ($r.ReadGb -gt 0) { $rows += @{Label="Total read"; Value="$([math]::Round($r.ReadGb).ToString('N0')) GB"} }
        if ($null -ne $r.PredictFail) { $rows += @{Label="Predicted failure (S.M.A.R.T.)"; Value=$(if ($r.PredictFail) { "YES" } else { "No" })} }
        if ($r.Health -ne 5) { $rows += @{Label="Health (Windows)"; Value=switch ($r.Health) { 0 { "Healthy" } 1 { "Warning" } 2 { "Unhealthy" } default { "Unknown" } }} }
        if ($r.Firmware) { $rows += @{Label="Firmware"; Value=$r.Firmware} }

        $cards += [PSCustomObject]@{Title=$r.Model; Verdict=$verdict; AccentColor=$accent; Rows=$rows}
    }
    return $cards
}

# Used by: Show-PageYourPCDisks. Builds one card per mounted drive letter (volume), with usage
# percentage and the underlying physical disk's model/bus - mirrors DriveMap.cs's Read()/DriveCard
# (kind classification Removable/External USB/Internal/Network/Optical, used/free/total sizing).
function Get-DriveMapCards {
    $diskByLetter = @{}
    try {
        $disks = @{}
        foreach ($d in (Get-CimInstance -Query "SELECT DeviceID, Model, InterfaceType, PNPDeviceID FROM Win32_DiskDrive")) {
            $bus = [string]$d.InterfaceType
            if ([string]$d.PNPDeviceID -match '^USBSTOR') { $bus = "USB" }
            $disks[[string]$d.DeviceID] = @{Model = $(if ($d.Model) { $d.Model.Trim() } else { "" }); Bus = $bus}
        }
        $diskOfPart = @{}
        foreach ($a in (Get-CimInstance -Query "SELECT Antecedent, Dependent FROM Win32_DiskDriveToDiskPartition")) {
            $disk = Get-DiskAssocRefId $a.Antecedent; $part = Get-DiskAssocRefId $a.Dependent
            if ($disk -and $part) { $diskOfPart[$part] = $disk }
        }
        foreach ($a in (Get-CimInstance -Query "SELECT Antecedent, Dependent FROM Win32_LogicalDiskToPartition")) {
            $part = Get-DiskAssocRefId $a.Antecedent; $letter = Get-DiskAssocRefId $a.Dependent
            if ($part -and $letter -and $diskOfPart.ContainsKey($part) -and $disks.ContainsKey($diskOfPart[$part])) {
                $diskByLetter[$letter] = $disks[$diskOfPart[$part]]
            }
        }
    } catch {}

    $cards = @()
    try {
        foreach ($v in (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=2 OR DriveType=3 OR DriveType=4 OR DriveType=5")) {
            $letter = [string]$v.DeviceID
            $info = $diskByLetter[$letter]
            $usb = $info -and $info.Bus -eq "USB"
            $kind = switch ([int]$v.DriveType) {
                2 { "Removable" }
                3 { if ($usb) { "External (USB)" } else { "Internal" } }
                4 { "Network" }
                5 { "Optical" }
                default { "Unknown" }
            }
            $total = [long]$v.Size; $free = [long]$v.FreeSpace
            $usedPct = if ($total -gt 0) { [math]::Round((($total - $free) / $total) * 100, 1) } else { 0 }
            $title = if ($v.VolumeName) { "$letter  $($v.VolumeName)" } else { $letter }
            $rows = @(
                @{Label="Type"; Value=$kind}
                @{Label="File system"; Value=$(if ($v.FileSystem) { $v.FileSystem } else { "—" })}
                @{Label="Disk"; Value=$(if ($info -and $info.Model) { "$($info.Model) ($($info.Bus))" } else { "—" })}
                @{Label="Used"; Value="$usedPct% — $(Format-DiskBytes ($total - $free)) used, $(Format-DiskBytes $free) free of $(Format-DiskBytes $total)"}
            )
            $cards += [PSCustomObject]@{Title=$title; Rows=$rows}
        }
    } catch {}
    return $cards
}

# "Your PC > Disks" page: a health card per physical disk (verdict + reasons + SMART/reliability
# metrics, with an LHM fallback for temperature/wear/written/read) followed by a card per mounted
# drive letter (usage, file system, underlying physical disk) - full feature parity with
# ResetExplode's Disks page (DiskHealth.cs + DriveMap.cs).
function Show-PageYourPCDisks {
    Clear-GuiContent
    Add-GuiPageTitle "Disks"

    $lhmOk = Initialize-LibreHardwareMonitor
    $healthCards = @(Get-DiskHealthCards -LhmOk $lhmOk)
    foreach ($c in $healthCards) {
        Add-GuiInfoCard -Title $c.Title -Icon "&#xEDA2;" -AccentColor $c.AccentColor -Rows $c.Rows
    }

    $driveCards = @(Get-DriveMapCards)
    foreach ($c in $driveCards) {
        Add-GuiInfoCard -Title $c.Title -Icon "&#xE88E;" -Rows $c.Rows
    }

    if ($healthCards.Count -eq 0 -and $driveCards.Count -eq 0) {
        Add-GuiInfoCard -Title "Disks" -Icon "&#xEDA2;" -Rows @(@{Label="Status"; Value="Disk detection failed."})
    }
}
