# Sandbox.ps1
# Runs the app's real action code inside the test process, but with every side effect redirected:
#
#   * mutating cmdlets (Set-ItemProperty, Remove-Item, Stop-Service, Start-Process, ...) are
#     replaced by shadows that record WHAT would have been done in a journal;
#   * native tools (netsh, powercfg, ipconfig, reg.exe, winget, ...) resolve to stub .cmd files
#     that append their arguments to the same journal;
#   * file deletions are really executed, but ONLY inside tests\.tools\sandbox-fs\ - any other
#     path is journaled and left untouched;
#   * the GUI layer (Write-GuiLog, Set-GuiProgress, $Window) is stubbed.
#
# The function bodies are the production ones, loaded from the repository in Build.ps1's order.
# Nothing here modifies a real filesystem path, a registry key, a service or a process.
#
# The safety net is the completeness guard in Test-StaticGuards.ps1: every mutating verb found in
# the sources must have a shadow here, so a new action that reaches the system some other way
# fails the suite instead of silently escaping the sandbox.
#
# Every shadow delegates to the real cmdlet when $Global:SandboxActive is false, so a test can
# still clean up its own artifacts with a plain Remove-Item.

Set-StrictMode -Version Latest

$Global:SandboxActive = $false
$Global:SandboxJournal = New-Object System.Collections.ArrayList
$Global:SandboxRepoRoot = $null
$Global:SandboxStubDir = $null
$Global:SandboxNativeJournal = $null
$Global:SandboxLog = New-Object System.Collections.ArrayList
$Global:SandboxFsRoot = $null
$Global:SandboxPathBefore = $null
$Global:SandboxTempBefore = $null
$Global:SandboxWindow = $null
$Global:SandboxRegExists = $null
$Global:SandboxRegGone = $null
$Global:SandboxRegValues = $null

# ------------------------------------------------------------------------------------------------
# Journal
# ------------------------------------------------------------------------------------------------

function Add-SandboxEntry {
    param([string]$Op, [string]$Target = "", [string]$Detail = "")
    [void]$Global:SandboxJournal.Add([pscustomobject]@{ Op = $Op; Target = $Target; Detail = $Detail })
}

function Get-SandboxJournal {
    param([string]$Op)
    $all = @($Global:SandboxJournal)
    if ($Op) { return @($all | Where-Object { $_.Op -eq $Op }) }
    return $all
}

function Format-SandboxJournal {
    foreach ($e in @($Global:SandboxJournal)) {
        if ($e.Detail) { "    {0} {1} :: {2}" -f $e.Op, $e.Target, $e.Detail }
        else { "    {0} {1}" -f $e.Op, $e.Target }
    }
}

function Clear-SandboxJournal {
    $Global:SandboxJournal.Clear()
    $Global:SandboxLog.Clear()
    if ($Global:SandboxNativeJournal -and (Test-Path -LiteralPath $Global:SandboxNativeJournal)) {
        # Module-qualified: this must delete for real even while the sandbox is intercepting.
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $Global:SandboxNativeJournal -Force -ErrorAction SilentlyContinue
    }
}

# Lines appended by the native stubs, one per invocation: "<tool> <arguments>".
function Get-SandboxNativeJournal {
    if (-not $Global:SandboxNativeJournal) { return @() }
    if (-not (Test-Path -LiteralPath $Global:SandboxNativeJournal)) { return @() }
    return @(Get-Content -LiteralPath $Global:SandboxNativeJournal -Encoding UTF8)
}

# True only for paths inside the throwaway filesystem sandbox. Deleting outside it is impossible
# while the sandbox is active, which is what makes it safe to call the real cleanup code.
function Test-SandboxPath {
    param([string]$Path)
    if (-not $Path -or -not $Global:SandboxFsRoot) { return $false }
    try {
        # GetFullPath rejects wildcards, and the cleanup code deletes with "<dir>\*" paths, so they
        # are stripped before the containment check.
        $clean = $Path -replace '[*?\[\]]', ''
        $full = [System.IO.Path]::GetFullPath($clean)
        $root = [System.IO.Path]::GetFullPath($Global:SandboxFsRoot)
        return $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
    } catch { return $false }
}

function Resolve-SandboxTarget {
    param($Path, $LiteralPath)
    if ($Path) { return [string]$Path }
    if ($LiteralPath) { return [string]$LiteralPath }
    return ""
}

# ------------------------------------------------------------------------------------------------
# Virtual registry
# ------------------------------------------------------------------------------------------------
# Because the shadows cannot let a real write happen, the app's own reads would otherwise not see
# what it just wrote: Test-Path on a key the action created returns $false, so every revert branch
# guarded by "if (Test-Path $key) { Remove-Item ... }" silently does nothing. That is precisely the
# bug class this suite looks for, so the sandbox models the registry the way the action expects to
# see it:
#   SandboxRegExists - keys created during this scenario
#   SandboxRegGone   - keys deleted during this scenario
#   SandboxRegValues - values written/removed, per key path
$Global:SandboxRegExists = $null
$Global:SandboxRegGone = $null
$Global:SandboxRegValues = $null

