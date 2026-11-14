
# ================================================
#region CLEAN TAB - STARTUP MANAGER (list/enable/disable/delete)
# ================================================
# Mirrors the four places a program or service can be made to start with Windows:
#   1. Registry (MSConfig/Task Manager Startup): Run/RunOnce values + StartupApproved state.
#   2. Startup folders: user (%APPDATA%) and all users (%ProgramData%).
#   3. Services: Windows services, non-Microsoft by default (MSConfig's Services tab).
#   4. Scheduled Items: Task Scheduler.
# Used by: Sidebar\Pages\Startup.ps1 (all 4 categories).

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

# Returns the Task Manager/msconfig enabled state for a Run or Startup folder entry.
# StartupApproved values are 12 bytes; an even first byte (usually 0x02) means enabled, an odd one
# (usually 0x03) means disabled. Missing/empty value means enabled. The remaining bytes are a
# timestamp written by Task Manager and do not matter here.
function Get-StartupApprovedEnabled {
    param([string]$Path, [string]$Name)
    if (-not $Path -or -not $Name) { return $true }
    $props = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
    $value = Get-SafeProp $props $Name
    if ($null -eq $value) { return $true }
    $bytes = @($value)
    if ($bytes.Count -eq 0) { return $true }
    return (([int]$bytes[0]) % 2) -eq 0
}

# Writes the Task Manager/msconfig enabled state without touching the Run value or the shortcut,
# so disabling is reversible and shows up in Task Manager too. 12 bytes like Windows writes.
function Set-StartupApprovedEnabled {
    param([string]$Path, [string]$Name, [bool]$Enabled)
    if (-not $Path -or -not $Name) { return $false }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    $bytes = New-Object 'byte[]' 12
    $bytes[0] = if ($Enabled) { [byte]2 } else { [byte]3 }
    New-ItemProperty -Path $Path -Name $Name -Value $bytes -PropertyType Binary -Force -ErrorAction Stop | Out-Null
    return $true
}

# Returns pscustomobjects: Label, Detail, Selected(=enabled), Name, Command, Location, Source,
# Publisher. Source: 'registry-hkcu' | 'registry-hklm' | 'startup-folder'.
function Get-StartupManagerItems {
    return @(Get-StartupRegistryItems) + @(Get-StartupFolderItems)
}

# Resolves the executable a startup command runs. Returns '' when the command is not a readable
# .exe (rundll32, explorer, a shortcut path, ...).
function Get-StartupCommandExecutable {
    param([string]$Command)
    if (-not $Command) { return '' }
    $text = [Environment]::ExpandEnvironmentVariables($Command.Trim())
    if ($text.StartsWith('"')) {
        $end = $text.IndexOf('"', 1)
        if ($end -gt 1) { return $text.Substring(1, $end - 1) }
    }
    if ($text -match '^(?<exe>[^\s]+?\.exe)(?=\s|$)') { return $Matches.exe }
    return ''
}

# Signer company of the executable behind a startup command ('Unsigned' when it has no valid
# Authenticode signature, '' when there is nothing readable to check). $Cache keeps one signature
# check per executable for the whole scan.
function Get-StartupPublisher {
    param([string]$Command, [hashtable]$Cache)
    $exe = Get-StartupCommandExecutable -Command $Command
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { return '' }
    $key = $exe.ToLowerInvariant()
    if ($Cache -and $Cache.ContainsKey($key)) { return $Cache[$key] }
    $publisher = ''
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $exe -ErrorAction Stop
        if ($sig.SignerCertificate -and $sig.SignerCertificate.Subject -match 'O=([^,]+)') {
            $publisher = $Matches[1].Trim()
        } else {
            $publisher = 'Unsigned'
        }
    } catch { $publisher = '' }
    if ($Cache) { $Cache[$key] = $publisher }
    return $publisher
}

# Startup folder entries are usually .lnk shortcuts, so $Path is the shortcut, not the executable.
function Get-StartupFolderPublisher {
    param([string]$Path, [hashtable]$Cache)
    if (-not $Path) { return '' }
    if ($Path -notmatch '\.lnk$') { return Get-StartupPublisher -Command $Path -Cache $Cache }
    try {
        $shell = New-Object -ComObject WScript.Shell
        try { $target = [string]$shell.CreateShortcut($Path).TargetPath }
        finally { if ($shell) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } }
        return Get-StartupPublisher -Command $target -Cache $Cache
    } catch { return '' }
}

