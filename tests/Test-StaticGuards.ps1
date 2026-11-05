# Test-StaticGuards.ps1
# Static checks for the three bug classes that reached the user in v3.2.31/v3.2.32 and could not be
# caught by a syntax check. Each guard encodes a rule that the fixes follow; breaking the rule in a
# new page or action fails this test before anything is compiled.
#
#   1. $null.Count      - a collection-returning function that yields nothing returns $null, and
#                         $null.Count throws under Set-StrictMode -Version Latest.
#   2. .CimClass        - scheduled-task triggers/actions do not all expose CimClass, and reading it
#                         inside a nested pipeline overflowed the stack in the compiled host.
#   3. @( ... | ConvertFrom-Json ) - ConvertFrom-Json emits a top-level JSON array as ONE object, so
#                         wrapping the pipeline in @() yields a single-element array of arrays
#                         (silently dropping every record read from that file).
#
# It reads the repository sources only: nothing is built, executed, or modified.

[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")

$sourceFiles = @(
    Get-ChildItem -Path $RepoRoot -Recurse -Include *.ps1 -File |
        Where-Object {
            $_.Name -notmatch '^SETTDash' -and
            $_.FullName -notmatch '\\tests\\' -and
            $_.FullName -notmatch '\\\.git\\'
        }
)
Assert-True ($sourceFiles.Count -gt 50) "Source tree was found" "$($sourceFiles.Count) .ps1 files under $RepoRoot"

# ---------------------------------------------------------------------------------------------
# 1. Collection-returning functions must be wrapped in @() before .Count / .Length / [0]
# ---------------------------------------------------------------------------------------------

Write-Section "Test-StaticGuards: $null.Count"

# A function counts as collection-returning when its body builds an array ($x = @() ... +=) or
# returns an array literal. Detected from the AST, so new helper functions are covered automatically.
$collectionFunctions = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in $sourceFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $body = $fn.Body.Extent.Text
        if ($body -match 'return\s+@\(' -or
            ($body -match '=\s*@\(\)' -and $body -match '\+=') -or
            ($body -match '=\s*\@\(\)' -and $body -match 'return\s+\$')) {
            [void]$collectionFunctions.Add($fn.Name)
        }
    }
}
Assert-True ($collectionFunctions.Count -gt 20) "Collection-returning functions detected" "$($collectionFunctions.Count) functions"

