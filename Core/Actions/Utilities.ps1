# ================================================
#region UTILITIES - GENERIC LAUNCHERS
# ================================================
# Used by: Utilities ("MSI Util v3", "O&O AppBuster", "Autoruns", "sPowers")
function Invoke-LaunchApp {
    param([string]$ExeName, [string]$Label)
    $path = Get-EmbeddedProgramPath $ExeName
    if ($path) { Start-Process $path; Write-GuiLog ((T "{0} launched") -f $Label) "OK" }
    else { Write-GuiLog ((T "{0} not found") -f $ExeName) "ERR" }
}

# Used by: Utilities ("vibranceGUI", "TimerResolution")
function Invoke-LaunchToDesktop {
    param([string]$ExeName, [string]$Label)
    $src = Get-EmbeddedProgramPath $ExeName
    if (-not $src) { Write-GuiLog ((T "{0} not found") -f $ExeName) "ERR"; return }
    $desktop = [Environment]::GetFolderPath("Desktop")
    $dest = Join-Path $desktop $ExeName
    try {
        Copy-Item $src $dest -Force
        Write-GuiLog ((T "{0} copied to Desktop") -f $Label) "OK"
        Start-Process $dest
        Write-GuiLog ((T "{0} launched from Desktop") -f $Label) "OK"
    } catch { Write-GuiLog ((T "Failed to copy {0} to Desktop: {1}") -f $Label, $_) "ERR" }
}

# Used by: Utilities ("SETT UTILITY Extension" > "Download Extension")
function Invoke-CopySettUtility {
    $url = "https://raw.githubusercontent.com/setttz/settUtility/main/sett-utility-extension.zip"
    $zipPath = Join-Path $Script:TempDir "sett-utility-extension.zip"
    $dest = Join-Path (Join-Path $env:USERPROFILE "Downloads") "sett-utility-extension"
    Write-GuiLog (T "Downloading SETT UTILITY Extension from GitHub...") "STEP"
    Set-GuiProgress 10 "Connecting to GitHub..."
    try {
        (New-Object System.Net.WebClient).DownloadFile($url, $zipPath)
        $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Set-GuiProgress 50 "Downloaded ${sizeKB}KB"
        Write-GuiLog ((T "Downloaded {0}KB") -f $sizeKB) "OK"
    } catch {
        Write-GuiLog ((T "Download failed: {0}") -f $_) "ERR"
        Set-GuiProgress 0
        return
    }
    Write-GuiLog (T "Extracting to Downloads...") "STEP"
    try {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $zipPath -DestinationPath $dest -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 100 "Complete"
        Write-GuiLog (T "SETT UTILITY Extension ready at Downloads\sett-utility") "OK"
        Write-GuiLog (T "Open chrome://extensions, enable Developer Mode and load unpacked") "INFO"
    } catch {
        Write-GuiLog ((T "Failed to extract extension: {0}") -f $_) "ERR"
        Set-GuiProgress 0
    }
}
#endregion
