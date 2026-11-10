# Used by: Installers, AllInstallers, GpuSoftware, CPU (generic install helpers)
# Installs an app via winget using its package $Id. If $Id is empty, or winget fails/isn't
# available, falls back to opening $FallbackUrl in the browser so the user can install manually.
# Treats winget's "already installed" exit codes as success.
# winget can take minutes, so on the UI thread this runs in a background job (window stays
# responsive, winget output is streamed to the log). Inside a job ($Script:BgWorker) it runs
# inline, so "Install Selected" still installs one app at a time instead of firing all at once.
function Invoke-InstallWingetApp {
    param([string]$Id, [string]$Name, [string]$Source="winget", [string]$FallbackUrl="")
    if (-not $Id) {
        if ($FallbackUrl) {
            Write-GuiLog "Opening $Name website..." "STEP"
            try { Start-Process $FallbackUrl -ErrorAction Stop; Write-GuiLog "$Name download page opened" "OK" }
            catch { Write-GuiLog "Failed to open $Name website: $($_.Exception.Message)" "ERR" }
        }
        else { Write-GuiLog "$Name : no download URL available" "ERR" }
        return
    }
    if (-not (Get-Variable -Name BgWorker -ValueOnly -Scope Script -ErrorAction SilentlyContinue)) {
        [void](Start-GuiBackgroundJob -Work { Invoke-InstallWingetApp -Id $InstallId -Name $InstallName -Source $InstallSource -FallbackUrl $InstallFallbackUrl } `
            -Functions @('Invoke-InstallWingetApp') -Name "Install $Name" `
            -Arguments @{ InstallId = $Id; InstallName = $Name; InstallSource = $Source; InstallFallbackUrl = $FallbackUrl })
        return
    }
    Write-GuiLog "Installing $Name via winget..." "STEP"
    $exitCode = $null
    try {
        $wingetArgs = @("install", "--id=$Id", "--silent", "--accept-source-agreements", "--accept-package-agreements")
        if ($Source -eq "msstore") { $wingetArgs += "--source", "msstore" }
        # Resolve the App Execution Alias before invoking: calling a missing command throws a raw
        # CommandNotFoundException that -ErrorAction cannot suppress on every host.
        $wingetExe = (Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if (-not $wingetExe) { throw "winget not available" }
        # Call it directly instead of Start-Process -Wait so every line winget prints reaches the log
        # while the install is still running.
        & $wingetExe @wingetArgs 2>&1 | ForEach-Object {
            $line = ([string]$_).Trim()
            if ($line) { Write-GuiLog $line "INFO" }
        }
        $exitCode = $LASTEXITCODE
    } catch { Write-GuiLog "Winget error: $($_.Exception.Message)" "WARN" }
    if ($exitCode -eq 0) { Write-GuiLog "$Name installed" "OK"; return }
    if ($exitCode -eq -1978335189 -or $exitCode -eq -1978335215) { Write-GuiLog "$Name already installed" "OK"; return }
    if ($null -ne $exitCode) { Write-GuiLog "Winget failed (code $exitCode), trying fallback..." "WARN" }
    if ($FallbackUrl) {
        Write-GuiLog "Opening $Name website..." "STEP"
        try { Start-Process $FallbackUrl -ErrorAction Stop; Write-GuiLog "$Name download page opened" "OK" }
        catch { Write-GuiLog "Failed to open $Name website: $($_.Exception.Message)" "ERR" }
    } else { Write-GuiLog "$Name : no fallback URL available" "ERR" }
}
# Used by: Installers, AllInstallers, GpuSoftware, CPU (generic install helpers)
# Downloads and executes a remote installer script from $Url via Invoke-Expression. On failure,
# falls back to opening $FallbackUrl in the browser (if provided) so the user can install manually.
function Invoke-InstallRemoteScript {
    param([string]$Url, [string]$Name, [string]$FallbackUrl="")
    Write-GuiLog "Installing $Name via remote script..." "STEP"
    try {
        Invoke-Expression (Invoke-RestMethod $Url)
        Write-GuiLog "$Name installed" "OK"
    } catch {
        Write-GuiLog "$Name install failed: $_" "WARN"
        if ($FallbackUrl) {
            Write-GuiLog "Opening $Name website..." "STEP"
            try { Start-Process $FallbackUrl -ErrorAction Stop; Write-GuiLog "$Name download page opened" "OK" }
            catch { Write-GuiLog "Failed to open $Name website: $($_.Exception.Message)" "ERR" }
        }
    }
}
