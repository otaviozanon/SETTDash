
# ================================================
#region 1. PLAYBOOK - AME WIZARD
# ================================================
# Used by: Playbooks ("Download AME Wizard")
function Invoke-PlaybookAME {
    Set-GuiProgress 20 "Fetching latest AME Wizard release..."
    Write-GuiLog "Fetching latest AME Wizard release..." "STEP"
    Write-GuiLog "Querying GitHub API: Ameliorated-io/ame-wizard-releases" "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/Ameliorated-io/ame-wizard-releases/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.zip") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog "Found: $($asset.name) ($size MB) - Tag: $($release.tag_name)" "OK"
                break
            }
        }
    } catch { Write-GuiLog "GitHub API lookup failed: $_" "WARN" }
    if (-not $url) {
        Write-GuiLog "Using fallback direct download URL" "WARN"
        $url = "https://download.ameliorated.io/AME%20Wizard%20Beta.zip"
    }
    Set-GuiProgress 80 "Opening browser..."
    Write-GuiLog "Opening AME Wizard download in browser: $url" "OK"
    try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    Write-GuiLog "AME Wizard download initiated" "OK"
    Set-GuiProgress 0
}
#endregion

# ================================================
#region 2. PLAYBOOK - ReviOS
# ================================================
# Used by: Playbooks ("Download ReviOS")
function Invoke-PlaybookReviOS {
    Set-GuiProgress 20 "Fetching latest ReviOS playbook..."
    Write-GuiLog "Fetching latest ReviOS playbook..." "STEP"
    Write-GuiLog "Querying GitHub API: meetrevision/playbook" "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/meetrevision/playbook/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.apbx") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog "Found: $($asset.name) ($size MB) - Tag: $($release.tag_name)" "OK"
                break
            }
        }
    } catch { Write-GuiLog "GitHub API lookup failed: $_" "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog "Opening ReviOS playbook in browser..." "STEP"
        try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    } else {
        Write-GuiLog "No .apbx asset found in latest ReviOS release" "ERR"
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
    Write-GuiLog "Fetching latest AtlasOS playbook..." "STEP"
    Write-GuiLog "Querying GitHub API: Atlas-OS/Atlas" "INFO"
    $url = $null
    try {
        $apiUrl = "https://api.github.com/repos/Atlas-OS/Atlas/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/1.0" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
        foreach ($asset in $release.assets) {
            if ($asset.name -like "*.apbx") {
                $url = $asset.browser_download_url
                $size = [math]::Round($asset.size / 1MB, 2)
                Write-GuiLog "Found: $($asset.name) ($size MB) - Tag: $($release.tag_name)" "OK"
                break
            }
        }
    } catch { Write-GuiLog "GitHub API lookup failed: $_" "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog "Opening AtlasOS playbook in browser..." "STEP"
        try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    } else {
        Write-GuiLog "No .apbx asset found in latest AtlasOS release" "ERR"
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
    Write-GuiLog "Scraping FSOS-X for latest playbook..." "STEP"
    $siteUrl = "https://fsosx.com/"
    $url = $null
    try {
        $web = Invoke-WebRequest -Uri $siteUrl -TimeoutSec 15 -UseBasicParsing
        $matches = [regex]::Matches($web.Content, 'https?://[^"''\s<>]+\.apbx')
        if ($matches -and $matches.Count -gt 0) {
            $url = $matches[0].Value
            Write-GuiLog "Found: $url" "OK"
        } else {
            $altMatch = [regex]::Match($web.Content, 'href="([^"]*\.apbx)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($altMatch.Success) {
                $relativePath = $altMatch.Groups[1].Value
                if ($relativePath -match '^https?://') { $url = $relativePath }
                else { $uri = [System.Uri]::new($siteUrl); $url = "$($uri.Scheme)://$($uri.Host)/$relativePath" }
                Write-GuiLog "Found: $url" "OK"
            }
        }
    } catch { Write-GuiLog "Failed to scrape FSOSX: $_" "WARN" }
    if ($url) {
        Set-GuiProgress 80 "Opening browser..."
        Write-GuiLog "Opening FSOS-X playbook in browser..." "STEP"
        try { Start-Process $url } catch { Write-GuiLog "Failed to open browser: $_" "ERR" }
    } else {
        Write-GuiLog "No .apbx link found on FSOSX site" "ERR"
    }
    Set-GuiProgress 0
}
#endregion