$countViolations = @()
foreach ($file in $sourceFiles) {
    $lines = @(Get-Content -Path $file.FullName -Encoding UTF8)

    # Variables assigned from a collection-returning function WITHOUT @() on the same line.
    $unwrapped = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
            $varName = $Matches[1]
            $rhs = $Matches[2]
            if ($rhs -match '@\(') { continue }
            if ($rhs -notmatch '^\(?([A-Za-z][A-Za-z0-9-]*)') { continue }
            if (-not $collectionFunctions.Contains($Matches[1])) { continue }
            $unwrapped += [pscustomobject]@{ Var = $varName; Line = ($i + 1) }
        }
    }

    foreach ($u in $unwrapped) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line.TrimStart().StartsWith('#')) { continue }
            $risky = $line -match "\`$$($u.Var)\.(Count|Length)\b" -or $line -match "\`$$($u.Var)\[0\]"
            if ($risky) {
                $countViolations += "{0}:{1}: `$$($u.Var)` = ... (line {2}) is used as `$$($u.Var).Count/index at line {3}" -f `
                    $file.Name, $u.Line, $u.Line, ($i + 1)
                break
            }
        }
    }
}
Assert-Equal 0 $countViolations.Count "No unwrapped collection result is used with .Count/.Length/[0]"
foreach ($v in $countViolations) { Write-Host "         $v" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------------------------------------
# 2. .CimClass must be read through Get-SafeProp
# ---------------------------------------------------------------------------------------------

Write-Section "Test-StaticGuards: .CimClass"

$cimViolations = @()
foreach ($file in $sourceFiles) {
    $lineNo = 0
    foreach ($line in (Get-Content -Path $file.FullName -Encoding UTF8)) {
        $lineNo++
        if ($line.TrimStart().StartsWith('#')) { continue }
        if ($line -notmatch '\.CimClass') { continue }
        # Allowed only as Get-SafeProp <object> 'CimClass'
        if ($line -match "Get-SafeProp\s+\S+\s+'CimClass'") { continue }
        $cimViolations += "{0}:{1}: {2}" -f $file.Name, $lineNo, $line.Trim()
    }
}
Assert-Equal 0 $cimViolations.Count "CimClass is only read via Get-SafeProp (never as a direct member)"
foreach ($v in $cimViolations) { Write-Host "         $v" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------------------------------------
# 3. @( ... | ConvertFrom-Json ) wraps the array, it does not flatten it
# ---------------------------------------------------------------------------------------------

Write-Section "Test-StaticGuards: ConvertFrom-Json unwrapping"

$jsonViolations = @()
foreach ($file in $sourceFiles) {
    $lineNo = 0
    foreach ($line in (Get-Content -Path $file.FullName -Encoding UTF8)) {
        $lineNo++
        if ($line.TrimStart().StartsWith('#')) { continue }
        if ($line -match '@\([^)]*ConvertFrom-Json') {
            $jsonViolations += "{0}:{1}: {2}" -f $file.Name, $lineNo, $line.Trim()
        }
    }
}
Assert-Equal 0 $jsonViolations.Count "ConvertFrom-Json output is assigned before being wrapped in @()"
foreach ($v in $jsonViolations) { Write-Host "         $v" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------------------------------------
# 4. Runtime files must never live under %TEMP%
# ---------------------------------------------------------------------------------------------

Write-Section "Test-StaticGuards: runtime paths"

$tempViolations = @()
foreach ($file in $sourceFiles) {
    $lineNo = 0
    foreach ($line in (Get-Content -Path $file.FullName -Encoding UTF8)) {
        $lineNo++
        if ($line.TrimStart().StartsWith('#')) { continue }
        # $Script:TempDir holds the embedded font and other files that must survive Full Cleanup.
        if ($line -match '\$Script:TempDir\s*=' -and $line -match '\$env:TEMP\b|\[System\.IO\.Path\]::GetTempPath') {
            $tempViolations += "{0}:{1}: {2}" -f $file.Name, $lineNo, $line.Trim()
        }
    }
}
Assert-Equal 0 $tempViolations.Count "`$Script:TempDir is not created under %TEMP%"
foreach ($v in $tempViolations) { Write-Host "         $v" -ForegroundColor DarkYellow }

Write-Section "Test-StaticGuards: FirstChanceException"

$firstChanceViolations = @()
foreach ($file in $sourceFiles) {
    $lineNo = 0
    foreach ($line in (Get-Content -Path $file.FullName -Encoding UTF8)) {
        $lineNo++
        if ($line.TrimStart().StartsWith('#')) { continue }
        if ($line -match 'add_FirstChanceException') {
            $firstChanceViolations += "{0}:{1}: {2}" -f $file.Name, $lineNo, $line.Trim()
        }
    }
}
# .NET raises a first-chance exception for every failed assembly probe, and in the ps2exe host each
# one re-enters the PowerShell handler synchronously until the stack dies. It crashed the app on
# "Your PC > Disks" (non-admin) and cannot be made safe from script code.
Assert-Equal 0 $firstChanceViolations.Count "No FirstChanceException hook (stack-overflow source in the compiled host)"
foreach ($v in $firstChanceViolations) { Write-Host "         $v" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------------------------------------
# 5. GUI work must stay on the dispatcher: no bare .Show()/.Close() from a background runspace
# ---------------------------------------------------------------------------------------------

Write-Section "Test-StaticGuards: sidebar wiring"

$sidebar = Join-Path $RepoRoot "Sidebar\Sidebar.ps1"
$sidebarText = Get-Content -Path $sidebar -Raw -Encoding UTF8
Assert-True ($sidebarText -match '\$navHandlers\s*=\s*@\{') "Sidebar still exposes `$navHandlers"
$navKeys = [regex]::Matches($sidebarText, '(?m)^\s*"(nav[A-Za-z0-9_]+)"\s*=')
Assert-True ($navKeys.Count -ge 20) "Sidebar wires at least 20 navigation handlers" "$($navKeys.Count) found"
$duplicateNav = @($navKeys | ForEach-Object { $_.Groups[1].Value } | Group-Object | Where-Object { $_.Count -gt 1 })
Assert-Equal 0 $duplicateNav.Count "No navigation key is wired twice"

Complete-Tests "Test-StaticGuards"
