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
        Add-GuiBackgroundBtn $w "YTSage" { Invoke-DownloadLatestRelease -RepoOwner "oop7" -RepoName "YTSage" -AssetPattern "*ffmpeg-Setup.exe" -Label "YTSage" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
        Add-GuiBtn $w "EarTrumpet" "InstallButtonStyle" { Invoke-InstallWingetApp "9NBLGGH516XP" "EarTrumpet" "msstore" "https://apps.microsoft.com/detail/9NBLGGH516XP" }
        Add-GuiBtn $w "MovieBox-TUI" "InstallButtonStyle" { Invoke-InstallRemoteScript "https://raw.githubusercontent.com/mesamirh/MovieBox-Tui/main/install.ps1" "MovieBox-TUI" -FallbackUrl "https://github.com/mesamirh/MovieBox-Tui/releases/latest" }
    } "&#xE8B2;" "Brush_AccentPink" -WrapButtons
    Add-GuiCard (T "Utilities") (T "System tools.") {
        param($w)
        Add-GuiBtn $w "Blip Transfer" "InstallButtonStyle" { Invoke-InstallWingetApp "9N7JSXC1SJK6" "Blip Transfer" "msstore" "https://apps.microsoft.com/detail/9N7JSXC1SJK6" }
        Add-GuiBtn $w "Firemin" "InstallButtonStyle" { Invoke-InstallWingetApp "Firemin" "Firemin" -FallbackUrl "https://rizonesoft.com/downloads/firemin/" }
        Add-GuiBtn $w "AirLiveDrive" "InstallButtonStyle" { Invoke-InstallWingetApp "AirLiveDrive" "Air Live Drive" -FallbackUrl "https://www.airlivedrive.com/en/" }
        Add-GuiBackgroundBtn $w "Uninstalr" { Invoke-DownloadDirectFile -Url "https://uninstalr.com/Uninstalr_Setup.exe" -FileName "Uninstalr_Setup.exe" -Label "Uninstalr" } @('Invoke-DownloadDirectFile') $null "InstallButtonStyle"
        Add-GuiBackgroundBtn $w "SETT Metter" { Invoke-DownloadLatestRelease -RepoOwner "otaviozanon" -RepoName "SETTMetter" -Label "SETT Metter" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
        Add-GuiBackgroundBtn $w "SETT Converter" { Invoke-DownloadLatestRelease -RepoOwner "otaviozanon" -RepoName "SETTConverter" -Label "SETT Converter" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
        Add-GuiBtn $w "FDM" "InstallButtonStyle" { Invoke-InstallWingetApp "Softdeluxe.FreeDownloadManager" "FDM" -FallbackUrl "https://www.freedownloadmanager.org/" }
    } "&#xEA99;" "Brush_AccentWarm" -WrapButtons
    Add-GuiCard (T "Desktop") (T "Customization tools.") {
        param($w)
        Add-GuiBtn $w "WindHawk" "InstallButtonStyle" { Invoke-InstallWingetApp "RamenSoftware.Windhawk" "WindHawk" -FallbackUrl "https://windhawk.net/" }
        Add-GuiBtn $w "TranslucentTB" "InstallButtonStyle" { Invoke-InstallWingetApp "9PF4KZ2VN4W9" "Translucent TB" "msstore" "https://apps.microsoft.com/detail/9PF4KZ2VN4W9" }
        Add-GuiBtn $w "Seelen UI" "InstallButtonStyle" { Invoke-InstallWingetApp "9P67C2D4T9FB" "Seelen UI" "msstore" "https://apps.microsoft.com/detail/9P67C2D4T9FB" }
        Add-GuiBtn $w "Flow Launcher" "InstallButtonStyle" { Invoke-InstallWingetApp "Flow-Launcher.Flow-Launcher" "Flow Launcher" -FallbackUrl "https://www.flowlauncher.com/" }
        Add-GuiBtn $w "Lively WP" "InstallButtonStyle" { Invoke-InstallWingetApp "9NTM2QC6QWS7" "Lively Wallpaper" "msstore" "https://apps.microsoft.com/detail/9NTM2QC6QWS7" }
        Add-GuiBtn $w "RainMeter" "InstallButtonStyle" { Invoke-InstallWingetApp "Rainmeter.Rainmeter" "RainMeter" -FallbackUrl "https://www.rainmeter.net/" }
        Add-GuiBackgroundBtn $w "Nusa" { Invoke-DownloadLatestRelease -RepoOwner "rama2555" -RepoName "nusa" -AssetPattern "*.zip" -Label "Nusa" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
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
        Add-GuiBackgroundBtn $w "LuaTools" { Invoke-DownloadLatestRelease -RepoOwner "madoiscool" -RepoName "luatools" -AssetPattern "*-Setup.exe" -Label "LuaTools" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
    } "&#xE7FC;" "Brush_AccentRed" -WrapButtons
    Add-GuiCard (T "VPN Free") (T "Free VPN clients.") {
        param($w)
        Add-GuiBtn $w "ProtonVPN" "InstallButtonStyle" { Invoke-InstallWingetApp "Proton.ProtonVPN" "Proton VPN" -FallbackUrl "https://protonvpn.com/" }
        Add-GuiBtn $w "Pritunl" "InstallButtonStyle" { Invoke-InstallWingetApp "Pritunl.PritunlClient" "Pritunl" -FallbackUrl "https://client.pritunl.com/#install" }
        Add-GuiBtn $w "Riseup" "InstallButtonStyle" { Invoke-InstallWingetApp "Riseup.RiseupVPN" "Riseup VPN" -FallbackUrl "https://riseup.net/pt/windows" }
        Add-GuiBackgroundBtn $w "SettVPN" { Invoke-DownloadLatestRelease -RepoOwner "otaviozanon" -RepoName "SettVPN" -Label "SettVPN" } @('Invoke-DownloadLatestRelease') $null "InstallButtonStyle"
    } "&#xEA18;" "Brush_AccentBlue" -WrapButtons
}
