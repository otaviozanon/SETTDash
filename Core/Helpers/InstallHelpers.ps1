# Used by: Installers, AllInstallers, GpuSoftware, CPU (generic install helpers)
# Installs an app via winget using its package $Id. If $Id is empty, or winget fails/isn't
# available, falls back to opening $FallbackUrl in the browser so the user can install manually.
# Treats winget's "already installed" exit codes as success.
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
    Write-GuiLog "Installing $Name via winget..." "STEP"
    try {
        $wingetArgs = @("install", "--id=$Id", "--silent", "--accept-source-agreements", "--accept-package-agreements")
        if ($Source -eq "msstore") { $wingetArgs += "--source", "msstore" }
        # Resolve the App Execution Alias before starting: Start-Process on a missing command throws
        # a raw Win32Exception that -ErrorAction cannot suppress on every host.
        $wingetExe = (Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if (-not $wingetExe) { throw "winget not available" }
        $p = Start-Process -FilePath $wingetExe -ArgumentList $wingetArgs -Wait -NoNewWindow -PassThru -ErrorAction Stop
        if ($p.ExitCode -eq 0) { Write-GuiLog "$Name installed" "OK"; return }
        elseif ($p.ExitCode -eq -1978335189 -or $p.ExitCode -eq -1978335215) { Write-GuiLog "$Name already installed" "OK"; return }
        Write-GuiLog "Winget failed (code $($p.ExitCode)), trying fallback..." "WARN"
    } catch { Write-GuiLog "Winget error, trying fallback..." "WARN" }
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
