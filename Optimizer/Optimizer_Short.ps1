# ============================================
#  OTIMIZADOR SETT - MAIN HUB
# ============================================
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[X] Run as Administrator required!" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ============================================
# COLOR MAP + LOG HELPERS
# ============================================
$Script:Col = @{
    OK    = "Green"
    X     = "Red"
    WARN  = "DarkYellow"
    INFO  = "Cyan"
    STEP  = "Yellow"
    TITLE = "White"
    CAT   = "White"
    HEAD  = "DarkGray"
}

function OK  { param($M) Write-Host "[OK] " -ForegroundColor $Script:Col.OK -NoNewline; Write-Host $M -ForegroundColor $Script:Col.OK }
function X   { param($M) Write-Host "[X]  " -ForegroundColor $Script:Col.X   -NoNewline; Write-Host $M -ForegroundColor $Script:Col.X }
function Warn { param($M) Write-Host "[*]  " -ForegroundColor $Script:Col.WARN -NoNewline; Write-Host $M -ForegroundColor $Script:Col.WARN }
function I   { param($M) Write-Host "[i]  " -ForegroundColor $Script:Col.INFO -NoNewline; Write-Host $M -ForegroundColor $Script:Col.INFO }
function S   { param($M) Write-Host "[+]  " -ForegroundColor $Script:Col.STEP -NoNewline; Write-Host $M -ForegroundColor $Script:Col.STEP }
function ShowHeader { param($M) Write-Host ""; Write-Host ("=" * 50) -ForegroundColor $Script:Col.HEAD; Write-Host "  $M" -ForegroundColor $Script:Col.TITLE; Write-Host ("=" * 50) -ForegroundColor $Script:Col.HEAD; Write-Host "" }

# ============================================
# MENU FRAMEWORK
# ============================================

function Show-Menu {
    param(
        [string]$Title,
        [string[]]$Options,
        [scriptblock[]]$Actions
    )
    do {
        Clear-Host
        Write-Host ("=" * 50) -ForegroundColor $Script:Col.HEAD
        Write-Host "       $Title" -ForegroundColor $Script:Col.TITLE
        Write-Host ("=" * 50) -ForegroundColor $Script:Col.HEAD
        Write-Host ""
        for ($i = 0; $i -lt $Options.Length; $i++) {
            $num = "[$($i + 1)]".PadRight(5)
            Write-Host "  $num" -ForegroundColor $Script:Col.STEP -NoNewline
            Write-Host $Options[$i] -ForegroundColor White
        }
        Write-Host ""
        Write-Host ("=" * 50) -ForegroundColor $Script:Col.HEAD

        $choice = Read-Host "`nChoose [1-$($Options.Length)]"
        $parsed = 0
        if (([int]::TryParse($choice, [ref]$parsed)) -and ($parsed -ge 1) -and ($parsed -le $Options.Length)) {
            $index = $parsed - 1
            $result = & $Actions[$index]
            if ($result -eq "BACK") { break }
        } else {
            X "Invalid option. Try again."
            Start-Sleep -Seconds 1
        }
    } while ($true)
}

