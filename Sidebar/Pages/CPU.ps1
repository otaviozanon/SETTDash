function Show-PageCPU {
    Clear-GuiContent
    Add-GuiPageTitle "CPU Software"
    Add-GuiCard "AMD" "AMD CPU tools." {
        param($p)
        Add-GuiBtn $p "Ryzen Master" "InstallButtonStyle" { Invoke-InstallWingetApp "AMD.RyzenMaster" "Ryzen Master" -FallbackUrl "https://www.amd.com/en/products/software/ryzen-master.html" }
    } "&#xE950;" -WrapButtons
    Add-GuiCard "Intel" "Intel CPU tools." {
        param($p)
        Add-GuiBtn $p "XTU" "InstallButtonStyle" { Invoke-InstallWingetApp "Intel.ExtremeTuningUtility" "Extreme Tuning Utility" -FallbackUrl "https://www.intel.com/content/www/us/en/download/17881/intel-extreme-tuning-utility-intel-xtu.html" }
        Add-GuiBtn $p "ThrottleStop" "InstallButtonStyle" { Invoke-InstallWingetApp "TechPowerUp.ThrottleStop" "ThrottleStop" -FallbackUrl "https://www.techpowerup.com/download/techpowerup-throttlestop/" }
    } "&#xE950;" -WrapButtons
    Add-GuiCard "Utilities" "CPU utilities." {
        param($p)
        Add-GuiBtn $p "FanControl" "InstallButtonStyle" { Invoke-InstallWingetApp "Rem0o.FanControl" "FanControl" -FallbackUrl "https://getfancontrol.com/" }
    } "&#xE950;" -WrapButtons
}