# Every scenario starts from the machine's real registry; the overlay only holds this scenario's
# changes, so a result never depends on what a previous test happened to write.
function Reset-SandboxRegistry {
    $Global:SandboxRegExists = New-Object 'System.Collections.Generic.HashSet[string]'
    $Global:SandboxRegGone = New-Object 'System.Collections.Generic.HashSet[string]'
    $Global:SandboxRegValues = @{}
}

# Normalized ("hklm:\software\x") form of a registry path, or $null when the path is not registry.
function Get-SandboxRegPath {
    param([string]$Path)
    if (-not $Path) { return $null }
    $p = $Path.Trim()
    if ($p.StartsWith('Registry::')) { $p = $p.Substring(10) }
    $p = $p -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
    $p = $p -replace '^HKEY_CURRENT_USER', 'HKCU:'
    $p = $p -replace '^HKEY_CLASSES_ROOT', 'HKCR:'
    $p = $p -replace '^HKEY_USERS', 'HKU:'
    $p = $p -replace '^HKEY_CURRENT_CONFIG', 'HKCC:'
    if ($p -notmatch '^(HKLM|HKCU|HKCR|HKU|HKCC):') { return $null }
    return $p.TrimEnd('\').ToLowerInvariant()
}

function Test-SandboxRegGone {
    param([string]$Reg)
    foreach ($g in $Global:SandboxRegGone) {
        if ($Reg -eq $g -or $Reg.StartsWith($g + '\')) { return $true }
    }
    return $false
}

function Test-SandboxRegCreated {
    param([string]$Reg)
    if ($Global:SandboxRegExists.Contains($Reg)) { return $true }
    foreach ($e in $Global:SandboxRegExists) {
        if ($Reg.StartsWith($e + '\')) { return $true }
    }
    return $false
}

function Set-SandboxRegValue {
    param([string]$Reg, [string]$Name, $Value)
    if (-not $Name) { $Name = '(default)' }
    if (-not $Global:SandboxRegValues.ContainsKey($Reg)) { $Global:SandboxRegValues[$Reg] = @{} }
    $Global:SandboxRegValues[$Reg][$Name] = $Value
    [void]$Global:SandboxRegExists.Add($Reg)
}

function Remove-SandboxRegValue {
    param([string]$Reg, [string]$Name)
    if (-not $Name) { $Name = '(default)' }
    # A value the action removes is recorded as removed even when the key pre-existed, so a later
    # read in the same scenario does not report the old value as still present.
    if ($Global:SandboxRegValues.ContainsKey($Reg)) { $Global:SandboxRegValues[$Reg].Remove($Name) }
    [void]$Global:SandboxRegExists.Add($Reg)
}

function Remove-SandboxRegKey {
    param([string]$Reg)
    [void]$Global:SandboxRegGone.Add($Reg)
    foreach ($k in @($Global:SandboxRegExists)) {
        if ($k -eq $Reg -or $k.StartsWith($Reg + '\')) { [void]$Global:SandboxRegExists.Remove($k) }
    }
    foreach ($k in @($Global:SandboxRegValues.Keys)) {
        if ($k -eq $Reg -or $k.StartsWith($Reg + '\')) { $Global:SandboxRegValues.Remove($k) }
    }
}

# ------------------------------------------------------------------------------------------------
# GUI stubs
# ------------------------------------------------------------------------------------------------

if (-not $Global:SandboxWindow) {
    $dispatcher = [pscustomobject]@{ Current = $null }
    $dispatcher | Add-Member -MemberType ScriptMethod -Name Invoke -Value { param($a, $b) if ($a -is [scriptblock]) { & $a } } -Force
    $dispatcher | Add-Member -MemberType ScriptMethod -Name BeginInvoke -Value { param($a, $b) $null } -Force
    $Global:SandboxWindow = [pscustomobject]@{ Dispatcher = $dispatcher }
    $Global:SandboxWindow | Add-Member -MemberType ScriptMethod -Name FindResource -Value { param($k) $null } -Force
    $Global:SandboxWindow | Add-Member -MemberType ScriptMethod -Name TryFindResource -Value { param($k) $null } -Force
}

function Write-GuiLog {
    param([string]$Text, [string]$Level = "INFO")
    [void]$Global:SandboxLog.Add(("{0} {1}" -f $Level, $Text))
}
function Set-GuiProgress { param($Percent, [string]$Text = "") }
function Clear-GuiLog { $Global:SandboxLog.Clear() }
function Add-LogBuffer { param([string]$Text) }
function Set-NavStatus { param($Text) }
function Invoke-OnUi { param([scriptblock]$Action) & $Action }

# ------------------------------------------------------------------------------------------------
# Cmdlet shadows
# ------------------------------------------------------------------------------------------------
# Each shadow is an advanced function, so the common parameters (-ErrorAction, -Verbose, ...) the
# production code passes keep binding. When the sandbox is off it delegates to the real cmdlet
# through its module-qualified name, which bypasses this shadow.

function Remove-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $LiteralPath, [switch]$Recurse, [switch]$Force, $Filter, $Include, $Exclude)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Remove-Item" $target ("recurse=" + [bool]$Recurse)
    $reg = Get-SandboxRegPath $target
    if ($reg) { Remove-SandboxRegKey $reg; return }
    if (Test-SandboxPath $target) {
        Microsoft.PowerShell.Management\Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function Remove-ItemProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Name, $LiteralPath, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Remove-ItemProperty @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Remove-ItemProperty" $target ([string]$Name)
    $reg = Get-SandboxRegPath $target
    if ($reg) { Remove-SandboxRegValue $reg ([string]$Name) }
}
function Set-ItemProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Name, $Value, $Type, $LiteralPath, [switch]$Force, [switch]$PassThru, $InputObject)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Set-ItemProperty @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Set-ItemProperty" $target ("$Name=" + [string]$Value)
    $reg = Get-SandboxRegPath $target
    if ($reg) { Set-SandboxRegValue $reg ([string]$Name) $Value }
}
function New-ItemProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Name, $Value, $PropertyType, $LiteralPath, [switch]$Force, [switch]$PassThru)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\New-ItemProperty @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "New-ItemProperty" $target ("$Name=" + [string]$Value)
    $reg = Get-SandboxRegPath $target
    if ($reg) { Set-SandboxRegValue $reg ([string]$Name) $Value }
}
function Set-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Value, $LiteralPath, [switch]$Force, [switch]$PassThru)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Set-Item @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Set-Item" $target ([string]$Value)
    $reg = Get-SandboxRegPath $target
    if ($reg) { Set-SandboxRegValue $reg '(default)' $Value }
}
function Clear-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $LiteralPath, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Clear-Item @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Clear-Item" $target
    $reg = Get-SandboxRegPath $target
    if ($reg) { Set-SandboxRegValue $reg '(default)' $null }
}
function New-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $ItemType, $Name, $Value, $LiteralPath, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\New-Item @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "New-Item" $target ([string]$ItemType)
    $reg = Get-SandboxRegPath $target
    if ($reg) { [void]$Global:SandboxRegExists.Add($reg); return }
    if (Test-SandboxPath $target) {
        Microsoft.PowerShell.Management\New-Item -Path $target -ItemType $ItemType -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# Read side of the overlay: the app checks Test-Path before creating keys and before removing them,
# so both answers have to come from the virtual registry first.
function Test-Path {
    [CmdletBinding()]
    param($Path, $LiteralPath, $PathType, [switch]$IsValid, $Filter, $Include, $Exclude)
    if (-not $Global:SandboxActive -or $IsValid) { Microsoft.PowerShell.Management\Test-Path @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    $reg = Get-SandboxRegPath $target
    if ($reg) {
        if (Test-SandboxRegGone $reg) { return $false }
        if (Test-SandboxRegCreated $reg) { return $true }
    }
    return (Microsoft.PowerShell.Management\Test-Path -Path $target)
}

function Get-ItemProperty {
    [CmdletBinding()]
    param($Path, $LiteralPath, $Name)
    # NOTE: no explicit $ErrorAction parameter - a CmdletBinding function already gets the common
    # parameters, so the app's -ErrorAction SilentlyContinue passes straight through.
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Get-ItemProperty @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    $reg = Get-SandboxRegPath $target
    if ($reg -and -not (Test-SandboxRegGone $reg)) {
        if ($Global:SandboxRegValues.ContainsKey($reg)) {
            $props = $Global:SandboxRegValues[$reg]
            $obj = [ordered]@{ PSPath = $target; PSParentPath = ''; PSChildName = ($reg -split '\\')[-1]; PSDrive = ''; PSProvider = '' }
            foreach ($k in $props.Keys) { $obj[$k] = $props[$k] }
            return [pscustomobject]$obj
        }
        if (Test-SandboxRegCreated $reg) {
            return [pscustomobject]@{ PSPath = $target; PSParentPath = ''; PSChildName = ($reg -split '\\')[-1]; PSDrive = ''; PSProvider = '' }
        }
    }
    return (Microsoft.PowerShell.Management\Get-ItemProperty @PSBoundParameters)
}

function Move-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Destination, $LiteralPath, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Move-Item @PSBoundParameters; return }
    Add-SandboxEntry "Move-Item" (Resolve-SandboxTarget $Path $LiteralPath) ([string]$Destination)
}
function Copy-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Destination, $LiteralPath, [switch]$Force, [switch]$Recurse)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters; return }
    Add-SandboxEntry "Copy-Item" (Resolve-SandboxTarget $Path $LiteralPath) ([string]$Destination)
}
function Rename-Item {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $NewName, $LiteralPath, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Rename-Item @PSBoundParameters; return }
    Add-SandboxEntry "Rename-Item" (Resolve-SandboxTarget $Path $LiteralPath) ([string]$NewName)
}
# File writes: the app persists state (theme, disabled startups, update cache) with Set-Content.
# Inside the sandbox a write is real only under tests\.tools\sandbox-fs\, so app state files in
# %LOCALAPPDATA% are never created or clobbered by a test run.
function Set-Content {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Value, $LiteralPath, $Encoding, [switch]$NoNewline, [switch]$Force, $Filter, $Include, $Exclude)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Set-Content @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Set-Content" $target ("len=" + [string]@($Value).Count)
    if (Test-SandboxPath $target) {
        Microsoft.PowerShell.Management\Set-Content -LiteralPath $target -Value $Value -Encoding UTF8 -Force -ErrorAction SilentlyContinue
    }
}
function Add-Content {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Value, $LiteralPath, $Encoding, [switch]$NoNewline, [switch]$Force, $Filter, $Include, $Exclude)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Add-Content @PSBoundParameters; return }
    $target = Resolve-SandboxTarget $Path $LiteralPath
    Add-SandboxEntry "Add-Content" $target
    if (Test-SandboxPath $target) {
        Microsoft.PowerShell.Management\Add-Content -LiteralPath $target -Value $Value -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}
