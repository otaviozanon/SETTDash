function Show-PageGpuSoftware {
    Clear-GuiContent
    Add-GuiPageTitle (T "GPU Software")
    Add-GuiCard (T "Utilities") (T "GPU monitoring and tuning tools.") {
        param($p)
        Add-GuiBtn $p "MSI Afterburner" "InstallButtonStyle" { Invoke-InstallWingetApp "Guru3D.MSIAfterburner" "MSI Afterburner" -FallbackUrl "https://www.msi.com/Landing/afterburner/graphics-cards" }
        Add-GuiBtn $p "HWMonitor" "InstallButtonStyle" { Invoke-InstallWingetApp "CPUID.HWMonitor" "HWMonitor" -FallbackUrl "https://www.cpuid.com/softwares/hwmonitor.html" }
        Add-GuiBackgroundBtn $p "GPU-Z" { Invoke-DownloadTechPowerUpApp -Url "https://www.techpowerup.com/download/techpowerup-gpu-z/" -Label "GPU-Z" } @('Invoke-DownloadTechPowerUpApp') $null "InstallButtonStyle"
        Add-GuiBtn $p "DDU" "InstallButtonStyle" { Invoke-InstallWingetApp "Wagnardsoft.DisplayDriverUninstaller" "DDU" -FallbackUrl "https://www.wagnardsoft.com/display-driver-uninstaller-DDU-" }
        Add-GuiBackgroundBtn $p "mVolt" { Invoke-DownloadLatestRelease -RepoOwner "b00nz" -RepoName "mVolt" -Label "mVolt" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
    } "&#xE7F4;" -WrapButtons
    Add-GuiCard "AMD" (T "AMD GPU tools.") {
        param($p)
        Add-GuiBackgroundBtn $p "RadeonSlimmer" { Invoke-DownloadLatestRelease -RepoOwner "GSDragoon" -RepoName "RadeonSoftwareSlimmer" -AssetPattern "*net48*.zip" -Label "RadeonSlimmer" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
        Add-GuiBtn $p "MorePowerTool" "InstallButtonStyle" { Invoke-InstallWingetApp "" "MorePowerTool" -FallbackUrl "https://www.igorslab.de/en/red-bios-rebellion-team/2/#Downloads" }
    } "&#xE7F4;" -WrapButtons
    Add-GuiCard "NVIDIA" (T "NVIDIA GPU tools.") {
        param($p)
        Add-GuiBackgroundBtn $p "NVCleanstall" { Invoke-DownloadTechPowerUpApp -Url "https://www.techpowerup.com/download/techpowerup-nvcleanstall/" -Label "NVCleanstall" } @('Invoke-DownloadTechPowerUpApp') $null "InstallButtonStyle"
        Add-GuiBackgroundBtn $p "Nvidia Profile Inspector" { Invoke-DownloadLatestRelease -RepoOwner "Orbmu2k" -RepoName "nvidiaProfileInspector" -AssetPattern "*.zip" -Label "Nvidia Profile Inspector" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
        Add-GuiBackgroundBtn $p "NvidiaInspector" { Invoke-DownloadTechPowerUpApp -Url "https://www.techpowerup.com/download/nvidia-inspector/" -Label "NvidiaInspector" } @('Invoke-DownloadTechPowerUpApp') $null "InstallButtonStyle"
    } "&#xE7F4;" -WrapButtons
}
