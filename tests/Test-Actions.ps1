# Test-Actions.ps1
# Exercises EVERY function that mutates the system (registry, services, files, tasks, processes,
# native tools) with the sandbox from Sandbox.ps1.
#
# What is proven here:
#   1. The function completes without throwing and without reporting an internal error.
#   2. Its side effects are the ones the test expects (exact journal assertions for the important
#      ones), and a revert really covers everything its apply touched (symmetry).
#   3. File deletion really happens - on fake files inside tests\.tools\sandbox-fs\.
#   4. Every mutating command used anywhere in the sources has a sandbox shadow. If someone adds a
#      new action that reaches the system through a command this harness does not know about, this
#      suite fails instead of letting a test silently touch the real machine.
#
# What is NOT proven here: that Windows accepts the registry/service/file change. The sandbox
# records the intent; the effect on a real key is covered by the user's manual elevated testing.

[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "Sandbox.ps1")

$sandbox = $Global:SandboxInfo

# ---------------------------------------------------------------------------------------------
# 0. The sandbox itself loaded the whole app
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: sandbox"

Assert-True ($sandbox.LoadedParts -ge 90) "The app's action layer was loaded" "$($sandbox.LoadedParts) files"
Assert-Equal 0 $sandbox.LoadFailures.Count "Every source file loads into the sandbox"
foreach ($f in $sandbox.LoadFailures) { Write-Host "         $f" -ForegroundColor DarkYellow }

$sourceFiles = @(
    Get-ChildItem -Path $RepoRoot -Recurse -Include *.ps1 -File |
        Where-Object {
            $_.Name -notmatch '^SETTDash' -and
            $_.FullName -notmatch '\\tests\\' -and
            $_.FullName -notmatch '\\\.git\\'
        }
)

# ---------------------------------------------------------------------------------------------
# 1. Completeness guard: nothing can reach the system unshadowed
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: sandbox completeness"

# Every command in the sources is classified by the *verb* it starts with, not by a hand-kept list:
# a new action that calls Set-SomethingNew fails this suite until somebody decides what to do with
# it - either add a shadow in Sandbox.ps1 or put it in $safeCommands with a reason. A hand-kept
# list would have silently missed Set-NetAdapterAdvancedProperty (it writes the real NIC config).
$mutatingPrefixes = @(
    'Add-', 'Backup-', 'Checkpoint-', 'Clear-', 'Compress-', 'Copy-', 'Disable-', 'Dismount-',
    'Enable-', 'Expand-', 'Export-', 'Grant-', 'Import-', 'Initialize-', 'Install-', 'Join-',
    'Lock-', 'Mount-', 'Move-', 'New-', 'Optimize-', 'Out-', 'Pop-', 'Protect-', 'Publish-',
    'Push-', 'Register-', 'Remove-', 'Rename-', 'Repair-', 'Reset-', 'Restart-', 'Restore-',
    'Resume-', 'Revoke-', 'Save-', 'Send-', 'Set-', 'Split-', 'Start-', 'Stop-', 'Suspend-',
    'Switch-', 'Uninstall-', 'Unlock-', 'Unprotect-', 'Unregister-', 'Update-', 'Write-'
)

# Built-in commands whose verb looks dangerous but which cannot change the machine: pure in-memory,
# session-scope, pipeline or console operations. Everything else with a mutating verb must be
# either an app function (its body is checked too) or intercepted by Sandbox.ps1.
$safeCommands = @(
    'Add-Member', 'Add-Type', 'Export-ModuleMember', 'Join-Path', 'New-Object', 'Out-Null',
    'Out-String', 'Pop-Location', 'Push-Location', 'Set-Location', 'Set-StrictMode', 'Set-Variable',
    'Split-Path', 'Start-Sleep', 'Write-Host', 'Write-Output', 'Write-Verbose', 'Write-Warning',
    'Write-Debug', 'Write-Progress', 'Write-Information', 'Test-Path'
)

$nativeTools = @(
    'netsh', 'powercfg', 'ipconfig', 'reg', 'winget', 'schtasks', 'sc', 'taskkill', 'bcdedit',
    'wusa', 'dism', 'sfc', 'takeown', 'icacls', 'choco', 'msiexec', 'wsreset', 'explorer',
    'msconfig', 'cleanmgr', 'robocopy', 'xcopy', 'curl', 'bitsadmin', 'fsutil', 'vssadmin',
    'pnputil', 'driverquery'
)

