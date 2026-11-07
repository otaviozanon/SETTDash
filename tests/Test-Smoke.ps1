# Test-Smoke.ps1
# The only test that runs the REAL app in the REAL host: it builds the concatenated script, injects a
# driver that walks every page and clicks every read-only "Scan" button, compiles it with ps2exe
# (-x64, WITHOUT -requireAdmin so no UAC prompt is needed) and then asserts that:
#
#   * the process exits on its own (no stack overflow, no native crash, no hang),
#   * the driver reached the end and reported zero failures,
#   * no error report was written (Core\Helpers\Log.ps1 only writes on a real failure).
#
# Why compile: the three crashes reported from v3.2.31/v3.2.32 only reproduced in the ps2exe host.
# A plain `powershell.exe SETTDash.ps1` run survived the same code, so a non-compiled test proves
# nothing about what the user downloads.
#
# It never touches the release SETTDash.exe: the smoke build goes to tests\.tools\.

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [int]$TimeoutSeconds = 420,
    [string]$Ps2exeModulePath,
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")

$toolsDir = Join-Path $PSScriptRoot ".tools"
if (-not (Test-Path $toolsDir)) { New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null }

$generated = Join-Path $RepoRoot "SETTDash.ps1"
$smokeScript = Join-Path $toolsDir "SETTDash.smoke.ps1"
$smokeExe = Join-Path $toolsDir "SETTDash.smoke.exe"
$markerFile = Join-Path $toolsDir "smoke-marker.txt"
$stdoutFile = Join-Path $toolsDir "smoke-stdout.txt"
$stderrFile = Join-Path $toolsDir "smoke-stderr.txt"
$logDir = Join-Path $env:LOCALAPPDATA "SETTDash\logs"

# The injection is inserted immediately before the message loop starts. Everything inside runs on
# the UI dispatcher (never on a background thread), exactly like a user's click.
$smokeBlock = @'
# ---- SMOKE TEST INJECTION (added by tests\Test-Smoke.ps1 - never present in a release) ----
if ($env:SETTDASH_SMOKE -eq '1') {
    # Some pages render a blocking modal (ShowDialog) whenever an optional component is missing,
    # and nothing ever clicks it - the sweep would hang until the test kills the process. This is
    # exactly what Windows Server CI does with the PawnIO install prompt (no PawnIO driver there),
    # which stopped the page walk right after navYourPCGpu. Redefining the prompt here in the same
    # script scope replaces the app's definition for this run only; a release keeps the real one.
    function Show-PawnIOInstallPrompt { }
    $Window.Dispatcher.BeginInvoke([action]{
        $marker = $env:SETTDASH_SMOKE_MARKER
        $failures = New-Object System.Collections.ArrayList
        $pageCount = 0
        $scanCount = 0
        $selectAllCount = 0

        function Write-SmokeMark {
            param([string]$Text)
            if ($marker) { try { Add-Content -LiteralPath $marker -Value $Text } catch { } }
            Write-Host "SMOKE $Text"
        }

        # Every Button in the window's logical tree. Pages are rebuilt on each navigation, so this
        # must be called again after every navigation.
        function Get-SmokeButtons {
            param($Node)
            $found = New-Object System.Collections.ArrayList
            if (-not $Node) { return $found }
            if ($Node -is [System.Windows.Controls.Button]) { [void]$found.Add($Node) }
            $children = $null
            try { $children = [System.Windows.LogicalTreeHelper]::GetChildren($Node) } catch { $children = $null }
            foreach ($child in @($children)) {
                foreach ($b in @(Get-SmokeButtons $child)) { [void]$found.Add($b) }
            }
            return $found
        }

        function Invoke-SmokePump {
            try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { }
        }

        try {
            Write-SmokeMark "START pid=$PID"
            $navKeys = @($navHandlers.Keys | Sort-Object)
            Write-SmokeMark ("NAVKEYS " + $navKeys.Count)

            foreach ($key in $navKeys) {
                $pageCount++
                try {
                    & $navHandlers[$key]
                    Write-SmokeMark ("PAGE_OK " + $key)
                } catch {
                    [void]$failures.Add("page $key -> $($_.Exception.Message)")
                    Write-SmokeMark ("PAGE_FAIL " + $key + " -> " + $_.Exception.Message)
                    continue
                }
                Invoke-SmokePump

                # Only "Scan" is auto-clicked: it is read-only by design (scan -> checklist), while
                # Fix/Delete/Optimize/Install/Download must never run unattended.
                foreach ($btn in @(Get-SmokeButtons $Window)) {
                    $label = ""
                    try { $label = [string]$btn.Content } catch { }
                    if ($label -ne 'Scan') { continue }
                    $scanCount++
                    try {
                        $btn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent, $btn)))
                        Write-SmokeMark ("SCAN_OK " + $key)
                    } catch {
                        [void]$failures.Add("scan $key -> $($_.Exception.Message)")
                        Write-SmokeMark ("SCAN_FAIL " + $key + " -> " + $_.Exception.Message)
                    }
                    Invoke-SmokePump
                }

                # "Select All" only flips checkboxes (nothing destructive), so it is safe to click
                # unattended. Guards the regression where the button was built but never added to
                # the button panel, so it never showed up on screen.
                foreach ($btn in @(Get-SmokeButtons $Window)) {
                    $label = ""
                    try { $label = [string]$btn.Content } catch { }
                    if ($label -ne 'Select All') { continue }
                    $selectAllCount++
                    try {
                        $btn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent, $btn)))
                        Write-SmokeMark ("SELECTALL_OK " + $key)
                    } catch {
                        [void]$failures.Add("select all $key -> $($_.Exception.Message)")
                        Write-SmokeMark ("SELECTALL_FAIL " + $key + " -> " + $_.Exception.Message)
                    }
                    Invoke-SmokePump
                }
            }
        } catch {
            [void]$failures.Add("driver -> $($_.Exception.Message)")
            Write-SmokeMark ("DRIVER_FAIL -> " + $_.Exception.Message)
        }

        foreach ($f in $failures) { Write-SmokeMark ("FAILURE " + $f) }
        Write-SmokeMark ("COUNTS pages=$pageCount scans=$scanCount selectalls=$selectAllCount")
        Write-SmokeMark ("SMOKE DONE failures=" + $failures.Count)

        # Close, then force the dispatcher to stop even if "Minimize to tray" turned Close() into a
        # Hide(): the process must never outlive the sweep and hang the test.
        try { $Window.Close() } catch { }
        try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() } catch { }
    }) | Out-Null
}
# ---- end SMOKE TEST INJECTION ----
'@

