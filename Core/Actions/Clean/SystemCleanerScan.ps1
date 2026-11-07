
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

# Empties a Recycle Bin drive through the shell API. Deleting C:\$Recycle.Bin\* directly only works
# when the ACL allows it and fails silently otherwise (the bin stays full while the log claims it
# was cleaned); Clear-RecycleBin reports a real error and refreshes the shell. Returns the size
# still present afterwards (0 when the bin is really empty).
function Clear-CleanRecycleBin {
    param([string]$Path)
    $drive = $null
    if ($Path -match '^([A-Za-z]):') { $drive = $Matches[1] }
    if ($drive) {
        try { Clear-RecycleBin -DriveLetter $drive -Force -ErrorAction Stop }
        catch {
            # "The Recycle Bin is already empty" is success for our purposes, not a failure.
            if ($_.Exception.Message -notmatch 'empty') { Write-GuiLog "Recycle Bin ($drive`:): $($_.Exception.Message)" "WARN" }
        }
    }
    return (Get-CleanPathSize -Paths @($Path))
}

# Returns the category definitions scanned for the System Cleaner section.
# Each item: Key, Label, Detail, Paths (array), SizeBytes, Selected.
# -SkipSize skips the (expensive) recursive size walk - used by Full Cleanup, which only needs
# the paths, not the byte totals.
function Get-SystemCleanerItems {
    param([switch]$SkipSize)
    $defs = @(
        @{ Key='temp-user';   Label='User Temp Files';        Paths=@($env:TEMP) }
        @{ Key='temp-win';    Label='Windows Temp Files';      Paths=@((Join-Path $env:windir 'Temp')) }
        @{ Key='winupdate';   Label='Windows Update Cache';    Paths=@((Join-Path $env:windir 'SoftwareDistribution\Download')) }
        @{ Key='deliveryopt'; Label='Delivery Optimization';   Paths=@((Join-Path $env:windir 'SoftwareDistribution\DeliveryOptimization')) }
        @{ Key='prefetch';    Label='Prefetch Files';          Paths=@((Join-Path $env:windir 'Prefetch')) }
        @{ Key='memdumps';    Label='Memory Dumps';            Paths=@((Join-Path $env:windir 'Minidump'), (Join-Path $env:windir 'MEMORY.DMP')) }
        @{ Key='wer';         Label='Windows Error Reports';   Paths=@((Join-Path $env:ProgramData 'Microsoft\Windows\WER')) }
        @{ Key='winlogs';     Label='Windows Log Files';       Paths=@((Join-Path $env:windir 'Logs')) }
        @{ Key='thumbcache';  Label='Thumbnail Cache';         Paths=@((Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer')) }
        @{ Key='shadercache'; Label='Shader Cache';            Paths=@((Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'), (Join-Path $env:LOCALAPPDATA 'D3DSCache')) }
        @{ Key='chromecache'; Label='Google Chrome Cache';     Paths=@((Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\Cache')) }
        @{ Key='edgecache';   Label='Microsoft Edge Cache';    Paths=@((Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Cache')) }
        @{ Key='firefoxcache';Label='Firefox Cache';           Paths=@((Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles')) }
        @{ Key='recyclebin';  Label='Recycle Bin';             Paths=@((Join-Path $env:SystemDrive '$Recycle.Bin')) }
    )
    $items = @()
    foreach ($d in $defs) {
        $size = if ($SkipSize) { 0 } else { Get-CleanPathSize -Paths $d.Paths }
        $items += [pscustomobject]@{
            Key       = $d.Key
            Label     = $d.Label
            Detail    = [string]$d.Paths[0]
            SizeText  = Format-ByteSize $size
            Paths     = $d.Paths
            SizeBytes = $size
            Selected  = $false
        }
    }
    return @($items | Sort-Object -Property SizeBytes -Descending)
}

# Cleans the given System Cleaner items (array of the objects returned by Get-SystemCleanerItems).
# Reports what was ACTUALLY removed: the size is measured after the attempt, so a file locked by a
# running app shows up as "remains (in use)" instead of being counted as freed just because the
# category was selected. Only fully empty categories count as "cleaned".
function Invoke-SystemCleanerClean {
    param([array]$Items)
    if (-not $Items -or $Items.Count -eq 0) { Write-GuiLog "No items selected." "WARN"; return }
    $total = $Items.Count
    $cleaned = 0; $freed = 0.0; $locked = 0.0
    for ($i = 0; $i -lt $total; $i++) {
        $it = $Items[$i]
        Set-GuiProgress ([math]::Round(($i+1)/[math]::Max($total,1)*100)) "Cleaning: $($it.Label)"
        try {
            $paths = @(Get-SafeProp $it 'Paths')
            # Before: the size the scan already reported (fresh in the scan -> clean flow). Items
            # built with -SkipSize (Full Cleanup) have none, so they are measured right here.
            $before = [double](Get-SafeProp $it 'SizeBytes')
            if ($before -le 0) { $before = [double](Get-CleanPathSize -Paths $paths) }

            if ((Get-SafeProp $it 'Key') -eq 'recyclebin') {
                $binPath = if ($paths.Count -gt 0) { $paths[0] } else { "" }
                $after = [double](Clear-CleanRecycleBin -Path $binPath)
            } else {
                foreach ($p in $paths) { Remove-CleanPath -Path $p }
                $after = [double](Get-CleanPathSize -Paths $paths)
            }

            $delta = $before - $after
            if ($delta -lt 0) { $delta = 0 }
            $freed += $delta
            $freedText = if ($delta -gt 0) { Format-ByteSize $delta } else { "0 B" }
            if ($after -gt 0) {
                $locked += $after
                Write-GuiLog ("{0}: {1} freed, {2} remains (in use)" -f $it.Label, $freedText, (Format-ByteSize $after)) "WARN"
            } else {
                $cleaned++
                Write-GuiLog ("{0} cleaned ({1} freed)" -f $it.Label, $freedText) "OK"
            }
        } catch {
            Write-GuiLog "Failed to clean $($it.Label): $_" "ERR"
        }
    }
    Set-GuiProgress 0
    $freedSummary = if ($freed -gt 0) { Format-ByteSize $freed } else { "0 B" }
    if ($locked -gt 0) {
        Write-GuiLog ("System Cleaner: {0}/{1} categories fully cleaned, {2} freed, {3} still in use by running apps" -f $cleaned, $total, $freedSummary, (Format-ByteSize $locked)) "WARN"
    } else {
        Write-GuiLog ("System Cleaner: {0}/{1} categories cleaned, {2} freed" -f $cleaned, $total, $freedSummary) "OK"
    }
}
#endregion