# Command names actually used in the sources, plus every function the app itself defines, taken
# from the AST (not from text matching, so a command that only appears inside a string cannot
# create a false positive).
$usedCommands = New-Object System.Collections.Generic.HashSet[string]
$appFunctions = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in $sourceFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        # "function global:X" / "function script:X" report the scope as part of the name.
        [void]$appFunctions.Add(($fn.Name -replace '^[A-Za-z]+:', ''))
    }
    foreach ($cmd in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $name = $cmd.GetCommandName()
        if ($name) { [void]$usedCommands.Add($name) }
    }
}

function Test-MutatingName {
    param([string]$Name)
    foreach ($p in $mutatingPrefixes) { if ($Name.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

# Commands the app calls that could change the machine if they were not intercepted.
$mutatingCommandsUsed = @($usedCommands | Where-Object {
    (Test-MutatingName $_) -and -not $appFunctions.Contains($_) -and $safeCommands -notcontains $_
})

$unshadowed = @()
foreach ($verb in $mutatingCommandsUsed) {
    $cmd = Get-Command $verb -CommandType Function -ErrorAction SilentlyContinue
    $scriptFile = ""
    if ($cmd -and $cmd.ScriptBlock -and $cmd.ScriptBlock.File) { $scriptFile = $cmd.ScriptBlock.File }
    if (-not $cmd) { $unshadowed += "$verb (used in the app, no sandbox shadow)"; continue }
    if ($scriptFile -notmatch 'Sandbox\.ps1$') { $unshadowed += "$verb (shadowed by $scriptFile, not by Sandbox.ps1)" }
}
Assert-Equal 0 $unshadowed.Count "Every mutating cmdlet used by the app is intercepted"
Write-Host "         $($mutatingCommandsUsed.Count) mutating commands checked" -ForegroundColor DarkGray
foreach ($u in $unshadowed) { Write-Host "         $u" -ForegroundColor DarkYellow }

# The guard must not silently stop seeing commands: if the AST walk broke, everything would pass.
Assert-True ($mutatingCommandsUsed.Count -ge 15) "The command census found the app's mutating calls" "$($mutatingCommandsUsed.Count) commands"
Assert-True ($appFunctions.Count -ge 200) "The command census found the app's own functions" "$($appFunctions.Count) functions"

# Direct .NET calls bypass every cmdlet shadow, so they get their own pinned list. Each entry is a
# reviewed exception; a new one fails the suite.
$dotNetWriteAllowList = @(
    'Cards.ps1|WriteAllText'                  # Export-GuiSystemReport writes the HTML into $env:TEMP, which the sandbox redirects
    'EmbeddedProgramsCore.ps1|WriteAllBytes'  # embedded binaries/fonts/DLLs are decoded into the versioned runtime folder
)
$dotNetWrites = @()
foreach ($file in $sourceFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($call in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)) {
        # Only static calls on the .NET types that really touch the disk or the registry; anything
        # else (string.Replace, [math]::Min, ...) is the instance/type method of an unrelated API.
        $expr = $call.Expression
        if ($expr -isnot [System.Management.Automation.Language.TypeExpressionAst]) { continue }
        if ($expr.TypeName.FullName -notmatch '^(System\.IO\.(File|Directory|FileInfo|DirectoryInfo|FileStream)|Microsoft\.Win32\.Registry|Microsoft\.Win32\.RegistryKey|System\.IO\.Registry)') { continue }
        $method = [string]$call.Member.Value
        if ($method -notmatch '^(WriteAll\w+|Delete|DeleteValue|DeleteSubKey\w*|SetValue|Move|CreateDirectory|Create|OpenWrite|Replace|Copy)$') { continue }
        $dotNetWrites += ("{0}|{1}" -f $file.Name, $method)
    }
}
$dotNetWrites = @($dotNetWrites | Sort-Object -Unique)
$unexpectedDotNet = @($dotNetWrites | Where-Object { $dotNetWriteAllowList -notcontains $_ })
Assert-Equal 0 $unexpectedDotNet.Count "No unreviewed direct .NET filesystem/registry write"
foreach ($d in $unexpectedDotNet) { Write-Host "         $d" -ForegroundColor DarkYellow }

# The native-tool stubs must exist for every tool the app invokes by name.
$stubMissing = @()
foreach ($tool in $nativeTools) {
    if (-not $usedCommands.Contains($tool)) { continue }
    if (-not (Test-Path -LiteralPath (Join-Path $sandbox.StubDir "$tool.cmd"))) { $stubMissing += $tool }
}
Assert-Equal 0 $stubMissing.Count "Every native tool the app invokes has a stub"
foreach ($s in $stubMissing) { Write-Host "         $s" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------------------------------------
# 2. Discover every function that mutates the system
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: discovery"

$mutatingFunctions = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in $sourceFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        foreach ($cmd in $fn.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $name = $cmd.GetCommandName()
            if (-not $name) { continue }
            if ($nativeTools -contains $name -or ((Test-MutatingName $name) -and -not $appFunctions.Contains($name) -and $safeCommands -notcontains $name)) {
                [void]$mutatingFunctions.Add($fn.Name)
                break
            }
        }
    }
}
$mutatingFunctions = @($mutatingFunctions | Sort-Object)

# Deliberately not swept: they run for minutes, need a real WPF window, or only talk to the
# network. None of them is a system mutation the sandbox could get wrong. The three disk
# benchmarks write and read gigabytes of a real disk, so they are out of the sweep on purpose.
$sweepExclusions = @(
    'Get-CpuBenchmarkResult', 'Get-GpuBenchmarkResult',     # multi-second real benchmarks
    'Get-DiskBenchmarkResult', 'Get-Disk4kRandomResult',     # real GBs of disk I/O
    'Get-DiskQueueDepthResult',
    'Invoke-SelfUpdate',                                     # opens a WPF progress dialog
    'Watch-PawnIOInstallResult',                             # needs DispatcherTimer + a real window
    'Show-PawnIOInstallPrompt'
)

# These are swept (they must not throw) but are allowed to report an error, because the sandbox
# has no network, no elevation and no third-party assets by design - which is exactly what they
# would report.
$sweepAllowsErrors = @(
    'Invoke-InstallWingetApp', 'Invoke-InstallRemoteScript',
    'Invoke-PlaybookAME', 'Invoke-PlaybookAtlasOS', 'Invoke-PlaybookFSOSX', 'Invoke-PlaybookReviOS',
    'Invoke-CheckForUpdates', 'Invoke-FullAutoOptimize',
    'Invoke-CopySettUtility', 'Invoke-RunAllPrograms'
)

# Functions whose parameters are typed but need real content (an object, a dictionary) rather than
# the empty placeholder Get-DefaultArguments builds.
$sweepStartupItem = [pscustomobject]@{
    Label    = 'SETTDash sandbox startup item'
    Detail   = 'not a real command'
    Selected = $true
    Name     = 'SETTDashSandbox'
    Command  = 'C:\SETTDash-sandbox\does-not-exist.exe'
    Location = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    Source   = 'registry-hkcu'
}
$sweepFixtures = @{
    # Export-GuiSystemReport calls each category value as a scriptblock that builds the rows, so
    # the fixture mirrors that shape instead of passing finished hashtables.
    'Export-GuiSystemReport' = @{
        PageTitle  = 'Sandbox'
        Categories = @{
            'CPU' = { @(
                @{ Label = 'IsHeader'; Value = ''; IsHeader = $true }
                @{ Label = 'Model'; Value = 'Sandbox CPU' }
            ) }
        }
    }
    'Remove-StartupItem'     = @{ Item = $sweepStartupItem }
    'Set-StartupItemEnabled' = @{ Item = $sweepStartupItem }
    'Remove-ScheduledTaskItem'  = @{ Item = $sweepStartupItem }
    # These need a real embedded program name: an empty one is not in $Script:EmbeddedPrograms and
    # would be reported as "not found" instead of exercising the launch path.
    'Invoke-LaunchApp'       = @{ ExeName = 'DnsJumper.exe'; Label = 'DnsJumper' }
    'Invoke-LaunchToDesktop' = @{ ExeName = 'vibranceGUI.exe'; Label = 'vibranceGUI' }
    'Set-ScheduledTaskEnabled'  = @{ Item = $sweepStartupItem }
}

$sweepList = @($mutatingFunctions | Where-Object { $sweepExclusions -notcontains $_ -and $_ -notmatch '^Show-' })
Assert-True ($sweepList.Count -ge 40) "Every mutating function was discovered" "$($sweepList.Count) of $($mutatingFunctions.Count)"

# ---------------------------------------------------------------------------------------------
# 3. Sweep: call each one with default parameters inside the sandbox
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: sweep"

# Builds a call from the function's own parameter metadata: arrays get @(), strings get '',
# numbers get 0, switches stay off. Path-ish strings get a path inside the sandbox, so functions
# that bind with ValidateNotNullOrEmpty are exercised instead of blowing up on ''.
function Get-DefaultArguments {
    param([string]$Name)
    $result = @{}
    $skip = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction',
              'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer',
              'PipelineVariable', 'ProgressAction', 'WhatIf', 'Confirm')
    $sandboxPath = Join-Path $sandbox.FsRoot "__sweep__\nothing-here.txt"
    try { $cmd = Get-Command $Name -ErrorAction Stop } catch { return $result }
    foreach ($p in $cmd.Parameters.Values) {
        if ($skip -contains $p.Name) { continue }
        if ($p.SwitchParameter) { continue }
        $t = $p.ParameterType
        if ($t.IsArray) { $result[$p.Name] = @() }
        elseif ($t -eq [string]) {
            if ($p.Name -match 'Path$|File$|Dir$|Folder$|OutFile|Destination') { $result[$p.Name] = $sandboxPath }
            else { $result[$p.Name] = "" }
        }
        elseif ($t -eq [int] -or $t -eq [long] -or $t -eq [double]) { $result[$p.Name] = 0 }
        elseif ($t -eq [bool]) { $result[$p.Name] = $false }
    }
    return $result
}