function Resolve-Ps2exeModule {
    param([string]$Explicit)

    $candidates = New-Object System.Collections.ArrayList
    if ($Explicit) { [void]$candidates.Add($Explicit) }
    if ($env:SETTDASH_PS2EXE_MODULE) { [void]$candidates.Add($env:SETTDASH_PS2EXE_MODULE) }
    [void]$candidates.Add((Join-Path $toolsDir "ps2exe\ps2exe.psd1"))
    [void]$candidates.Add((Join-Path $toolsDir "ps2exe\Module\ps2exe.psd1"))
    $localBuild = Join-Path $env:LOCALAPPDATA "opencode-build\ps2exe"
    if (Test-Path $localBuild) {
        foreach ($f in @(Get-ChildItem -Path $localBuild -Recurse -Filter "ps2exe.psd1" -ErrorAction SilentlyContinue)) {
            [void]$candidates.Add($f.FullName)
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
    }

    # Last resort: fetch the pinned commit from GitHub, the same way the release workflow does
    # (the PowerShell Gallery outage is what made the pinned download necessary).
    $sha = "05c62615b33864c177f5de8e56e06e4c7f34adbb"
    Write-Host "  ps2exe not found locally; downloading MScholtes/PS2EXE@$sha ..." -ForegroundColor DarkGray
    $zip = Join-Path $toolsDir "PS2EXE.zip"
    $extract = Join-Path $toolsDir "PS2EXE_extract"
    try {
        Invoke-WebRequest -Uri "https://codeload.github.com/MScholtes/PS2EXE/zip/$sha" -OutFile $zip -UserAgent "SETTDash-tests" -ErrorAction Stop
        if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $extract -Force
        $moduleDir = Get-ChildItem -Path $extract -Recurse -Filter "ps2exe.psm1" | Select-Object -First 1
        if (-not $moduleDir) { throw "ps2exe.psm1 not found in the downloaded archive" }
        $target = Join-Path $toolsDir "ps2exe"
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        New-Item -Path $target -ItemType Directory -Force | Out-Null
        Copy-Item -Path (Join-Path $moduleDir.DirectoryName "*") -Destination $target -Recurse -Force
        $manifest = Join-Path $target "ps2exe.psd1"
        if (Test-Path $manifest) { return $manifest }
        return (Join-Path $target "ps2exe.psm1")
    } finally {
        if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extract) { Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$startedAt = Get-Date
$errorLogsBefore = @{}
if (Test-Path $logDir) {
    foreach ($f in @(Get-ChildItem -Path $logDir -Filter "error-settdash-*.log" -ErrorAction SilentlyContinue)) {
        $errorLogsBefore[$f.FullName] = $f.LastWriteTimeUtc
    }
}

try {
    Write-Section "Test-Smoke: build"

    if (Test-Path $generated) {
        Assert-True $false "No stale SETTDash.ps1 in the repo root" "found $generated - remove it before running the tests"
        Complete-Tests "Test-Smoke"
    }

    $buildOk = $true
    try { & (Join-Path $RepoRoot "Build.ps1") | Out-Null } catch { $buildOk = $false; Write-Host "  build failed: $($_.Exception.Message)" -ForegroundColor Red }
    Assert-True $buildOk "Build.ps1 generated the script"
    if (-not (Test-Path $generated)) { Complete-Tests "Test-Smoke" }

    Write-Section "Test-Smoke: inject driver"

    $text = Get-Content -Path $generated -Raw -Encoding UTF8
    $anchor = $text.LastIndexOf('$Window.Show()')
    Assert-True ($anchor -gt 0) "Anchor '`$Window.Show()' found in the generated script"
    if ($anchor -lt 0) { Complete-Tests "Test-Smoke" }

    $injected = $text.Substring(0, $anchor) + "`r`n" + $smokeBlock + "`r`n" + $text.Substring($anchor)
    Set-Content -Path $smokeScript -Value $injected -Encoding UTF8

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($smokeScript, [ref]$tokens, [ref]$parseErrors)
    $parseDetail = (@($parseErrors) | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join " | "
    Assert-Equal 0 @($parseErrors).Count "Injected script parses"
    if ($parseDetail) { Write-Host "         $parseDetail" -ForegroundColor DarkYellow }

    Write-Section "Test-Smoke: compile (x64, no elevation)"

    $modulePath = $null
    try { $modulePath = Resolve-Ps2exeModule -Explicit $Ps2exeModulePath } catch { Write-Host "  ps2exe unavailable: $($_.Exception.Message)" -ForegroundColor Red }
    Assert-True ([bool]$modulePath) "ps2exe module is available" "$modulePath"
    if (-not $modulePath) { Complete-Tests "Test-Smoke" }

    if (Test-Path $smokeExe) { Remove-Item $smokeExe -Force }
    $compileOk = $true
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) { throw "ps2exe module does not export Invoke-ps2exe" }
        Invoke-ps2exe -inputFile $smokeScript -outputFile $smokeExe -x64 `
            -title "SETTDash smoke" -description "Automated smoke test build" -product "SETTDash" -company "otaviozanon" -version "0.0.0" | Out-Null
    } catch {
        $compileOk = $false
        Write-Host "  compile failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Assert-True $compileOk "ps2exe compiled the smoke build"
    Assert-True (Test-Path $smokeExe) "Smoke executable exists"
    if (-not (Test-Path $smokeExe)) { Complete-Tests "Test-Smoke" }

    # The whole point is to reproduce the compiled host, not an elevated one: UAC cannot be accepted
    # in CI, so the manifest must stay asInvoker (i.e. no -requireAdmin was passed).
    $exeBytes = [System.IO.File]::ReadAllBytes($smokeExe)
    $exeText = [System.Text.Encoding]::ASCII.GetString($exeBytes)
    Assert-True (-not $exeText.Contains("requireAdministrator")) "Smoke build does not require elevation"

    Write-Section "Test-Smoke: run"

    foreach ($f in @($markerFile, $stdoutFile, $stderrFile)) { if (Test-Path $f) { Remove-Item $f -Force } }

    $env:SETTDASH_SMOKE = "1"
    $env:SETTDASH_SMOKE_MARKER = $markerFile
    # Never let the startup update check run here: a release newer than the local build opens a
    # blocking "update available" modal and the unattended sweep would hang until the timeout.
    $env:SETTDASH_NO_UPDATE_CHECK = "1"
    $process = $null
    $timedOut = $false
    $stdout = ""
    $stderr = ""
    $exitCode = -1
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $smokeExe
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()

        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            try { $process.Kill() } catch { }
            try { [void]$process.WaitForExit(10000) } catch { }
        } else {
            $exitCode = $process.ExitCode
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
    } finally {
        Remove-Item Env:\SETTDASH_SMOKE -ErrorAction SilentlyContinue
        Remove-Item Env:\SETTDASH_SMOKE_MARKER -ErrorAction SilentlyContinue
        Remove-Item Env:\SETTDASH_NO_UPDATE_CHECK -ErrorAction SilentlyContinue
        if ($process) { try { $process.Dispose() } catch { } }
        Set-Content -Path $stdoutFile -Value $stdout -Encoding UTF8
        Set-Content -Path $stderrFile -Value $stderr -Encoding UTF8
    }

    Assert-True (-not $timedOut) "Smoke run finished within $TimeoutSeconds s" "timed out and was killed"
    Assert-Equal 0 $exitCode "Smoke process exited with code 0"

    $markerLines = @()
    if (Test-Path $markerFile) { $markerLines = @(Get-Content -Path $markerFile) }
    foreach ($line in $markerLines) { Write-Host "         $line" }

    $stdout = [string]$stdout
    $stderr = [string]$stderr

    Write-Section "Test-Smoke: results"

    Assert-True ($markerLines.Count -gt 0) "The driver produced markers (the app actually started)"
    Assert-True (-not ($stderr -match "StackOverflow|guard page")) "No stack overflow in the compiled host"
    Assert-True (-not ($stdout -match "StackOverflow|guard page")) "No stack overflow on stdout"

    $navKeyCount = 0
    foreach ($line in $markerLines) {
        if ($line -match '^NAVKEYS (\d+)') { $navKeyCount = [int]$Matches[1] }
    }
    Assert-True ($navKeyCount -ge 20) "The driver walked the sidebar navigation" "$navKeyCount keys"

    $pageFailures = @($markerLines | Where-Object { $_ -match '^(PAGE_FAIL|SCAN_FAIL|SELECTALL_FAIL|DRIVER_FAIL)' })
    Assert-Equal 0 $pageFailures.Count "No page, scan or select-all failed"
    foreach ($f in $pageFailures) { Write-Host "         $f" -ForegroundColor DarkYellow }

    $doneLine = @($markerLines | Where-Object { $_ -match '^SMOKE DONE failures=(\d+)' }) | Select-Object -Last 1
    Assert-True ([bool]$doneLine) "The driver reached the end of the sweep" "no 'SMOKE DONE' marker - the process died mid-run"
    if ($doneLine -and $doneLine -match 'failures=(\d+)') {
        Assert-Equal 0 ([int]$Matches[1]) "The sweep reported zero failures"
    }

    $scans = @($markerLines | Where-Object { $_ -match '^SCAN_OK' }).Count
    Assert-True ($scans -ge 3) "Every Scan button was exercised" "$scans scan clicks"

    $selectAlls = @($markerLines | Where-Object { $_ -match '^SELECTALL_OK' }).Count
    Assert-True ($selectAlls -ge 4) "Select All buttons exist and are clickable" "$selectAlls select-all clicks"

    Write-Section "Test-Smoke: no error report"

    $newLogs = @()
    if (Test-Path $logDir) {
        foreach ($f in @(Get-ChildItem -Path $logDir -Filter "error-settdash-*.log" -ErrorAction SilentlyContinue)) {
            $known = $errorLogsBefore.ContainsKey($f.FullName)
            if (-not $known -or $f.LastWriteTimeUtc -gt $startedAt.ToUniversalTime()) { $newLogs += $f.FullName }
        }
    }
    Assert-Equal 0 $newLogs.Count "The run wrote no error report"
    foreach ($f in $newLogs) {
        Write-Host "         report: $f" -ForegroundColor DarkYellow
        try { Get-Content -Path $f | Select-Object -Last 25 | ForEach-Object { Write-Host "         $_" } } catch { }
    }
} finally {
    if (Test-Path $generated) { Remove-Item $generated -Force -ErrorAction SilentlyContinue }
    if (-not $KeepArtifacts) {
        foreach ($f in @($smokeScript, $smokeExe)) {
            if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
        }
    }
}

Complete-Tests "Test-Smoke"
