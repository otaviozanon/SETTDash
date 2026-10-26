
# ================================================
#region SYSTEM INFO
# ================================================
# Used by: Home (specs panel), Show-SystemInfoPopup, and startup wiring
function Get-SystemInfo {
    param([switch]$Force)
    if (-not $Force -and $Script:CachedSystemInfo) {
        return $Script:CachedSystemInfo
    }
    Write-GuiLog "Gathering system information..." "STEP"
    $info = @{}
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $info.CPUName = $cpu.Name.Trim()
        $info.CPUPhysicalCores = $cpu.NumberOfCores
        $info.CPULogicalCores = $cpu.NumberOfLogicalProcessors
        Write-GuiLog "CPU: $($info.CPUName)" "INFO"
    } catch { $info.CPUName = "Unknown"; Write-GuiLog "CPU detection failed" "WARN" }
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $info.RAMTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $info.RAMFreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $info.OSCaption = $os.Caption
        $info.OSBuild = $os.BuildNumber
        Write-GuiLog "RAM: $($info.RAMTotalGB) GB total | $($info.RAMFreeGB) GB free" "INFO"
        Write-GuiLog "OS: $($info.OSCaption) (Build $($info.OSBuild))" "INFO"
    } catch { Write-GuiLog "RAM/OS detection failed" "WARN" }
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        if ($disk -and $disk.Size) {
            $info.DiskTotalGB = [math]::Round($disk.Size / 1GB, 1)
            $info.DiskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
            Write-GuiLog "HD: $($info.DiskTotalGB) GB total | $($info.DiskFreeGB) GB free" "INFO"
        }
    } catch { Write-GuiLog "HD detection failed" "WARN" }
    try {
        # Exclude virtual/remote/basic display adapters (e.g. "Windows Video", "Microsoft Basic Display Adapter", RDP virtual displays)
        $allGpus = @(Get-CimInstance Win32_VideoController)
        $gpus = @($allGpus | Where-Object {
            $_.Name -and
            $_.Name -notmatch "Microsoft Basic|Remote Display|Virtual|Meta Virtual Monitor|Citrix|VMware|Windows Video"
        })
        # Fallback: if filtering removed everything, use the unfiltered list
        if (-not $gpus -or $gpus.Count -eq 0) { $gpus = $allGpus }

        if ($gpus -and $gpus.Count -gt 0) {
            $gpuEntries = @()
            $vendors = @()
            foreach ($g in $gpus) {
                $name = $g.Name.Trim()
                $nameLow = $name.ToLower()
                if ($nameLow -match "nvidia") { $vendor = "NVIDIA" }
                elseif ($nameLow -match "amd|radeon") { $vendor = "AMD" }
                elseif ($nameLow -match "intel") { $vendor = "Intel" }
                else { $vendor = "Unknown" }
                $vendors += $vendor
                $vramGB = if ($g.AdapterRAM) { [math]::Round($g.AdapterRAM / 1GB, 1) } else { 0 }
                $gpuEntries += [PSCustomObject]@{ Vendor = $vendor; Name = $name; VRAM = $vramGB }
                Write-GuiLog "GPU detected: $vendor - $name ($vramGB GB VRAM)" "INFO"
            }
            $info.GPUs = $gpuEntries
            $info.GPUVendor = ($vendors | Select-Object -Unique) -join " / "
            $info.GPUName = ($gpuEntries | ForEach-Object { $_.Name }) -join ", "
            $info.GPUVRAM = ($gpuEntries | Measure-Object -Property VRAM -Maximum).Maximum
        } else {
            $info.GPUs = @()
            $info.GPUVendor = "Unknown"
            $info.GPUName = "Unknown"
            $info.GPUVRAM = 0
            Write-GuiLog "No GPU detected" "WARN"
        }
    } catch {
        $info.GPUs = @()
        $info.GPUVendor = "Unknown"
        $info.GPUName = "Unknown"
        $info.GPUVRAM = 0
        Write-GuiLog "GPU detection failed" "WARN"
    }
    $Script:CachedSystemInfo = $info
    return $info
}
#endregion

# ================================================
#region SYSTEM INFO POPUP
# ================================================
# Used by: (currently not wired to any page/button - orphan helper, available for future use)
function Show-SystemInfoPopup {
    Write-GuiLog "Gathering system information..." "STEP"
    $info = Get-SystemInfo
    $msg = @"
=== SYSTEM INFORMATION ===

CPU    : $($info.CPUName)
Cores  : $($info.CPUPhysicalCores) physical / $($info.CPULogicalCores) logical
RAM    : $($info.RAMTotalGB) GB total / $($info.RAMFreeGB) GB free
OS     : $($info.OSCaption) (Build $($info.OSBuild))
GPU    : $($info.GPUVendor) - $($info.GPUName) ($($info.GPUVRAM) GB VRAM)
"@
    Write-GuiLog $msg "INFO"
    Write-GuiLog "System info gathered successfully" "OK"
}
#endregion
