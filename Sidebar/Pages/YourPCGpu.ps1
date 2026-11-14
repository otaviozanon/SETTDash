# Used by: Show-PageYourPCGpu only. Builds the "INFO" tab rows for one GPU (Win32_VideoController),
# mirroring ResetExplode's GpuInfoCollector sections (driver/BIOS, display, memory) using WMI, with
# VRAM/shared-memory/feature-level overridden by DXGI when available (WMI's AdapterRAM is a 32-bit
# field and truncates on cards with 4GB+ VRAM), plus extra NVML-only sections (memory bus, PCIe
# link, power limits, VBIOS, CUDA) when $NvmlHandle is set.
function Get-GpuInfoRows {
    param($Gpu, [IntPtr]$NvmlHandle = [IntPtr]::Zero, $DxgiAdapter = $null)
    $vramGB = if ($DxgiAdapter -and $DxgiAdapter.DedicatedVideoMemory -gt 0) {
        [math]::Round($DxgiAdapter.DedicatedVideoMemory / 1GB, 1)
    } elseif ($Gpu.AdapterRAM -and $Gpu.AdapterRAM -gt 0) { [math]::Round($Gpu.AdapterRAM / 1GB, 1) } else { $null }
    $resolution = if ($Gpu.CurrentHorizontalResolution -and $Gpu.CurrentVerticalResolution) {
        "$($Gpu.CurrentHorizontalResolution) x $($Gpu.CurrentVerticalResolution)"
    } else { "N/A" }
    $driverDate = try { if ($Gpu.DriverDate) { [Management.ManagementDateTimeConverter]::ToDateTime($Gpu.DriverDate).ToString("yyyy-MM-dd") } else { "N/A" } } catch { "$($Gpu.DriverDate)" }

    $rows = @(
        @{IsHeader=$true; Label=(T "DISPLAY")}
        @{Label=(T "Video Processor"); Value=$(if ($Gpu.VideoProcessor) { $Gpu.VideoProcessor } else { T "N/A" })}
        @{Label=(T "Current Resolution"); Value=$resolution}
        @{Label=(T "Refresh Rate"); Value=$(if ($Gpu.CurrentRefreshRate) { "$($Gpu.CurrentRefreshRate) Hz" } else { T "N/A" })}
        @{Label=(T "Color Depth"); Value=$(if ($Gpu.CurrentBitsPerPixel) { "$($Gpu.CurrentBitsPerPixel)-bit" } else { T "N/A" })}
        @{Label=(T "Video Mode"); Value=$(if ($Gpu.VideoModeDescription) { $Gpu.VideoModeDescription } else { T "N/A" })}

        @{IsHeader=$true; Label=(T "MEMORY")}
        @{Label=(T "Dedicated VRAM"); Value=$(if ($vramGB) { "$vramGB GB" } else { T "N/A" })}
        @{Label=(T "Video Memory Type"); Value=$(if ($Gpu.VideoMemoryType) { $Gpu.VideoMemoryType } else { T "N/A" })}

        @{IsHeader=$true; Label=(T "DRIVER AND BIOS")}
        @{Label=(T "Driver Version"); Value=$(if ($Gpu.DriverVersion) { $Gpu.DriverVersion } else { T "N/A" })}
        @{Label=(T "Driver Date"); Value=$driverDate}
        @{Label=(T "INF Section"); Value=$(if ($Gpu.InfSection) { $Gpu.InfSection } else { T "N/A" })}
        @{Label=(T "Signed Driver"); Value=$(if ($Gpu.Status) { $Gpu.Status } else { T "N/A" })}

        @{IsHeader=$true; Label=(T "DEVICE")}
        @{Label=(T "Adapter Compatibility"); Value=$(if ($Gpu.AdapterCompatibility) { $Gpu.AdapterCompatibility } else { T "N/A" })}
        @{Label=(T "PNP Device ID"); Value=$(if ($Gpu.PNPDeviceID) { $Gpu.PNPDeviceID } else { T "N/A" })}
        @{Label=(T "Availability"); Value=$(if ($Gpu.Availability) { $Gpu.Availability } else { T "N/A" })}
        @{Label=(T "Status"); Value=$(if ($Gpu.Status) { $Gpu.Status } else { T "N/A" })}
    )
    if ($DxgiAdapter) {
        $rows += @{IsHeader=$true; Label=(T "DIRECTX (DXGI)")}
        if ($DxgiAdapter.FeatureLevel) { $rows += @{Label=(T "Max Feature Level"); Value="D3D_FEATURE_LEVEL_$($DxgiAdapter.FeatureLevel)"} }
        if ($DxgiAdapter.SharedSystemMemory -gt 0) { $rows += @{Label=(T "Shared System Memory"); Value="$([math]::Round($DxgiAdapter.SharedSystemMemory/1GB,1)) GB"} }
        if ($DxgiAdapter.DedicatedSystemMemory -gt 0) { $rows += @{Label=(T "Dedicated System Memory"); Value="$([math]::Round($DxgiAdapter.DedicatedSystemMemory/1MB,0)) MB"} }
    }
    if ($NvmlHandle -ne [IntPtr]::Zero) { $rows += Get-NvmlInfoRows -Handle $NvmlHandle }
    return $rows
}