function Apply-RegistryTweaks {
    param([array]$settings, [string]$title)
    $c = 0; $t = $settings.Count
    foreach ($s in $settings) {
        $c++
        if ($t -gt 0) { Write-Progress -Activity "Applying: $title" -Status "$c/$t" -PercentComplete ([math]::Round(($c/$t)*100)) }
        try {
            if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $s.Path -Name $s.Name -Value $s.Value -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    Write-Progress -Activity "Applying: $title" -Completed
    OK "Operation completed: $title"
    Read-Host "`nPress ENTER to return."
}

# ============================================
# LAUNCH SUB-SCRIPTS
# ============================================

function Invoke-CacheCleaner {
    $p = Join-Path $PSScriptRoot "CacheCleaner.ps1"
    if (Test-Path $p) {
        S "Launching Cache Cleaner..."
        Start-Process powershell -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$p`""
    } else { X "CacheCleaner.ps1 not found: $p"; Read-Host "`nPress ENTER to return." }
}

function Invoke-NetworkOptimizer {
    $p = Join-Path $PSScriptRoot "OptimizerEthernetWifi.ps1"
    if (Test-Path $p) {
        S "Launching Network Optimizer..."
        Start-Process powershell -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$p`""
    } else { X "OptimizerEthernetWifi.ps1 not found: $p"; Read-Host "`nPress ENTER to return." }
}

# ============================================
# MAIN MENU
# ============================================

function Show-MainMenu {
    do {
        $options = @(
            "Windows 11 Tweaks"
            "Browser Tweaks"
            "Network Optimizer (Ethernet / Wi-Fi)"
            "Cache Cleaner"
            "Exit"
        )
        $actions = @(
            { Show-W11TweaksMenu }
            { Show-BrowserTweaksMenu }
            { Invoke-NetworkOptimizer }
            { Invoke-CacheCleaner }
            {
                I "Goodbye!"
                Start-Sleep -Seconds 1
                Stop-Process -Id $PID
            }
        )
        Show-Menu -Title "OTIMIZADOR SETT" -Options $options -Actions $actions
    } while ($true)
}

# ============================================
# WINDOWS 11 TWEAKS
# ============================================

function Show-W11TweaksMenu {
    Show-Menu -title "WINDOWS 11 TWEAKS" `
        -options @("Apply Old Context Menu", "Apply Classic Alt+Tab", "Revert Old Context Menu", "Revert Classic Alt+Tab", "Back") `
        -actions @(
            { Invoke-OldMenu; Read-Host "`nPress ENTER to return." }
            { Invoke-OldClassicAltTab; Read-Host "`nPress ENTER to return." }
            { Invoke-RevertOldMenu; Read-Host "`nPress ENTER to return." }
            { Invoke-RevertClassicAltTab; Read-Host "`nPress ENTER to return." }
            { "BACK" }
        )
}

function Invoke-OldMenu {
    ShowHeader "APPLY OLD CONTEXT MENU"
    try {
        $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        if (-not (Test-Path $bp)) { New-Item -Path $bp -Force | Out-Null }
        Set-ItemProperty -Path $bp -Name "(default)" -Value "" -Force
        OK "Old context menu applied. Restart Explorer to take effect."
    } catch { X "Failed: $_" }
}

function Invoke-RevertOldMenu {
    ShowHeader "REVERT OLD CONTEXT MENU"
    try {
        $bp = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
        if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
        OK "Reverted to Windows 11 default. Restart Explorer to take effect."
    } catch { X "Failed: $_" }
}

function Invoke-OldClassicAltTab {
    ShowHeader "APPLY CLASSIC ALT+TAB"
    try {
        $rp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
        New-ItemProperty -Path $rp -Name "AltTabSettings" -PropertyType DWord -Value 1 -Force | Out-Null
        OK "Classic Alt+Tab applied."
    } catch { X "Failed: $_" }
}

function Invoke-RevertClassicAltTab {
    ShowHeader "REVERT CLASSIC ALT+TAB"
    try {
        $rp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
        if (Get-ItemProperty -Path $rp -Name "AltTabSettings" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $rp -Name "AltTabSettings" -Force
        }
        OK "Alt+Tab reverted to modern style."
    } catch { X "Failed: $_" }
}

# ============================================
# BROWSER TWEAKS
# ============================================

function Show-BrowserTweaksMenu {
    Show-Menu -title "BROWSER TWEAKS" `
        -options @("Brave", "Chrome", "Edge", "Firefox", "Back") `
        -actions @(
            { Show-BraveMenu }
            { Show-ChromeMenu }
            { Show-EdgeMenu }
            { Show-FirefoxMenu }
            { "BACK" }
        )
}

function Show-BraveMenu   { Show-Menu -title "BRAVE"   -options @("Apply Tweaks","Revert Tweaks","Back") -actions @({Invoke-BraveBloatware},{Revert-BraveBloatware},{"BACK"}) }
function Show-ChromeMenu  { Show-Menu -title "CHROME"  -options @("Apply Tweaks","Revert Tweaks","Back") -actions @({Invoke-ChromeBloatware},{Revert-ChromeBloatware},{"BACK"}) }
function Show-EdgeMenu    { Show-Menu -title "EDGE"    -options @("Apply Tweaks","Revert Tweaks","Back") -actions @({Invoke-EdgeBloatware},{Revert-EdgeBloatware},{"BACK"}) }
function Show-FirefoxMenu { Show-Menu -title "FIREFOX" -options @("Apply Tweaks","Revert Tweaks","Back") -actions @({Invoke-FirefoxBloatware},{Revert-FirefoxBloatware},{"BACK"}) }

# --- BRAVE ---
function Invoke-BraveBloatware {
    ShowHeader "BRAVE OPTIMIZATION"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveRewardsDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveWalletDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveVPNDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveAIChatEnabled"; Value = 0; Type = "DWORD" }
    ) -title "Brave"
}

function Revert-BraveBloatware {
    ShowHeader "BRAVE REVERT"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveRewardsDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveWalletDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"; Name = "BraveAIChatEnabled"; Value = 1; Type = "DWORD" }
    ) -title "Brave (Revert)"
}

# --- CHROME ---
function Invoke-ChromeBloatware {
    ShowHeader "CHROME OPTIMIZATION"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "SearchSuggestEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "PromotionalTabsEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Value = 0; Type = "DWORD" }
    ) -title "Chrome"
}

function Revert-ChromeBloatware {
    ShowHeader "CHROME REVERT"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "SyncDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "TranslateEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "SearchSuggestEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "PromotionalTabsEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "MetricsReportingEnabled"; Value = 1; Type = "DWORD" }
    ) -title "Chrome (Revert)"
}

# --- EDGE ---
function Invoke-EdgeBloatware {
    ShowHeader "EDGE OPTIMIZATION"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SyncDisabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WalletEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WebWidgetEnabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HideFirstRunExperience"; Value = 1; Type = "DWORD" }
    ) -title "Edge"
}

function Revert-EdgeBloatware {
    ShowHeader "EDGE REVERT"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SyncDisabled"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WalletEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HubsSidebarEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "WebWidgetEnabled"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "HideFirstRunExperience"; Value = 0; Type = "DWORD" }
    ) -title "Edge (Revert)"
}

# --- FIREFOX ---
function Invoke-FirefoxBloatware {
    ShowHeader "FIREFOX OPTIMIZATION"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableTelemetry"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisablePocket"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableFirefoxStudies"; Value = 1; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "SearchSuggestEnabled"; Value = 0; Type = "DWORD" }
    ) -title "Firefox"
}

function Revert-FirefoxBloatware {
    ShowHeader "FIREFOX REVERT"
    Apply-RegistryTweaks -settings @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableTelemetry"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisablePocket"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "DisableFirefoxStudies"; Value = 0; Type = "DWORD" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"; Name = "SearchSuggestEnabled"; Value = 1; Type = "DWORD" }
    ) -title "Firefox (Revert)"
}

# ============================================
# INIT
# ============================================

Show-MainMenu