# Category 1 (Startup page): MSConfig/Task Manager Run/RunOnce entries (HKCU+HKLM+32-bit view).
# The enabled flag comes from StartupApproved (the same store Task Manager's Startup tab writes),
# so disabling here and enabling in Task Manager (or vice versa) agree.
function Get-StartupRegistryItems {
    $items = @()
    $sigCache = @{}
    $runKeys = @(
        @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Source='registry-hkcu'; Approval='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Source='registry-hkcu'; Approval='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Source='registry-hklm'; Approval='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Source='registry-hklm'; Approval='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Source='registry-hklm'; Approval='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
        @{ Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Source='registry-hklm'; Approval='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
    )
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk.Path)) { continue }
        $props = Get-ItemProperty $rk.Path -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' -and $_.Name -ne '(default)' } | ForEach-Object {
            $cmd = [string]$_.Value
            $publisher = Get-StartupPublisher -Command $cmd -Cache $sigCache
            $pubText = if ($publisher) { $publisher } else { 'Unknown' }
            $scope = if ($rk.Source -eq 'registry-hkcu') { 'User' } else { 'Machine' }
            $items += [pscustomobject]@{
                Label=$_.Name; Detail="$cmd  |  Publisher: $pubText  |  $scope"
                Selected=(Get-StartupApprovedEnabled -Path $rk.Approval -Name $_.Name)
                Name=$_.Name; Command=$cmd; Location=$rk.Path; Source=$rk.Source
                ApprovalPath=$rk.Approval; Publisher=$publisher
            }
        }
    }
    # Merge in registry-based entries the user disabled with an older build (which removed the
    # value from the Run key). They are re-shown as unchecked rows using the saved command so the
    # user can still find and re-enable them; enabling writes the value back and clears the record.
    foreach ($stored in (Get-StartupDisabledEntries)) {
        $name = Get-SafeProp $stored 'Name'
        $source = Get-SafeProp $stored 'Source'
        if (-not $name -or -not $source -or $source -ne 'registry-hkcu' -and $source -ne 'registry-hklm') { continue }
        $already = $items | Where-Object { $_.Name -eq $name -and $_.Source -eq $source }
        if ($already) { continue }
        $cmd = [string](Get-SafeProp $stored 'Command')
        $publisher = Get-StartupPublisher -Command $cmd -Cache $sigCache
        $pubText = if ($publisher) { $publisher } else { 'Unknown' }
        $scope = if ($source -eq 'registry-hkcu') { 'User' } else { 'Machine' }
        $items += [pscustomobject]@{
            Label=$name; Detail="$cmd  |  Publisher: $pubText  |  $scope"; Selected=$false
            Name=$name; Command=$cmd; Location=(Get-SafeProp $stored 'Location'); Source=$source
            ApprovalPath=''; Publisher=$publisher
        }
    }
    return $items
}