# Used by: Show-PageYourPCGpu only. Builds the "SENSORS" tab rows for one GPU: live readings from
# LibreHardwareMonitor whose hardware name matches this adapter (mirrors ResetExplode's GpuLive,
# which filters SensorMonitor.Rows by Hardware == gpu.Name), with Min/Max alongside the value, plus
# a trailing "NVIDIA LIVE DATA" group from NVML (P-state, PerfCap, power %, encoder/decoder, PCIe).
function Get-GpuSensorRows {
    param([string]$GpuName, [bool]$LhmOk, [IntPtr]$NvmlHandle = [IntPtr]::Zero, $AdlAdapterIndex = $null)
    $rows = @()
    if (-not $LhmOk) {
        $rows += @{Label=(T "Status"); Value=(T "Unavailable: install PawnIO / enable LibreHardwareMonitor for live GPU sensors.")}
    } else {
        $matched = @(Get-LHMSensorRows | Where-Object {
            $_.HardwareType -like "Gpu*" -and ($_.HardwareName -eq $GpuName -or $GpuName -like "*$($_.HardwareName)*" -or $_.HardwareName -like "*$GpuName*")
        })
        if (-not $matched -or $matched.Count -eq 0) {
            $rows += @{Label=(T "Status"); Value=(T "No live sensors exposed by LibreHardwareMonitor for this GPU.")}
        } else {
            foreach ($group in ($matched | Group-Object SensorType)) {
                $rows += @{IsHeader=$true; Label=(Get-LHMSensorCategory $group.Name).ToUpper()}
                foreach ($s in ($group.Group | Sort-Object SensorName)) {
                    $valText = Format-LHMSensorValue $s.SensorType $s.Value
                    $minText = Format-LHMSensorValue $s.SensorType $s.Min
                    $maxText = Format-LHMSensorValue $s.SensorType $s.Max
                    $rows += @{Label=$s.SensorName; Value="$valText  (min $minText / max $maxText)"}
                }
            }
        }
    }
    if ($NvmlHandle -ne [IntPtr]::Zero) { $rows += Get-NvmlLiveRows -Handle $NvmlHandle }
    if ($null -ne $AdlAdapterIndex) { $rows += Get-AdlLiveRows -AdapterIndex $AdlAdapterIndex }
    return $rows
}

