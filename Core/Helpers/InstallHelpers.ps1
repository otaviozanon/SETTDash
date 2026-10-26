# Used by: Installers, AllInstallers, GpuSoftware, CPU (generic install helpers)
# Installs an app via winget using its package $Id. If $Id is empty, or winget fails/isn't
# available, falls back to opening $FallbackUrl in the browser so the user can install manually.
# Treats winget's "already installed" exit codes as success.
function Invoke-InstallWingetApp {
    param([string]$Id, [string]$Name, [string]$Source="winget", [string]$FallbackUrl="")
    if (-not $Id) {
        if ($FallbackUrl) { Write-GuiLog "Opening $Name website..." "STEP"; Start-Process $FallbackUrl; Write-GuiLog "$Name download page opened" "OK" }
        else { Write-GuiLog "$Name : no download URL available" "ERR" }
        return
    }
    Write-GuiLog "Installing $Name via winget..." "STEP"
    try {
        $wingetArgs = @("install", "--id=$Id", "--silent", "--accept-source-agreements", "--accept-package-agreements")
        if ($Source -eq "msstore") { $wingetArgs += "--source", "msstore" }
        $p = Start-Process winget -ArgumentList $wingetArgs -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -eq 0) { Write-GuiLog "$Name installed" "OK"; return }
        elseif ($p.ExitCode -eq -1978335189 -or $p.ExitCode -eq -1978335215) { Write-GuiLog "$Name already installed" "OK"; return }
        Write-GuiLog "Winget failed (code $($p.ExitCode)), trying fallback..." "WARN"
    } catch { Write-GuiLog "Winget error, trying fallback..." "WARN" }
    if ($FallbackUrl) {
        Write-GuiLog "Opening $Name website..." "STEP"
        Start-Process $FallbackUrl
        Write-GuiLog "$Name download page opened" "OK"
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
            Start-Process $FallbackUrl
            Write-GuiLog "$Name download page opened" "OK"
        }
    }
}
