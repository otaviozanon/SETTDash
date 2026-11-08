# Test-StrictMode.ps1
# Runs the data layer of the app (scan / selection / clean functions) under
# Set-StrictMode -Version Latest, with the GUI functions stubbed out, and feeds it the inputs that
# used to crash the compiled exe: empty scans, $null collections, malformed JSON on disk.
#
# This is the regression net for the "Registry Cleaner second scan" crash:
#   The property 'Count' cannot be found on this object. Verify that the property exists.
# Caused by $null.Count when a scan found nothing - PowerShell unrolls an empty array to $null.
# Those functions are called here exactly the way the pages call them.

[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")

Set-StrictMode -Version Latest
# Mirrors the app (Main\Window.ps1). Non-terminating errors stay non-fatal here on purpose: the
# tests care about exceptions (property missing, null dereference), not about access-denied noise
# that the real app already logs.
$ErrorActionPreference = "Continue"

Write-Section "Test-StrictMode: loading data layer"

# GUI stubs: the real ones write to the WPF log panel / progress bar, which do not exist here.
$script:LogLines = New-Object System.Collections.ArrayList
function Write-GuiLog { param([string]$Message, [string]$Type = "INFO") [void]$script:LogLines.Add("$Type $Message") }
function Write-ErrorLog { param([string]$Message) [void]$script:LogLines.Add("ERR $Message") }
function Add-LogBuffer { param([string]$Line) }
function Set-GuiProgress { param([double]$Value, [string]$Status) }
function Clear-GuiLog { }

$loadErrors = @()
foreach ($file in @(
    "Core\Helpers\SystemPaths.ps1",
    "Core\Helpers\CleanList.ps1",
    "Core\Helpers\BackgroundJob.ps1",
    "Core\Actions\Clean\SystemCleanerScan.ps1",
    "Core\Actions\Clean\RegistryCleanerScan.ps1",
    "Core\Actions\Clean\StartupManagerScan.ps1",
    "Core\Actions\Clean\NetworkCleanupScan.ps1"
)) {
    $path = Join-Path $RepoRoot $file
    try { . $path } catch { $loadErrors += "${file}: $($_.Exception.Message)" }
}
Assert-Equal 0 $loadErrors.Count "Data layer loads under StrictMode Latest"
if ($loadErrors.Count -gt 0) { Write-Host "         $($loadErrors -join ' | ')" -ForegroundColor DarkYellow }

# Never touch the real disabled-startups cache: point it at a scratch file and delete it after.
$script:ScratchDir = Join-Path ([System.IO.Path]::GetTempPath()) ("settdash-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -Path $script:ScratchDir -ItemType Directory -Force | Out-Null
$script:StartupDisabledPath = Join-Path $script:ScratchDir "disabled-startups.json"

try {
    Write-Section "Test-StrictMode: Get-CleanSelected (empty selection)"

    $empty = @(Get-CleanSelected $null)
    Assert-Equal 0 $empty.Count "Get-CleanSelected `$null returns an empty array, not `$null"

    $empty = @(Get-CleanSelected @())
    Assert-Equal 0 $empty.Count "Get-CleanSelected @() returns an empty array"

    $items = @(
        [pscustomobject]@{ Label = "a"; Selected = $true }
        [pscustomobject]@{ Label = "b"; Selected = $false }
        [pscustomobject]@{ Label = "c"; Selected = $true }
    )
    Assert-Equal 2 @(Get-CleanSelected $items).Count "Get-CleanSelected keeps only checked rows"

    $noneSelected = @($items | ForEach-Object { $_.Selected = $false; $_ })
    $empty = @(Get-CleanSelected $noneSelected)
    Assert-Equal 0 $empty.Count "Get-CleanSelected with everything unchecked returns an empty array"

    Write-Section "Test-StrictMode: Test-CleanAllSelected"

    Assert-True (-not (Test-CleanAllSelected $null)) "Test-CleanAllSelected `$null is false"
    Assert-True (-not (Test-CleanAllSelected @())) "Test-CleanAllSelected empty list is false"
    Assert-True (-not (Test-CleanAllSelected $items)) "Test-CleanAllSelected partial selection is false"
    Assert-True (-not (Test-CleanAllSelected $noneSelected)) "Test-CleanAllSelected no selection is false"
    Assert-True (Test-CleanAllSelected @([pscustomobject]@{ Selected = $true }, [pscustomobject]@{ Selected = $true })) "Test-CleanAllSelected all-selected is true"

    Write-Section "Test-StrictMode: Format-ByteSize / Get-CleanPathSize"

    Assert-Equal "Empty" (Format-ByteSize 0) "Format-ByteSize 0"
    Assert-Equal "Empty" (Format-ByteSize $null) "Format-ByteSize `$null"
    Assert-Equal "1.5 KB" (Format-ByteSize 1536) "Format-ByteSize 1536"
    Assert-Equal "1 MB" (Format-ByteSize 1048576) "Format-ByteSize 1 MB"

    Assert-Equal 0 (Get-CleanPathSize -Paths @()) "Get-CleanPathSize with no paths"
    Assert-Equal 0 (Get-CleanPathSize -Paths $null) "Get-CleanPathSize with `$null paths"
    Assert-Equal 0 (Get-CleanPathSize -Paths (Join-Path $script:ScratchDir "does-not-exist")) "Get-CleanPathSize on a missing path"

    $sampleFile = Join-Path $script:ScratchDir "sample.bin"
    [System.IO.File]::WriteAllBytes($sampleFile, (New-Object byte[] 2048))
    Assert-Equal 2048 (Get-CleanPathSize -Paths $sampleFile) "Get-CleanPathSize on a file"
    Assert-Equal 4096 (Get-CleanPathSize -Paths @($sampleFile, $sampleFile)) "Get-CleanPathSize sums several paths"

    Write-Section "Test-StrictMode: clean/apply entry points with nothing selected"

    Assert-NoThrow { Invoke-SystemCleanerClean -Items @() } "Invoke-SystemCleanerClean @() does not throw"
    Assert-NoThrow { Invoke-SystemCleanerClean -Items $null } "Invoke-SystemCleanerClean `$null does not throw"
    Assert-NoThrow { Invoke-NetworkCleanupClean -Items @() } "Invoke-NetworkCleanupClean @() does not throw"
    Assert-NoThrow { Invoke-NetworkCleanupClean -Items $null } "Invoke-NetworkCleanupClean `$null does not throw"

    $result = Invoke-RegistryCleanerFix -Items @()
    Assert-True ($null -ne $result) "Invoke-RegistryCleanerFix @() returns a result object"
    Assert-Equal 0 $result['Fixed'] "Invoke-RegistryCleanerFix @() fixed nothing"
    Assert-Equal 0 $result['Failed'] "Invoke-RegistryCleanerFix @() failed nothing"

    # A bogus item must be counted as a failure, not abort the loop or throw out of the function.
    Assert-NoThrow {
        $bad = @([pscustomobject]@{
            Label = "guarded test item"; Detail = "nonexistent"; Selected = $true
            KeyPath = "HKCU:\Software\SETTDash\__test_missing_key__"; ValueName = ''; FixOp = 'delete-key'
        })
        $badResult = Invoke-RegistryCleanerFix -Items $bad
        if ($badResult['Failed'] -ne 1) { throw "expected Failed=1, got $($badResult['Failed'])" }
    } "Invoke-RegistryCleanerFix counts a failing item instead of aborting"

    Write-Section "Test-StrictMode: startup cache (missing / corrupt / malformed)"

    Assert-Equal 0 @(Get-StartupDisabledEntries).Count "Missing disabled-startups cache reads as empty"

    Set-Content -Path $script:StartupDisabledPath -Value '{"not":"an array"}gebroken' -Encoding UTF8
    Assert-NoThrow { $script:x = @(Get-StartupDisabledEntries) } "Corrupt disabled-startups JSON does not throw"
    Assert-Equal 0 @(Get-StartupDisabledEntries).Count "Corrupt disabled-startups JSON reads as empty"

    # Records without Name/Source used to blow up every caller that touched .Name/.Source.
    Set-Content -Path $script:StartupDisabledPath -Encoding UTF8 -Value @'
[
  {"Name":"Good","Command":"C:\\x.exe","Location":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run","Source":"registry-hkcu"},
  {"Name":"NoSource","Command":"C:\\y.exe"},
  {"Command":"C:\\z.exe","Source":"registry-hkcu"},
  {"Name":"","Command":"C:\\w.exe","Source":"registry-hkcu"}
]
'@
    $entries = @(Get-StartupDisabledEntries)
    Assert-Equal 1 $entries.Count "Malformed disabled-startups records are dropped"
    Assert-True ($entries.Count -ge 1) "The valid disabled-startups record survives"
    if ($entries.Count -ge 1) {
        Assert-Equal "Good" (Get-SafeProp $entries[0] 'Name') "The surviving record is the valid one"
    }

    $parsed = ConvertFrom-Json -InputObject (Get-Content $script:StartupDisabledPath -Raw)
    $repaired = @()
    if ($null -ne $parsed) { $repaired = @($parsed) }
    Assert-Equal 1 $repaired.Count "The cache is rewritten without the malformed records"

    Set-StartupDisabledEntries -Entries @()
    Assert-Equal 0 @(Get-StartupDisabledEntries).Count "Empty cache round-trips"

    # One entry used to be serialized as a bare JSON object (not an array); the reader must still
    # accept that old format, otherwise an upgrade silently forgets what the user disabled.
    Set-StartupDisabledEntries -Entries @([pscustomobject]@{ Name = 'One'; Command = 'C:\one.exe'; Location = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Source = 'registry-hkcu' })
    $one = @(Get-StartupDisabledEntries)
    Assert-Equal 1 $one.Count "Single-entry cache round-trips"
    Set-Content -Path $script:StartupDisabledPath -Encoding UTF8 -Value '{"Name":"Legacy","Command":"C:\\legacy.exe","Location":"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run","Source":"registry-hkcu"}'
    $legacy = @(Get-StartupDisabledEntries)
    Assert-Equal 1 $legacy.Count "Legacy single-object cache file is still read"
    Assert-Equal "Legacy" (Get-SafeProp $legacy[0] 'Name') "Legacy record keeps its name"

    Write-Section "Test-StrictMode: live scans (read-only, real machine data)"

    $startup = @()
    Assert-NoThrow { $script:startup = @(Get-StartupManagerItems) } "Get-StartupManagerItems does not throw"
    $startup = @($script:startup)
    $badStartup = @($startup | Where-Object {
        -not (Get-SafeProp $_ 'Label') -or -not (Get-SafeProp $_ 'Name') -or -not (Get-SafeProp $_ 'Source')
    })
    Assert-Equal 0 $badStartup.Count "Every startup item exposes Label/Name/Source"
    $allowedSources = @('registry-hkcu', 'registry-hklm', 'startup-folder', 'task-scheduler')
    $badSources = @($startup | Where-Object { $allowedSources -notcontains (Get-SafeProp $_ 'Source') })
    Assert-Equal 0 $badSources.Count "Every startup item has a known Source"
    Assert-Equal 0 @($startup | Where-Object { (Get-SafeProp $_ 'Selected') -isnot [bool] }).Count "Startup items expose a bool Selected flag"

    $services = @()
    Assert-NoThrow { $script:services = @(Get-ServiceItems) } "Get-ServiceItems does not throw"
    $services = @($script:services)
    $badServices = @($services | Where-Object {
        -not (Get-SafeProp $_ 'Label') -or -not (Get-SafeProp $_ 'Name') -or (Get-SafeProp $_ 'Source') -ne 'service'
    })
    Assert-Equal 0 $badServices.Count "Every service item exposes Label/Name and the service Source"
    Assert-Equal 0 @($services | Where-Object { (Get-SafeProp $_ 'Selected') -isnot [bool] }).Count "Service items expose a bool Selected flag"
    Assert-Equal 0 @($services | Where-Object {
        [string](Get-SafeProp $_ 'Location') -notmatch '^HKLM:\\SYSTEM\\CurrentControlSet\\Services\\'
    }).Count "Every service points at its Services key"
    Assert-Equal 0 @($services | Where-Object { @(2, 3) -notcontains (Get-SafeProp $_ 'PreviousStart') }).Count "Service items carry a restore start type"
    $allServices = @()
    Assert-NoThrow { $script:allServices = @(Get-ServiceItems -IncludeMicrosoft) } "Get-ServiceItems -IncludeMicrosoft does not throw"
    Assert-True (@($script:allServices).Count -gt $services.Count) "The Microsoft filter removes services by default"

    $tasks = @()
    Assert-NoThrow { $script:tasks = @(Get-ScheduledTaskItems) } "Get-ScheduledTaskItems does not throw"
    $tasks = @($script:tasks)
    Assert-True ($tasks.Count -gt 0) "Scheduled Items scan returns third-party tasks"
    Assert-Equal 0 @($tasks | Where-Object { (Get-SafeProp $_ 'Location') -match '^\\Microsoft\\' }).Count "Scheduled Items never lists Microsoft tasks"

    $registry = @()
    Assert-NoThrow { $script:registry = @(Get-RegistryCleanerItems) } "Get-RegistryCleanerItems does not throw with any number of issues"
    $registry = @($script:registry)
    Assert-Equal 0 @($registry | Where-Object {
        -not (Get-SafeProp $_ 'KeyPath') -or -not (Get-SafeProp $_ 'FixOp')
    }).Count "Every registry issue exposes KeyPath and FixOp"
    Assert-Equal 0 @($registry | Where-Object { Get-SafeProp $_ 'Selected' }).Count "Registry scan starts with nothing selected"

    $system = @()
    Assert-NoThrow { $script:system = @(Get-SystemCleanerItems) } "Get-SystemCleanerItems does not throw"
    $system = @($script:system)
    Assert-Equal 14 $system.Count "System Cleaner still reports its 14 categories"
    Assert-Equal 0 @($system | Where-Object { $null -eq (Get-SafeProp $_ 'SizeBytes') }).Count "Every system category has a size"
    Assert-Equal 0 @($system | Where-Object { Get-SafeProp $_ 'Selected' }).Count "System Cleaner scan starts with nothing selected"

    Assert-NoThrow { $script:network = @(Get-NetworkCleanupItems) } "Get-NetworkCleanupItems does not throw"
    Assert-Equal 0 @($script:network | Where-Object { Get-SafeProp $_ 'Selected' }).Count "Network Cleanup scan starts with nothing selected"

    Write-Section "Test-StrictMode: background job function bundle"

    # Get-GuiFunctionBundle copies app functions into the job runspace. It must never copy a module
    # proxy: ScheduledTasks exports Get-ScheduledTask as a function, and re-defining it that way
    # shadows the cmdlet and makes every scheduled-task scan return an empty list.
    $bundle = Get-GuiFunctionBundle -Names @('Get-ScheduledTaskItems')
    Assert-True ($bundle -notmatch '(?m)^function Get-ScheduledTask\s*\{') "Bundle does not copy the ScheduledTasks proxy Get-ScheduledTask"
    Assert-True ($bundle -match '(?m)^function Get-ScheduledTaskItems\s*\{') "Bundle contains the requested app function"

    $serviceBundle = Get-GuiFunctionBundle -Names @('Get-ServiceItems')
    Assert-True ($serviceBundle -match '(?m)^function Get-ServiceItems\s*\{') "Service bundle contains the requested app function"
    Assert-True ($serviceBundle -match '(?m)^function Test-MicrosoftServicePath\s*\{') "Service bundle carries its Microsoft-path helper"
    Assert-True ($serviceBundle -match '(?m)^function Get-ServiceExecutablePath\s*\{') "Service bundle carries its executable-path helper"

    Write-Section "Test-StrictMode: helpers"

    Assert-True ($null -eq (Get-SafeProp $null 'Anything')) "Get-SafeProp `$null returns `$null"
    Assert-True ($null -eq (Get-SafeProp ([pscustomobject]@{ A = 1 }) 'B')) "Get-SafeProp missing property returns `$null"
    Assert-Equal 1 (Get-SafeProp ([pscustomobject]@{ A = 1 }) 'A') "Get-SafeProp reads an existing property"

    $regExe = Get-SystemToolPath "reg.exe"
    Assert-True ($regExe -and (Test-Path $regExe)) "Get-SystemToolPath resolves reg.exe" "$regExe"
    Assert-True ($null -eq (Get-SystemToolPath "definitely-not-a-tool.exe")) "Get-SystemToolPath returns `$null for a missing tool"
    Assert-True ((Get-ProgramFiles64Path) -like "*Program Files*") "Get-ProgramFiles64Path returns a Program Files path" (Get-ProgramFiles64Path)

    Write-Section "Test-StrictMode: no unexpected error reports"

    # The stub above swallows Write-ErrorLog, so a bug would be invisible here. Instead assert that
    # nothing logged an ERR line: the scans must be silent on a healthy machine.
    $errLines = @($script:LogLines | Where-Object { $_ -like "ERR *" -and $_ -notmatch "guarded test item" })
    Assert-Equal 0 $errLines.Count "Scans produced no ERR log lines"
    if ($errLines.Count -gt 0) { Write-Host "         $($errLines -join ' | ')" -ForegroundColor DarkYellow }

    # An assertion whose own expression throws (e.g. reading .Count on $null) never reaches
    # Assert-Equal, so it would be silently skipped and the run would still report success.
    # Any uncaught error attributed to THIS file is therefore a test bug and must fail the suite.
    $selfErrors = @($Error | Where-Object {
        $_.InvocationInfo -and $_.InvocationInfo.ScriptName -eq $PSCommandPath
    })
    Assert-Equal 0 $selfErrors.Count "No assertion raised an unexpected error"
    if ($selfErrors.Count -gt 0) {
        Write-Host "         $(($selfErrors | ForEach-Object { $_.Exception.Message }) -join ' | ')" -ForegroundColor DarkYellow
    }
} finally {
    if (Test-Path $script:ScratchDir) { Remove-Item $script:ScratchDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Complete-Tests "Test-StrictMode"
