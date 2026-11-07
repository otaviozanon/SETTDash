
# ================================================
#region CLEAN TAB - STARTUP MANAGER (list/enable/disable/delete)
# ================================================
# Recreates Kudu's "Startup Manager" (startup-manager.ipc.ts) as native PowerShell:
# lists Run/RunOnce (HKCU+HKLM), Startup folder shortcuts, logon-trigger tasks, and all
# other Task Scheduler entries; supports Enable/Disable (registry delete + re-add from
# stored command) and Delete. Used by: Sidebar\Pages\Startup.ps1 (all 4 categories).

$Script:StartupDisabledPath = Join-Path $env:LOCALAPPDATA "SETTDash\Backups\disabled-startups.json"

# Reads the persisted "disabled startup entries" cache and returns only well-formed records
# (Name + Source present). Any malformed/legacy entry (e.g. from an older build) is silently
# dropped here AND the cleaned-up list is written back, so corruption self-heals on first read
# instead of crashing every caller that touches .Name/.Source on it.
function Get-StartupDisabledEntries {
    if (-not (Test-Path $Script:StartupDisabledPath)) { return @() }
    $raw = @()
    try {
        # ConvertFrom-Json in PowerShell 5.1 emits a top-level JSON array as ONE object, so the
        # result is assigned first and only then wrapped in @(): writing
        # @(Get-Content -Raw | ConvertFrom-Json) produces a single-element array whose only
        # element is the whole record list, every property check below then sees an array instead
        # of a record, and the entire cache is silently dropped (and rewritten empty).
        $parsed = ConvertFrom-Json -InputObject (Get-Content $Script:StartupDisabledPath -Raw)
        if ($null -ne $parsed) { $raw = @($parsed) }
    } catch { $raw = @() }
    $clean = @($raw | Where-Object { (Get-SafeProp $_ 'Name') -and (Get-SafeProp $_ 'Source') })
    if ($clean.Count -ne $raw.Count) { Set-StartupDisabledEntries -Entries $clean }
    return $clean
}

function Set-StartupDisabledEntries {
    param([array]$Entries)
    $dir = Split-Path $Script:StartupDisabledPath -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    # -InputObject (not the pipeline): the cache must always be a JSON array, even with 0 or 1
    # entries, so the reader above always sees a list.
    $json = ConvertTo-Json -InputObject @($Entries) -Depth 4
    Set-Content -Path $Script:StartupDisabledPath -Value $json -Encoding UTF8
}

# Returns pscustomobjects: Label, Detail, Selected(=enabled), Name, Command, Location, Source
# Source: 'registry-hkcu' | 'registry-hklm' | 'startup-folder' | 'task-scheduler'
function Get-StartupManagerItems {
    return @(Get-StartupRegistryItems) + @(Get-StartupFolderItems) + @(Get-StartupLogonTaskItems)
}

# Category 1 (Startup page): MSConfig-style Run/RunOnce registry entries (HKCU+HKLM).
function Get-StartupRegistryItems {
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
    # Merge in registry-based entries the user disabled previously (Remove-ItemProperty took
    # them out of the live Run key, so they would otherwise vanish from the list entirely).
    # They are re-shown here as unchecked/disabled rows, using the command saved at disable
    # time, so the user can still find and re-enable them on a later scan/session.
    foreach ($stored in (Get-StartupDisabledEntries)) {
        $name = Get-SafeProp $stored 'Name'
        $source = Get-SafeProp $stored 'Source'
        if (-not $name -or -not $source -or $source -ne 'registry-hkcu' -and $source -ne 'registry-hklm') { continue }
        $already = $items | Where-Object { $_.Name -eq $name -and $_.Source -eq $source }
        if ($already) { continue }
        $items += [pscustomobject]@{
            Label=$name; Detail=(Get-SafeProp $stored 'Command'); Selected=$false
            Name=$name; Command=(Get-SafeProp $stored 'Command'); Location=(Get-SafeProp $stored 'Location'); Source=$source
        }
    }
    return $items
}

# Category 2 (Startup page): Startup folder shortcuts (current user).
function Get-StartupFolderItems {
    $items = @()
    $startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    if (Test-Path $startupDir) {
        Get-ChildItem $startupDir -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $items += [pscustomobject]@{
                Label=$_.BaseName; Detail=$_.FullName; Selected=$false
                Name=$_.Name; Command=$_.FullName; Location=$startupDir; Source='startup-folder'
            }
        }
    }
    return $items
}

