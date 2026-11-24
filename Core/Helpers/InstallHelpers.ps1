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
            Write-GuiLog ((T "Opening {0} website...") -f $Name) "STEP"
            try { Start-Process $FallbackUrl -ErrorAction Stop; Write-GuiLog ((T "{0} download page opened") -f $Name) "OK" }
            catch { Write-GuiLog ((T "Failed to open {0} website: {1}") -f $Name, $_.Exception.Message) "ERR" }
        }
        else { Write-GuiLog ((T "{0} : no download URL available") -f $Name) "ERR" }
        return
    }
    if (-not (Get-Variable -Name BgWorker -ValueOnly -Scope Script -ErrorAction SilentlyContinue)) {
        [void](Start-GuiBackgroundJob -Work { Invoke-InstallWingetApp -Id $InstallId -Name $InstallName -Source $InstallSource -FallbackUrl $InstallFallbackUrl } `
            -Functions @('Invoke-InstallWingetApp') -Name "Install $Name" `
            -Arguments @{ InstallId = $Id; InstallName = $Name; InstallSource = $Source; InstallFallbackUrl = $FallbackUrl })
        return
    }
    Write-GuiLog ((T "Installing {0} via winget...") -f $Name) "STEP"
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
    } catch { Write-GuiLog ((T "Winget error: {0}") -f $_.Exception.Message) "WARN" }
    if ($exitCode -eq 0) { Write-GuiLog ((T "{0} installed") -f $Name) "OK"; return }
    if ($exitCode -eq -1978335189 -or $exitCode -eq -1978335215) { Write-GuiLog ((T "{0} already installed") -f $Name) "OK"; return }
    if ($null -ne $exitCode) { Write-GuiLog ((T "Winget failed (code {0}), trying fallback...") -f $exitCode) "WARN" }
    if ($FallbackUrl) {
        Write-GuiLog ((T "Opening {0} website...") -f $Name) "STEP"
        try { Start-Process $FallbackUrl -ErrorAction Stop; Write-GuiLog ((T "{0} download page opened") -f $Name) "OK" }
        catch { Write-GuiLog ((T "Failed to open {0} website: {1}") -f $Name, $_.Exception.Message) "ERR" }
    } else { Write-GuiLog ((T "{0} : no fallback URL available") -f $Name) "ERR" }
}
# Used by: Invoke-DownloadLatestRelease and direct-download buttons (Uninstalr)
# Streams $Url to the Desktop with the progress bar and opens the saved file. Downloads to the
# runtime folder first, so a cancelled/failed transfer never leaves a broken file on the Desktop.
function Invoke-DownloadDirectFile {
    param([string]$Url, [string]$FileName, [string]$Label = $FileName, [long]$Size = 0)
    try {
        # HTTPS needs TLS 1.2, which .NET Framework (the WinPS 5.1 host) does not negotiate by default.
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $tmp = Join-Path $Script:TempDir $FileName
        $dest = Join-Path ([Environment]::GetFolderPath("Desktop")) $FileName
        Set-GuiProgress 0 ((T "Downloading {0}...") -f $FileName)
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.UserAgent = "SETTDash"
        $resp = $req.GetResponse()
        try {
            # Chunked responses report -1; callers that know the real size pass it in.
            $total = if ($resp.ContentLength -gt 0) { [long]$resp.ContentLength } else { $Size }
            $in = $resp.GetResponseStream()
            $out = [System.IO.File]::Create($tmp)
            try {
                $buf = New-Object byte[] 81920
                $read = 0L
                while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                    $out.Write($buf, 0, $n)
                    $read += $n
                    if ($total -gt 0) { Set-GuiProgress ([math]::Min(99, [math]::Round($read * 100 / $total))) }
                }
            } finally { $out.Dispose(); $in.Dispose() }
        } finally { $resp.Dispose() }
        Move-Item -LiteralPath $tmp -Destination $dest -Force
        Set-GuiProgress 100
        Write-GuiLog ((T "{0} saved to Desktop") -f $Label) "OK"
        Start-Process $dest
    } catch {
        Set-GuiProgress 0
        Write-GuiLog ((T "{0} download failed: {1}") -f $Label, $_.Exception.Message) "ERR"
    }
}
# Used by: Utilities ("SETT Memory Cleaner", "SETT Metter", "SETT VPN", "SETT Converter"), GpuSoftware (mVolt, GPU-Z, NVCleanstall, Nvidia Profile Inspector, RadeonSlimmer) and Installers (SETT apps, YTSage, Nusa, LuaTools)
# Downloads the newest asset of a repo's latest GitHub release to the Desktop and launches it, so
# the button always delivers the current build instead of a version pinned here. Runs in a
# background job (Add-GuiBackgroundBtn): the progress bar follows the transfer and the window
# keeps painting while a large .exe is fetched.
function Invoke-DownloadLatestRelease {
    param([string]$RepoOwner, [string]$RepoName, [string]$AssetPattern = "*.exe", [string]$Label = $RepoName)
    Write-GuiLog ((T "Looking up the latest {0} release on GitHub...") -f $Label) "STEP"
    try {
        # GitHub requires TLS 1.2, which .NET Framework (the WinPS 5.1 host) does not negotiate by default.
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest" `
            -Headers @{ "User-Agent" = "SETTDash" } -TimeoutSec 15
        $asset = @($release.assets) | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
        if (-not $asset) { throw "no asset matching '$AssetPattern' in release $($release.tag_name)" }
        Invoke-DownloadDirectFile -Url $asset.browser_download_url -FileName $asset.name -Size $asset.size -Label "$Label $($release.tag_name)"
    } catch {
        Set-GuiProgress 0
        Write-GuiLog ((T "{0} download failed: {1}") -f $Label, $_.Exception.Message) "ERR"
    }
}
# Used by: GpuSoftware ("NvidiaInspector", GPU-Z, NVCleanstall), CPU (ThrottleStop)
# TechPowerUp has no stable file URL: the download is a two-step POST (version id, then mirror
# server id) that returns the file itself, so both ids are read from the app page and posted back.
# Saves to the Desktop and opens the file, same as the GitHub downloader above.
function Invoke-DownloadTechPowerUpApp {
    param([string]$Url, [string]$Label)
    Write-GuiLog ((T "Looking up the latest {0} download on TechPowerUp...") -f $Label) "STEP"
    try {
        # TechPowerUp requires TLS 1.2, which .NET Framework (the WinPS 5.1 host) does not negotiate by default.
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "SETTDash")
        try {
            $page = $wc.DownloadString($Url)
            $id = [regex]::Match($page, 'name="id" value="(\d+)"').Groups[1].Value
            $file = [regex]::Match($page, '<div class="filename"[^>]*>([^<]+)</div>').Groups[1].Value
            if (-not $id -or -not $file) { throw "could not read the download form" }
            $form = New-Object System.Collections.Specialized.NameValueCollection
            $form["id"] = $id
            $mirrors = [System.Text.Encoding]::UTF8.GetString($wc.UploadValues($Url, "POST", $form))
            $server = [regex]::Match($mirrors, 'name="server_id" value="(\d+)"').Groups[1].Value
            if (-not $server) { throw "no mirror server listed" }
            Set-GuiProgress 0 ((T "Downloading {0}...") -f $file)
            $form["server_id"] = $server
            $bytes = $wc.UploadValues($Url, "POST", $form)
        } finally { $wc.Dispose() }
        # Download to the runtime folder first, so a failed write never leaves a broken file on the Desktop.
        $tmp = Join-Path $Script:TempDir $file
        $dest = Join-Path ([Environment]::GetFolderPath("Desktop")) $file
        [System.IO.File]::WriteAllBytes($tmp, $bytes)
        Move-Item -LiteralPath $tmp -Destination $dest -Force
        Set-GuiProgress 100
        Write-GuiLog ((T "{0} saved to Desktop") -f $file) "OK"
        Start-Process $dest
    } catch {
        Set-GuiProgress 0
        Write-GuiLog ((T "{0} download failed: {1}") -f $Label, $_.Exception.Message) "ERR"
    }
}
# Used by: Installers, AllInstallers, GpuSoftware, CPU (generic install helpers)
# Downloads and executes a remote installer script from $Url via Invoke-Expression. On failure,
# falls back to opening $FallbackUrl in the browser (if provided) so the user can install manually.
function Invoke-InstallRemoteScript {
    param([string]$Url, [string]$Name, [string]$FallbackUrl="")
    Write-GuiLog ((T "Installing {0} via remote script...") -f $Name) "STEP"
    try {
        Invoke-Expression (Invoke-RestMethod $Url)
        Write-GuiLog ((T "{0} installed") -f $Name) "OK"
    } catch {
        Write-GuiLog ((T "{0} install failed: {1}") -f $Name, $_) "WARN"
        if ($FallbackUrl) {
            Write-GuiLog ((T "Opening {0} website...") -f $Name) "STEP"
            try { Start-Process $FallbackUrl -ErrorAction Stop; Write-GuiLog ((T "{0} download page opened") -f $Name) "OK" }
            catch { Write-GuiLog ((T "Failed to open {0} website: {1}") -f $Name, $_.Exception.Message) "ERR" }
        }
    }
}
