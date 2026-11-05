# Test-Build.ps1
# Runs Build.ps1 (the same concatenation used to produce the release input) and validates the
# generated SETTDash.ps1: it must parse, must contain the runtime/logging contracts the app relies
# on, must not define a function twice, and must not contain any of the debug/autorun hooks that
# were injected while tracking down the v3.2.31 crashes.
#
# It never leaves SETTDash.ps1 behind: the file is deleted at the end (a stale generated script in
# the repo root is how "I fixed it" but the .exe still shipped the old code happens).

[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")

$buildScript = Join-Path $RepoRoot "Build.ps1"
$generated = Join-Path $RepoRoot "SETTDash.ps1"

Write-Section "Test-Build: generate SETTDash.ps1"

if (Test-Path $generated) {
    # Refuse to clobber a hand-edited file: SETTDash.ps1 is generated, so anything sitting there
    # while the tests start is either leftover or manual work. Both must be inspected, not deleted.
    Assert-True $false "No stale SETTDash.ps1 in the repo root" "found $generated - remove it before running the tests"
    Complete-Tests "Test-Build"
}

$buildOutput = $null
$buildError = $null
try {
    $buildOutput = & $buildScript 2>&1
} catch {
    $buildError = $_.Exception.Message
}
Assert-True (-not $buildError) "Build.ps1 completes without throwing" $buildError
Assert-True (Test-Path $generated) "Build.ps1 wrote SETTDash.ps1"

if (-not (Test-Path $generated)) { Complete-Tests "Test-Build" }

try {
    Write-Section "Test-Build: parser"

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($generated, [ref]$tokens, [ref]$parseErrors)
    $errorText = (@($parseErrors) | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join " | "
    Assert-Equal 0 @($parseErrors).Count "Generated script parses with no syntax errors"
    if ($errorText) { Write-Host "         $errorText" -ForegroundColor DarkYellow }

    Write-Section "Test-Build: required contracts"

    $text = Get-Content $generated -Raw

    Assert-True ($text.Contains("function Get-ErrorLogPath")) "Error report path helper is included"
    Assert-True ($text.Contains("SETTDash\runtime")) "Runtime files live under %LOCALAPPDATA%\SETTDash\runtime (not %TEMP%)"
    Assert-True (-not $text.Contains('Join-Path $env:TEMP "SETTDash"')) "No runtime path built under %TEMP%"

    foreach ($fn in @("Get-SystemToolPath", "Start-SystemTool", "Get-ProgramFiles64Path", "Get-InstalledProgramPath")) {
        Assert-True ($text.Contains("function $fn")) "WOW64 path helper $fn is included"
    }

    Assert-True ($text.Contains("New-Object System.Collections.Queue")) "Log ring buffer is initialized"
    Assert-True (-not $text.Contains("add_FirstChanceException")) "No FirstChanceException hook (it overflows the compiled host)"
    Assert-True ($text.Contains("add_UnhandledException")) "Unhandled-exception crash hook is wired"

    Write-Section "Test-Build: no debug leftovers"

    foreach ($marker in @("SETTDASH_SMOKE", "SETTDASH_STARTUPSCAN", "SETTDASH_STARTUPBISECT", "SETTDASH_REGSCAN", "SETTDASH_AUTOCLEAN", "SETTDASH_MARKER")) {
        Assert-True (-not $text.Contains($marker)) "No $marker injection in the generated script"
    }

    Write-Section "Test-Build: no duplicated function definitions"

    # Parse the AST instead of grepping: a concatenation-order mistake shows up as the same function
    # being defined twice, and the later definition silently wins at runtime.
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    $duplicates = $functions |
        Group-Object { $_.Name } |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object { "$($_.Name) x$($_.Count)" }
    Assert-Equal 0 @($duplicates).Count "No function defined more than once"
    if (@($duplicates).Count -gt 0) { Write-Host "         $($duplicates -join ', ')" -ForegroundColor DarkYellow }

    Write-Section "Test-Build: dependency order"

    # SystemPaths.ps1 must be included before the files that call Get-SystemToolPath / Start-SystemTool,
    # otherwise calling them in the compiled exe resolves to nothing.
    $systemPathsAt = $text.IndexOf("function Get-SystemToolPath")
    foreach ($dependent in @("function Invoke-FullCleanup", "function Get-BrowserCacheItems", "function Get-StoreCacheItems", "function Get-RegistryCleanerItems")) {
        $at = $text.IndexOf($dependent)
        if ($at -lt 0) { continue }
        Assert-True ($systemPathsAt -lt $at) "$dependent is defined after the WOW64 helpers"
    }
} finally {
    if (Test-Path $generated) { Remove-Item $generated -Force }
    Assert-True (-not (Test-Path $generated)) "Generated SETTDash.ps1 removed after the test"
}

Complete-Tests "Test-Build"