# "Your PC > GPU" page: one card per detected adapter, each with an Info/Sensors pill switcher in
# the header - mirrors ResetExplode's "Placa de vídeo" page (GpuSections = specs, GpuLive = live
# sensors for that adapter), adapted to the WMI + LibreHardwareMonitor data available here.
function Show-PageYourPCGpu {
    Clear-GuiContent
    Add-GuiPageTitle (T "GPU")

    $lhmOk = Initialize-LibreHardwareMonitor
    $nvmlOk = Initialize-Nvml
    $adlOk = Initialize-Adl

    try {
        $gpus = @(Get-CimInstance Win32_VideoController)
    } catch { $gpus = @() }

    if (-not $gpus -or $gpus.Count -eq 0) {
        Add-GuiInfoCard -Title (T "GPU") -Icon "&#xE7F4;" -Rows @(@{Label=(T "Status"); Value=(T "No GPU detected.")})
        return
    }

    $activeStyle = $Window.FindResource("CategoryPillActiveStyle")
    $normalStyle = $Window.FindResource("CategoryPillStyle")
    $cardStyle = $Window.FindResource("CardStyle")

    # Search box (like Sensors page): filters each card's currently active tab by label/value -
    # every card keeps its own $renderTab closure, so the search box just re-invokes whichever tab
    # is currently active on each card.
    $searchState = @{ Search = "" }
    $cardRenderers = New-Object System.Collections.Generic.List[object]
    $searchBox = Add-GuiPageSearchHeader -SubtitleText (T "Detected adapters") -Placeholder (T "Search spec or sensor...")
    $searchBox.Add_TextChanged({
        $searchState.Search = $searchBox.Text.Trim()
        foreach ($r in $cardRenderers) { & $r }
    }.GetNewClosure())

    foreach ($g in $gpus) {
        $nvmlHandle = [IntPtr]::Zero
        if ($nvmlOk -and $g.PNPDeviceID -match "VEN_10DE&DEV_([0-9A-Fa-f]{4})") {
            $nvmlHandle = Get-NvmlHandleForDevice -DeviceHex $Matches[1]
        }
        $dxgiAdapter = Get-DxgiAdapterForDevice -PNPDeviceID $g.PNPDeviceID
        $adlIndex = $null
        if ($adlOk -and $g.PNPDeviceID -match "VEN_1002&DEV_([0-9A-Fa-f]{4})") {
            $adlIndex = Get-AdlAdapterIndexForDevice -DeviceHex $Matches[1]
        }

        $card = New-Object System.Windows.Controls.Border
        if ($cardStyle) { $card.Style = $cardStyle }
        $card.Padding = "12"

        $stack = New-Object System.Windows.Controls.StackPanel
        $titlePanel = New-Object System.Windows.Controls.StackPanel
        Add-GuiIconTitle $titlePanel "&#xE7F4;" $g.Name "Brush_AccentWarm" -AccentTitle
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
            $rows = if ($activeTab.Name -eq "Info") { Get-GpuInfoRows $g $nvmlHandle $dxgiAdapter } else { Get-GpuSensorRows -GpuName $g.Name -LhmOk $lhmOk -NvmlHandle $nvmlHandle -AdlAdapterIndex $adlIndex }
            $rows = Get-GuiFilteredInfoRows -Rows $rows -Search $searchState.Search
            foreach ($row in $rows) { Add-GuiInfoRowItem $detailPanel $row }
        }.GetNewClosure()
        $cardRenderers.Add({ & $renderTab $null }.GetNewClosure()) | Out-Null

        foreach ($tabName in @("Info", "Sensors")) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Content = T $tabName
            $btn.Style = $normalStyle
            $btn.Add_Click({ & $renderTab $tabName }.GetNewClosure())
            $tabButtons[$tabName] = $btn
            $pillsStack.AddChild($btn)
        }

        & $renderTab "Info"
    }

    # Keep each card's active tab (Info or Sensors) updating in real time while this page stays
    # open - stopped by Clear-GuiContent as soon as the user navigates away (see
    # $Script:LivePageTimer). Reuses $cardRenderers (re-invokes whichever tab is currently active
    # per card, respecting the search filter), same callback the search box already uses.
    $Script:LivePageTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Script:LivePageTimer.Interval = [TimeSpan]::FromSeconds(2)
    $Script:LivePageTimer.Add_Tick({
        foreach ($r in $cardRenderers) { & $r }
    }.GetNewClosure())
    $Script:LivePageTimer.Start()
}
