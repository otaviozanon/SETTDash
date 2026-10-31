# Used by: Show-PageYourPCCpu only. Builds the "INFO" tab rows for one CPU (Win32_Processor), mirroring
# ResetExplode's SystemInfoCollector.CollectCpu but with extra fields exposed by WMI (architecture,
# address/data width, voltage, external clock, processor ID, L1/L2/L3 cache sizes via Win32_CacheMemory) -
# the CPU counterpart of Get-GpuInfoRows, giving more depth than the plain "Your PC > System" CPU section.
function Get-CpuInfoRows {
    param($Cpu, $CacheSizesKB)
    $archMap = @{0="x86"; 1="MIPS"; 2="Alpha"; 3="PowerPC"; 6="Intel Itanium-based"; 9="x64"}
    $arch = if ($archMap.ContainsKey([int]$Cpu.Architecture)) { $archMap[[int]$Cpu.Architecture] } else { "Unknown" }

    $rows = @(
        @{IsHeader=$true; Label="IDENTIFICATION"}
        @{Label="Name"; Value=$(if ($Cpu.Name) { $Cpu.Name.Trim() } else { "N/A" })}
        @{Label="Manufacturer"; Value=$(if ($Cpu.Manufacturer) { $Cpu.Manufacturer } else { "N/A" })}
        @{Label="Socket"; Value=$(if ($Cpu.SocketDesignation) { $Cpu.SocketDesignation } else { "N/A" })}
        @{Label="Architecture"; Value=$arch}
        @{Label="Processor ID"; Value=$(if ($Cpu.ProcessorId) { $Cpu.ProcessorId } else { "N/A" })}
        @{Label="Address Width / Data Width"; Value="$($Cpu.AddressWidth)-bit / $($Cpu.DataWidth)-bit"}

        @{IsHeader=$true; Label="CORES AND THREADS"}
        @{Label="Physical Cores"; Value=$(if ($Cpu.NumberOfCores) { $Cpu.NumberOfCores } else { "N/A" })}
        @{Label="Logical Processors (Threads)"; Value=$(if ($Cpu.NumberOfLogicalProcessors) { $Cpu.NumberOfLogicalProcessors } else { "N/A" })}
        @{Label="Number of Enabled Cores"; Value=$(if ($Cpu.NumberOfEnabledCore) { $Cpu.NumberOfEnabledCore } else { "N/A" })}

        @{IsHeader=$true; Label="CLOCKS"}
        @{Label="Max Clock Speed"; Value=$(if ($Cpu.MaxClockSpeed) { "$($Cpu.MaxClockSpeed) MHz" } else { "N/A" })}
        @{Label="Current Clock Speed"; Value=$(if ($Cpu.CurrentClockSpeed) { "$($Cpu.CurrentClockSpeed) MHz" } else { "N/A" })}
        @{Label="External Clock (Bus Speed)"; Value=$(if ($Cpu.ExtClock -and $Cpu.ExtClock -gt 0) { "$($Cpu.ExtClock) MHz" } else { "N/A" })}

        @{IsHeader=$true; Label="CACHE"}
        @{Label="L1 Cache"; Value=$(if ($CacheSizesKB.L1 -gt 0) { "$($CacheSizesKB.L1) KB" } else { "N/A" })}
        @{Label="L2 Cache"; Value=$(if ($Cpu.L2CacheSize -gt 0) { "$($Cpu.L2CacheSize) KB" } else { "N/A" })}
        @{Label="L3 Cache"; Value=$(if ($Cpu.L3CacheSize -gt 0) { "$($Cpu.L3CacheSize) KB" } else { "N/A" })}

        @{IsHeader=$true; Label="FEATURES"}
        @{Label="Virtualization Firmware Enabled"; Value=$(if ($null -ne $Cpu.VirtualizationFirmwareEnabled) { $Cpu.VirtualizationFirmwareEnabled } else { "N/A" })}
        @{Label="VM Monitor Mode Extensions"; Value=$(if ($null -ne $Cpu.VMMonitorModeExtensions) { $Cpu.VMMonitorModeExtensions } else { "N/A" })}
        @{Label="Current Voltage"; Value=$(if ($Cpu.CurrentVoltage) { "$([math]::Round($Cpu.CurrentVoltage / 10, 1)) V" } else { "N/A" })}

        @{IsHeader=$true; Label="DEVICE"}
        @{Label="Device ID"; Value=$(if ($Cpu.DeviceID) { $Cpu.DeviceID } else { "N/A" })}
        @{Label="Status"; Value=$(if ($Cpu.Status) { $Cpu.Status } else { "N/A" })}
        @{Label="Load (At Read Time)"; Value=$(if ($null -ne $Cpu.LoadPercentage) { "$($Cpu.LoadPercentage) %" } else { "N/A" })}
    )
    return $rows
}

