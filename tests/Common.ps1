# Shared helpers for the test scripts in this folder.
# Each test runs as its own process (tests\Run-All.ps1) and exits 0 when everything passed,
# 1 when at least one assertion failed. Nothing here touches the real user profile except the
# read-only app paths described in each test.

$script:TestFailures = 0
$script:TestChecks = 0

# Prints a section header so the console output of a failing run is easy to scan.
function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

# Records the outcome of one assertion. $Name is what appears in the summary; include the
# concrete values in $Detail so a CI log explains the failure without re-running anything.
function Assert-True {
    param([bool]$Condition, [string]$Name, [string]$Detail = "")
    $script:TestChecks++
    if ($Condition) {
        Write-Host "  [ok]   $Name" -ForegroundColor DarkGray
        return
    }
    $script:TestFailures++
    $suffix = if ($Detail) { " -> $Detail" } else { "" }
    Write-Host "  [FAIL] $Name$suffix" -ForegroundColor Red
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    $ok = ("$Expected" -eq "$Actual")
    Assert-True $ok $Name ("expected '$Expected', got '$Actual'")
}

# Runs $Action and fails when it throws. Used for the "must not raise" cases (empty selection,
# null collections, strict-mode property access).
function Assert-NoThrow {
    param([scriptblock]$Action, [string]$Name)
    $script:TestChecks++
    try {
        & $Action | Out-Null
        Write-Host "  [ok]   $Name" -ForegroundColor DarkGray
    } catch {
        $script:TestFailures++
        Write-Host "  [FAIL] $Name -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Final summary + process exit code. Called at the end of every test script.
function Complete-Tests {
    param([string]$Suite)
    Write-Host ""
    if ($script:TestFailures -eq 0) {
        Write-Host "${Suite}: $script:TestChecks checks passed." -ForegroundColor Green
        exit 0
    }
    Write-Host "${Suite}: $script:TestFailures of $script:TestChecks checks FAILED." -ForegroundColor Red
    exit 1
}
