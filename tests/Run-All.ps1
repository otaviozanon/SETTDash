# Run-All.ps1
# Runs every test in this folder, each in its own powershell.exe process (so a crash or an exit in
# one test cannot hide or abort the others), prints a summary and exits 1 when anything failed.
#
# This is the gate to run after ANY code change and before committing / publishing a new version:
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-All.ps1
#
# Order matters: cheap static checks first, the compiled smoke sweep last.

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$SkipSmoke,
    [int]$SmokeTimeoutSeconds = 420
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path

$suites = @(
    @{ Name = "Build";       File = "Test-Build.ps1";        Timeout = 300;  Description = "Build.ps1 output: parses, contracts, no duplicate functions, no debug leftovers" }
    @{ Name = "StaticGuards";File = "Test-StaticGuards.ps1"; Timeout = 300;  Description = "Regressions from v3.2.31: `$null.Count, .CimClass, ConvertFrom-Json, FirstChance hook" }
    @{ Name = "StrictMode";  File = "Test-StrictMode.ps1";   Timeout = 600;  Description = "Data layer under StrictMode Latest: empty scans, corrupt cache, real machine scans" }
    @{ Name = "Smoke";       File = "Test-Smoke.ps1";        Timeout = 900;  Description = "Compiled x64 exe: walks all pages, clicks every Scan, asserts no crash and no error report" }
)

if ($SkipSmoke) { $suites = @($suites | Where-Object { $_.Name -ne "Smoke" }) }

$results = New-Object System.Collections.ArrayList
$startedAt = Get-Date

Write-Host ""
Write-Host "SETTDash test suite" -ForegroundColor Cyan
Write-Host "  repo: $RepoRoot"
Write-Host "  suites: $(@($suites | ForEach-Object { $_.Name }) -join ', ')"
Write-Host "  started: $($startedAt.ToString('yyyy-MM-dd HH:mm:ss'))"

foreach ($suite in $suites) {
    $path = Join-Path $PSScriptRoot $suite.File
    Write-Host ""
    Write-Host ("-" * 72)
    Write-Host ">> $($suite.Name): $($suite.Description)" -ForegroundColor Cyan
    Write-Host ("-" * 72)

    $suiteStart = Get-Date
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $path, "-RepoRoot", $RepoRoot)
    if ($suite.Name -eq "Smoke") { $arguments += @("-TimeoutSeconds", "$SmokeTimeoutSeconds", "-KeepArtifacts") }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = ($arguments | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join " "
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $timedOut = -not $proc.WaitForExit($suite.Timeout * 1000)
    if ($timedOut) {
        try { $proc.Kill() } catch { }
        try { [void]$proc.WaitForExit(10000) } catch { }
    }
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    $code = if ($timedOut) { -1 } else { $proc.ExitCode }
    $proc.Dispose()

    Write-Host $out.TrimEnd()
    if ($err.Trim()) { Write-Host $err.TrimEnd() -ForegroundColor DarkYellow }

    $passed = (-not $timedOut) -and ($code -eq 0)
    [void]$results.Add([pscustomobject]@{
        Suite    = $suite.Name
        Passed   = $passed
        ExitCode = $code
        TimedOut = $timedOut
        Seconds  = [math]::Round(((Get-Date) - $suiteStart).TotalSeconds, 1)
    })
}

$elapsed = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
$failed = @($results | Where-Object { -not $_.Passed })

Write-Host ""
Write-Host ("=" * 72)
Write-Host "SUMMARY" -ForegroundColor Cyan
foreach ($r in $results) {
    $status = if ($r.Passed) { "PASS" } else { if ($r.TimedOut) { "TIMEOUT" } else { "FAIL" } }
    $color = if ($r.Passed) { "Green" } else { "Red" }
    Write-Host ("  {0,-12} {1,-8} exit={2,-3} {3,6} s" -f $r.Suite, $status, $r.ExitCode, $r.Seconds) -ForegroundColor $color
}
Write-Host ("  total: {0} s" -f $elapsed)

if ($failed.Count -eq 0) {
    Write-Host ""
    Write-Host "ALL TESTS PASSED - safe to commit / publish." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "$($failed.Count) SUITE(S) FAILED - do not publish a release yet." -ForegroundColor Red
exit 1