# Used by: Show-PageYourPCCpu only. Builds the "SENSORS" tab rows for one CPU: live readings from
# LibreHardwareMonitor whose hardware type is Cpu and name matches this processor (mirrors
# ResetExplode's SensorMonitor rows filtered by HardwareType.Cpu), with Min/Max alongside the value -
# the CPU counterpart of Get-GpuSensorRows (no vendor-specific live API like NVML/ADL exists for CPUs,
# LHM via PawnIO/MSR already covers temperature/power/clock/load per-core).
function Get-CpuSensorRows {
    param([string]$CpuName, [bool]$LhmOk, [bool]$PawnIOInstalled)
    $rows = @()
    if (-not $LhmOk) {
        $msg = if ($PawnIOInstalled) { "Unavailable (if you just installed PawnIO, restart your PC)." } else { "Unavailable: install PawnIO / enable LibreHardwareMonitor for live CPU sensors." }
        $rows += @{Label="Status"; Value=$msg}
        return $rows
    }
    $matched = Get-LHMSensorRows | Where-Object {
        $_.HardwareType -eq "Cpu" -and ($_.HardwareName -eq $CpuName -or $CpuName -like "*$($_.HardwareName)*" -or $_.HardwareName -like "*$CpuName*")
    }
    if (-not $matched -or $matched.Count -eq 0) {
        # Fall back to every Cpu-typed sensor (some boards report a generic hardware name that doesn't
        # match Win32_Processor's Name string, e.g. "AMD Ryzen..." vs a shortened LHM label).
        $matched = Get-LHMSensorRows | Where-Object { $_.HardwareType -eq "Cpu" }
    }
    if (-not $matched -or $matched.Count -eq 0) {
        $rows += @{Label="Status"; Value="No live sensors exposed by LibreHardwareMonitor for this CPU."}
        return $rows
    }
    foreach ($group in ($matched | Group-Object SensorType)) {
        $rows += @{IsHeader=$true; Label=(Get-LHMSensorCategory $group.Name).ToUpper()}
        foreach ($s in ($group.Group | Sort-Object SensorName)) {
            $valText = Format-LHMSensorValue $s.SensorType $s.Value
            $minText = Format-LHMSensorValue $s.SensorType $s.Min
            $maxText = Format-LHMSensorValue $s.SensorType $s.Max
            $rows += @{Label=$s.SensorName; Value="$valText  (min $minText / max $maxText)"}
        }
    }
    return $rows
}

# "Your PC > CPU" page: one card per detected processor, each with an Info/Sensors pill switcher in
# the header - mirrors ResetExplode's "Processador" page (SystemInfoCollector.CollectCpu for specs,
# SensorMonitor rows filtered by HardwareType.Cpu for live data), same layout pattern as Show-PageYourPCGpu.
function Show-PageYourPCCpu {
    Clear-GuiContent
    Add-GuiPageTitle "CPU"

    $pawnIOInstalled = Test-PawnIOInstalled
    $lhmOk = Initialize-LibreHardwareMonitor

    try {
        $cpus = @(Get-CimInstance Win32_Processor)
    } catch { $cpus = @() }

    if (-not $cpus -or $cpus.Count -eq 0) {
        Add-GuiInfoCard -Title "CPU" -Icon "&#xE950;" -Rows @(@{Label="Status"; Value="No CPU detected."})
        return
    }

    $activeStyle = $Window.FindResource("CategoryPillActiveStyle")
    $normalStyle = $Window.FindResource("CategoryPillStyle")
    $cardStyle = $Window.FindResource("CardStyle")

    $allCache = try { @(Get-CimInstance Win32_CacheMemory) } catch { @() }

    # Search box (like Sensors page): filters each card's currently active tab by label/value -
    # every card keeps its own $renderTab closure, so the search box just re-invokes whichever tab
    # is currently active on each card.
    $searchState = @{ Search = "" }
    $cardRenderers = New-Object System.Collections.Generic.List[object]
    $searchBox = Add-GuiPageSearchHeader -SubtitleText "Detected processors" -Placeholder "Search spec or sensor..."
    $searchBox.Add_TextChanged({
        $searchState.Search = $searchBox.Text.Trim()
        foreach ($r in $cardRenderers) { & $r }
    }.GetNewClosure())

    foreach ($c in $cpus) {
        $l1 = ($allCache | Where-Object { $_.Level -eq 3 } | Measure-Object -Property InstalledSize -Sum).Sum
        $cacheSizes = @{ L1 = $(if ($l1) { $l1 } else { 0 }) }

        $card = New-Object System.Windows.Controls.Border
        if ($cardStyle) { $card.Style = $cardStyle }
        $card.Padding = "12"

        $stack = New-Object System.Windows.Controls.StackPanel
        $titlePanel = New-Object System.Windows.Controls.StackPanel
        Add-GuiIconTitle $titlePanel "&#xE950;" $c.Name.Trim() "#F0883E" -AccentTitle
        $stack.AddChild($titlePanel)

        $pillsStack = New-Object System.Windows.Controls.WrapPanel
        $pillsStack.Orientation = "Horizontal"
        $pillsStack.Margin = "0,2,0,10"
        $stack.AddChild($pillsStack)

        $detailPanel = New-Object System.Windows.Controls.StackPanel
        $stack.AddChild($detailPanel)
        $card.Child = $stack
        $pnlContent.AddChild($card)

        $tabButtons = @{}
        $activeTab = @{ Name = "Info" }
        $renderTab = {
            param($tabName)
            if ($tabName) {
                foreach ($bn in $tabButtons.Keys) { $tabButtons[$bn].Style = if ($bn -eq $tabName) { $activeStyle } else { $normalStyle } }
                $activeTab.Name = $tabName
            }
            $detailPanel.Children.Clear()
            $rows = if ($activeTab.Name -eq "Info") { Get-CpuInfoRows $c $cacheSizes } else { Get-CpuSensorRows -CpuName $c.Name.Trim() -LhmOk $lhmOk -PawnIOInstalled $pawnIOInstalled }
            $rows = Get-GuiFilteredInfoRows -Rows $rows -Search $searchState.Search
            foreach ($row in $rows) { Add-GuiInfoRowItem $detailPanel $row }
        }.GetNewClosure()
        $cardRenderers.Add({ & $renderTab $null }.GetNewClosure()) | Out-Null

        foreach ($tabName in @("Info", "Sensors")) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Content = $tabName
            $btn.Style = $normalStyle
            $btn.Add_Click({ & $renderTab $tabName }.GetNewClosure())
            $tabButtons[$tabName] = $btn
            $pillsStack.AddChild($btn)
        }

        & $renderTab "Info"
    }
}
