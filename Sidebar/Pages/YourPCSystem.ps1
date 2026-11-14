# Converts a byte count into a human-readable string (B/KB/MB/GB/TB), matching ResetExplode's
# SystemInfoCollector.Bytes() helper.
function Format-ByteSizeAuto {
    param($Value)
    if ($null -eq $Value) { return "-" }
    $b = [double]$Value
    $units = @("B","KB","MB","GB","TB")
    $i = 0
    while ($b -ge 1024 -and $i -lt ($units.Count - 1)) { $b /= 1024; $i++ }
    return "{0:0.##} {1}" -f $b, $units[$i]
}

function Show-PageYourPCSystem {
    $categories = [ordered]@{
        (T "System") = {
            $os = Get-CimInstance Win32_OperatingSystem
            @(
                @{Label=(T "Name"); Value=$os.Caption}
                @{Label=(T "Version"); Value=$os.Version}
                @{Label=(T "Build"); Value=$os.BuildNumber}
                @{Label=(T "Architecture"); Value=$os.OSArchitecture}
                @{Label=(T "Computer Name"); Value=$env:COMPUTERNAME}
            )
        }
        (T "Motherboard and BIOS") = {
            $rows = @()
            try {
                $board = Get-CimInstance Win32_BaseBoard
                $rows += @{IsHeader=$true; Label=(T "Motherboard")}
                $rows += @{Label=(T "Manufacturer"); Value=$board.Manufacturer}
                $rows += @{Label=(T "Model"); Value=$board.Product}
                $rows += @{Label=(T "Version"); Value=$board.Version}
                $rows += @{Label=(T "Serial Number"); Value=$board.SerialNumber}
            } catch {}
            try {
                $bios = Get-CimInstance Win32_BIOS
                $rows += @{IsHeader=$true; Label="BIOS"}
                $rows += @{Label=(T "Manufacturer"); Value=$bios.Manufacturer}
                $rows += @{Label=(T "Version"); Value=$bios.SMBIOSBIOSVersion}
                $biosDate = try { [System.Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate).ToString("dd/MM/yyyy") } catch { "-" }
                $rows += @{Label=(T "Release Date"); Value=$biosDate}
            } catch {}
            $rows
        }
        (T "CPU") = {
            $rows = @()
            foreach ($c in (Get-CimInstance Win32_Processor)) {
                $rows += @{IsHeader=$true; Label=$c.Name.Trim()}
                $rows += @{Label=(T "Manufacturer"); Value=$c.Manufacturer}
                $rows += @{Label=(T "Socket"); Value=$c.SocketDesignation}
                $rows += @{Label=(T "Physical Cores"); Value=$c.NumberOfCores}
                $rows += @{Label=(T "Logical Processors (Threads)"); Value=$c.NumberOfLogicalProcessors}
                $rows += @{Label=(T "Max Clock Speed"); Value="$($c.MaxClockSpeed) MHz"}
                $rows += @{Label=(T "L2 Cache"); Value="$($c.L2CacheSize) KB"}
                $rows += @{Label=(T "L3 Cache"); Value="$($c.L3CacheSize) KB"}
                $rows += @{Label=(T "Virtualization Firmware Enabled"); Value=$c.VirtualizationFirmwareEnabled}
            }
            $rows
        }
        (T "GPU") = {
            $rows = @()
            $gpus = Get-CimInstance Win32_VideoController
            if ($gpus) {
                foreach ($g in $gpus) {
                    $rows += @{IsHeader=$true; Label=$g.Name}
                    $rows += @{Label=(T "Driver Version"); Value=$g.DriverVersion}
                    $rows += @{Label=(T "Memory (WMI, capped at 4 GB)"); Value=(Format-ByteSizeAuto $g.AdapterRAM)}
                    $rows += @{Label=(T "Current Resolution"); Value="$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate) Hz"}
                }
            } else {
                $rows += @{Label=(T "Status"); Value=(T "No GPU detected.")}
            }
            $rows
        }
        (T "RAM") = {
            $rows = @()
            $ramTypeMap = @{20="DDR";21="DDR2";24="DDR3";26="DDR4";34="DDR5";35="LPDDR5"}
            $ramFormMap = @{8="DIMM";12="SO-DIMM";13="Micro-DIMM";15="FB-DIMM";9="RIMM";11="SRIMM";6="Proprietary";0="-"}
            $rankMap = @{1="1 (single)";2="2 (dual)";3="3";4="4 (quad)"}
            function Format-GuiVolt($mv) {
                if (-not $mv) { return "-" }
                $v = [double]$mv
                if ($v -gt 0) { return "{0:0.00#} V" -f ($v / 1000) }
                return "-"
            }
            function Get-GuiRamChannel([string]$Locator) {
                if (-not $Locator) { return $null }
                if ($Locator -match "(?i)(?:channel|chan|ch)[\s_-]*([A-H0-9])") { return $Matches[1].ToUpper() }
                if ($Locator -match "(?i)dimm[\s_-]*([A-H])\d") { return $Matches[1].ToUpper() }
                if ($Locator -match "(?i)(?:^|[^A-Za-z])([A-H])[12](?:$|[^0-9])") { return $Matches[1].ToUpper() }
                return $null
            }

            $mods = @(Get-CimInstance Win32_PhysicalMemory)
            # Guarded .Sum: on a machine with no enumerable memory devices Measure-Object produces no
            # record and reading .Sum off it throws under StrictMode (CI-only failure class).
            $memInfo = if ($mods) { $mods | Measure-Object -Property Capacity -Sum } else { $null }
            $total = $(if ($memInfo) { $memInfo.Sum } else { 0 })
            $rows += @{Label=(T "Total Installed"); Value=(Format-ByteSizeAuto $total)}

            $slots = 0; $maxBytes = 0
            try {
                foreach ($a in (Get-CimInstance Win32_PhysicalMemoryArray)) {
                    $slots += [int]$a.MemoryDevices
                    $kb = if ($a.MaxCapacityEx) { $a.MaxCapacityEx } else { $a.MaxCapacity }
                    $maxBytes += [double]$kb * 1024
                }
            } catch {}

            $rows += @{IsHeader=$true; Label=(T "Summary")}
            $rows += @{Label=(T "Installed Modules"); Value=$(if ($slots -gt 0) { "$($mods.Count) of $slots slots" } else { "$($mods.Count)" })}
            if ($maxBytes -gt 0) { $rows += @{Label=(T "Max Capacity Supported"); Value=(Format-ByteSizeAuto $maxBytes)} }
            if ($mods.Count -gt 0) {
                $types = $mods | ForEach-Object { $ramTypeMap[[int]$_.SMBIOSMemoryType] } | Where-Object { $_ } | Select-Object -Unique
                if ($types) { $rows += @{Label=(T "Type"); Value=($types -join " / ")} }
                $confSpeeds = $mods | Where-Object { $_.ConfiguredClockSpeed -gt 0 } | ForEach-Object { $_.ConfiguredClockSpeed }
                $ratedSpeeds = $mods | ForEach-Object { $_.Speed }
                $conf = if ($confSpeeds) { ($confSpeeds | Measure-Object -Minimum).Minimum } else { 0 }
                $rated = if ($ratedSpeeds) { ($ratedSpeeds | Measure-Object -Maximum).Maximum } else { 0 }
                $rows += @{Label=(T "Speed In Use"); Value=$(if ($conf -gt 0) { "$conf MT/s" } else { "-" })}
                $rows += @{Label=(T "Rated Speed (Module)"); Value=$(if ($rated -gt 0) { "$rated MT/s" } else { "-" })}

                # EXPO/XMP profile: Windows doesn't expose whether it's on, so we estimate from the
                # speed figure baked into the module's part number (e.g. ...6000C30 -> 6000 MT/s).
                $label = 0
                foreach ($m in $mods) {
                    if ($m.PartNumber -match "(?<!\d)(2133|2400|2666|2933|3000|3200|3466|3600|3733|3800|4000|4133|4266|4400|4800|5200|5600|5800|6000|6200|6400|6600|6800|7000|7200|7400|7600|7800|8000|8200|8400|8800)(?!\d)") {
                        $v = [int]$Matches[1]; if ($v -gt $label) { $label = $v }
                    }
                }
                $profile =
                    if ($conf -le 0) { "Could not read the speed in use." }
                    elseif ($label -gt 0 -and $conf -lt ($label * 0.95)) { "Likely OFF: RAM runs at $conf MT/s, but the part number indicates $label MT/s. Enable EXPO/XMP in the BIOS." }
                    elseif ($label -gt 0) { "Likely ON: running at $conf MT/s (part number indicates $label MT/s)." }
                    elseif ($rated -gt 0 -and $conf -lt $rated) { "Running below rated speed ($conf of $rated MT/s). Check EXPO/XMP in the BIOS." }
                    else { "Cannot estimate (part number has no speed figure). Check in the BIOS." }
                $rows += @{Label=(T "EXPO/XMP Profile (estimated)"); Value=$profile}

                # Channels: inferred from slot names (e.g. DIMM_A2 + DIMM_B2 = two channels).
                $chans = $mods | ForEach-Object { $c = Get-GuiRamChannel $_.DeviceLocator; if (-not $c) { $c = Get-GuiRamChannel $_.BankLabel }; $c }
                $chText =
                    if ($mods.Count -eq 1) { "Single channel (1 module). With 2 matching modules RAM runs in dual channel and is noticeably faster." }
                    elseif (-not ($chans -contains $null)) {
                        $distinct = ($chans | Select-Object -Unique).Count
                        if ($distinct -ge 2) { "$distinct channels (dual channel or more)" } else { "Single channel: modules are in the same channel. Move them to the slots recommended in the motherboard manual." }
                    } else { "Could not detect from slot names ($($mods.DeviceLocator -join ", ")). See the motherboard manual." }
                $rows += @{Label=(T "Channels (estimated)"); Value=$chText}

                $ecc = $mods | Where-Object { $_.TotalWidth -gt $_.DataWidth -and $_.DataWidth -gt 0 } | Select-Object -First 1
                $rows += @{Label="ECC"; Value=$(if ($ecc) { T "Yes (error correction)" } else { T "No" })}

                $volts = $mods | ForEach-Object { Format-GuiVolt $_.ConfiguredVoltage } | Where-Object { $_ -ne "-" } | Select-Object -Unique
                if ($volts) { $rows += @{Label=(T "Voltage In Use"); Value=($volts -join " / ")} }
            }
            $rows += @{Label=(T "Timings (CL, tRCD, tRP...)"); Value=(T "Not exposed by Windows. Check the BIOS or CPU-Z (Memory/SPD tab).")}

            $os = Get-CimInstance Win32_OperatingSystem
            $totKb = [double]$os.TotalVisibleMemorySize; $freeKb = [double]$os.FreePhysicalMemory
            $pct = if ($totKb -gt 0) { [math]::Round((($totKb - $freeKb) / $totKb) * 100) } else { 0 }
            $rows += @{Label=(T "In Use (At Read Time)"); Value="$(Format-ByteSizeAuto (($totKb - $freeKb) * 1024)) of $(Format-ByteSizeAuto ($totKb * 1024)) ($pct%)"}
            $virtTotKb = [double]$os.TotalVirtualMemorySize; $virtFreeKb = [double]$os.FreeVirtualMemory
            $rows += @{Label=(T "Virtual Memory In Use (RAM + pagefile)"); Value="$(Format-ByteSizeAuto (($virtTotKb - $virtFreeKb) * 1024)) of $(Format-ByteSizeAuto ($virtTotKb * 1024))"}

            foreach ($m in $mods) {
                $rows += @{IsHeader=$true; Label="$(T 'Module') - $($m.BankLabel) / $($m.DeviceLocator)"}
                $rows += @{Label=(T "Capacity"); Value=(Format-ByteSizeAuto $m.Capacity)}
                $rows += @{Label=(T "Type"); Value=$(if ($ramTypeMap.ContainsKey([int]$m.SMBIOSMemoryType)) { $ramTypeMap[[int]$m.SMBIOSMemoryType] } else { T "Unknown" })}
                $rows += @{Label=(T "Form Factor"); Value=$(if ($ramFormMap.ContainsKey([int]$m.FormFactor)) { $ramFormMap[[int]$m.FormFactor] } else { T "Other" })}
                $rows += @{Label=(T "Ranks"); Value=$(if ($rankMap.ContainsKey([int]$m.Attributes)) { $rankMap[[int]$m.Attributes] } else { "-" })}
                $rows += @{Label=(T "Speed In Use"); Value=$(if ($m.ConfiguredClockSpeed -gt 0) { "$($m.ConfiguredClockSpeed) MT/s" } else { "-" })}
                $rows += @{Label=(T "Rated Speed"); Value=$(if ($m.Speed -gt 0) { "$($m.Speed) MT/s" } else { "-" })}
                $rows += @{Label=(T "Voltage In Use"); Value=(Format-GuiVolt $m.ConfiguredVoltage)}
                $voltRange = if ($m.MinVoltage -and $m.MaxVoltage) { "$(Format-GuiVolt $m.MinVoltage) - $(Format-GuiVolt $m.MaxVoltage)" } else { "-" }
                $rows += @{Label=(T "Module Voltage Range"); Value=$voltRange}
                $rows += @{Label=(T "Data / Total Width"); Value=$(if ($m.DataWidth -gt 0) { "$($m.DataWidth) / $($m.TotalWidth) bits" } else { "-" })}
                $rows += @{Label=(T "Manufacturer"); Value=$m.Manufacturer}
                $rows += @{Label=(T "Part Number"); Value=$m.PartNumber}
                $rows += @{Label=(T "Serial Number"); Value=$m.SerialNumber}
            }
            $rows
        }
        (T "Storage") = {
            $rows = @()
            $drives = Get-CimInstance Win32_DiskDrive
            if ($drives) {
                foreach ($d in $drives) {
                    $rows += @{IsHeader=$true; Label=$d.Model}
                    $rows += @{Label=(T "Capacity"); Value=(Format-ByteSizeAuto $d.Size)}
                    $rows += @{Label=(T "Interface"); Value=$d.InterfaceType}
                    $rows += @{Label=(T "Serial Number"); Value=$d.SerialNumber}
                    $rows += @{Label=(T "Firmware"); Value=$d.FirmwareRevision}
                }
            } else {
                $rows += @{Label=(T "Status"); Value=(T "No disk detected.")}
            }
            $rows
        }
    }

    Show-GuiCategoryDetailPage -PageTitle (T "System") -Categories $categories
}