function Out-File {
    [CmdletBinding(SupportsShouldProcess)]
    param($FilePath, $InputObject, $Encoding, [switch]$Append, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Utility\Out-File @PSBoundParameters; return }
    Add-SandboxEntry "Out-File" ([string]$FilePath)
}
function Export-Clixml {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $LiteralPath, $InputObject, $Depth, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Utility\Export-Clixml @PSBoundParameters; return }
    Add-SandboxEntry "Export-Clixml" (Resolve-SandboxTarget $Path $LiteralPath)
}

# System Restore (RestorePoint.ps1). Creating a checkpoint needs elevation, so it must never be the
# real call inside a test.
function Checkpoint-Computer {
    [CmdletBinding(SupportsShouldProcess)]
    param($Description, $RestorePointType)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Checkpoint-Computer @PSBoundParameters; return }
    Add-SandboxEntry "Checkpoint-Computer" ([string]$Description) ([string]$RestorePointType)
}
function Enable-ComputerRestore {
    [CmdletBinding(SupportsShouldProcess)]
    param($Drive)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Enable-ComputerRestore @PSBoundParameters; return }
    Add-SandboxEntry "Enable-ComputerRestore" ([string]$Drive)
}
function Disable-ComputerRestore {
    [CmdletBinding(SupportsShouldProcess)]
    param($Drive)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Disable-ComputerRestore @PSBoundParameters; return }
    Add-SandboxEntry "Disable-ComputerRestore" ([string]$Drive)
}
# Scheduled tasks (Startup Manager can disable/remove them)
function Disable-ScheduledTask {
    [CmdletBinding(SupportsShouldProcess)]
    param($TaskName, $TaskPath, $InputObject)
    if (-not $Global:SandboxActive) { ScheduledTasks\Disable-ScheduledTask @PSBoundParameters; return }
    Add-SandboxEntry "Disable-ScheduledTask" ([string]$TaskName) ([string]$TaskPath)
}
function Enable-ScheduledTask {
    [CmdletBinding(SupportsShouldProcess)]
    param($TaskName, $TaskPath, $InputObject)
    if (-not $Global:SandboxActive) { ScheduledTasks\Enable-ScheduledTask @PSBoundParameters; return }
    Add-SandboxEntry "Enable-ScheduledTask" ([string]$TaskName) ([string]$TaskPath)
}
function Unregister-ScheduledTask {
    [CmdletBinding(SupportsShouldProcess)]
    param($TaskName, $TaskPath, $InputObject)
    if (-not $Global:SandboxActive) { ScheduledTasks\Unregister-ScheduledTask @PSBoundParameters; return }
    Add-SandboxEntry "Unregister-ScheduledTask" ([string]$TaskName) ([string]$TaskPath)
}
function Register-ScheduledTask {
    [CmdletBinding(SupportsShouldProcess)]
    param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
    if (-not $Global:SandboxActive) { ScheduledTasks\Register-ScheduledTask @PSBoundParameters; return }
    Add-SandboxEntry "Register-ScheduledTask" ([string]$TaskName)
}
function Set-ScheduledTask {
    [CmdletBinding(SupportsShouldProcess)]
    param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Principal, $InputObject)
    if (-not $Global:SandboxActive) { ScheduledTasks\Set-ScheduledTask @PSBoundParameters; return }
    Add-SandboxEntry "Set-ScheduledTask" ([string]$TaskName)
}
function Clear-RecycleBin {
    [CmdletBinding(SupportsShouldProcess)]
    param($DriveLetter, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Clear-RecycleBin @PSBoundParameters; return }
    Add-SandboxEntry "Clear-RecycleBin" ([string]$DriveLetter)
}

