# Generic helper to apply a batch of registry settings: iterates $Settings (each with Path/Name/
# Type/Value), creating missing keys as needed, updates the progress bar per item, and logs a
# summary of how many succeeded/failed. Used by most Invoke-*Apply functions in Core/Actions.ps1.
function Invoke-RegistryApply {
    param([array]$Settings, [string]$Label)
    $total = $Settings.Count
    $applied = 0; $failed = 0
    for ($i = 0; $i -lt $total; $i++) {
        $s = $Settings[$i]
        Set-GuiProgress ([math]::Round(($i+1)/$total*100)) "$Label : $($i+1)/$total"
        try {
            if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            New-ItemProperty -Path $s.Path -Name $s.Name -PropertyType $s.Type -Value $s.Value -Force -ErrorAction SilentlyContinue | Out-Null
            $applied++
        } catch { $failed++ }
    }
    Set-GuiProgress 0
    Write-GuiLog "$Label : $applied applied, $failed failed" "OK"
    return @{Applied=$applied; Failed=$failed}
}
