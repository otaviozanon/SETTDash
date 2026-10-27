
# ================================================
#region CLEAN TAB - STARTUP MANAGER (list/enable/disable/delete)
# ================================================
# Recreates Kudu's "Startup Manager" (startup-manager.ipc.ts) as native PowerShell:
# lists Run/RunOnce (HKCU+HKLM), Startup folder shortcuts, and Task Scheduler logon-trigger
# tasks; supports Enable/Disable (registry delete + re-add from stored command) and Delete.
# Used by: Sidebar\Pages\Clean.ps1

$Script:StartupDisabledPath = Join-Path $env:LOCALAPPDATA "SETTDash\Backups\disabled-startups.json"

# Reads the persisted "disabled startup entries" cache and returns only well-formed records
# (Name + Source present). Any malformed/legacy entry (e.g. from an older build) is silently
# dropped here AND the cleaned-up list is written back, so corruption self-heals on first read
# instead of crashing every caller that touches .Name/.Source on it.
function Get-StartupDisabledEntries {
    if (-not (Test-Path $Script:StartupDisabledPath)) { return @() }
    $raw = $null
    try { $raw = @(Get-Content $Script:StartupDisabledPath -Raw | ConvertFrom-Json) } catch { $raw = @() }
    $clean = @($raw | Where-Object { (Get-SafeProp $_ 'Name') -and (Get-SafeProp $_ 'Source') })
    if ($clean.Count -ne $raw.Count) { Set-StartupDisabledEntries -Entries $clean }
    return $clean
}

function Set-StartupDisabledEntries {
    param([array]$Entries)
    $dir = Split-Path $Script:StartupDisabledPath -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $Entries | ConvertTo-Json -Depth 4 | Set-Content -Path $Script:StartupDisabledPath -Encoding UTF8
}

# Returns pscustomobjects: Label, Detail, Selected(=enabled), Name, Command, Location, Source
# Source: 'registry-hkcu' | 'registry-hklm' | 'startup-folder' | 'task-scheduler'
function Get-StartupManagerItems {
    $items = @()

    $runKeys = @(
        @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Source='registry-hkcu' }
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Source='registry-hklm' }
        @{ Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Source='registry-hklm' }
    )
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk.Path)) { continue }
        $props = Get-ItemProperty $rk.Path -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $items += [pscustomobject]@{
                Label=$_.Name; Detail=[string]$_.Value; Selected=$true
                Name=$_.Name; Command=[string]$_.Value; Location=$rk.Path; Source=$rk.Source
            }
        }
    }

    $startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    if (Test-Path $startupDir) {
        Get-ChildItem $startupDir -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $items += [pscustomobject]@{
                Label=$_.BaseName; Detail=$_.FullName; Selected=$true
                Name=$_.Name; Command=$_.FullName; Location=$startupDir; Source='startup-folder'
            }
        }
    }

    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
            $task = $_
            $hasLogon = $task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' }
            if ($hasLogon -and $task.TaskPath -notmatch '^\\Microsoft\\') {
                $action = $task.Actions | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskExecAction' } | Select-Object -First 1
                if ($action) {
                    $cmd = if ($action.Arguments) { "$($action.Execute) $($action.Arguments)" } else { $action.Execute }
                    $items += [pscustomobject]@{
                        Label=$task.TaskName; Detail=$cmd; Selected=($task.State -eq 'Ready' -or $task.State -eq 'Running')
                        Name=$task.TaskName; Command=$cmd; Location='Task Scheduler'; Source='task-scheduler'
                    }
                }
            }
        }
    } catch { }

    # Merge in registry-based entries the user disabled previously (Remove-ItemProperty took
    # them out of the live Run key, so they would otherwise vanish from the list entirely).
    # They are re-shown here as unchecked/disabled rows, using the command saved at disable
    # time, so the user can still find and re-enable them on a later scan/session.
    foreach ($stored in (Get-StartupDisabledEntries)) {
        $name = Get-SafeProp $stored 'Name'
        $source = Get-SafeProp $stored 'Source'
        if (-not $name -or -not $source -or $source -eq 'task-scheduler' -or $source -eq 'startup-folder') { continue }
        $already = $items | Where-Object { $_.Name -eq $name -and $_.Source -eq $source }
        if ($already) { continue }
        $items += [pscustomobject]@{
            Label=$name; Detail=(Get-SafeProp $stored 'Command'); Selected=$false
            Name=$name; Command=(Get-SafeProp $stored 'Command'); Location=(Get-SafeProp $stored 'Location'); Source=$source
        }
    }

    return $items
}

# Toggles enabled/disabled for a single startup item. $Enabled=$false disables.
function Set-StartupItemEnabled {
    param($Item, [bool]$Enabled)
    try {
        if ($Item.Source -eq 'task-scheduler') {
            if ($Enabled) { Enable-ScheduledTask -TaskName $Item.Name -ErrorAction Stop | Out-Null }
            else { Disable-ScheduledTask -TaskName $Item.Name -ErrorAction Stop | Out-Null }
            return $true
        }
        if ($Item.Source -eq 'startup-folder') {
            Write-GuiLog "Startup folder items cannot be disabled, only deleted." "WARN"
            return $false
        }
        if (-not $Enabled) {
            Remove-ItemProperty -Path $Item.Location -Name $Item.Name -Force -ErrorAction SilentlyContinue
            $entries = @(Get-StartupDisabledEntries | Where-Object { -not ((Get-SafeProp $_ 'Name') -eq $Item.Name -and (Get-SafeProp $_ 'Source') -eq $Item.Source) })
            $entries += [pscustomobject]@{ Name=$Item.Name; Command=$Item.Command; Location=$Item.Location; Source=$Item.Source }
            Set-StartupDisabledEntries -Entries $entries
        } else {
            $stored = Get-StartupDisabledEntries | Where-Object { (Get-SafeProp $_ 'Name') -eq $Item.Name -and (Get-SafeProp $_ 'Source') -eq $Item.Source } | Select-Object -First 1
            $cmd = if ($stored) { Get-SafeProp $stored 'Command' } else { $Item.Command }
            if (-not $cmd) { $cmd = $Item.Command }
            New-ItemProperty -Path $Item.Location -Name $Item.Name -Value $cmd -PropertyType String -Force -ErrorAction Stop | Out-Null
            $entries = @(Get-StartupDisabledEntries | Where-Object { -not ((Get-SafeProp $_ 'Name') -eq $Item.Name -and (Get-SafeProp $_ 'Source') -eq $Item.Source) })
            Set-StartupDisabledEntries -Entries $entries
        }
        return $true
    } catch {
        Write-GuiLog "Failed to toggle $($Item.Name): $_" "ERR"
        return $false
    }
}

# Permanently removes a startup item (registry value, Startup folder shortcut, or scheduled task).
function Remove-StartupItem {
    param($Item)
    try {
        switch ($Item.Source) {
            'task-scheduler' { Unregister-ScheduledTask -TaskName $Item.Name -Confirm:$false -ErrorAction Stop }
            'startup-folder' { Remove-Item -Path $Item.Command -Force -ErrorAction Stop }
            default { Remove-ItemProperty -Path $Item.Location -Name $Item.Name -Force -ErrorAction SilentlyContinue }
        }
        $entries = @(Get-StartupDisabledEntries | Where-Object { -not ((Get-SafeProp $_ 'Name') -eq $Item.Name -and (Get-SafeProp $_ 'Source') -eq $Item.Source) })
        Set-StartupDisabledEntries -Entries $entries
        return $true
    } catch {
        Write-GuiLog "Failed to delete $($Item.Name): $_" "ERR"
        return $false
    }
}
#endregion