# Memory compression (MMAgent). Disable-MMAgent removes the compression store of every running
# process, so it must never be the real cmdlet inside a test.
function Enable-MMAgent {
    [CmdletBinding(SupportsShouldProcess)]
    param($ApplicationPreLaunch, $MemoryCompression, $OperationAPI, $PageCombining, $ErrorAction)
    if (-not $Global:SandboxActive) { MMAgent\Enable-MMAgent @PSBoundParameters; return }
    Add-SandboxEntry "Enable-MMAgent" "" ("pageCombining=" + [string]$PageCombining)
}
function Disable-MMAgent {
    [CmdletBinding(SupportsShouldProcess)]
    param($ApplicationPreLaunch, $MemoryCompression, $OperationAPI, $PageCombining, $ErrorAction)
    if (-not $Global:SandboxActive) { MMAgent\Disable-MMAgent @PSBoundParameters; return }
    Add-SandboxEntry "Disable-MMAgent" "" ("pageCombining=" + [string]$PageCombining)
}

# Network adapter properties are written straight into the NIC driver configuration. This is the
# one action that would silently repoint a real network card during a test run.
function Set-NetAdapterAdvancedProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param($Name, $DisplayName, $DisplayValue, $RegistryKeyword, $RegistryValue, $ErrorAction)
    if (-not $Global:SandboxActive) { NetAdapter\Set-NetAdapterAdvancedProperty @PSBoundParameters; return }
    $detail = if ($RegistryKeyword) { "$RegistryKeyword=$RegistryValue" } else { "$DisplayName=$DisplayValue" }
    Add-SandboxEntry "Set-NetAdapterAdvancedProperty" ([string]$Name) $detail
}
function Clear-DnsClientCache {
    [CmdletBinding(SupportsShouldProcess)]
    param($ErrorAction)
    if (-not $Global:SandboxActive) { DnsClient\Clear-DnsClientCache @PSBoundParameters; return }
    Add-SandboxEntry "Clear-DnsClientCache" ""
}
# Expanding an archive writes files wherever the caller points it at, so it is journaled only.
function Expand-Archive {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $DestinationPath, [switch]$Force, $ErrorAction)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Archive\Expand-Archive @PSBoundParameters; return }
    Add-SandboxEntry "Expand-Archive" ([string]$Path) ([string]$DestinationPath)
}

