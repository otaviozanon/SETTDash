$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot\SETTDash.ps1", [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) {
    $parseErrors | ForEach-Object { Write-Host $_.ToString() }
} else {
    Write-Host "OK"
}