# Category 2 (Startup page): user and all-users Startup folders. Same StartupApproved store as
# Task Manager's Startup tab, so a shortcut can be disabled without deleting it.
function Get-StartupFolderItems {
    $items = @()
    $sigCache = @{}
    $folders = @(
        @{ Path=(Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'); Approval='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
        @{ Path=(Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'); Approval='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
    )
    foreach ($folder in $folders) {
        if (-not $folder.Path -or -not (Test-Path $folder.Path)) { continue }
        Get-ChildItem $folder.Path -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer -and $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $publisher = Get-StartupFolderPublisher -Path $_.FullName -Cache $sigCache
            $pubText = if ($publisher) { $publisher } else { 'Unknown' }
            $scope = if ($folder.Approval -like 'HKCU:*') { 'User folder' } else { 'All users folder' }
            $items += [pscustomobject]@{
                Label=$_.BaseName; Detail="$($_.FullName)  |  Publisher: $pubText  |  $scope"
                Selected=(Get-StartupApprovedEnabled -Path $folder.Approval -Name $_.Name)
                Name=$_.Name; Command=$_.FullName; Location=$folder.Path; Source='startup-folder'
                ApprovalPath=$folder.Approval; Publisher=$publisher
            }
        }
    }
    return $items
}

# ---- Services (MSConfig "Services" tab) -------------------------------------------------------
# Lists Win32 services (not kernel drivers) from Win32_Service, so msconfig is not needed.
# Microsoft services are hidden by default (-IncludeMicrosoft shows them). "Microsoft" here means
# the service binary lives under the Windows directory, the same practical rule msconfig uses;
# checking the signature of every executable on each scan would be far slower.
# Toggle only changes the Start type in the registry (4 = Disabled). Like msconfig, disabling does
# not stop a service that is already running.

function Get-ServiceExecutablePath {
    param([string]$Path)
    if (-not $Path) { return '' }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path).TrimStart('"')
    $expanded = $expanded -replace '^\\\?\?\\', ''
    if ($expanded -match '^(?<exe>.+?\.exe)') { return $Matches.exe }
    return $expanded
}

# Persistent cache of "is this executable signed by Microsoft?" keyed by lower-case path. The
# file's size and last-write time validate an entry, so an updated binary is checked again. Without
# it every scan re-checked ~59 signatures (~2.8 s); with it a rescan is near-instant.
function Get-ServiceSignatureCachePath {
    $dir = Join-Path $env:LOCALAPPDATA 'SETTDash\runtime'
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    return (Join-Path $dir 'service-signatures.json')
}

function Read-ServiceSignatureCache {
    $cache = @{}
    try {
        $path = Get-ServiceSignatureCachePath
        if (-not (Test-Path $path)) { return $cache }
        $json = Get-Content -Path $path -Raw -ErrorAction Stop | ConvertFrom-Json
        if (-not $json) { return $cache }
        $json.PSObject.Properties | ForEach-Object {
            $cache[$_.Name] = @{
                Size = [long]$_.Value.Size
                Mtime = [long]$_.Value.Mtime
                Microsoft = [bool]$_.Value.Microsoft
            }
        }
    } catch { }
    return $cache
}

function Save-ServiceSignatureCache {
    param([hashtable]$Cache)
    if (-not $Cache) { return }
    try {
        $Cache | ConvertTo-Json -Depth 4 | Set-Content -Path (Get-ServiceSignatureCachePath) -Encoding UTF8
    } catch { }
}

# True when the service executable is signed by Microsoft - the same test MSConfig's
# "Hide all Microsoft services" uses. Falls back to the old "lives under Windows" rule when the
# binary cannot be read. $Cache is the persistent table above (one signature check per executable).
function Test-MicrosoftServicePath {
    param([string]$Path, [hashtable]$Cache)
    $exe = Get-ServiceExecutablePath -Path $Path
    if (-not $exe) { return $true }
    $key = $exe.ToLowerInvariant()
    $size = -1; $mtime = -1
    try {
        $file = Get-Item -LiteralPath $exe -ErrorAction Stop
        $size = [long]$file.Length
        $mtime = [long]$file.LastWriteTimeUtc.ToFileTimeUtc()
    } catch { }
    if ($Cache -and $Cache.ContainsKey($key)) {
        $entry = $Cache[$key]
        if ($size -ge 0 -and [long]$entry.Size -eq $size -and [long]$entry.Mtime -eq $mtime) {
            return [bool]$entry.Microsoft
        }
    }
    $isMicrosoft = $false
    try {
        $sig = Get-AuthenticodeSignature -FilePath $exe -ErrorAction Stop
        $isMicrosoft = ($null -ne $sig.SignerCertificate) -and ($sig.SignerCertificate.Subject -match 'O=Microsoft Corporation')
    } catch {
        $isMicrosoft = $exe -match '^[A-Za-z]:\\Windows\\'
    }
    if ($Cache) { $Cache[$key] = @{ Size = $size; Mtime = $mtime; Microsoft = $isMicrosoft } }
    return $isMicrosoft
}

# Category 4 (Startup page): Windows services, non-Microsoft by default.
function Get-ServiceItems {
    param([switch]$IncludeMicrosoft)
    $items = @()
    $sigCache = Read-ServiceSignatureCache
    try {
        foreach ($svc in @(Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue)) {
            $path = [string](Get-SafeProp $svc 'PathName')
            if (-not $IncludeMicrosoft -and (Test-MicrosoftServicePath -Path $path -Cache $sigCache)) { continue }
            $name = [string](Get-SafeProp $svc 'Name')
            if (-not $name) { continue }
            $display = [string](Get-SafeProp $svc 'DisplayName')
            if (-not $display) { $display = $name }
            $startMode = [string](Get-SafeProp $svc 'StartMode')
            $state = [string](Get-SafeProp $svc 'State')
            # 2 = Automatic, 3 = Manual. A service already disabled has no previous type to restore,
            # so enabling it falls back to Manual instead of surprising the user with Automatic.
            $previousStart = if ($startMode -eq 'Auto') { 2 } else { 3 }
            $items += [pscustomobject]@{
                Label=$display; Detail="$name  |  Start: $startMode  |  $state  |  $path"
                Selected=($startMode -ne 'Disabled')
                Name=$name; Command=$path; Location="HKLM:\SYSTEM\CurrentControlSet\Services\$name"
                PreviousStart=$previousStart; Source='service'
            }
        }
    } catch { Write-GuiLog ((T "Service scan failed: {0}") -f $_.Exception.Message) "ERR" }
    Save-ServiceSignatureCache -Cache $sigCache
    return $items
}

# Toggles a service Start type (MSConfig behavior: off = Disabled).
function Set-ServiceItemEnabled {
    param($Item, [bool]$Enabled)
    if (-not $Item) { return $false }
    try {
        $start = if ($Enabled) {
            $previous = Get-SafeProp $Item 'PreviousStart'
            if ($previous -eq 2 -or $previous -eq 3) { [int]$previous } else { 3 }
        } else { 4 }
        Set-ItemProperty -Path $Item.Location -Name 'Start' -Value $start -Type DWord -ErrorAction Stop
        return $true
    } catch {
        Write-GuiLog ((T "Failed to toggle {0}: {1}") -f (Get-SafeProp $Item 'Name'), $_) "ERR"
        return $false
    }
}

# Category 3 (Startup page): Task Scheduler items that do not belong to Windows.
# Microsoft's built-in tasks (\Microsoft\...) are never listed, so they can never be disabled or
# deleted from this page. There is no toggle: the filter is always on.
function Get-ScheduledTaskItems {
    $items = @()
    try {
        foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
            if ((Get-SafeProp $task 'TaskPath') -match '^\\Microsoft\\') { continue }

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
            # Run history is what tells whether a third-party task actually does anything.
            $lastRun = $null; $nextRun = $null; $lastResult = $null
            try {
                $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop
                $lastRun = Get-SafeProp $info 'LastRunTime'
                $nextRun = Get-SafeProp $info 'NextRunTime'
                $lastResult = Get-SafeProp $info 'LastTaskResult'
            } catch { }
            $lastText = if ($lastRun -is [datetime] -and $lastRun.Year -gt 1980) { $lastRun.ToString('yyyy-MM-dd HH:mm') } else { 'never' }
            $nextText = if ($nextRun -is [datetime] -and $nextRun.Year -gt 1980) { $nextRun.ToString('yyyy-MM-dd HH:mm') } else { 'never' }
            $resultText = if ($null -eq $lastResult) { '?' } else { [string]$lastResult }
            $items += [pscustomobject]@{
                Label=$taskName
                Detail="$taskPath  |  $cmd  |  Last: $lastText ($resultText)  |  Next: $nextText  |  $state"
                Selected=($state -eq 'Ready' -or $state -eq 'Running')
                Name=$taskName; Command=$cmd; Location=$taskPath; Source='task-scheduler'
                LastRun=$lastRun; NextRun=$nextRun; LastResult=$lastResult; State=$state
            }
        }
    } catch { Write-GuiLog ((T "Scheduled task scan failed: {0}") -f $_.Exception.Message) "ERR" }
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
        Write-GuiLog ((T "Failed to toggle {0}: {1}") -f $Item.Name, $_) "ERR"
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
        Write-GuiLog ((T "Failed to delete {0}: {1}") -f $Item.Name, $_) "ERR"
        return $false
    }
}

