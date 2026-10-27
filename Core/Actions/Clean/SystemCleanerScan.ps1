
# ================================================
#region CLEAN TAB - SYSTEM CLEANER (scan/apply)
# ================================================
# Recreates Kudu's "System Cleaner" categories (temp/cache/log locations) as a
# scan-then-select-then-clean workflow, mirroring file-utils.ts's category list.
# Used by: Sidebar\Pages\Clean.ps1

# Sums the size (bytes) of one or more paths (files or directories). Missing paths are 0.
function Get-CleanPathSize {
    param([string[]]$Paths)
    $total = 0
    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) { continue }
        $item = Get-Item -Path $p -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) { continue }
        if ($item.PSIsContainer) {
            # -File: PS 5.1's Measure-Object throws "Cannot process argument because the
            # value of argument 'Property' is not valid" when any pipeline object lacks
            # the -Property (e.g. DirectoryInfo, which has no Length). Only files feed it.
            $measured = Get-ChildItem -Path $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
            $sum = Get-SafeProp $measured 'Sum'
            if ($sum) { $total += $sum }
        } else {
            $total += $item.Length
        }
    }
    return $total
}

# Removes the contents of a path: directory contents if $Path is a folder, or the file itself.
function Remove-CleanPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $item = Get-Item -Path $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return }
    if ($item.PSIsContainer) {
        Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
    }
}

# Returns the category definitions scanned for the System Cleaner section.
# Each item: Key, Label, Detail, Paths (array), SizeBytes, Selected.
function Get-SystemCleanerItems {
    $defs = @(
        @{ Key='temp-user';   Label='User Temp Files';        Paths=@($env:TEMP) }
        @{ Key='temp-win';    Label='Windows Temp Files';      Paths=@((Join-Path $env:windir 'Temp')) }
        @{ Key='winupdate';   Label='Windows Update Cache';    Paths=@((Join-Path $env:windir 'SoftwareDistribution\Download')) }
        @{ Key='deliveryopt'; Label='Delivery Optimization';   Paths=@((Join-Path $env:windir 'SoftwareDistribution\DeliveryOptimization')) }
        @{ Key='prefetch';    Label='Prefetch Files';          Paths=@((Join-Path $env:windir 'Prefetch')) }
        @{ Key='memdumps';    Label='Memory Dumps';            Paths=@((Join-Path $env:windir 'Minidump'), (Join-Path $env:windir 'MEMORY.DMP')) }
        @{ Key='wer';         Label='Windows Error Reports';   Paths=@('C:\ProgramData\Microsoft\Windows\WER') }
        @{ Key='winlogs';     Label='Windows Log Files';       Paths=@((Join-Path $env:windir 'Logs')) }
        @{ Key='thumbcache';  Label='Thumbnail Cache';         Paths=@((Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer')) }
        @{ Key='shadercache'; Label='Shader Cache';            Paths=@((Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'), (Join-Path $env:LOCALAPPDATA 'D3DSCache')) }
        @{ Key='chromecache'; Label='Google Chrome Cache';     Paths=@((Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Cache')) }
        @{ Key='edgecache';   Label='Microsoft Edge Cache';    Paths=@((Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Cache')) }
        @{ Key='firefoxcache';Label='Firefox Cache';           Paths=@((Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles')) }
        @{ Key='recyclebin';  Label='Recycle Bin';             Paths=@('C:\$Recycle.Bin') }
    )
    $items = @()
    foreach ($d in $defs) {
        $size = Get-CleanPathSize -Paths $d.Paths
        $items += [pscustomobject]@{
            Key       = $d.Key
            Label     = $d.Label
            Detail    = [string]$d.Paths[0]
            SizeText  = Format-ByteSize $size
            Paths     = $d.Paths
            SizeBytes = $size
            Selected  = $true
        }
    }
    return @($items | Sort-Object -Property SizeBytes -Descending)
}

# Cleans the given System Cleaner items (array of the objects returned by Get-SystemCleanerItems).
function Invoke-SystemCleanerClean {
    param([array]$Items)
    $total = $Items.Count
    $cleaned = 0; $freed = 0
    for ($i = 0; $i -lt $total; $i++) {
        $it = $Items[$i]
        Set-GuiProgress ([math]::Round(($i+1)/[math]::Max($total,1)*100)) "Cleaning: $($it.Label)"
        try {
            foreach ($p in $it.Paths) { Remove-CleanPath -Path $p }
            $freed += $it.SizeBytes
            $cleaned++
            Write-GuiLog "$($it.Label) cleaned" "OK"
        } catch {
            Write-GuiLog "Failed to clean $($it.Label): $_" "ERR"
        }
    }
    Set-GuiProgress 0
    Write-GuiLog ("System Cleaner: {0}/{1} categories cleaned (~{2} freed)" -f $cleaned, $total, (Format-ByteSize $freed)) "OK"
}
#endregion