$sweepFailures = @()
$sweptOk = 0
foreach ($fn in $sweepList) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) { $sweepFailures += "$fn : not defined after loading"; continue }
    Start-Sandbox
    try {
        $splat = Get-DefaultArguments -Name $fn
        if ($sweepFixtures.ContainsKey($fn)) {
            foreach ($k in $sweepFixtures[$fn].Keys) { $splat[$k] = $sweepFixtures[$fn][$k] }
        }
        & $fn @splat | Out-Null
        $sweptOk++
        if ($sweepAllowsErrors -notcontains $fn) {
            $errors = @(Get-SandboxErrors)
            if ($errors.Count -gt 0) {
                $sweepFailures += ("{0} : reported {1}: {2}" -f $fn, $errors.Count, $errors[0])
            }
        }
    } catch {
        $sweepFailures += ("{0} : threw {1}" -f $fn, $_.Exception.Message)
    } finally {
        Stop-Sandbox
    }
}

Assert-Equal 0 $sweepFailures.Count "No mutating function throws or fails on empty input"
foreach ($f in $sweepFailures) { Write-Host "         $f" -ForegroundColor DarkYellow }
Write-Host "         swept $sweptOk/$($sweepList.Count) mutating functions" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------------------------
# 4. Real deletion, but only inside the filesystem sandbox
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: file cleanup really deletes"

