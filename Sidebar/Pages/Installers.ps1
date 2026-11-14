# Used by: Installers page only
function Invoke-RunAllPrograms {
    $ap = Join-Path $Script:AppDir "Requirements\0_AllPrograms.exe"
    if (Test-Path $ap) { Start-Process $ap; Write-GuiLog (T "AllPrograms installer launched") "OK" }
    else { Write-GuiLog (T "0_AllPrograms.exe not found in Requirements folder") "ERR" }
}
function Show-PageInstallers {
    Clear-GuiContent
    Add-GuiPageTitle (T "Essentials")

    # Highlighted all-in-one installer card
    Add-GuiCard (T "All-in-One Installer") (T "Automatically installs all essential programs with a single click. Place 0_AllPrograms.exe next to SETTDash.exe.") {
        param($p) Add-GuiBtn $p (T "Run Installer") "InstallButtonStyle" { Invoke-RunAllPrograms }
    } "&#xE7B8;" "Brush_AccentGreen" -WrapButtons

    # Full-width cards stacked vertically, same pattern as every other page:
    # title left, buttons right while there's room, wrapping below (left-aligned)
    # once the window gets narrow.
    Add-GuiCard (T "Developer") (T "Code and CLI tools.") {
        param($w)
        Add-GuiBtn $w "GitHub CLI" "InstallButtonStyle" { Invoke-InstallWingetApp "GitHub.cli" "GitHub CLI" -FallbackUrl "https://cli.github.com/" }
        Add-GuiBtn $w "VS Code" "InstallButtonStyle" { Invoke-InstallWingetApp "Microsoft.VisualStudioCode" "VS Code" -FallbackUrl "https://code.visualstudio.com/" }
        Add-GuiBtn $w "NodeJS" "InstallButtonStyle" { Invoke-InstallWingetApp "OpenJS.NodeJS.LTS" "NodeJS" -FallbackUrl "https://nodejs.org/" }
        Add-GuiBtn $w "Python" "InstallButtonStyle" { Invoke-InstallWingetApp "Python.Python.3.13" "Python 3.13" -FallbackUrl "https://www.python.org/downloads/" }
    } "&#xE770;" "Brush_AccentBlue" -WrapButtons
    Add-GuiCard (T "Media") (T "Audio and video.") {
        param($w)
        Add-GuiBtn $w "Spotify" "InstallButtonStyle" { Invoke-InstallWingetApp "Spotify.Spotify" "Spotify" -FallbackUrl "https://www.spotify.com/download/" }
        Add-GuiBtn $w "Image Glass" "InstallButtonStyle" { Invoke-InstallWingetApp "DuongDieuPhap.ImageGlass" "Image Glass" -FallbackUrl "https://imageglass.org/" }
        Add-GuiBtn $w "Lightshot" "InstallButtonStyle" { Invoke-InstallWingetApp "Skillbrains.Lightshot" "Lightshot" -FallbackUrl "https://app.prntscr.com/" }
        Add-GuiBtn $w "YTSage" "InstallButtonStyle" { Invoke-InstallWingetApp "" "YTSage" -FallbackUrl "https://github.com/oop7/YTSage/releases/download/v5.2.0/YTSage-v5.2.0-Setup.exe" }
        Add-GuiBtn $w "EarTrumpet" "InstallButtonStyle" { Invoke-InstallWingetApp "9NBLGGH516XP" "EarTrumpet" "msstore" "https://apps.microsoft.com/detail/9NBLGGH516XP" }
        Add-GuiBtn $w "MovieBox-TUI" "InstallButtonStyle" { Invoke-InstallRemoteScript "https://raw.githubusercontent.com/mesamirh/MovieBox-Tui/main/install.ps1" "MovieBox-TUI" -FallbackUrl "https://github.com/mesamirh/MovieBox-Tui" }
    } "&#xE8B2;" "Brush_AccentPink" -WrapButtons
    Add-GuiCard (T "Utilities") (T "System tools.") {
        param($w)
        Add-GuiBtn $w "Blip Transfer" "InstallButtonStyle" { Invoke-InstallWingetApp "9N7JSXC1SJK6" "Blip Transfer" "msstore" "https://apps.microsoft.com/detail/9N7JSXC1SJK6" }
        Add-GuiBtn $w "Firemin" "InstallButtonStyle" { Invoke-InstallWingetApp "Firemin" "Firemin" -FallbackUrl "https://rizonesoft.com/downloads/firemin/" }
        Add-GuiBtn $w "AirLiveDrive" "InstallButtonStyle" { Invoke-InstallWingetApp "AirLiveDrive" "Air Live Drive" -FallbackUrl "https://www.airlivedrive.com/en/" }
        Add-GuiBtn $w "Uninstalr" "InstallButtonStyle" { Invoke-InstallWingetApp "" "Uninstalr" -FallbackUrl "https://uninstalr.com/download/" }
        Add-GuiBtn $w "Kudu" "InstallButtonStyle" { Invoke-InstallWingetApp "" "Kudu" -FallbackUrl "https://github.com/AdventDevInc/kudu/releases/download/v1.47.0/Kudu-Setup-1.47.0.exe" }
        Add-GuiBtn $w "FDM" "InstallButtonStyle" { Invoke-InstallWingetApp "Softdeluxe.FreeDownloadManager" "FDM" -FallbackUrl "https://www.freedownloadmanager.org/" }
        Add-GuiBtn $w "filee.sh" "InstallButtonStyle" { Invoke-InstallWingetApp "" "filee.sh" -FallbackUrl "https://filee.sh/#download" }
    } "&#xEA99;" "Brush_AccentWarm" -WrapButtons
    Add-GuiCard (T "Desktop") (T "Customization tools.") {
        param($w)
        Add-GuiBtn $w "WindHawk" "InstallButtonStyle" { Invoke-InstallWingetApp "RamenSoftware.Windhawk" "WindHawk" -FallbackUrl "https://windhawk.net/" }
        Add-GuiBtn $w "TranslucentTB" "InstallButtonStyle" { Invoke-InstallWingetApp "9PF4KZ2VN4W9" "Translucent TB" "msstore" "https://apps.microsoft.com/detail/9PF4KZ2VN4W9" }
        Add-GuiBtn $w "Seelen UI" "InstallButtonStyle" { Invoke-InstallWingetApp "9P67C2D4T9FB" "Seelen UI" "msstore" "https://apps.microsoft.com/detail/9P67C2D4T9FB" }
        Add-GuiBtn $w "Flow Launcher" "InstallButtonStyle" { Invoke-InstallWingetApp "Flow-Launcher.Flow-Launcher" "Flow Launcher" -FallbackUrl "https://www.flowlauncher.com/" }
        Add-GuiBtn $w "Lively WP" "InstallButtonStyle" { Invoke-InstallWingetApp "9NTM2QC6QWS7" "Lively Wallpaper" "msstore" "https://apps.microsoft.com/detail/9NTM2QC6QWS7" }
        Add-GuiBtn $w "RainMeter" "InstallButtonStyle" { Invoke-InstallWingetApp "Rainmeter.Rainmeter" "RainMeter" -FallbackUrl "https://www.rainmeter.net/" }
        Add-GuiBtn $w "Nusa" "InstallButtonStyle" { Invoke-InstallWingetApp "" "Nusa" -FallbackUrl "https://github.com/rama2555/nusa/releases/latest/download/NusaSetup.zip" }
    } "&#xE771;" "Brush_AccentCyan" -WrapButtons
    Add-GuiCard (T "Communication") (T "Chat and voice.") {
        param($w)
        Add-GuiBtn $w "TeamSpeak" "InstallButtonStyle" { Invoke-InstallWingetApp "TeamSpeakSystems.TeamSpeak" "TeamSpeak" -FallbackUrl "https://www.teamspeak.com/en/downloads/" }
        Add-GuiBtn $w "Vencord" "InstallButtonStyle" { Invoke-InstallWingetApp "Vencord.Vendroid" "Vencord" -FallbackUrl "https://vencord.dev/" }
    } "&#xE8BD;" "Brush_AccentPurple" -WrapButtons
    Add-GuiCard (T "Games") (T "Gaming platforms.") {
        param($w)
        Add-GuiBtn $w "FACEIT" "InstallButtonStyle" { Invoke-InstallWingetApp "FACEITLTD.FACEITClient" "FACEIT" -FallbackUrl "https://www.faceit.com/en/downloads" }
        Add-GuiBtn $w "GamersClub" "InstallButtonStyle" { Invoke-InstallWingetApp "br.gamersclub.launcher" "GamersClub" -FallbackUrl "https://gamersclub.com.br/" }
        Add-GuiBtn $w "LuaTools" "InstallButtonStyle" { Invoke-InstallWingetApp "" "LuaTools" -FallbackUrl "https://github.com/madoiscool/luatools/releases/latest/download/LuaTools-win-Setup.exe" }
    } "&#xE7FC;" "Brush_AccentRed" -WrapButtons
    Add-GuiCard (T "VPN Free") (T "Free VPN clients.") {
        param($w)
        Add-GuiBtn $w "ProtonVPN" "InstallButtonStyle" { Invoke-InstallWingetApp "Proton.ProtonVPN" "Proton VPN" -FallbackUrl "https://protonvpn.com/" }
        Add-GuiBtn $w "Pritunl" "InstallButtonStyle" { Invoke-InstallWingetApp "Pritunl.PritunlClient" "Pritunl" -FallbackUrl "https://client.pritunl.com/#install" }
        Add-GuiBtn $w "Riseup" "InstallButtonStyle" { Invoke-InstallWingetApp "Riseup.RiseupVPN" "Riseup VPN" -FallbackUrl "https://riseup.net/pt/windows" }
        Add-GuiBtn $w "SettVPN" "InstallButtonStyle" { Invoke-InstallWingetApp "" "SettVPN" -FallbackUrl "https://github.com/otaviozanon/SettVPN/releases" }
    } "&#xEA18;" "Brush_AccentBlue" -WrapButtons
}
