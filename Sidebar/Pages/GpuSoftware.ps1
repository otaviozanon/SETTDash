function Show-PageGpuSoftware {
    Clear-GuiContent
    Add-GuiPageTitle "GPU Software"
    Add-GuiCard "Utilities" "GPU monitoring and tuning tools." {
        param($p)
        Add-GuiBtn $p "MSI Afterburner" "ActionButtonStyle" { Invoke-InstallWingetApp "Guru3D.MSIAfterburner" "MSI Afterburner" -FallbackUrl "https://www.msi.com/Landing/afterburner/graphics-cards" }
        Add-GuiBtn $p "HWMonitor" "ActionButtonStyle" { Invoke-InstallWingetApp "CPUID.HWMonitor" "HWMonitor" -FallbackUrl "https://www.cpuid.com/softwares/hwmonitor.html" }
        Add-GuiBtn $p "GPU-Z" "ActionButtonStyle" { Invoke-InstallWingetApp "TechPowerUp.GPU-Z" "GPU-Z" -FallbackUrl "https://www.techpowerup.com/download/techpowerup-gpu-z/" }
        Add-GuiBtn $p "DDU" "ActionButtonStyle" { Invoke-InstallWingetApp "Wagnardsoft.DisplayDriverUninstaller" "DDU" -FallbackUrl "https://www.wagnardsoft.com/display-driver-uninstaller-DDU-" }
    } "&#xE7F4;" -WrapButtons
    Add-GuiCard "AMD" "AMD GPU tools." {
        param($p)
        Add-GuiBtn $p "RadeonSlimmer" "ActionButtonStyle" { Invoke-InstallWingetApp "" "RadeonSoftwareSlimmer" -FallbackUrl "https://github.com/GSDragoon/RadeonSoftwareSlimmer/releases/latest" }
        Add-GuiBtn $p "MorePowerTool" "ActionButtonStyle" { Invoke-InstallWingetApp "" "MorePowerTool" -FallbackUrl "https://www.igorslab.de/en/red-bios-rebellion-team/2/#Downloads" }
    } "&#xE7F4;" -WrapButtons
    Add-GuiCard "NVIDIA" "NVIDIA GPU tools." {
        param($p)
        Add-GuiBtn $p "NVCleanstall" "ActionButtonStyle" { Invoke-InstallWingetApp "TechPowerUp.NVCleanstall" "NVCleanstall" -FallbackUrl "https://www.techpowerup.com/download/techpowerup-nvcleanstall/" }
        Add-GuiBtn $p "NvidiaInspector" "ActionButtonStyle" { Invoke-InstallWingetApp "" "NvidiaProfileInspector" -FallbackUrl "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/latest" }
    } "&#xE7F4;" -WrapButtons
}