# Category 3 (Startup page): Task Scheduler entries with a logon or boot trigger (excludes
# Microsoft's own built-in tasks). Boot trigger is included alongside logon trigger to match
# what Sysinternals Autoruns' "Logon" tab and the original optimizerDuck's
# ScheduledTaskService.GetStartupTasks() consider "startup-related" (HasLogonTrigger ||
# HasBootTrigger), instead of only logon-trigger tasks. Deliberately a plain foreach over the
# task list (NOT `Get-ScheduledTask | ForEach-Object`): driving nested Where-Object pipelines
# from inside a pipeline stage made every strict-mode property error (below) blow the stack -
# the process died with "a new guard page for the stack cannot be created" and no managed
# handler could run, so no error report was written. Triggers/actions are read through
# Get-SafeProp because some of them really do not expose CimClass/Execute, and a missing
# property must be "skip", not an exception.
function Get-StartupLogonTaskItems {
    $items = @()
    try {
        foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            $hasLogonOrBoot = $false
            foreach ($trigger in @(Get-SafeProp $task 'Triggers')) {
                $cim = Get-SafeProp $trigger 'CimClass'
                $cimName = if ($cim) { Get-SafeProp $cim 'CimClassName' } else { $null }
                if ($cimName -eq 'MSFT_TaskLogonTrigger' -or $cimName -eq 'MSFT_TaskBootTrigger') { $hasLogonOrBoot = $true; break }
            }
            if (-not $hasLogonOrBoot) { continue }
            if ((Get-SafeProp $task 'TaskPath') -match '^\\Microsoft\\') { continue }

            $action = $null
            foreach ($candidate in @(Get-SafeProp $task 'Actions')) {
                $cim = Get-SafeProp $candidate 'CimClass'
                if ($cim -and (Get-SafeProp $cim 'CimClassName') -eq 'MSFT_TaskExecAction') { $action = $candidate; break }
            }
            if (-not $action) { continue }

            $execute = Get-SafeProp $action 'Execute'
            $arguments = Get-SafeProp $action 'Arguments'
            $cmd = if ($arguments) { "$execute $arguments" } else { $execute }
            $state = Get-SafeProp $task 'State'
            $items += [pscustomobject]@{
                Label=(Get-SafeProp $task 'TaskName'); Detail=$cmd; Selected=($state -eq 'Ready' -or $state -eq 'Running')
                Name=(Get-SafeProp $task 'TaskName'); Command=$cmd; Location='Task Scheduler'; Source='task-scheduler'
            }
        }
    } catch { }
    return $items
}

# Category 4 (Startup page): ALL scheduled tasks (not just logon-trigger ones). By default
# Microsoft's own built-in tasks (\Microsoft\...) are excluded; -IncludeMicrosoft shows them too
# (wired to the page's show/hide toggle).
# Returns pscustomobjects: Label, Detail, Selected(=enabled), Name, Command, Location, Source='task-scheduler'.
function Get-ScheduledTaskItems {
    param([switch]$IncludeMicrosoft)
    $items = @()
    try {
        foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            if (-not $IncludeMicrosoft -and (Get-SafeProp $task 'TaskPath') -match '^\\Microsoft\\') { continue }

            $action = $null
            foreach ($candidate in @(Get-SafeProp $task 'Actions')) {
                $cim = Get-SafeProp $candidate 'CimClass'
                if ($cim -and (Get-SafeProp $cim 'CimClassName') -eq 'MSFT_TaskExecAction') { $action = $candidate; break }
            }
            $execute = if ($action) { Get-SafeProp $action 'Execute' } else { '' }
            $arguments = if ($action) { Get-SafeProp $action 'Arguments' } else { '' }
            $cmd = if ($arguments) { "$execute $arguments" } else { $execute }
            $taskPath = Get-SafeProp $task 'TaskPath'
            $taskName = Get-SafeProp $task 'TaskName'
            $state = Get-SafeProp $task 'State'
            $items += [pscustomobject]@{
                Label=$taskName; Detail="$taskPath  |  $cmd"; Selected=($state -eq 'Ready' -or $state -eq 'Running')
                Name=$taskName; Command=$cmd; Location=$taskPath; Source='task-scheduler'
            }
        }
    } catch { }
    return $items
}

# Toggles enabled/disabled for a single Scheduled Tasks page item (Task Scheduler only).
function Set-ScheduledTaskEnabled {
    param($Item, [bool]$Enabled)
    try {
        if ($Enabled) { Enable-ScheduledTask -TaskName $Item.Name -TaskPath $Item.Location -ErrorAction Stop | Out-Null }
        else { Disable-ScheduledTask -TaskName $Item.Name -TaskPath $Item.Location -ErrorAction Stop | Out-Null }
        return $true
    } catch {
        Write-GuiLog "Failed to toggle $($Item.Name): $_" "ERR"
        return $false
    }
}

# Permanently removes a scheduled task (Scheduled Tasks page).
function Remove-ScheduledTaskItem {
    param($Item)
    try {
        Unregister-ScheduledTask -TaskName $Item.Name -TaskPath $Item.Location -Confirm:$false -ErrorAction Stop
        return $true
    } catch {
        Write-GuiLog "Failed to delete $($Item.Name): $_" "ERR"
        return $false
    }
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
