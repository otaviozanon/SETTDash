# ============================================
#  PLAYBOOK OPTIMIZER - SETT
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

$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:UserDownloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$Script:DownloadsDir = Join-Path $Script:ScriptDir "Downloads"

if (-not (Test-Path $Script:UserDownloads)) {
    New-Item -Path $Script:UserDownloads -ItemType Directory -Force | Out-Null
}


function Invoke-DownloadFile {
    param(
        [string]$Url,
        [string]$OutPath,
        [string]$Label = "Downloading"
    )
    $global:downloadCancelled = $false
    $global:downloadDone = $false
    $global:lastPercent = -1
    $webClient = $null
    $progressEvent = $null
    $completedEvent = $null
    $ctrlCHandler = $null

    try {
        $webClient = New-Object System.Net.WebClient

        $ctrlCHandler = [ConsoleCancelEventHandler] {
            param($sender, $e)
            $e.Cancel = $true
            $global:downloadCancelled = $true
            if ($webClient.IsBusy) { $webClient.CancelAsync() }
            Write-Host "`n[*]  Cancelling download..." -ForegroundColor Yellow
        }
        [Console]::CancelKeyPress += $ctrlCHandler

        $progressEvent = Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $pct = $EventArgs.ProgressPercentage
            if ($pct -ne $global:lastPercent) {
                $global:lastPercent = $pct
                $received = [math]::Round($EventArgs.BytesReceived / 1MB, 1)
                $total = [math]::Round($EventArgs.TotalBytesToReceive / 1MB, 1)
                Write-Progress -Activity $Event.MessageData.Activity -Status "$pct% - $received MB / $total MB  (ESC to cancel)" -PercentComplete $pct
            }
        } -MessageData @{ Activity = $Label }

        $completedEvent = Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
            $global:downloadDone = $true
        }

        S "$Label..."
        $webClient.DownloadFileAsync($Url, $OutPath)

        while (-not $global:downloadDone) {
            if ($Host.UI.RawUI.KeyAvailable) {
                $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
                if ($key.VirtualKeyCode -eq 27) {
                    $global:downloadCancelled = $true
                    if ($webClient.IsBusy) { $webClient.CancelAsync() }
                    Write-Host "`n[*]  Cancelling download..." -ForegroundColor Yellow
                }
            }
            Start-Sleep -Milliseconds 100
        }

        if ($global:downloadCancelled) {
            Warn "Download cancelled by user"
            if (Test-Path $OutPath) { Remove-Item -Path $OutPath -Force -ErrorAction SilentlyContinue }
            return $false
        }

        return $true
    } catch {
        return $false
    } finally {
        Write-Progress -Activity $Label -Completed
        if ($progressEvent) { Unregister-Event -SourceIdentifier $progressEvent.Name -Force -ErrorAction SilentlyContinue }
        if ($completedEvent) { Unregister-Event -SourceIdentifier $completedEvent.Name -Force -ErrorAction SilentlyContinue }
        if ($ctrlCHandler) { [Console]::CancelKeyPress -= $ctrlCHandler }
        if ($webClient) { $webClient.Dispose() }
    }
}

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

# ============================================
# URL FETCH HELPERS
# ============================================

function Get-GitHubLatestReleaseAsset {
    param(
        [string]$Repo,
        [string]$AssetPattern,
        [string]$SourceName
    )
    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    $headers = @{ "User-Agent" = "PlaybookOptimizer/1.0" }
    try {
        S "Fetching latest release from $SourceName..."
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 15
        foreach ($asset in $release.assets) {
            if ($asset.name -like $AssetPattern) {
                $url = $asset.browser_download_url
                $name = $asset.name
                $size = [math]::Round($asset.size / 1MB, 2)
                I "Found: $name ($size MB)"
                return @{ URL = $url; Name = $name; Size = $size; Tag = $release.tag_name }
            }
        }
        X "No asset matching '$AssetPattern' found in latest release."
        return $null
    } catch {
        X "Failed to fetch from $SourceName : $_"
        return $null
    }
}

function Get-FSOSXDownloadUrl {
    $siteUrl = "https://fsosx.com/"
    try {
        S "Scraping FSOSX for latest download link..."
        $web = Invoke-WebRequest -Uri $siteUrl -TimeoutSec 15 -UseBasicParsing

        $altMatch = [regex]::Match($web.Content, 'href="([^"]*\.apbx)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($altMatch.Success) {
            $relativePath = $altMatch.Groups[1].Value
            if ($relativePath -match '^https?://') {
                $url = $relativePath
            } else {
                $uri = [System.Uri]::new($siteUrl)
                $url = "$($uri.Scheme)://$($uri.Host)/$relativePath"
            }
            I "Found: $url"
            $name = [System.IO.Path]::GetFileName($url)
            return @{ URL = $url; Name = $name; Size = 0 }
        }

        $matches = [regex]::Matches($web.Content, 'https?://[^"''\s<>]+\.apbx')
        if ($matches.Count -gt 0) {
            $url = $matches[0].Value
            I "Found: $url"
            $name = [System.IO.Path]::GetFileName($url)
            return @{ URL = $url; Name = $name; Size = 0 }
        }
        X "No .apbx link found on FSOSX site."
        return $null
    } catch {
        X "Failed to scrape FSOSX: $_"
        return $null
    }
}