function Set-Service {
    [CmdletBinding(SupportsShouldProcess)]
    param($Name, $StartupType, $Status, $DisplayName, $Description, [switch]$PassThru)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Set-Service @PSBoundParameters; return }
    Add-SandboxEntry "Set-Service" ([string]$Name) ("startup=" + [string]$StartupType + " status=" + [string]$Status)
}
function Stop-Service {
    [CmdletBinding(SupportsShouldProcess)]
    param($Name, $InputObject, [switch]$Force, [switch]$NoWait, [switch]$PassThru)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Stop-Service @PSBoundParameters; return }
    Add-SandboxEntry "Stop-Service" ([string]$Name)
}
function Start-Service {
    [CmdletBinding(SupportsShouldProcess)]
    param($Name, $InputObject, [switch]$PassThru)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Start-Service @PSBoundParameters; return }
    Add-SandboxEntry "Start-Service" ([string]$Name)
}
function Restart-Service {
    [CmdletBinding(SupportsShouldProcess)]
    param($Name, $InputObject, [switch]$Force, [switch]$PassThru)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Restart-Service @PSBoundParameters; return }
    Add-SandboxEntry "Restart-Service" ([string]$Name)
}

function Start-Process {
    [CmdletBinding(SupportsShouldProcess)]
    param($FilePath, $ArgumentList, $WorkingDirectory, $Verb, $WindowStyle, [switch]$Wait, [switch]$PassThru,
          [switch]$NoNewWindow, $RedirectStandardOutput, $RedirectStandardError, $Credential)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Start-Process @PSBoundParameters; return }
    $argText = ""
    if ($ArgumentList) {
        $argText = if ($ArgumentList -is [array]) { ($ArgumentList -join " ") } else { [string]$ArgumentList }
    }
    Add-SandboxEntry "Start-Process" ([string]$FilePath) $argText
    if ($PassThru) { return [pscustomobject]@{ Id = 0; ExitCode = 0; HasExited = $true } }
}
function Stop-Process {
    [CmdletBinding(SupportsShouldProcess)]
    param($Id, $Name, $InputObject, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Management\Stop-Process @PSBoundParameters; return }
    if ($Name) { Add-SandboxEntry "Stop-Process" ([string]$Name) } else { Add-SandboxEntry "Stop-Process" ([string]$Id) }
}
function Set-ExecutionPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param($ExecutionPolicy, $Scope, [switch]$Force)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Security\Set-ExecutionPolicy @PSBoundParameters; return }
    Add-SandboxEntry "Set-ExecutionPolicy" ([string]$ExecutionPolicy) ([string]$Scope)
}

