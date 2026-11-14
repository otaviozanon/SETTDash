# Test-Settings.ps1
# Covers the logic that had no tests: the update-version decision and the Settings preferences
# (auto-start, minimize to tray, default startup page, auto update check).
#
# Nothing here touches the real profile: %APPDATA% is redirected to a scratch folder, and the
# registry cmdlets are shadowed by in-memory stubs so no Run key is ever written.

[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Continue"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")

Set-StrictMode -Version Latest

$script:LogLines = New-Object System.Collections.ArrayList
function Write-GuiLog { param([string]$Message, [string]$Type = "INFO") [void]$script:LogLines.Add("$Type $Message") }
function Set-GuiProgress { param([double]$Value, [string]$Status) }

# Registry stubs: the app reads/writes HKCU:\...\Run, which must not happen during a test.
$script:RegStore = @{}
function Get-ItemProperty {
    param($Path, $Name, $ErrorAction)
    if ($Name -and $script:RegStore.ContainsKey($Name)) {
        $obj = New-Object System.Management.Automation.PSObject
        $obj | Add-Member -NotePropertyName $Name -NotePropertyValue $script:RegStore[$Name]
        return $obj
    }
    return $null
}
function Set-ItemProperty {
    param($Path, $Name, $Value, $Type, [switch]$Force, $ErrorAction)
    $script:RegStore[$Name] = $Value
}
function Remove-ItemProperty {
    param($Path, $Name, $ErrorAction)
    [void]$script:RegStore.Remove($Name)
}

$script:ScratchDir = Join-Path ([System.IO.Path]::GetTempPath()) ("settdash-settings-" + [guid]::NewGuid().ToString("N"))
New-Item -Path $script:ScratchDir -ItemType Directory -Force | Out-Null
$script:OldAppData = $env:APPDATA

try {
    $env:APPDATA = Join-Path $script:ScratchDir "AppData"
    New-Item -Path $env:APPDATA -ItemType Directory -Force | Out-Null

    . (Join-Path $RepoRoot "Core\Helpers\Theme.ps1")
    . (Join-Path $RepoRoot "Core\Helpers\Localization.ps1")
    . (Join-Path $RepoRoot "Core\Actions\Settings\AppBehavior.ps1")
    . (Join-Path $RepoRoot "Core\Helpers\UpdateChecker.ps1")
    $Script:CurrentLanguage = "EN"
    $Script:AppVersion = "4.0.7"

    Write-Section "Test-Settings: update availability"

    Assert-Equal "4.0.8" (Get-UpdateAvailability -CurrentVersion "4.0.7" -LatestTag "v4.0.8") "A newer tag is offered"
    Assert-Equal "4.0.8" (Get-UpdateAvailability -CurrentVersion "4.0.7" -LatestTag "4.0.8") "The leading 'v' is optional"
    Assert-Equal "4.0.10" (Get-UpdateAvailability -CurrentVersion "4.0.7" -LatestTag "v4.0.10") "Versions compare numerically, not as text"
    Assert-True ($null -eq (Get-UpdateAvailability -CurrentVersion "4.0.7" -LatestTag "v4.0.7")) "The same version is not an update"
    Assert-True ($null -eq (Get-UpdateAvailability -CurrentVersion "4.0.7" -LatestTag "v4.0.6")) "An older tag is not an update"
    Assert-True ($null -eq (Get-UpdateAvailability -CurrentVersion "not-a-version" -LatestTag "v4.0.8")) "An unparsable current version is ignored"
    Assert-True ($null -eq (Get-UpdateAvailability -CurrentVersion "4.0.7" -LatestTag "banana")) "An unparsable tag is ignored"
    Assert-True ($null -eq (Get-UpdateAvailability -CurrentVersion "" -LatestTag "")) "Empty versions are ignored"

    $env:SETTDASH_NO_UPDATE_CHECK = "1"
    $script:LogLines.Clear()
    Assert-NoThrow { Invoke-CheckForUpdates } "The unattended switch skips the check without throwing"
    Assert-Equal 0 $script:LogLines.Count "The unattended switch logs nothing"
    Remove-Item Env:\SETTDASH_NO_UPDATE_CHECK -ErrorAction SilentlyContinue

    Write-Section "Test-Settings: preferences"

    Assert-True (Get-GuiAutoUpdateCheckPref) "Auto update check defaults to on"
    Save-GuiAutoUpdateCheckPref $false
    Assert-True (-not (Get-GuiAutoUpdateCheckPref)) "Auto update check can be disabled"
    Save-GuiAutoUpdateCheckPref $true
    Assert-True (Get-GuiAutoUpdateCheckPref) "Auto update check can be enabled again"

    Assert-True (-not (Get-GuiMinimizeToTrayPref)) "Minimize to tray defaults to off"
    Save-GuiMinimizeToTrayPref $true
    Assert-True (Get-GuiMinimizeToTrayPref) "Minimize to tray can be enabled"
    Save-GuiMinimizeToTrayPref $false
    Assert-True (-not (Get-GuiMinimizeToTrayPref)) "Minimize to tray can be disabled again"

    Assert-Equal "navHome" (Get-GuiDefaultStartupPagePref) "Default startup page falls back to Home"
    Save-GuiDefaultStartupPagePref "navStartup"
    Assert-Equal "navStartup" (Get-GuiDefaultStartupPagePref) "A valid startup page is restored"
    Save-GuiDefaultStartupPagePref "navNotAPage"
    Assert-Equal "navHome" (Get-GuiDefaultStartupPagePref) "An unknown startup page falls back to Home"

    # Saving one preference must not drop the others.
    Save-GuiSettingValue -Key "Theme" -Value "TerminalRetro"
    Save-GuiAutoUpdateCheckPref $false
    $data = Get-GuiSettingsData
    Assert-Equal "TerminalRetro" $data["Theme"] "Saving a preference keeps the other keys"
    Assert-True (-not [bool]$data["AutoUpdateCheck"]) "The new preference landed in settings.json"

    Write-Section "Test-Settings: auto-start"

    Assert-True (-not (Test-GuiAutoStartEnabled)) "Auto-start is off when the Run value is absent"
    $target = Get-GuiAutoStartTarget
    Assert-True ([bool]$target) "The auto-start target is the running process" "$target"

    Invoke-AutoStartApply
    Assert-True (Test-GuiAutoStartEnabled) "Enable auto-start writes the Run value"
    Assert-Equal ('"' + $target + '"') $script:RegStore["SETTDash"] "The Run value points at the quoted executable"

    Invoke-AutoStartRevert
    Assert-True (-not (Test-GuiAutoStartEnabled)) "Disable auto-start removes the Run value"
    Assert-Equal 0 $script:RegStore.Count "Disable auto-start leaves no value behind"

    Write-Section "Test-Settings: no unexpected errors"

    Assert-Equal 0 @($Error | Where-Object {
        $_ -is [System.Management.Automation.ErrorRecord] -and
        $_.InvocationInfo -and $_.InvocationInfo.ScriptName -eq $PSCommandPath
    }).Count "The suite raised no unexpected error"
} finally {
    $env:APPDATA = $script:OldAppData
    Remove-Item Env:\SETTDASH_NO_UPDATE_CHECK -ErrorAction SilentlyContinue
    if (Test-Path $script:ScratchDir) { Remove-Item -Path $script:ScratchDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Complete-Tests "Test-Settings"