function Show-DownloadHandler {
    param(
        [hashtable]$Asset,
        [string]$Label
    )
    if (-not $Asset) {
        Read-Host "`nPress ENTER to return."
        return
    }

    do {
        Clear-Host
        ShowHeader "$Label"
        Write-Host "  Release : " -ForegroundColor $Script:Col.INFO -NoNewline
        $tag = if ($Asset['Tag']) { $Asset['Tag'] } else { "N/A" }
        Write-Host $tag -ForegroundColor White
        Write-Host "  File    : " -ForegroundColor $Script:Col.INFO -NoNewline
        Write-Host $Asset.Name -ForegroundColor White
        Write-Host "  Size    : " -ForegroundColor $Script:Col.INFO -NoNewline
        if ($Asset.Size -gt 0) {
            Write-Host "$($Asset.Size) MB" -ForegroundColor White
        } else {
            Write-Host "N/A" -ForegroundColor White
        }
        Write-Host "  URL     : " -ForegroundColor $Script:Col.INFO -NoNewline
        Write-Host $Asset.URL -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [1] Download to Downloads folder" -ForegroundColor White
        Write-Host "  [2] Open in Browser" -ForegroundColor White
        Write-Host "  [3] Copy URL to Clipboard" -ForegroundColor White
        Write-Host "  [0] Back" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "  Choice"

        switch ($choice) {
            "1" {
                $outPath = Join-Path $Script:UserDownloads $Asset.Name
                if (Invoke-DownloadFile -Url $Asset.URL -OutPath $outPath -Label "Downloading $($Asset.Name)") {
                    OK "Saved to: $outPath"
                } else {
                    X "Download failed"
                }
                Read-Host "`nPress ENTER to return."
            }
            "2" {
                I "Opening browser..."
                Start-Process $Asset.URL
                Read-Host "`nPress ENTER to return."
            }
            "3" {
                Set-Clipboard -Value $Asset.URL
                OK "URL copied to clipboard."
                Read-Host "`nPress ENTER to return."
            }
            "0" { return }
            default {
                X "Invalid option"
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

function Open-DiscordInvite {
    param([string]$Url, [string]$Label)
    I "Opening Discord for $Label..."
    Start-Process $Url
    OK "Browser opened. Join the Discord server to get the playbook."
    Read-Host "`nPress ENTER to return."
}

# ============================================
# AME WIZARD
# ============================================

function Show-AMEWizardMenu {
    Show-Menu -title "AME WIZARD" `
        -options @("Download Latest AME Wizard", "Back") `
        -actions @(
            { Invoke-AMEWizardDownload }
            { "BACK" }
        )
}

function Invoke-AMEWizardDownload {
    $ameAsset = $null

    try {
        S "Fetching latest AME Wizard from GitHub..."
        $headers = @{ "User-Agent" = "PlaybookOptimizer/1.0" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/Ameliorated-io/ame-wizard-releases/releases/latest" -Headers $headers -TimeoutSec 15
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.zip" -and ($asset.name -match "AME" -or $asset.name -match "Wizard")) {
                $url = $asset.browser_download_url
                $name = $asset.name
                $size = [math]::Round($asset.size / 1MB, 2)
                I "Found: $name ($size MB)"
                $ameAsset = @{ URL = $url; Name = $name; Size = $size; Tag = $release.tag_name }
                break
            }
        }
    } catch {
        X "GitHub lookup failed: $_"
    }

    if (-not $ameAsset) {
        I "Using direct download fallback..."
        $ameAsset = @{ URL = "https://download.ameliorated.io/AME%20Wizard%20Beta.zip"; Name = "AME Wizard Beta.zip"; Size = 0 }
    }

    Show-DownloadHandler -Asset $ameAsset -Label "AME WIZARD DOWNLOAD"
}

# ============================================
# PLAYBOOKS
# ============================================

function Show-PlaybooksMenu {
    Show-Menu -title "PLAYBOOKS" `
        -options @("FSOS-X (FrameSyncLabs)", "ReviOS", "AtlasOS", "SapphireOS", "XOS", "Back") `
        -actions @(
            { Invoke-FSOSXDownload }
            { Invoke-ReviOSDownload }
            { Invoke-AtlasOSDownload }
            { Open-DiscordInvite -Url "https://discord.com/invite/sapphireos-1123140900084797510" -Label "SapphireOS" }
            { Open-DiscordInvite -Url "https://discord.com/invite/XTYEjZNPgX" -Label "XOS" }
            { "BACK" }
        )
}

function Invoke-FSOSXDownload {
    $asset = Get-FSOSXDownloadUrl
    Show-DownloadHandler -Asset $asset -Label "FSOS-X DOWNLOAD"
}

function Invoke-ReviOSDownload {
    $asset = Get-GitHubLatestReleaseAsset -Repo "meetrevision/playbook" -AssetPattern "*.apbx" -SourceName "ReviOS"
    Show-DownloadHandler -Asset $asset -Label "ReviOS PLAYBOOK DOWNLOAD"
}

function Invoke-AtlasOSDownload {
    $asset = Get-GitHubLatestReleaseAsset -Repo "Atlas-OS/Atlas" -AssetPattern "*.apbx" -SourceName "AtlasOS"
    Show-DownloadHandler -Asset $asset -Label "AtlasOS PLAYBOOK DOWNLOAD"
}

# ============================================
# MAIN MENU
# ============================================

function Show-MainMenu {
    do {
        $options = @(
            "AME Wizard"
            "Playbooks"
            "Exit"
        )
        $actions = @(
            { Show-AMEWizardMenu }
            { Show-PlaybooksMenu }
            {
                I "Goodbye!"
                Start-Sleep -Seconds 1
                Stop-Process -Id $PID
            }
        )
        Show-Menu -Title "PLAYBOOK OPTIMIZER" -Options $options -Actions $actions
    } while ($true)
}

# ============================================
# INIT
# ============================================

Show-MainMenu
