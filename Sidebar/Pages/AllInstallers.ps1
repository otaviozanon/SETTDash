# Used by: AllInstallers page only
# Initialize script-scope variables for ALL Programs page
$global:AllAppsData = @{}
$global:AllSelectedSet = New-Object 'System.Collections.Generic.List[int]'
$global:AllInstallBtn = $null
$global:AllWrapPanels = $null

function Invoke-AllChecked {
    param($cb, $e)
    if ($null -eq $cb -or $null -eq $cb.Tag) { return }
    $idx = [int]$cb.Tag
    $bd = $cb.Parent
    if ($bd -is [System.Windows.Controls.Border]) {
        $bd.Background = "#0D419D"
        $bd.BorderBrush = "#1F6FEB"
    }
    if ($null -ne $global:AllSelectedSet) {
        if (-not ($global:AllSelectedSet.Contains($idx))) {
            $global:AllSelectedSet.Add($idx) | Out-Null
        }
    }
    $cnt = $global:AllSelectedSet.Count
    if ($null -ne $global:AllInstallBtn) {
        $global:AllInstallBtn.Content = "Install Selected [$cnt]"
        $global:AllInstallBtn.Background = if ($cnt -gt 0) { "#2EA043" } else { "#238636" }
    }
}

function Invoke-AllUnchecked {
    param($cb, $e)
    if ($null -eq $cb -or $null -eq $cb.Tag) { return }
    $idx = [int]$cb.Tag
    $bd = $cb.Parent
    if ($bd -is [System.Windows.Controls.Border]) {
        $bd.Background = "#161B22"
        $bd.BorderBrush = "#21262D"
    }
    if ($null -ne $global:AllSelectedSet) { $global:AllSelectedSet.Remove($idx) }
    $cnt = $global:AllSelectedSet.Count
    if ($null -ne $global:AllInstallBtn) {
        $global:AllInstallBtn.Content = "Install Selected [$cnt]"
        $global:AllInstallBtn.Background = if ($cnt -gt 0) { "#2EA043" } else { "#238636" }
    }
}

function Invoke-AllFilter {
    param($tb)
    if ($null -eq $tb) { return }
    try { $f = $tb.Text.ToLowerInvariant() } catch { return }
    if ($null -eq $global:AllWrapPanels) { return }
    foreach ($wpanel in $global:AllWrapPanels) {
        if ($null -eq $wpanel) { continue }
        foreach ($child in $wpanel.Children) {
            if ($child -is [System.Windows.Controls.Border] -and $child.Child -is [System.Windows.Controls.CheckBox]) {
                $txt = $child.Child.Content.ToString().ToLowerInvariant()
                $child.Visibility = if ($f -eq "" -or $txt.Contains($f)) { "Visible" } else { "Collapsed" }
            }
        }
    }
}

function Invoke-AllInstallSelected {
    if ($null -eq $global:AllSelectedSet -or $global:AllSelectedSet.Count -eq 0) { return }
    $count = $global:AllSelectedSet.Count
    $ids = $global:AllSelectedSet.ToArray() | Sort-Object
    Write-GuiLog "Installing $count selected program(s)..." "STEP"
    foreach ($idx in $ids) {
        $d2 = $global:AllAppsData[$idx]
        if ($d2) { Invoke-InstallWingetApp $d2.Winget $d2.Name -FallbackUrl $d2.Url }
    }
    Write-GuiLog "Done." "OK"
}