function Invoke-WebRequest {
    [CmdletBinding(SupportsShouldProcess)]
    param($Uri, $OutFile, $Method, $Body, $Headers, [switch]$UseBasicParsing, $UserAgent, $TimeoutSec)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Utility\Invoke-WebRequest @PSBoundParameters; return }
    Add-SandboxEntry "Invoke-WebRequest" ([string]$Uri) ([string]$OutFile)
    if ($OutFile) { Set-Content -LiteralPath $OutFile -Value "sandbox" -Encoding UTF8 -ErrorAction SilentlyContinue }
    return [pscustomobject]@{ StatusCode = 200; Content = ""; Headers = @{} }
}
function Invoke-RestMethod {
    [CmdletBinding(SupportsShouldProcess)]
    param($Uri, $Method, $Body, $Headers, $TimeoutSec, $UserAgent)
    if (-not $Global:SandboxActive) { Microsoft.PowerShell.Utility\Invoke-RestMethod @PSBoundParameters; return }
    Add-SandboxEntry "Invoke-RestMethod" ([string]$Uri)
    return [pscustomobject]@{ tag_name = "v0.0.0"; assets = @(); body = "" }
}

function Invoke-CimMethod {
    [CmdletBinding(SupportsShouldProcess)]
    param($ClassName, $Namespace, $MethodName, $Arguments, $InputObject, $ComputerName)
    if (-not $Global:SandboxActive) { CimCmdlets\Invoke-CimMethod @PSBoundParameters; return }
    Add-SandboxEntry "Invoke-CimMethod" ([string]$ClassName) ([string]$MethodName)
    return [pscustomobject]@{ ReturnValue = 0 }
}

