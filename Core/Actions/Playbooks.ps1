
# ================================================
#region 1. PLAYBOOK - AME WIZARD
# ================================================
# Used by: Playbooks ("Download AME Wizard")
function Invoke-PlaybookAME {
    Set-GuiProgress 20 "Fetching latest AME Wizard release..."
    Write-GuiLog (T "Fetching latest AME Wizard release...") "STEP"
    Write-GuiLog ((T "Querying GitHub API: {0}") -f "Ameliorated-io/ame-wizard-releases") "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/Ameliorated-io/ame-wizard-releases/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.zip") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog ((T "Found: {0} ({1} MB) - Tag: {2}") -f $asset.name, $size, $release.tag_name) "OK"
                break
            }
        }
    } catch { Write-GuiLog ((T "GitHub API lookup failed: {0}") -f $_) "WARN" }
    if (-not $url) {
        Write-GuiLog (T "Using fallback direct download URL") "WARN"
        $url = "https://download.ameliorated.io/AME%20Wizard%20Beta.zip"
    }
    Set-GuiProgress 80 "Opening browser..."
    Write-GuiLog ((T "Opening AME Wizard download in browser: {0}") -f $url) "OK"
    try { Start-Process $url } catch { Write-GuiLog ((T "Failed to open browser: {0}") -f $_) "ERR" }
    Write-GuiLog (T "AME Wizard download initiated") "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 2. PLAYBOOK - ReviOS
# ================================================
# Used by: Playbooks ("Download ReviOS")
function Invoke-PlaybookReviOS {
    Set-GuiProgress 20 "Fetching latest ReviOS playbook..."
    Write-GuiLog (T "Fetching latest ReviOS playbook...") "STEP"
    Write-GuiLog ((T "Querying GitHub API: {0}") -f "meetrevision/playbook") "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/meetrevision/playbook/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.apbx") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog ((T "Found: {0} ({1} MB) - Tag: {2}") -f $asset.name, $size, $release.tag_name) "OK"
                break
            }
        }
    } catch { Write-GuiLog ((T "GitHub API lookup failed: {0}") -f $_) "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog (T "Opening ReviOS playbook in browser...") "STEP"
        try { Start-Process $url } catch { Write-GuiLog ((T "Failed to open browser: {0}") -f $_) "ERR" }
    } else {
        Write-GuiLog (T "No .apbx asset found in latest ReviOS release") "ERR"
    }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 3. PLAYBOOK - AtlasOS
# ================================================
# Used by: Playbooks ("Download AtlasOS")
function Invoke-PlaybookAtlasOS {
    Set-GuiProgress 20 "Fetching latest AtlasOS playbook..."
    Write-GuiLog (T "Fetching latest AtlasOS playbook...") "STEP"
    Write-GuiLog ((T "Querying GitHub API: {0}") -f "Atlas-OS/Atlas") "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/Atlas-OS/Atlas/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.apbx") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog ((T "Found: {0} ({1} MB) - Tag: {2}") -f $asset.name, $size, $release.tag_name) "OK"
                break
            }
        }
    } catch { Write-GuiLog ((T "GitHub API lookup failed: {0}") -f $_) "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog (T "Opening AtlasOS playbook in browser...") "STEP"
        try { Start-Process $url } catch { Write-GuiLog ((T "Failed to open browser: {0}") -f $_) "ERR" }
    } else {
        Write-GuiLog (T "No .apbx asset found in latest AtlasOS release") "ERR"
    }
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 4. PLAYBOOK - FSOS-X
# ================================================
# Used by: Playbooks ("Download FSOS-X")
function Invoke-PlaybookFSOSX {
    Set-GuiProgress 20 "Scraping FSOS-X for latest playbook..."
    Write-GuiLog (T "Scraping FSOS-X for latest playbook...") "STEP"
    $siteUrl = "https://fsosx.com/"
    $url = $null
    try {
        $web = Invoke-WebRequest -Uri $siteUrl -TimeoutSec 15 -UseBasicParsing
        $matches = [regex]::Matches($web.Content, 'https?://[^"''\s<>]+\.apbx')
        if ($matches -and $matches.Count -gt 0) {
            $url = $matches[0].Value
            Write-GuiLog ((T "Found: {0}") -f $url) "OK"
        } else {
            $altMatch = [regex]::Match($web.Content, 'href="([^"]*\.apbx)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($altMatch.Success) {
                $relativePath = $altMatch.Groups[1].Value
                if ($relativePath -match '^https?://') { $url = $relativePath }
                else { $uri = [System.Uri]::new($siteUrl); $url = "$($uri.Scheme)://$($uri.Host)/$relativePath" }
                Write-GuiLog ((T "Found: {0}") -f $url) "OK"
            }
        }
    } catch { Write-GuiLog ((T "Failed to scrape FSOSX: {0}") -f $_) "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog (T "Opening FSOS-X playbook in browser...") "STEP"
        try { Start-Process $url } catch { Write-GuiLog ((T "Failed to open browser: {0}") -f $_) "ERR" }
    } else {
        Write-GuiLog (T "No .apbx link found on FSOSX site") "ERR"
    }
    Set-GuiProgress 0
}
#endregion