# Toggles enabled/disabled for a single startup item. $Enabled=$false disables.
function Set-StartupItemEnabled {
    param($Item, [bool]$Enabled)
    try {
        if ($Item.Source -eq 'task-scheduler') {
            if ($Enabled) { Enable-ScheduledTask -TaskName $Item.Name -TaskPath $Item.Location -ErrorAction Stop | Out-Null }
            else { Disable-ScheduledTask -TaskName $Item.Name -TaskPath $Item.Location -ErrorAction Stop | Out-Null }
            return $true
        }
        if ($Item.Source -eq 'service') {
            return Set-ServiceItemEnabled -Item $Item -Enabled $Enabled
        }
        if ((Get-SafeProp $Item 'ApprovalPath')) {
            return Set-StartupApprovedEnabled -Path $Item.ApprovalPath -Name $Item.Name -Enabled $Enabled
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
        Write-GuiLog ((T "Failed to toggle {0}: {1}") -f $Item.Name, $_) "ERR"
        return $false
    }
}

# Permanently removes a startup item (registry value, Startup folder shortcut, or scheduled task).
function Remove-StartupItem {
    param($Item)
    try {
        switch ($Item.Source) {
            'task-scheduler' { Unregister-ScheduledTask -TaskName $Item.Name -TaskPath $Item.Location -Confirm:$false -ErrorAction Stop }
            'startup-folder' { Remove-Item -Path $Item.Command -Force -ErrorAction Stop }
            default { Remove-ItemProperty -Path $Item.Location -Name $Item.Name -Force -ErrorAction SilentlyContinue }
        }
        # StartupApproved is a second store for the same entry; delete it with the entry so a
        # later reinstall of the program does not come back disabled.
        if ((Get-SafeProp $Item 'ApprovalPath') -and (Get-SafeProp $Item 'Name')) {
            Remove-ItemProperty -Path $Item.ApprovalPath -Name $Item.Name -Force -ErrorAction SilentlyContinue
        }
        $entries = @(Get-StartupDisabledEntries | Where-Object { -not ((Get-SafeProp $_ 'Name') -eq $Item.Name -and (Get-SafeProp $_ 'Source') -eq $Item.Source) })
        Set-StartupDisabledEntries -Entries $entries
        return $true
    } catch {
        Write-GuiLog ((T "Failed to delete {0}: {1}") -f $Item.Name, $_) "ERR"
        return $false
    }
}
#endregion
