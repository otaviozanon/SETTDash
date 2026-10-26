# Used by: Installers page only
function Invoke-RunAllPrograms {
    $ap = Join-Path $Script:AppDir "Requirements\0_AllPrograms.exe"
    if (Test-Path $ap) { Start-Process $ap; Write-GuiLog "AllPrograms installer launched" "OK" }
    else { Write-GuiLog "0_AllPrograms.exe not found in Requirements folder" "ERR" }
}
function Show-PageInstallers {
    Clear-GuiContent
    Add-GuiPageTitle "Essentials"

    # Highlighted all-in-one installer card
    Add-GuiCard "All-in-One Installer" "Automatically installs all essential programs with a single click. Place 0_AllPrograms.exe next to SETTDash.exe." {
        param($p) Add-GuiBtn $p "Run Installer" "ActionButtonStyle" { Invoke-RunAllPrograms }
    } "&#xE7B8;" "#3FB950" -WrapButtons

    # Full-width cards stacked vertically, same pattern as every other page:
    # title left, buttons right while there's room, wrapping below (left-aligned)
    # once the window gets narrow.
    Add-GuiCard "Developer" "Code and CLI tools." {
        param($w)
        Add-GuiBtn $w "GitHub CLI" "ActionButtonStyle" { Invoke-InstallWingetApp "GitHub.cli" "GitHub CLI" -FallbackUrl "https://cli.github.com/" }
        Add-GuiBtn $w "VS Code" "ActionButtonStyle" { Invoke-InstallWingetApp "Microsoft.VisualStudioCode" "VS Code" -FallbackUrl "https://code.visualstudio.com/" }
        Add-GuiBtn $w "NodeJS" "ActionButtonStyle" { Invoke-InstallWingetApp "OpenJS.NodeJS.LTS" "NodeJS" -FallbackUrl "https://nodejs.org/" }
        Add-GuiBtn $w "Python" "ActionButtonStyle" { Invoke-InstallWingetApp "Python.Python.3.13" "Python 3.13" -FallbackUrl "https://www.python.org/downloads/" }
    } "&#xE770;" "#58A6FF" -WrapButtons
    Add-GuiCard "Media" "Audio and video." {
        param($w)
        Add-GuiBtn $w "Spotify" "ActionButtonStyle" { Invoke-InstallWingetApp "Spotify.Spotify" "Spotify" -FallbackUrl "https://www.spotify.com/download/" }
        Add-GuiBtn $w "Image Glass" "ActionButtonStyle" { Invoke-InstallWingetApp "DuongDieuPhap.ImageGlass" "Image Glass" -FallbackUrl "https://imageglass.org/" }
        Add-GuiBtn $w "Lightshot" "ActionButtonStyle" { Invoke-InstallWingetApp "Skillbrains.Lightshot" "Lightshot" -FallbackUrl "https://app.prntscr.com/" }
        Add-GuiBtn $w "YTSage" "ActionButtonStyle" { Invoke-InstallWingetApp "" "YTSage" -FallbackUrl "https://github.com/oop7/YTSage/releases/download/v5.2.0/YTSage-v5.2.0-Setup.exe" }
        Add-GuiBtn $w "EarTrumpet" "ActionButtonStyle" { Invoke-InstallWingetApp "9NBLGGH516XP" "EarTrumpet" "msstore" "https://apps.microsoft.com/detail/9NBLGGH516XP" }
        Add-GuiBtn $w "MovieBox-TUI" "ActionButtonStyle" { Invoke-InstallRemoteScript "https://raw.githubusercontent.com/mesamirh/MovieBox-Tui/main/install.ps1" "MovieBox-TUI" -FallbackUrl "https://github.com/mesamirh/MovieBox-Tui" }
    } "&#xE8B2;" "#DB61A2" -WrapButtons
    Add-GuiCard "Utilities" "System tools." {
        param($w)
        Add-GuiBtn $w "Blip Transfer" "ActionButtonStyle" { Invoke-InstallWingetApp "9N7JSXC1SJK6" "Blip Transfer" "msstore" "https://apps.microsoft.com/detail/9N7JSXC1SJK6" }
        Add-GuiBtn $w "Firemin" "ActionButtonStyle" { Invoke-InstallWingetApp "Firemin" "Firemin" -FallbackUrl "https://rizonesoft.com/downloads/firemin/" }
        Add-GuiBtn $w "AirLiveDrive" "ActionButtonStyle" { Invoke-InstallWingetApp "AirLiveDrive" "Air Live Drive" -FallbackUrl "https://www.airlivedrive.com/en/" }
        Add-GuiBtn $w "Uninstalr" "ActionButtonStyle" { Invoke-InstallWingetApp "" "Uninstalr" -FallbackUrl "https://uninstalr.com/download/" }
        Add-GuiBtn $w "Kudu" "ActionButtonStyle" { Invoke-InstallWingetApp "" "Kudu" -FallbackUrl "https://github.com/AdventDevInc/kudu/releases/download/v1.47.0/Kudu-Setup-1.47.0.exe" }
        Add-GuiBtn $w "FDM" "ActionButtonStyle" { Invoke-InstallWingetApp "Softdeluxe.FreeDownloadManager" "FDM" -FallbackUrl "https://www.freedownloadmanager.org/" }
    } "&#xEA99;" "#F0883E" -WrapButtons
    Add-GuiCard "Desktop" "Customization tools." {
        param($w)
        Add-GuiBtn $w "WindHawk" "ActionButtonStyle" { Invoke-InstallWingetApp "RamenSoftware.Windhawk" "WindHawk" -FallbackUrl "https://windhawk.net/" }
        Add-GuiBtn $w "TranslucentTB" "ActionButtonStyle" { Invoke-InstallWingetApp "9PF4KZ2VN4W9" "Translucent TB" "msstore" "https://apps.microsoft.com/detail/9PF4KZ2VN4W9" }
        Add-GuiBtn $w "Seelen UI" "ActionButtonStyle" { Invoke-InstallWingetApp "9P67C2D4T9FB" "Seelen UI" "msstore" "https://apps.microsoft.com/detail/9P67C2D4T9FB" }
        Add-GuiBtn $w "Flow Launcher" "ActionButtonStyle" { Invoke-InstallWingetApp "Flow-Launcher.Flow-Launcher" "Flow Launcher" -FallbackUrl "https://www.flowlauncher.com/" }
        Add-GuiBtn $w "Lively WP" "ActionButtonStyle" { Invoke-InstallWingetApp "9NTM2QC6QWS7" "Lively Wallpaper" "msstore" "https://apps.microsoft.com/detail/9NTM2QC6QWS7" }
        Add-GuiBtn $w "RainMeter" "ActionButtonStyle" { Invoke-InstallWingetApp "Rainmeter.Rainmeter" "RainMeter" -FallbackUrl "https://www.rainmeter.net/" }
    } "&#xE771;" "#39C5CF" -WrapButtons
    Add-GuiCard "Communication" "Chat and voice." {
        param($w)
        Add-GuiBtn $w "TeamSpeak" "ActionButtonStyle" { Invoke-InstallWingetApp "TeamSpeakSystems.TeamSpeak" "TeamSpeak" -FallbackUrl "https://www.teamspeak.com/en/downloads/" }
        Add-GuiBtn $w "Vencord" "ActionButtonStyle" { Invoke-InstallWingetApp "Vencord.Vendroid" "Vencord" -FallbackUrl "https://vencord.dev/" }
    } "&#xE8BD;" "#A371F7" -WrapButtons
    Add-GuiCard "Games" "Gaming platforms." {
        param($w)
        Add-GuiBtn $w "FACEIT" "ActionButtonStyle" { Invoke-InstallWingetApp "FACEITLTD.FACEITClient" "FACEIT" -FallbackUrl "https://www.faceit.com/en/downloads" }
        Add-GuiBtn $w "GamersClub" "ActionButtonStyle" { Invoke-InstallWingetApp "br.gamersclub.launcher" "GamersClub" -FallbackUrl "https://gamersclub.com.br/" }
    } "&#xE7FC;" "#F85149" -WrapButtons
    Add-GuiCard "VPN Free" "Free VPN clients." {
        param($w)
        Add-GuiBtn $w "ProtonVPN" "ActionButtonStyle" { Invoke-InstallWingetApp "Proton.ProtonVPN" "Proton VPN" -FallbackUrl "https://protonvpn.com/" }
        Add-GuiBtn $w "Pritunl" "ActionButtonStyle" { Invoke-InstallWingetApp "Pritunl.PritunlClient" "Pritunl" -FallbackUrl "https://client.pritunl.com/#install" }
        Add-GuiBtn $w "Riseup" "ActionButtonStyle" { Invoke-InstallWingetApp "Riseup.RiseupVPN" "Riseup VPN" -FallbackUrl "https://riseup.net/pt/windows" }
        Add-GuiBtn $w "SettVPN" "ActionButtonStyle" { Invoke-InstallWingetApp "" "SettVPN" -FallbackUrl "https://github.com/otaviozanon/SettVPN/releases" }
    } "&#xEA18;" "#58A6FF" -WrapButtons
}