function Show-PageAllInstallers {
    Clear-GuiContent
    Add-GuiPageTitle "ALL Programs"

    # --- Data ---
    $global:AllAppsData.Clear()
    $global:AllSelectedSet.Clear()

    # --- Search + Install bar ---
    $topRow = New-Object System.Windows.Controls.StackPanel
    $topRow.Orientation = "Horizontal"; $topRow.Margin = "0,0,0,8"

    $searchBorder = New-Object System.Windows.Controls.Border
    $searchBorder.Background = "#0D1117"; $searchBorder.BorderBrush = "#1F6FEB"; $searchBorder.BorderThickness = "1"
    $searchBorder.CornerRadius = "8"; $searchBorder.Padding = "4,3,4,3"
    $searchBorder.Width = 520

    $searchGrid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "Auto"
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = "*"
    $searchGrid.ColumnDefinitions.Add($c1); $searchGrid.ColumnDefinitions.Add($c2)

    $searchIcon = New-Object System.Windows.Controls.TextBlock
    $searchIcon.Text = "Q"; $searchIcon.Foreground = "#58A6FF"; $searchIcon.FontSize = 15
    $searchIcon.FontWeight = "Bold"; $searchIcon.VerticalAlignment = "Center"; $searchIcon.Margin = "4,0,6,0"
    [System.Windows.Controls.Grid]::SetColumn($searchIcon, 0); $searchGrid.AddChild($searchIcon)

    $tb = New-Object System.Windows.Controls.TextBox
    $tb.MinWidth = 300; $tb.Height = 24; $tb.FontSize = 13
    $tb.Background = "Transparent"; $tb.Foreground = "#C9D1D9"; $tb.BorderBrush = "Transparent"; $tb.BorderThickness = "0"
    $tb.CaretBrush = "#58A6FF"; $tb.Padding = "2,3,2,2"; $tb.VerticalContentAlignment = "Center"
    $tb.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($tb, 1); $searchGrid.AddChild($tb)
    $searchBorder.Child = $searchGrid
    $topRow.AddChild($searchBorder)

    $btnInstall = New-Object System.Windows.Controls.Button
    $btnInstall.Content = "Install Selected [0]"
    $btnInstall.Background = "#238636"; $btnInstall.Foreground = "White"
    $btnInstall.FontSize = 12; $btnInstall.FontWeight = "SemiBold"
    $btnInstall.MinHeight = 30; $btnInstall.Padding = "18,0"; $btnInstall.Cursor = "Hand"
    $btnInstall.BorderThickness = "0"
    $btnInstall.VerticalAlignment = "Center"; $btnInstall.Margin = "10,0,0,0"
    $topRow.AddChild($btnInstall)

    $pnlContent.AddChild($topRow)

    # Store button reference at script scope for handlers
    $global:AllInstallBtn = $btnInstall

    $global:AllAppsData[0] = @{Cat='Browsers'; Name='Brave'; Winget='Brave.Brave'; Url='https://www.brave.com'}
    $global:AllAppsData[1] = @{Cat='Browsers'; Name='Chrome'; Winget='Google.Chrome'; Url='https://www.google.com/chrome/'}
    $global:AllAppsData[2] = @{Cat='Browsers'; Name='Chromium'; Winget='Hibbiki.Chromium'; Url='https://github.com/Hibbiki/chromium-win64'}
    $global:AllAppsData[3] = @{Cat='Browsers'; Name='Edge'; Winget='Microsoft.Edge'; Url='https://www.microsoft.com/edge'}
    $global:AllAppsData[4] = @{Cat='Browsers'; Name='Firefox'; Winget='Mozilla.Firefox'; Url='https://www.mozilla.org/en-US/firefox/new/'}
    $global:AllAppsData[5] = @{Cat='Browsers'; Name='Firefox ESR'; Winget='Mozilla.Firefox.ESR'; Url='https://www.mozilla.org/en-US/firefox/enterprise/'}
    $global:AllAppsData[6] = @{Cat='Browsers'; Name='Floorp'; Winget='Ablaze.Floorp'; Url='https://floorp.app/'}
    $global:AllAppsData[7] = @{Cat='Browsers'; Name='Helium'; Winget='ImputNet.Helium'; Url='https://github.com/imputnet/helium/'}
    $global:AllAppsData[8] = @{Cat='Browsers'; Name='LibreWolf'; Winget='LibreWolf.LibreWolf'; Url='https://librewolf-community.gitlab.io/'}
    $global:AllAppsData[9] = @{Cat='Browsers'; Name='Mullvad Browser'; Winget='MullvadVPN.MullvadBrowser'; Url='https://mullvad.net/browser'}
    $global:AllAppsData[10] = @{Cat='Browsers'; Name='Tor Browser'; Winget='TorProject.TorBrowser'; Url='https://www.torproject.org/'}
    $global:AllAppsData[11] = @{Cat='Browsers'; Name='Ungoogled Chromium'; Winget='eloston.ungoogled-chromium'; Url='https://github.com/Eloston/ungoogled-chromium'}
    $global:AllAppsData[12] = @{Cat='Browsers'; Name='Vivaldi'; Winget='Vivaldi.Vivaldi'; Url='https://vivaldi.com/'}
    $global:AllAppsData[13] = @{Cat='Browsers'; Name='Waterfox'; Winget='Waterfox.Waterfox'; Url='https://www.waterfox.net/'}
    $global:AllAppsData[14] = @{Cat='Browsers'; Name='Zen Browser'; Winget='Zen-Team.Zen-Browser'; Url='https://zen-browser.app/'}
    $global:AllAppsData[15] = @{Cat='Communications'; Name='Chatterino'; Winget='ChatterinoTeam.Chatterino'; Url='https://www.chatterino.com/'}
    $global:AllAppsData[16] = @{Cat='Communications'; Name='Discord'; Winget='Discord.Discord'; Url='https://discord.com/'}
    $global:AllAppsData[17] = @{Cat='Communications'; Name='Dorion'; Winget='SpikeHD.Dorion'; Url='https://github.com/SpikeHD/Dorion'}
    $global:AllAppsData[18] = @{Cat='Communications'; Name='Element'; Winget='Element.Element'; Url='https://element.io/'}
    $global:AllAppsData[19] = @{Cat='Communications'; Name='Proton Mail'; Winget='Proton.ProtonMail'; Url='https://proton.me/mail'}
    $global:AllAppsData[20] = @{Cat='Communications'; Name='QTox'; Winget='Tox.qTox'; Url='https://qtox.github.io/'}
    $global:AllAppsData[21] = @{Cat='Communications'; Name='Signal'; Winget='OpenWhisperSystems.Signal'; Url='https://signal.org/'}
    $global:AllAppsData[22] = @{Cat='Communications'; Name='Slack'; Winget='SlackTechnologies.Slack'; Url='https://slack.com/'}
    $global:AllAppsData[23] = @{Cat='Communications'; Name='Teams'; Winget='Microsoft.Teams'; Url='https://www.microsoft.com/en-us/microsoft-teams/group-chat-software'}
    $global:AllAppsData[24] = @{Cat='Communications'; Name='TeamSpeak 3'; Winget='TeamSpeakSystems.TeamSpeakClient'; Url='https://www.teamspeak.com/'}
    $global:AllAppsData[25] = @{Cat='Communications'; Name='Telegram'; Winget='Telegram.TelegramDesktop'; Url='https://telegram.org/'}
    $global:AllAppsData[26] = @{Cat='Communications'; Name='Thunderbird'; Winget='Mozilla.Thunderbird'; Url='https://www.thunderbird.net/'}
    $global:AllAppsData[27] = @{Cat='Communications'; Name='Betterbird'; Winget='Betterbird.Betterbird'; Url='https://www.betterbird.eu/'}
    $global:AllAppsData[28] = @{Cat='Communications'; Name='Vesktop'; Winget='Vencord.Vesktop'; Url='https://github.com/Vencord/Vesktop'}
    $global:AllAppsData[29] = @{Cat='Communications'; Name='Viber'; Winget='Rakuten.Viber'; Url='https://www.viber.com/'}
    $global:AllAppsData[30] = @{Cat='Communications'; Name='WhatsApp Desktop'; Winget='msstore:9NKSQGP7F2NH'; Url='https://apps.microsoft.com/detail/9nksqgp7f2nh'}
    $global:AllAppsData[31] = @{Cat='Communications'; Name='Zoom'; Winget='Zoom.Zoom'; Url='https://zoom.us/'}
    $global:AllAppsData[32] = @{Cat='Development'; Name='ChatGPT Desktop'; Winget='msstore:9NT1R1C2HH7J'; Url='https://apps.microsoft.com/detail/9nt1r1c2hh7j'}
    $global:AllAppsData[33] = @{Cat='Development'; Name='Claude Desktop'; Winget='Anthropic.Claude'; Url='https://claude.ai/download'}
    $global:AllAppsData[34] = @{Cat='Development'; Name='Claude Code'; Winget='Anthropic.ClaudeCode'; Url='https://code.claude.com/'}
    $global:AllAppsData[35] = @{Cat='Development'; Name='CMake'; Winget='Kitware.CMake'; Url='https://cmake.org/'}
    $global:AllAppsData[36] = @{Cat='Development'; Name='Codex'; Winget='OpenAI.Codex'; Url='https://developers.openai.com/codex/cli'}
    $global:AllAppsData[37] = @{Cat='Development'; Name='Cursor'; Winget='Anysphere.Cursor'; Url='https://cursor.com/'}
    $global:AllAppsData[38] = @{Cat='Development'; Name='Git'; Winget='Git.Git'; Url='https://git-scm.com/'}
    $global:AllAppsData[39] = @{Cat='Development'; Name='GitHub Desktop'; Winget='GitHub.GitHubDesktop'; Url='https://desktop.github.com/'}
    $global:AllAppsData[40] = @{Cat='Development'; Name='Go'; Winget='GoLang.Go'; Url='https://go.dev/'}
    $global:AllAppsData[41] = @{Cat='Development'; Name='Amazon Corretto 8 (LTS)'; Winget='Amazon.Corretto.8.JDK'; Url='https://aws.amazon.com/corretto'}
    $global:AllAppsData[42] = @{Cat='Development'; Name='Amazon Corretto 21 (LTS)'; Winget='Amazon.Corretto.21.JDK'; Url='https://aws.amazon.com/corretto'}
    $global:AllAppsData[43] = @{Cat='Development'; Name='Amazon Corretto 25 (LTS)'; Winget='Amazon.Corretto.25.JDK'; Url='https://aws.amazon.com/corretto'}
    $global:AllAppsData[44] = @{Cat='Development'; Name='Jetbrains Toolbox'; Winget='JetBrains.Toolbox'; Url='https://www.jetbrains.com/toolbox/'}
    $global:AllAppsData[45] = @{Cat='Development'; Name='Lazygit'; Winget='JesseDuffield.lazygit'; Url='https://github.com/jesseduffield/lazygit/'}
    $global:AllAppsData[46] = @{Cat='Development'; Name='Neovim'; Winget='Neovim.Neovim'; Url='https://neovim.io/'}
    $global:AllAppsData[47] = @{Cat='Development'; Name='NodeJS'; Winget='OpenJS.NodeJS'; Url='https://nodejs.org/'}
    $global:AllAppsData[48] = @{Cat='Development'; Name='NodeJS LTS'; Winget='OpenJS.NodeJS.LTS'; Url='https://nodejs.org/'}
    $global:AllAppsData[49] = @{Cat='Development'; Name='pnpm'; Winget='pnpm.pnpm'; Url='https://pnpm.io/'}
    $global:AllAppsData[50] = @{Cat='Development'; Name='Oh My Posh (Prompt)'; Winget='JanDeDobbeleer.OhMyPosh'; Url='https://ohmyposh.dev/'}
    $global:AllAppsData[51] = @{Cat='Development'; Name='Python3'; Winget='Python.Python.3.14'; Url='https://www.python.org/'}
    $global:AllAppsData[52] = @{Cat='Development'; Name='Rust'; Winget='Rustlang.Rust.MSVC'; Url='https://www.rust-lang.org/'}
    $global:AllAppsData[53] = @{Cat='Development'; Name='System Informer'; Winget='WinsiderSS.SystemInformer'; Url='https://systeminformer.com/'}
    $global:AllAppsData[54] = @{Cat='Development'; Name='Sublime Text'; Winget='SublimeHQ.SublimeText.4'; Url='https://www.sublimetext.com/'}
    $global:AllAppsData[55] = @{Cat='Development'; Name='Unity Game Engine'; Winget='Unity.UnityHub'; Url='https://unity.com/'}
    $global:AllAppsData[56] = @{Cat='Development'; Name='Visual Studio 2022'; Winget='Microsoft.VisualStudio.2022.Community'; Url='https://visualstudio.microsoft.com/'}
    $global:AllAppsData[57] = @{Cat='Development'; Name='Visual Studio 2026'; Winget='Microsoft.VisualStudio.Community'; Url='https://visualstudio.microsoft.com/'}
    $global:AllAppsData[58] = @{Cat='Development'; Name='VS Code'; Winget='Microsoft.VisualStudioCode'; Url='https://code.visualstudio.com/'}
    $global:AllAppsData[59] = @{Cat='Development'; Name='VS Codium'; Winget='VSCodium.VSCodium'; Url='https://vscodium.com/'}
    $global:AllAppsData[60] = @{Cat='Development'; Name='Yarn'; Winget='Yarn.Yarn'; Url='https://yarnpkg.com/'}
    $global:AllAppsData[61] = @{Cat='Development'; Name='uv'; Winget='astral-sh.uv'; Url='https://docs.astral.sh/uv/getting-started/installation/'}
    $global:AllAppsData[62] = @{Cat='Development'; Name='Zed'; Winget='ZedIndustries.Zed'; Url='https://zed.dev/'}
    $global:AllAppsData[63] = @{Cat='Development'; Name='Ruby'; Winget='RubyInstallerTeam.Ruby.4.0'; Url='https://rubyinstaller.org/'}
    $global:AllAppsData[64] = @{Cat='Development'; Name='Lua'; Winget='rjpcomputing.luaforwindows'; Url='https://github.com/rjpcomputing/luaforwindows'}
    $global:AllAppsData[65] = @{Cat='Games'; Name='Cemu'; Winget='Cemu.Cemu'; Url='https://cemu.info/'}
    $global:AllAppsData[66] = @{Cat='Games'; Name='EA App'; Winget='ElectronicArts.EADesktop'; Url='https://www.ea.com/ea-app'}
    $global:AllAppsData[67] = @{Cat='Games'; Name='Epic Games Launcher'; Winget='EpicGames.EpicGamesLauncher'; Url='https://www.epicgames.com/store/en-US/'}
    $global:AllAppsData[68] = @{Cat='Games'; Name='GeForce NOW'; Winget='Nvidia.GeForceNow'; Url='https://www.nvidia.com/en-us/geforce-now/'}
    $global:AllAppsData[69] = @{Cat='Games'; Name='GOG Galaxy'; Winget='GOG.Galaxy'; Url='https://www.gog.com/galaxy'}
    $global:AllAppsData[70] = @{Cat='Games'; Name='Heroic Games Launcher'; Winget='HeroicGamesLauncher.HeroicGamesLauncher'; Url='https://heroicgameslauncher.com/'}
    $global:AllAppsData[71] = @{Cat='Games'; Name='Itch.io'; Winget='ItchIo.Itch'; Url='https://itch.io/'}
    $global:AllAppsData[72] = @{Cat='Games'; Name='Modrinth App'; Winget='Modrinth.ModrinthApp'; Url='https://modrinth.com/app'}
    $global:AllAppsData[73] = @{Cat='Games'; Name='Playnite'; Winget='Playnite.Playnite'; Url='https://playnite.link/'}
    $global:AllAppsData[74] = @{Cat='Games'; Name='Prism Launcher'; Winget='PrismLauncher.PrismLauncher'; Url='https://prismlauncher.org/'}
    $global:AllAppsData[75] = @{Cat='Games'; Name='Steam'; Winget='Valve.Steam'; Url='https://store.steampowered.com/about/'}
    $global:AllAppsData[76] = @{Cat='Games'; Name='Ubisoft Connect'; Winget='Ubisoft.Connect'; Url='https://ubisoftconnect.com/'}
    $global:AllAppsData[77] = @{Cat='Games'; Name='Virtual Desktop Streamer'; Winget='VirtualDesktop.Streamer'; Url='https://www.vrdesktop.net/'}
    $global:AllAppsData[78] = @{Cat='Games'; Name='Overwolf'; Winget='Overwolf.CurseForge'; Url='https://www.overwolf.com/app/overwolf-curseforge'}
    $global:AllAppsData[79] = @{Cat='Microsoft Tools'; Name='Autoruns'; Winget='Microsoft.Sysinternals.Autoruns'; Url='https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns'}
    $global:AllAppsData[80] = @{Cat='Microsoft Tools'; Name='RDCMan'; Winget='Microsoft.Sysinternals.RDCMan'; Url='https://learn.microsoft.com/en-us/sysinternals/downloads/rdcman'}
    $global:AllAppsData[81] = @{Cat='Microsoft Tools'; Name='DISMTools'; Winget='CodingWondersSoftware.DISMTools.Stable'; Url='https://github.com/CodingWonders/DISMTools'}
    $global:AllAppsData[82] = @{Cat='Microsoft Tools'; Name='NTLite'; Winget='Nlitesoft.NTLite'; Url='https://ntlite.com'}
    $global:AllAppsData[83] = @{Cat='Microsoft Tools'; Name='.NET Desktop Runtime 6'; Winget='Microsoft.DotNet.DesktopRuntime.6'; Url='https://dotnet.microsoft.com/download/dotnet/6.0'}
    $global:AllAppsData[84] = @{Cat='Microsoft Tools'; Name='.NET Desktop Runtime 8'; Winget='Microsoft.DotNet.DesktopRuntime.8'; Url='https://dotnet.microsoft.com/download/dotnet/8.0'}
    $global:AllAppsData[85] = @{Cat='Microsoft Tools'; Name='.NET Desktop Runtime 9'; Winget='Microsoft.DotNet.DesktopRuntime.9'; Url='https://dotnet.microsoft.com/download/dotnet/9.0'}
    $global:AllAppsData[86] = @{Cat='Microsoft Tools'; Name='.NET Desktop Runtime 10'; Winget='Microsoft.DotNet.DesktopRuntime.10'; Url='https://dotnet.microsoft.com/download/dotnet/10.0'}
    $global:AllAppsData[87] = @{Cat='Microsoft Tools'; Name='NuGet'; Winget='Microsoft.NuGet'; Url='https://www.nuget.org/'}
    $global:AllAppsData[88] = @{Cat='Microsoft Tools'; Name='OneDrive'; Winget='Microsoft.OneDrive'; Url='https://onedrive.live.com/'}
    $global:AllAppsData[89] = @{Cat='Microsoft Tools'; Name='Process Explorer'; Winget='Microsoft.Sysinternals.ProcessExplorer'; Url='https://learn.microsoft.com/sysinternals/downloads/process-explorer'}
    $global:AllAppsData[90] = @{Cat='Microsoft Tools'; Name='PowerShell'; Winget='Microsoft.PowerShell'; Url='https://github.com/PowerShell/PowerShell'}
    $global:AllAppsData[91] = @{Cat='Microsoft Tools'; Name='PowerToys'; Winget='Microsoft.PowerToys'; Url='https://github.com/microsoft/PowerToys'}
    $global:AllAppsData[92] = @{Cat='Microsoft Tools'; Name='Process Monitor'; Winget='Microsoft.Sysinternals.ProcessMonitor'; Url='https://docs.microsoft.com/en-us/sysinternals/downloads/procmon'}
    $global:AllAppsData[93] = @{Cat='Microsoft Tools'; Name='TCPView'; Winget='Microsoft.Sysinternals.TCPView'; Url='https://docs.microsoft.com/en-us/sysinternals/downloads/tcpview'}
    $global:AllAppsData[94] = @{Cat='Microsoft Tools'; Name='Windows Terminal'; Winget='Microsoft.WindowsTerminal'; Url='https://aka.ms/terminal'}
    $global:AllAppsData[95] = @{Cat='Microsoft Tools'; Name='Visual C++ 2015-2022 32-bit'; Winget='Microsoft.VCRedist.2015+.x86'; Url='https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads'}
    $global:AllAppsData[96] = @{Cat='Microsoft Tools'; Name='Visual C++ 2015-2022 64-bit'; Winget='Microsoft.VCRedist.2015+.x64'; Url='https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads'}
    $global:AllAppsData[97] = @{Cat='Multimedia Tools'; Name='Adobe Acrobat Reader'; Winget='Adobe.Acrobat.Reader.64-bit'; Url='https://www.adobe.com/acrobat/pdf-reader.html'}
    $global:AllAppsData[98] = @{Cat='Multimedia Tools'; Name='AIMP (Music Player)'; Winget='AIMP.AIMP'; Url='https://www.aimp.ru/'}
    $global:AllAppsData[99] = @{Cat='Multimedia Tools'; Name='Audacity'; Winget='Audacity.Audacity'; Url='https://www.audacityteam.org/'}
    $global:AllAppsData[100] = @{Cat='Multimedia Tools'; Name='Blender (3D Graphics)'; Winget='BlenderFoundation.Blender'; Url='https://www.blender.org/'}
    $global:AllAppsData[101] = @{Cat='Multimedia Tools'; Name='Calibre'; Winget='calibre.calibre'; Url='https://calibre-ebook.com/'}
    $global:AllAppsData[102] = @{Cat='Multimedia Tools'; Name='EarTrumpet (Audio)'; Winget='File-New-Project.EarTrumpet'; Url='https://eartrumpet.app/'}
    $global:AllAppsData[103] = @{Cat='Multimedia Tools'; Name='GIMP (Image Editor)'; Winget='GIMP.GIMP.3'; Url='https://www.gimp.org/'}
    $global:AllAppsData[104] = @{Cat='Multimedia Tools'; Name='HandBrake'; Winget='HandBrake.HandBrake'; Url='https://handbrake.fr/'}
    $global:AllAppsData[105] = @{Cat='Multimedia Tools'; Name='ImageGlass (Image Viewer)'; Winget='DuongDieuPhap.ImageGlass'; Url='https://imageglass.org/'}
    $global:AllAppsData[106] = @{Cat='Multimedia Tools'; Name='IrfanView'; Winget='IrfanSkiljan.IrfanView'; Url='https://irfanview.com/'}
    $global:AllAppsData[107] = @{Cat='Multimedia Tools'; Name='iTunes'; Winget='Apple.iTunes'; Url='https://www.apple.com/itunes/'}
    $global:AllAppsData[108] = @{Cat='Multimedia Tools'; Name='K-Lite Codec Standard'; Winget='CodecGuide.K-LiteCodecPack.Standard'; Url='https://www.codecguide.com/'}
    $global:AllAppsData[109] = @{Cat='Multimedia Tools'; Name='LibreOffice'; Winget='TheDocumentFoundation.LibreOffice'; Url='https://www.libreoffice.org/'}
    $global:AllAppsData[110] = @{Cat='Multimedia Tools'; Name='mpc-qt'; Winget='mpc-qt.mpc-qt'; Url='https://github.com/mpc-qt/mpc-qt'}
    $global:AllAppsData[111] = @{Cat='Multimedia Tools'; Name='Media Player Classic - Home Cinema'; Winget='clsid2.mpc-hc'; Url='https://github.com/clsid2/mpc-hc/'}
    $global:AllAppsData[112] = @{Cat='Multimedia Tools'; Name='nomacs'; Winget='nomacs.nomacs'; Url='https://nomacs.org/'}
    $global:AllAppsData[113] = @{Cat='Multimedia Tools'; Name='NAPS2 (Document Scanner)'; Winget='Cyanfish.NAPS2'; Url='https://www.naps2.com/'}
    $global:AllAppsData[114] = @{Cat='Multimedia Tools'; Name='Notepad++'; Winget='Notepad++.Notepad++'; Url='https://notepad-plus-plus.org/'}
    $global:AllAppsData[115] = @{Cat='Multimedia Tools'; Name='OBS Studio'; Winget='OBSProject.OBSStudio'; Url='https://obsproject.com/'}
    $global:AllAppsData[116] = @{Cat='Multimedia Tools'; Name='Obsidian'; Winget='Obsidian.Obsidian'; Url='https://obsidian.md/'}
    $global:AllAppsData[117] = @{Cat='Multimedia Tools'; Name='ONLYOFFICE Desktop'; Winget='ONLYOFFICE.DesktopEditors'; Url='https://www.onlyoffice.com/desktop.aspx'}
    $global:AllAppsData[118] = @{Cat='Multimedia Tools'; Name='Paint.NET'; Winget='dotPDN.PaintDotNet'; Url='https://www.getpaint.net/'}
    $global:AllAppsData[119] = @{Cat='Multimedia Tools'; Name='ShareX (Screenshots)'; Winget='ShareX.ShareX'; Url='https://getsharex.com/'}
    $global:AllAppsData[120] = @{Cat='Multimedia Tools'; Name='VLC (Video Player)'; Winget='VideoLAN.VLC'; Url='https://www.videolan.org/vlc/'}
    $global:AllAppsData[121] = @{Cat='Pro Tools'; Name='Advanced IP Scanner'; Winget='Famatech.AdvancedIPScanner'; Url='https://www.advanced-ip-scanner.com/'}
    $global:AllAppsData[122] = @{Cat='Pro Tools'; Name='Angry IP Scanner'; Winget='angryziber.AngryIPScanner'; Url='https://angryip.org/'}
    $global:AllAppsData[123] = @{Cat='Pro Tools'; Name='Cinebench R23'; Winget='Maxon.CinebenchR23'; Url='https://www.maxon.net/en/cinebench'}
    $global:AllAppsData[124] = @{Cat='Pro Tools'; Name='CPU-Z'; Winget='CPUID.CPU-Z'; Url='https://www.cpuid.com/softwares/cpu-z.html'}
    $global:AllAppsData[125] = @{Cat='Pro Tools'; Name='Display Driver Uninstaller'; Winget='Wagnardsoft.DisplayDriverUninstaller'; Url='https://www.wagnardsoft.com/display-driver-uninstaller-DDU-'}
    $global:AllAppsData[126] = @{Cat='Pro Tools'; Name='GPU-Z'; Winget='TechPowerUp.GPU-Z'; Url='https://www.techpowerup.com/gpuz/'}
    $global:AllAppsData[127] = @{Cat='Pro Tools'; Name='gsudo'; Winget='gerardog.gsudo'; Url='https://github.com/gerardog/gsudo'}
    $global:AllAppsData[128] = @{Cat='Pro Tools'; Name='HWiNFO'; Winget='REALiX.HWiNFO'; Url='https://www.hwinfo.com/'}
    $global:AllAppsData[129] = @{Cat='Pro Tools'; Name='HWMonitor'; Winget='CPUID.HWMonitor'; Url='https://www.cpuid.com/softwares/hwmonitor.html'}
    $global:AllAppsData[130] = @{Cat='Pro Tools'; Name='Mullvad VPN'; Winget='MullvadVPN.MullvadVPN'; Url='https://github.com/mullvad/mullvadvpn-app'}
    $global:AllAppsData[131] = @{Cat='Pro Tools'; Name='Nmap'; Winget='Insecure.Nmap'; Url='https://nmap.org/'}
    $global:AllAppsData[132] = @{Cat='Pro Tools'; Name='OpenVPN Connect'; Winget='OpenVPNTechnologies.OpenVPNConnect'; Url='https://openvpn.net/'}
    $global:AllAppsData[133] = @{Cat='Pro Tools'; Name='Proton VPN'; Winget='Proton.ProtonVPN'; Url='https://protonvpn.com/'}
    $global:AllAppsData[134] = @{Cat='Pro Tools'; Name='PuTTY'; Winget='PuTTY.PuTTY'; Url='https://www.chiark.greenend.org.uk/~sgtatham/putty/'}
    $global:AllAppsData[135] = @{Cat='Pro Tools'; Name='Simplewall'; Winget='Henry++.simplewall'; Url='https://github.com/henrypp/simplewall'}
    $global:AllAppsData[136] = @{Cat='Pro Tools'; Name='Ventoy'; Winget='Ventoy.Ventoy'; Url='https://www.ventoy.net/'}
    $global:AllAppsData[137] = @{Cat='Pro Tools'; Name='WinSCP'; Winget='WinSCP.WinSCP'; Url='https://winscp.net/'}
    $global:AllAppsData[138] = @{Cat='Pro Tools'; Name='WireGuard'; Winget='WireGuard.WireGuard'; Url='https://www.wireguard.com/'}
    $global:AllAppsData[139] = @{Cat='Pro Tools'; Name='Wireshark'; Winget='WiresharkFoundation.Wireshark'; Url='https://www.wireshark.org/'}
    $global:AllAppsData[140] = @{Cat='Selfhosted Tools'; Name='Jellyfin Media Player'; Winget='Jellyfin.JellyfinMediaPlayer'; Url='https://github.com/jellyfin/jellyfin-media-player'}
    $global:AllAppsData[141] = @{Cat='Selfhosted Tools'; Name='Jellyfin Server'; Winget='Jellyfin.Server'; Url='https://jellyfin.org/'}
    $global:AllAppsData[142] = @{Cat='Selfhosted Tools'; Name='Kodi Media Center'; Winget='XBMCFoundation.Kodi'; Url='https://kodi.tv/'}
    $global:AllAppsData[143] = @{Cat='Selfhosted Tools'; Name='LocalSend'; Winget='LocalSend.LocalSend'; Url='https://localsend.org/'}
    $global:AllAppsData[144] = @{Cat='Selfhosted Tools'; Name='Moonlight/GameStream Client'; Winget='MoonlightGameStreamingProject.Moonlight'; Url='https://moonlight-stream.org/'}
    $global:AllAppsData[145] = @{Cat='Selfhosted Tools'; Name='NetBird'; Winget='Netbird.Netbird'; Url='https://netbird.io/'}
    $global:AllAppsData[146] = @{Cat='Selfhosted Tools'; Name='Nextcloud Desktop'; Winget='Nextcloud.NextcloudDesktop'; Url='https://nextcloud.com/install/#install-clients'}
    $global:AllAppsData[147] = @{Cat='Selfhosted Tools'; Name='Plex Media Server'; Winget='Plex.PlexMediaServer'; Url='https://www.plex.tv/your-media/'}
    $global:AllAppsData[148] = @{Cat='Selfhosted Tools'; Name='Plex Desktop'; Winget='Plex.Plex'; Url='https://www.plex.tv'}
    $global:AllAppsData[149] = @{Cat='Selfhosted Tools'; Name='Sunshine/GameStream Server'; Winget='LizardByte.Sunshine'; Url='https://github.com/LizardByte/Sunshine'}
    $global:AllAppsData[150] = @{Cat='Utilities'; Name='1Password'; Winget='AgileBits.1Password'; Url='https://1password.com/'}
    $global:AllAppsData[151] = @{Cat='Utilities'; Name='7-Zip'; Winget='7zip.7zip'; Url='https://www.7-zip.org/'}
    $global:AllAppsData[152] = @{Cat='Utilities'; Name='AnyDesk'; Winget='AnyDesk.AnyDesk'; Url='https://anydesk.com/'}
    $global:AllAppsData[153] = @{Cat='Utilities'; Name='AutoHotkey'; Winget='AutoHotkey.AutoHotkey'; Url='https://www.autohotkey.com/'}
    $global:AllAppsData[154] = @{Cat='Utilities'; Name='Bitwarden'; Winget='Bitwarden.Bitwarden'; Url='https://bitwarden.com/'}
    $global:AllAppsData[155] = @{Cat='Utilities'; Name='Bulk Crap Uninstaller'; Winget='Klocman.BulkCrapUninstaller'; Url='https://www.bcuninstaller.com/'}
    $global:AllAppsData[156] = @{Cat='Utilities'; Name='BlurAutoClicker'; Winget='Blur009.BlurAutoClicker'; Url='https://blur009.vercel.app/projects/blur-autoclicker/'}
    $global:AllAppsData[157] = @{Cat='Utilities'; Name='Crystal Disk Info'; Winget='CrystalDewWorld.CrystalDiskInfo'; Url='https://crystalmark.info/en/software/crystaldiskinfo/'}
    $global:AllAppsData[158] = @{Cat='Utilities'; Name='Crystal Disk Mark'; Winget='CrystalDewWorld.CrystalDiskMark'; Url='https://crystalmark.info/en/software/crystaldiskmark/'}
    $global:AllAppsData[159] = @{Cat='Utilities'; Name='Dropbox'; Winget='Dropbox.Dropbox'; Url='https://www.dropbox.com/desktop'}
    $global:AllAppsData[160] = @{Cat='Utilities'; Name='Ente Auth'; Winget='ente-io.auth-desktop'; Url='https://ente.io/auth/'}
    $global:AllAppsData[161] = @{Cat='Utilities'; Name='Files'; Winget='FilesCommunity.Files'; Url='https://github.com/files-community/Files'}
    $global:AllAppsData[162] = @{Cat='Utilities'; Name='F.lux'; Winget='flux.flux'; Url='https://justgetflux.com/'}
    $global:AllAppsData[163] = @{Cat='Utilities'; Name='Google Drive'; Winget='Google.GoogleDrive'; Url='https://www.google.com/drive/'}
    $global:AllAppsData[164] = @{Cat='Utilities'; Name='Hugo'; Winget='Hugo.Hugo.Extended'; Url='https://github.com/gohugoio/hugo/'}
    $global:AllAppsData[165] = @{Cat='Utilities'; Name='Internet Download Manager'; Winget='Tonec.InternetDownloadManager'; Url='https://www.internetdownloadmanager.com/'}
    $global:AllAppsData[166] = @{Cat='Utilities'; Name='JPEG View'; Winget='sylikc.JPEGView'; Url='https://github.com/sylikc/jpegview'}
    $global:AllAppsData[167] = @{Cat='Utilities'; Name='KeePassXC'; Winget='KeePassXCTeam.KeePassXC'; Url='https://keepassxc.org/'}
    $global:AllAppsData[168] = @{Cat='Utilities'; Name='MiniTool Partition Wizard'; Winget='MiniTool.PartitionWizard.Free'; Url='https://www.partitionwizard.com/'}
    $global:AllAppsData[169] = @{Cat='Utilities'; Name='MSEdgeRedirect'; Winget='rcmaehl.MSEdgeRedirect'; Url='https://github.com/rcmaehl/MSEdgeRedirect'}
    $global:AllAppsData[170] = @{Cat='Utilities'; Name='MSI Afterburner'; Winget='Guru3D.Afterburner'; Url='https://www.msi.com/Landing/afterburner'}
    $global:AllAppsData[171] = @{Cat='Utilities'; Name='NanaZip'; Winget='M2Team.NanaZip'; Url='https://github.com/M2Team/NanaZip'}
    $global:AllAppsData[172] = @{Cat='Utilities'; Name='NVCleanstall'; Winget='TechPowerUp.NVCleanstall'; Url='https://www.techpowerup.com/nvcleanstall/'}
    $global:AllAppsData[173] = @{Cat='Utilities'; Name='OPAutoClicker'; Winget='OPAutoClicker.OPAutoClicker'; Url='https://www.opautoclicker.com'}
    $global:AllAppsData[174] = @{Cat='Utilities'; Name='OpenRGB'; Winget='OpenRGB.OpenRGB'; Url='https://openrgb.org/'}
    $global:AllAppsData[175] = @{Cat='Utilities'; Name='Oracle VirtualBox'; Winget='Oracle.VirtualBox'; Url='https://www.virtualbox.org/'}
    $global:AllAppsData[176] = @{Cat='Utilities'; Name='Policy Plus'; Winget='Fleex255.PolicyPlus'; Url='https://github.com/Fleex255/PolicyPlus'}
    $global:AllAppsData[177] = @{Cat='Utilities'; Name='Parsec'; Winget='Parsec.Parsec'; Url='https://parsec.app/'}
    $global:AllAppsData[178] = @{Cat='Utilities'; Name='PeaZip'; Winget='Giorgiotani.Peazip'; Url='https://peazip.github.io/'}
    $global:AllAppsData[179] = @{Cat='Utilities'; Name='Process Lasso'; Winget='BitSum.ProcessLasso'; Url='https://bitsum.com/'}
    $global:AllAppsData[180] = @{Cat='Utilities'; Name='Proton Authenticator'; Winget='Proton.ProtonAuthenticator'; Url='https://proton.me/authenticator'}
    $global:AllAppsData[181] = @{Cat='Utilities'; Name='Proton Drive'; Winget='Proton.ProtonDrive'; Url='https://proton.me/drive'}
    $global:AllAppsData[182] = @{Cat='Utilities'; Name='Proton Pass'; Winget='Proton.ProtonPass'; Url='https://proton.me/pass'}
    $global:AllAppsData[183] = @{Cat='Utilities'; Name='qBittorrent'; Winget='qBittorrent.qBittorrent'; Url='https://www.qbittorrent.org/'}
    $global:AllAppsData[184] = @{Cat='Utilities'; Name='Revo Uninstaller'; Winget='RevoUninstaller.RevoUninstaller'; Url='https://www.revouninstaller.com/'}
    $global:AllAppsData[185] = @{Cat='Utilities'; Name='Wise Program Uninstaller (WiseCleaner)'; Winget='WiseCleaner.WiseProgramUninstaller'; Url='https://www.wisecleaner.com/wise-program-uninstaller.html'}
    $global:AllAppsData[186] = @{Cat='Utilities'; Name='Rufus Imager'; Winget='Rufus.Rufus'; Url='https://rufus.ie/'}
    $global:AllAppsData[187] = @{Cat='Utilities'; Name='Snappy Driver Installer Origin'; Winget='GlennDelahoy.SnappyDriverInstallerOrigin'; Url='https://www.glenn.delahoy.com/snappy-driver-installer-origin/'}
    $global:AllAppsData[188] = @{Cat='Utilities'; Name='Nilesoft Shell'; Winget='Nilesoft.Shell'; Url='https://nilesoft.org/'}
    $global:AllAppsData[189] = @{Cat='Utilities'; Name='SignalRGB'; Winget='WhirlwindFX.SignalRgb'; Url='https://www.signalrgb.com/'}
    $global:AllAppsData[190] = @{Cat='Utilities'; Name='StartAllBack'; Winget='StartIsBack.StartAllBack'; Url='https://www.startallback.com/'}
    $global:AllAppsData[191] = @{Cat='Utilities'; Name='TeamViewer'; Winget='TeamViewer.TeamViewer'; Url='https://www.teamviewer.com/'}
    $global:AllAppsData[192] = @{Cat='Utilities'; Name='Total Commander'; Winget='Ghisler.TotalCommander'; Url='https://www.ghisler.com/'}
    $global:AllAppsData[193] = @{Cat='Utilities'; Name='TreeSize Free'; Winget='JAMSoftware.TreeSize.Free'; Url='https://www.jam-software.com/treesize_free/'}
    $global:AllAppsData[194] = @{Cat='Utilities'; Name='TranslucentTB'; Winget='CharlesMilette.TranslucentTB'; Url='https://github.com/TranslucentTB/TranslucentTB'}
    $global:AllAppsData[195] = @{Cat='Utilities'; Name='Everything'; Winget='voidtools.Everything'; Url='https://www.voidtools.com/'}
    $global:AllAppsData[196] = @{Cat='Utilities'; Name='UniGetUI'; Winget='Devolutions.UniGetUI'; Url='https://devolutions.net/unigetui/'}
    $global:AllAppsData[197] = @{Cat='Utilities'; Name='WinRAR'; Winget='RARLab.WinRAR'; Url='https://www.win-rar.com/'}
    $global:AllAppsData[198] = @{Cat='Utilities'; Name='WizTree'; Winget='AntibodySoftware.WizTree'; Url='https://wiztreefree.com/'}
    $global:AllAppsData[199] = @{Cat='Utilities'; Name='HxD Hex Editor'; Winget='MHNexus.HxD'; Url='https://mh-nexus.de/en/hxd/'}
    $global:AllAppsData[200] = @{Cat='Utilities'; Name='TightVNC'; Winget='GlavSoft.TightVNC'; Url='https://www.tightvnc.com/'}
    $global:AllAppsData[201] = @{Cat='Utilities'; Name='GlazeWM'; Winget='glzr-io.glazewm'; Url='https://github.com/glzr-io/glazewm'}
    $global:AllAppsData[202] = @{Cat='Utilities'; Name='OFGB (Oh Frick Go Back)'; Winget='xM4ddy.OFGB'; Url='https://github.com/xM4ddy/OFGB'}
    $global:AllAppsData[203] = @{Cat='Utilities'; Name='Deskflow'; Winget='Deskflow.Deskflow'; Url='https://github.com/deskflow/deskflow'}

    # --- Build categories ---
    $global:AllWrapPanels = [System.Collections.Generic.List[System.Windows.Controls.WrapPanel]]::new()
    $prevCat = ""
    $wp = $null

    # Count items per category for badge
    $catCounts = @{}
    for ($j = 0; $j -lt $global:AllAppsData.Count; $j++) {
        $cn = $global:AllAppsData[$j].Cat
        if (-not $catCounts[$cn]) { $catCounts[$cn] = 0 }
        $catCounts[$cn]++
    }

    for ($i = 0; $i -lt $global:AllAppsData.Count; $i++) {
        $d = $global:AllAppsData[$i]
        if ($d.Cat -ne $prevCat) {
            $prevCat = $d.Cat

            # Category header card
            $catCard = New-Object System.Windows.Controls.Border
            $catCard.Background = "#0D1117"; $catCard.BorderBrush = "#1F6FEB"; $catCard.BorderThickness = "0,0,0,1"
            $catCard.Padding = "10,8,10,7"; $catCard.Margin = "0,10,0,0"

            $catGrid = New-Object System.Windows.Controls.Grid
            $cc1 = New-Object System.Windows.Controls.ColumnDefinition; $cc1.Width = "Auto"
            $cc2 = New-Object System.Windows.Controls.ColumnDefinition; $cc2.Width = "*"
            $cc3 = New-Object System.Windows.Controls.ColumnDefinition; $cc3.Width = "Auto"
            $cc4 = New-Object System.Windows.Controls.ColumnDefinition; $cc4.Width = "Auto"
            $catGrid.ColumnDefinitions.Add($cc1); $catGrid.ColumnDefinitions.Add($cc2); $catGrid.ColumnDefinitions.Add($cc3); $catGrid.ColumnDefinitions.Add($cc4)

            $catToggle = New-Object System.Windows.Controls.TextBlock
            $catToggle.Text = "v"; $catToggle.Foreground = "#58A6FF"; $catToggle.FontSize = 11
            $catToggle.FontFamily = "Consolas"; $catToggle.FontWeight = "Bold"
            $catToggle.VerticalAlignment = "Center"; $catToggle.Margin = "0,0,8,0"
            [System.Windows.Controls.Grid]::SetColumn($catToggle, 0); $catGrid.AddChild($catToggle)

            $catLabel = New-Object System.Windows.Controls.TextBlock
            $catLabel.Text = $d.Cat; $catLabel.Foreground = "#E6EDF3"; $catLabel.FontSize = 13
            $catLabel.FontWeight = "SemiBold"; $catLabel.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($catLabel, 1); $catGrid.AddChild($catLabel)

            $catBadge = New-Object System.Windows.Controls.Border
            $catBadge.Background = "#21262D"; $catBadge.CornerRadius = "10"; $catBadge.Padding = "6,1"
            $catBadge.Margin = "0,0,6,0"; $catBadge.VerticalAlignment = "Center"
            $badgeText = New-Object System.Windows.Controls.TextBlock
            $badgeText.Text = "$($catCounts[$d.Cat])"; $badgeText.Foreground = "#8B949E"; $badgeText.FontSize = 11
            $catBadge.Child = $badgeText
            [System.Windows.Controls.Grid]::SetColumn($catBadge, 2); $catGrid.AddChild($catBadge)

            # Select all link
            $selAll = New-Object System.Windows.Controls.TextBlock
            $selAll.Text = "Select all"; $selAll.Foreground = "#8B949E"; $selAll.FontSize = 11
            $selAll.VerticalAlignment = "Center"; $selAll.Cursor = "Hand"
            [System.Windows.Controls.Grid]::SetColumn($selAll, 3); $catGrid.AddChild($selAll)

            $selAll.Add_MouseLeftButtonUp({
                $targetWp = $this.Tag
                if ($null -eq $targetWp) { return }
                foreach ($b in $targetWp.Children) {
                    if ($b -is [System.Windows.Controls.Border] -and $b.Child -is [System.Windows.Controls.CheckBox]) {
                        $b.Child.IsChecked = $true
                    }
                }
            })

            $catCard.Child = $catGrid
            $catCard.Cursor = "Hand"

            $wp = New-Object System.Windows.Controls.WrapPanel
            $wp.Orientation = "Horizontal"; $wp.Margin = "2,6,2,2"
            $global:AllWrapPanels.Add($wp)

            # Set Tag AFTER wp is created for THIS category
            $selAll.Tag = $wp

            # Toggle handler -- skip if click came from Select all link
            $catCard.Add_MouseLeftButtonUp({
                param($s,$e)
                if ($e -and $e.OriginalSource -is [System.Windows.Controls.TextBlock] -and $e.OriginalSource.Text -eq "Select all") { return }
                if ($wp.Visibility -eq "Collapsed") { $wp.Visibility = "Visible"; $catToggle.Text = "v"; $catToggle.Foreground = "#58A6FF" }
                else { $wp.Visibility = "Collapsed"; $catToggle.Text = ">"; $catToggle.Foreground = "#8B949E" }
            }.GetNewClosure())

            # Hover effects on header
            $catCard.Add_MouseEnter({ $this.Background = "#161B22" })
            $catCard.Add_MouseLeave({ $this.Background = "#0D1117" })

            $pnlContent.AddChild($catCard)
            $pnlContent.AddChild($wp)
        }

        $eb = New-Object System.Windows.Controls.Border
        $eb.Background = "#161B22"; $eb.BorderBrush = "#21262D"; $eb.BorderThickness = "1"
        $eb.CornerRadius = "4"; $eb.Padding = "5,4,7,3"; $eb.Margin = "3,2"
        $eb.Cursor = "Hand"; $eb.Tag = $i

        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.FontSize = 12; $cb.Foreground = "#C9D1D9"
        $cb.VerticalContentAlignment = "Center"; $cb.Margin = "-2,0,0,0"
        $cb.Content = $d.Name; $cb.Tag = $i

        $eb.Add_MouseEnter({
            if ($this.Child -is [System.Windows.Controls.CheckBox] -and $this.Child.IsChecked -eq $false) {
                $this.Background = "#1C2333"; $this.BorderBrush = "#30363D"
            }
        })
        $eb.Add_MouseLeave({
            if ($this.Child -is [System.Windows.Controls.CheckBox] -and $this.Child.IsChecked -eq $false) {
                $this.Background = "#161B22"; $this.BorderBrush = "#21262D"
            }
        })

        $cb.Add_Checked({ param($s,$e) Invoke-AllChecked $s $e })
        $cb.Add_Unchecked({ param($s,$e) Invoke-AllUnchecked $s $e })

        $eb.Child = $cb
        if ($wp) { $wp.AddChild($eb) }
    }

    # --- Filter ---
    $tb.Add_TextChanged({ param($s,$e) Invoke-AllFilter $s })

    # --- Install handler ---
    $btnInstall.Add_Click({ param($s,$e) Invoke-AllInstallSelected })
}