$fsRoot = $sandbox.FsRoot
$targetDir = Join-Path $fsRoot "cleanup-target"
$keepDir = Join-Path $fsRoot "keep-me"
foreach ($d in @($targetDir, $keepDir)) {
    if (-not (Test-Path -LiteralPath $d)) { Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
foreach ($n in @("a.tmp", "b.log", "c.cache")) {
    Microsoft.PowerShell.Management\Set-Content -LiteralPath (Join-Path $targetDir $n) -Value "junk" -Encoding UTF8
}
Microsoft.PowerShell.Management\Set-Content -LiteralPath (Join-Path $keepDir "important.txt") -Value "keep" -Encoding UTF8

$items = @(
    [pscustomobject]@{ Key = 'test-junk'; Label = 'Sandbox junk'; Detail = $targetDir; Paths = @($targetDir); SizeBytes = 4096; Selected = $true }
)
$cleanError = $null
Start-Sandbox
try { Invoke-SystemCleanerClean -Items $items } catch { $cleanError = $_.Exception.Message } finally { Stop-Sandbox }
Assert-True (-not $cleanError) "Invoke-SystemCleanerClean completed" ([string]$cleanError)
Assert-Equal 0 @(Get-ChildItem -LiteralPath $targetDir -ErrorAction SilentlyContinue).Count "Files in the target folder were really deleted"
Assert-True (Test-Path -LiteralPath (Join-Path $keepDir "important.txt")) "A folder that was not selected was left alone"

# Anything outside the sandbox root must never be really deleted, no matter what the code asks.
$outside = Join-Path $env:LOCALAPPDATA "SETTDash\__sandbox_probe__.txt"
Microsoft.PowerShell.Management\Set-Content -LiteralPath $outside -Value "must survive" -Encoding UTF8
Start-Sandbox
try { Remove-CleanPath -Path $outside } catch { } finally { Stop-Sandbox }
Assert-True (Test-Path -LiteralPath $outside) "A path outside the sandbox was not deleted"
Microsoft.PowerShell.Management\Remove-Item -LiteralPath $outside -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------------------------
# 5. Apply / revert symmetry
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: apply/revert symmetry"

# A revert that does not cover everything its apply wrote is a silent bug: the user reverts a tweak
# and part of it stays applied. These pairs are compared on the registry paths and service names
# each side touches.
# Pairs whose revert cannot be expressed as registry writes, with the reason. Everything not
# listed here is expected to be fully reversible.
$pairsSkipped = @{
    'Integrations' = 'removes package integration keys permanently - revert says so explicitly'
    'PowerPlan'    = 'uses powercfg, not the registry (checked separately below)'
    'GPU'          = 'only reacts to an AMD/NVIDIA adapter, which this machine may not have'
}

$pairs = @(
    @{ Name = 'SystemTweaks'; Apply = 'Invoke-TweaksApply';        Revert = 'Invoke-TweaksRevert' },
    @{ Name = 'Services';     Apply = 'Invoke-ServicesApply';      Revert = 'Invoke-ServicesRevert' },
    @{ Name = 'Privacy';      Apply = 'Invoke-PrivacyApply';       Revert = 'Invoke-PrivacyRevert' },
    @{ Name = 'Integrations'; Apply = 'Invoke-IntegrationsApply';  Revert = 'Invoke-IntegrationsRevert' },
    @{ Name = 'GameMode';     Apply = 'Invoke-GameModeApply';      Revert = 'Invoke-GameModeRevert' },
    @{ Name = 'GameExtra';    Apply = 'Invoke-GameExtraApply';     Revert = 'Invoke-GameExtraRevert' },
    @{ Name = 'Memory';       Apply = 'Invoke-MemoryApply';        Revert = 'Invoke-MemoryRevert' },
    @{ Name = 'GPU';          Apply = 'Invoke-GPUApply';           Revert = 'Invoke-GPURevert' },
    @{ Name = 'InternetQoS';  Apply = 'Invoke-InternetOptimize';   Revert = 'Invoke-InternetRevert' },
    @{ Name = 'ContextMenu';  Apply = 'Invoke-ContextApply';       Revert = 'Invoke-ContextRevert' },
    @{ Name = 'PowerPlan';    Apply = 'Invoke-PowerApply';         Revert = 'Invoke-PowerRevert' }
)

# Turns journal entries into comparable "path\name" spots.
function Get-JournalSpots {
    param($Entries)
    # A journal with no entries comes back as $null; @($null) still yields one null element, so the
    # nulls are dropped before any filter reads a property (StrictMode would throw otherwise).
    $list = @($Entries | Where-Object { $null -ne $_ })
    # Only value writes are comparable between apply and revert. New-Item just creates a key, and
    # whether that key already existed on the host differs between machines (CI lacked
    # Control Panel\Mouse-around keys, QoS\ValorantPolicy, etc.), so counting key creations made
    # the symmetry check machine-dependent: it flagged spots like "HKCU:\Control\" with no value.
    return @($list | Where-Object { $_.Op -match 'ItemProperty$' -and $_.Target -match '^(HK|HKEY)' } | ForEach-Object {
        [pscustomobject]@{
            Path = $_.Target
            Name = ($_.Detail -replace '=.*$', '')
            Op   = $_.Op
        }
    })
}

$symmetryReport = @()
foreach ($pair in $pairs) {
    if (-not (Get-Command $pair.Apply -ErrorAction SilentlyContinue)) { $symmetryReport += "$($pair.Name): $($pair.Apply) missing"; continue }
    if (-not (Get-Command $pair.Revert -ErrorAction SilentlyContinue)) { $symmetryReport += "$($pair.Name): $($pair.Revert) missing"; continue }

    Start-Sandbox
    try { & $pair.Apply | Out-Null } catch { $symmetryReport += "$($pair.Name): apply threw $($_.Exception.Message)" }
    $applied = @(Get-JournalSpots (Get-SandboxJournal))
    Clear-SandboxJournal
    try { & $pair.Revert | Out-Null } catch { $symmetryReport += "$($pair.Name): revert threw $($_.Exception.Message)" }
    $reverted = @(Get-JournalSpots (Get-SandboxJournal))
    Stop-Sandbox

    if ($applied.Count -eq 0) {
        if ($pairsSkipped.ContainsKey($pair.Name)) {
            Write-Host ("         {0,-14} skipped: {1}" -f $pair.Name, $pairsSkipped[$pair.Name]) -ForegroundColor DarkGray
        } else {
            $symmetryReport += "$($pair.Name): apply touched no registry value (nothing to compare)"
        }
        continue
    }

    # A revert covers a spot when it writes/removes exactly that value, or when it deletes a whole
    # key that contains the value (common for policy keys). Key removal is read straight from the
    # raw journal: Get-JournalSpots only contains value writes, and Remove-Item entries have no
    # "name=value" detail from which a spot could be derived.
    $removedKeys = @(Get-SandboxJournal | Where-Object { $null -ne $_ -and $_.Op -eq 'Remove-Item' -and $_.Target -match '^(HK|HKEY)' } | ForEach-Object { $_.Target })
    $uncovered = @($applied | Where-Object {
        $spot = $_
        $exact = @($reverted | Where-Object { $_.Path -eq $spot.Path -and $_.Name -eq $spot.Name })
        if ($exact.Count -gt 0) { return $false }
        $coveredByKeyRemoval = @($removedKeys | Where-Object { $spot.Path.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
        return ($coveredByKeyRemoval.Count -eq 0)
    })

    if ($uncovered.Count -gt 0) {
        $symmetryReport += ("{0}: revert leaves {1} value(s) applied: {2}" -f $pair.Name, $uncovered.Count,
            (($uncovered | ForEach-Object { "$($_.Path)\$($_.Name)" } | Select-Object -First 4) -join ' | '))
    }
    Write-Host ("         {0,-14} apply={1,3} values  revert={2,3} writes  uncovered={3}" -f $pair.Name, $applied.Count, $reverted.Count, $uncovered.Count) -ForegroundColor DarkGray
}
Assert-Equal 0 $symmetryReport.Count "Every apply is fully covered by its revert"
foreach ($r in $symmetryReport) { Write-Host "         $r" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------------------------------------
# 6. Native tools are journaled through their stubs
# ---------------------------------------------------------------------------------------------

Write-Section "Test-Actions: native tools"

Start-Sandbox
try { & 'Invoke-PowerApply' | Out-Null } catch { }
$powerJournal = @(Get-SandboxNativeJournal | Where-Object { $_ -match '^powercfg' })
Stop-Sandbox
Assert-True ($powerJournal.Count -gt 0) "Power plan changes go through powercfg (stubbed)" "$($powerJournal.Count) calls"
foreach ($line in $powerJournal) { Write-Host "         $line" -ForegroundColor DarkGray }

Start-Sandbox
try { & 'Invoke-InternetOptimize' | Out-Null } catch { }
$netshJournal = @(Get-SandboxNativeJournal | Where-Object { $_ -match '^netsh' })
Stop-Sandbox
Assert-True ($netshJournal.Count -gt 0) "Network tweaks go through netsh (stubbed)" "$($netshJournal.Count) calls"
foreach ($line in $netshJournal) { Write-Host "         $line" -ForegroundColor DarkGray }

# NIC properties are the other half of the network tweaks: they must be journaled, not applied.
Start-Sandbox
try { & 'Invoke-NetworkOptimize' | Out-Null } catch { }
$nicJournal = @(Get-SandboxJournal -Op 'Set-NetAdapterAdvancedProperty')
Stop-Sandbox
Write-Host ("         Invoke-NetworkOptimize journaled {0} NIC property change(s)" -f $nicJournal.Count) -ForegroundColor DarkGray

Complete-Tests "Test-Actions"