# System tool resolution: while the sandbox is on, every "System32" tool resolves to a stub whose
# only job is to record its arguments, so reg.exe/powercfg/wsreset are never the real binaries.
function Get-SystemToolPath {
    param([string]$Name)
    if ($Global:SandboxActive -and $Global:SandboxStubDir) {
        $stub = Join-Path $Global:SandboxStubDir $Name
        if (Test-Path -LiteralPath $stub) { return $stub }
        return $null
    }
    $candidates = @()
    if (-not [Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) {
        $candidates += (Join-Path $env:windir "Sysnative\$Name")
    }
    $candidates += (Join-Path $env:windir "System32\$Name")
    $candidates += (Join-Path $env:windir "SysWOW64\$Name")
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

# ------------------------------------------------------------------------------------------------
# Native command stubs
# ------------------------------------------------------------------------------------------------

$script:SandboxNativeTools = @(
    "netsh", "powercfg", "ipconfig", "reg", "winget", "schtasks", "sc", "taskkill", "bcdedit",
    "wusa", "dism", "sfc", "takeown", "icacls", "choco", "msiexec", "wsreset", "explorer",
    "msconfig", "cleanmgr", "robocopy", "xcopy", "curl", "bitsadmin", "fsutil", "vssadmin",
    "pnputil", "driverquery", "cmd"
)

function New-SandboxNativeStubs {
    param([string]$Directory, [string]$JournalPath)
    if (-not (Test-Path -LiteralPath $Directory)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    foreach ($tool in $script:SandboxNativeTools) {
        $stub = Join-Path $Directory ($tool + ".cmd")
        $body = "@echo off`r`n>>`"$JournalPath`" echo $tool %*`r`n"
        # The app parses powercfg output to discover scheme GUIDs, so the stub answers like the real
        # tool instead of returning nothing (returning nothing makes the caller read a $null match).
        if ($tool -eq "powercfg") {
            $body += "echo Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)`r`n"
            $body += "echo Power Scheme GUID: e9a42b02-d5df-448d-aa00-03f14749eb61  (SETTDash)`r`n"
        }
        $body += "exit /b 0`r`n"
        [System.IO.File]::WriteAllText($stub, $body, (New-Object System.Text.ASCIIEncoding))
    }

    # reg.exe export is followed by the caller inspecting the .reg file, so the stub writes one.
    $regStub = Join-Path $Directory "reg.cmd"
    $regBody = "@echo off`r`n>>`"$JournalPath`" echo reg %*`r`necho Windows Registry Editor Version 5.00 > %4`r`nexit /b 0`r`n"
    [System.IO.File]::WriteAllText($regStub, $regBody, (New-Object System.Text.ASCIIEncoding))
}


# ------------------------------------------------------------------------------------------------
# Bootstrap
# ------------------------------------------------------------------------------------------------
# The loading loop below runs at file scope ON PURPOSE. Dot-sourcing the app inside a function
# would define every app function in that function's scope, and they would vanish when it
# returned.

# Reads the load order straight out of Build.ps1, so the sandbox can never drift from the real
# concatenation order.
function Get-BuildParts {
    param([string]$RepoRoot)
    $buildText = Get-Content -Path (Join-Path $RepoRoot "Build.ps1") -Raw -Encoding UTF8
    $m = [regex]::Match($buildText, '(?s)\$parts\s*=\s*@\((.*?)\r?\n\)')
    if (-not $m.Success) { throw "Could not read the `$parts list from Build.ps1" }
    return @([regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
}

# Parts that need a real window/host. Their public functions are stubbed above, or are not
# reachable from the actions under test.
$script:SandboxSkipParts = @(
    "Main\Layout.ps1",
    "Main\Window.ps1",
    "Main\Startup.ps1",
    "Main\TitleBar.ps1",
    "Sidebar\Sidebar.ps1",
    "Core\Embed\Fonts\EmbeddedMonospaceFont.ps1"
)

$Global:SandboxRepoRoot = Split-Path $PSScriptRoot -Parent
if ($env:SETTDASH_SANDBOX_REPO) { $Global:SandboxRepoRoot = $env:SETTDASH_SANDBOX_REPO }

$sandboxToolsDir = Join-Path $PSScriptRoot ".tools"
if (-not (Test-Path -LiteralPath $sandboxToolsDir)) { New-Item -ItemType Directory -Path $sandboxToolsDir -Force | Out-Null }
$Global:SandboxStubDir = Join-Path $sandboxToolsDir "sandbox-bin"
$Global:SandboxNativeJournal = Join-Path $sandboxToolsDir "sandbox-native.txt"
$Global:SandboxFsRoot = Join-Path $sandboxToolsDir "sandbox-fs"
$Global:SandboxUtf8Dir = Join-Path $sandboxToolsDir "utf8-parts"

New-SandboxNativeStubs -Directory $Global:SandboxStubDir -JournalPath $Global:SandboxNativeJournal

# Filesystem sandbox: the only tree the app is ever allowed to really delete from.
if (Test-Path -LiteralPath $Global:SandboxFsRoot) {
    Microsoft.PowerShell.Management\Remove-Item -Path $Global:SandboxFsRoot -Recurse -Force -ErrorAction SilentlyContinue
}
[void](Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $Global:SandboxFsRoot -Force)
if (Test-Path -LiteralPath $Global:SandboxUtf8Dir) {
    Microsoft.PowerShell.Management\Remove-Item -Path $Global:SandboxUtf8Dir -Recurse -Force -ErrorAction SilentlyContinue
}
[void](Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $Global:SandboxUtf8Dir -Force)

# Globals the app expects to exist before the actions run. Window/Layout/Startup are not loaded.
$Script:AppVersion = "0.0.0-test"
$Script:AppDir = $Global:SandboxRepoRoot
$Script:CurrentTheme = "Default"
$Script:TempDir = Join-Path $sandboxToolsDir "sandbox-runtime"
if (-not (Test-Path -LiteralPath $Script:TempDir)) { [void](Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $Script:TempDir -Force) }
# Extract-EmbeddedPrograms writes into <TempDir>\Programs and does not create the folder itself.
$sandboxProgramsDir = Join-Path $Script:TempDir "Programs"
if (-not (Test-Path -LiteralPath $sandboxProgramsDir)) { [void](Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $sandboxProgramsDir -Force) }
$Window = $Global:SandboxWindow
$txtLog = $null
$btnLogCopy = $null
$btnLogClear = $null

$sandboxParts = Get-BuildParts -RepoRoot $Global:SandboxRepoRoot
$sandboxLoaded = New-Object System.Collections.ArrayList
$sandboxSkipped = New-Object System.Collections.ArrayList
$sandboxFailures = New-Object System.Collections.ArrayList
$utf8Bom = New-Object System.Text.UTF8Encoding($true)

$sandboxIndex = 0
foreach ($part in $sandboxParts) {
    if ($script:SandboxSkipParts -contains $part) { [void]$sandboxSkipped.Add($part); continue }
    $path = Join-Path $Global:SandboxRepoRoot $part
    if (-not (Test-Path -LiteralPath $path)) { [void]$sandboxFailures.Add("$part -> missing"); continue }

    # The source files are UTF-8 without BOM. Dot-sourcing them directly makes Windows PowerShell
    # 5.1 read them as ANSI and choke on characters such as the degree sign, so each file is
    # re-emitted with a BOM first (line numbers stay identical).
    $sandboxIndex++
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $tmpName = ("{0:d3}-{1}" -f $sandboxIndex, ($part -replace '[\\/]', '_'))
    $tmp = Join-Path $Global:SandboxUtf8Dir $tmpName
    [System.IO.File]::WriteAllText($tmp, $text, $utf8Bom)

    try { . $tmp } catch { [void]$sandboxFailures.Add("$part -> $($_.Exception.Message)") }
    [void]$sandboxLoaded.Add($part)
}

# ------------------------------------------------------------------------------------------------
# Overrides that must win over whatever was just loaded
# ------------------------------------------------------------------------------------------------
# Log.ps1 defines the real Write-GuiLog / Write-ErrorLog, which touch the WPF log box and the
# on-disk report. In the sandbox they only record, so an action's own error reporting can be
# asserted without writing anything to %LOCALAPPDATA%.

function Write-GuiLog {
    param([string]$Text, [string]$Level = "INFO")
    [void]$Global:SandboxLog.Add(("{0} {1}" -f $Level, $Text))
}
function Set-GuiProgress { param($Percent, [string]$Text = "") }
function Clear-GuiLog { $Global:SandboxLog.Clear() }
function Add-LogBuffer { param([string]$Text) }
function Write-ErrorLog {
    param([string]$Text)
    [void]$Global:SandboxLog.Add(("ERRLOG " + $Text))
    return $false
}

# Pure-UI helpers from Core\Helpers: they reach into the XAML window through FindName, which does
# not exist here. Run under the sandbox they must not be what makes an action fail.
function Set-NavStatus { param([string]$Name, [bool]$Applied) }
function Update-GuiMetric { param($Name, $Value) }
function Set-GuiTheme { param([string]$ThemeName) [void]$Global:SandboxLog.Add("THEME $ThemeName") }
function Set-GuiGaugeValue { param($Gauge, $Value, $Text) }
function Set-GuiMetricBarValue { param($Bar, $Value) }
function Update-GuiNavActive { param([string]$activeTag) }

# Reads the error lines an action reported through its own logging, which is how the app tells the
# user "this step failed" without throwing.
function Get-SandboxErrors {
    return @($Global:SandboxLog | Where-Object { $_ -match '^(ERR|ERRLOG)\s' })
}

$Global:SandboxInfo = [pscustomobject]@{
    RepoRoot     = $Global:SandboxRepoRoot
    LoadedParts  = $sandboxLoaded.Count
    SkippedParts = $sandboxSkipped
    LoadFailures = $sandboxFailures
    StubDir      = $Global:SandboxStubDir
    JournalPath  = $Global:SandboxNativeJournal
    FsRoot       = $Global:SandboxFsRoot
}

# Turns interception on. From here until Stop-Sandbox, no production call can reach the system.
function Start-Sandbox {
    $Global:SandboxActive = $true
    Clear-SandboxJournal
    Reset-SandboxRegistry
    $Global:SandboxPathBefore = $env:PATH
    $env:PATH = $Global:SandboxStubDir + ";" + $env:PATH
    # Code that bypasses the cmdlet shadows by calling .NET directly (WriteAllText into %TEMP%)
    # then still lands inside the sandbox tree.
    $Global:SandboxTempBefore = $env:TEMP
    $sandboxTemp = Join-Path $Global:SandboxFsRoot "temp"
    if (-not (Test-Path -LiteralPath $sandboxTemp)) {
        [void](Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $sandboxTemp -Force)
    }
    $env:TEMP = $sandboxTemp
    $env:TMP = $sandboxTemp
}

function Stop-Sandbox {
    $Global:SandboxActive = $false
    if ($Global:SandboxPathBefore) { $env:PATH = $Global:SandboxPathBefore; $Global:SandboxPathBefore = $null }
    if ($Global:SandboxTempBefore) {
        $env:TEMP = $Global:SandboxTempBefore
        $env:TMP = $Global:SandboxTempBefore
        $Global:SandboxTempBefore = $null
    }
}

# Runs a block with interception on, always turning it back off.
function Invoke-Sandboxed {
    param([scriptblock]$Action)
    Start-Sandbox
    try { & $Action } finally { Stop-Sandbox }
}
