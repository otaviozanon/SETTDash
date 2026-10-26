# ================================================
#region UTILITIES - GENERIC LAUNCHERS
# ================================================
# Used by: Utilities ("MSI Util v3", "O&O AppBuster", "Autoruns", "sPowers")
function Invoke-LaunchApp {
    param([string]$ExeName, [string]$Label)
    $path = Join-Path $Script:TempDir "Programs\$ExeName"
    if (-not (Test-Path $path)) { Extract-EmbeddedPrograms }
    if (Test-Path $path) { Start-Process $path; Write-GuiLog "$Label launched" "OK" }
    else { Write-GuiLog "$ExeName not found" "ERR" }
}

# Used by: Utilities ("vibranceGUI", "TimerResolution")
function Invoke-LaunchToDesktop {
    param([string]$ExeName, [string]$Label)
    $src = Join-Path $Script:TempDir "Programs\$ExeName"
    if (-not (Test-Path $src)) { Extract-EmbeddedPrograms }
    if (-not (Test-Path $src)) { Write-GuiLog "$ExeName not found" "ERR"; return }
    $desktop = [Environment]::GetFolderPath("Desktop")
    $dest = Join-Path $desktop $ExeName
    try {
        Copy-Item $src $dest -Force
        Write-GuiLog "$Label copied to Desktop" "OK"
        Start-Process $dest
        Write-GuiLog "$Label launched from Desktop" "OK"
    } catch { Write-GuiLog "Failed to copy $Label to Desktop: $_" "ERR" }
}

# Used by: Utilities ("SETT UTILITY Extension" > "Download Extension")
function Invoke-CopySettUtility {
    $url = "https://raw.githubusercontent.com/setttz/settUtility/main/sett-utility-extension.zip"
    $zipPath = Join-Path $Script:TempDir "sett-utility-extension.zip"
    $dest = Join-Path (Join-Path $env:USERPROFILE "Downloads") "sett-utility-extension"
    Write-GuiLog "Downloading SETT UTILITY Extension from GitHub..." "STEP"
    Set-GuiProgress 10 "Connecting to GitHub..."
    try {
        (New-Object System.Net.WebClient).DownloadFile($url, $zipPath)
        $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Set-GuiProgress 50 "Downloaded ${sizeKB}KB"
        Write-GuiLog "Downloaded ${sizeKB}KB" "OK"
    } catch {
        Write-GuiLog "Download failed: $_" "ERR"
        Set-GuiProgress 0
        return
    }
    Write-GuiLog "Extracting to Downloads..." "STEP"
    try {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $zipPath -DestinationPath $dest -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Set-GuiProgress 100 "Complete"
        Write-GuiLog "SETT UTILITY Extension ready at Downloads\sett-utility" "OK"
        Write-GuiLog "Open chrome://extensions, enable Developer Mode and load unpacked" "INFO"
    } catch {
        Write-GuiLog "Failed to extract extension: $_" "ERR"
        Set-GuiProgress 0
    }
}
#endregion
