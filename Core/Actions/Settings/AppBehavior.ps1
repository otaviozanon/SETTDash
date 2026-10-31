
# ================================================
#region SETTINGS - APP BEHAVIOR (auto-start, minimize to tray)
# ================================================
$Script:AutoStartRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$Script:AutoStartRunName = "SETTDash"

# Path to the running .exe (or script, when testing unpacked) used as the Run key's target.
function Get-GuiAutoStartTarget {
    try { return [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch {}
    return $PSCommandPath
}

# Whether SETTDash is currently registered to start with Windows (reads the registry directly,
# so it always reflects reality even if the Run key was changed outside the app).
function Test-GuiAutoStartEnabled {
    try {
        $val = (Get-ItemProperty -Path $Script:AutoStartRunKey -Name $Script:AutoStartRunName -ErrorAction SilentlyContinue).$Script:AutoStartRunName
        return [bool]$val
    } catch { return $false }
}

# Used by: Settings ("Enable Auto-Start")
function Invoke-AutoStartApply {
    Set-GuiProgress 50 "Enabling auto-start with Windows..."
    try {
        $target = Get-GuiAutoStartTarget
        Set-ItemProperty -Path $Script:AutoStartRunKey -Name $Script:AutoStartRunName -Value ('"' + $target + '"') -Force
        Write-GuiLog "SETTDash will now start automatically with Windows" "OK"
    } catch { Write-GuiLog "Failed to enable auto-start: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Settings ("Disable Auto-Start")
function Invoke-AutoStartRevert {
    Set-GuiProgress 50 "Disabling auto-start with Windows..."
    try {
        Remove-ItemProperty -Path $Script:AutoStartRunKey -Name $Script:AutoStartRunName -ErrorAction SilentlyContinue
        Write-GuiLog "Auto-start with Windows disabled" "OK"
    } catch { Write-GuiLog "Failed to disable auto-start: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: Settings ("Enable Minimize to Tray")
function Invoke-MinimizeToTrayApply {
    Save-GuiMinimizeToTrayPref $true
    Write-GuiLog "Closing the window now minimizes SETTDash to the system tray" "OK"
}

# Used by: Settings ("Disable Minimize to Tray")
function Invoke-MinimizeToTrayRevert {
    Save-GuiMinimizeToTrayPref $false
    Write-GuiLog "Closing the window now exits SETTDash normally" "OK"
}

# Whether to check GitHub for a newer release automatically on every launch (default: on).
function Get-GuiAutoUpdateCheckPref {
    $data = Get-GuiSettingsData
    if (-not $data.Contains("AutoUpdateCheck")) { return $true }
    return [bool]$data["AutoUpdateCheck"]
}
function Save-GuiAutoUpdateCheckPref { param([bool]$Enabled) Save-GuiSettingValue -Key "AutoUpdateCheck" -Value $Enabled }

# Maps the Settings page's "Default Startup Page" picker to the same nav handler scriptblocks
# used by the sidebar buttons ($navHandlers, defined in Sidebar\Sidebar.ps1) - so launching with
# a non-Home default also auto-expands its sidebar section and highlights the right nav item.
$Script:StartupPageOptions = [ordered]@{
    "Home"               = "navHome"
    "Your PC - System"   = "navYourPCSystem"
    "Your PC - Sensors"  = "navYourPCSensors"
    "Your PC - GPU"      = "navYourPCGpu"
    "Your PC - CPU"      = "navYourPCCpu"
    "Your PC - Disks"    = "navYourPCDisks"
    "Your PC - Energy"   = "navYourPCEnergy"
    "Performance"        = "navPerformance"
    "Network & Privacy"  = "navNetworkPrivacy"
    "Windows Tweaks"     = "navWindows"
    "Clean"              = "navClean"
    "Network"            = "navNetwork"
    "Settings"           = "navSettings"
}

# Reads the saved default startup page's nav key, falling back to "navHome" if none/invalid.
function Get-GuiDefaultStartupPagePref {
    $data = Get-GuiSettingsData
    $saved = $data["DefaultStartupPage"]
    if ($saved -and ($Script:StartupPageOptions.Values -contains $saved)) { return $saved }
    return "navHome"
}
function Save-GuiDefaultStartupPagePref { param([string]$NavKey) Save-GuiSettingValue -Key "DefaultStartupPage" -Value $NavKey }
#endregion
