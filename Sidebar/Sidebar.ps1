#region WIRE NAVIGATION
$navHandlers = @{
    "navHome"         = { Clear-GuiLog; Update-GuiNavActive "pageHome"; Show-PageHome }
                        "navInstallers"   = { Expand-Section $secInstallers $hdrInstallers; Clear-GuiLog; Update-GuiNavActive "pageInstallers"; Show-PageInstallers }
                        "navGpuProgs"     = { Expand-Section $secInstallers $hdrInstallers; Clear-GuiLog; Update-GuiNavActive "pageGpuSoftware"; Show-PageGpuSoftware }
                        "navCpuProgs"     = { Expand-Section $secInstallers $hdrInstallers; Clear-GuiLog; Update-GuiNavActive "pageCpuSoftware"; Show-PageCPU }
                        "navAllInstallers"= { Expand-Section $secInstallers $hdrInstallers; Clear-GuiLog; Update-GuiNavActive "pageAllInstallers"; Show-PageAllInstallers }
    "navPerformance"     = { Expand-Section $secSystem $hdrSystem; Clear-GuiLog; Update-GuiNavActive "pagePerformance"; Show-PagePerformance }
    "navNetworkPrivacy"  = { Expand-Section $secSystem $hdrSystem; Clear-GuiLog; Update-GuiNavActive "pageNetworkPrivacy"; Show-PageNetworkPrivacy }
    "navSystemTweaks"    = { Expand-Section $secSystem $hdrSystem; Clear-GuiLog; Update-GuiNavActive "pageSystemTweaksAll"; Show-PageSystemTweaksAll }
    "navWindows"         = { Expand-Section $secSystem $hdrSystem; Clear-GuiLog; Update-GuiNavActive "pageWindows"; Show-PageWindows }
                        "navPlaybooks"    = { Expand-Section $secTools $hdrTools; Clear-GuiLog; Update-GuiNavActive "pagePlaybooks"; Show-PagePlaybooks }
                        "navUtilities"   = { Expand-Section $secTools $hdrTools; Clear-GuiLog; Update-GuiNavActive "pageUtilities"; Show-PageUtilities }
                        "navWinShortcuts"= { Expand-Section $secShortcuts $hdrShortcuts; Clear-GuiLog; Update-GuiNavActive "pageWinShortcuts"; Show-PageWinShortcuts }
                        "navYourPCSystem" = { Expand-Section $secYourPC $hdrYourPC; Clear-GuiLog; Update-GuiNavActive "pageYourPCSystem"; Show-PageYourPCSystem }
                        "navYourPCSensors"= { Expand-Section $secYourPC $hdrYourPC; Clear-GuiLog; Update-GuiNavActive "pageYourPCSensors"; Show-PageYourPCSensors }
                        "navYourPCGpu"    = { Expand-Section $secYourPC $hdrYourPC; Clear-GuiLog; Update-GuiNavActive "pageYourPCGpu"; Show-PageYourPCGpu }
                        "navYourPCCpu"    = { Expand-Section $secYourPC $hdrYourPC; Clear-GuiLog; Update-GuiNavActive "pageYourPCCpu"; Show-PageYourPCCpu }
                        "navYourPCDisks"  = { Expand-Section $secYourPC $hdrYourPC; Clear-GuiLog; Update-GuiNavActive "pageYourPCDisks"; Show-PageYourPCDisks }
                        "navYourPCEnergy" = { Expand-Section $secYourPC $hdrYourPC; Clear-GuiLog; Update-GuiNavActive "pageYourPCEnergy"; Show-PageYourPCEnergy }
                        "navBenchCpu"     = { Expand-Section $secBenchmark $hdrBenchmark; Clear-GuiLog; Update-GuiNavActive "pageBenchCpu"; Show-PageBenchCpu }
                        "navBenchGpu"     = { Expand-Section $secBenchmark $hdrBenchmark; Clear-GuiLog; Update-GuiNavActive "pageBenchGpu"; Show-PageBenchGpu }
                        "navBenchRam"     = { Expand-Section $secBenchmark $hdrBenchmark; Clear-GuiLog; Update-GuiNavActive "pageBenchRam"; Show-PageBenchRam }
                        "navBenchDisk"    = { Expand-Section $secBenchmark $hdrBenchmark; Clear-GuiLog; Update-GuiNavActive "pageBenchDisk"; Show-PageBenchDisk }
                        "navBenchExport"  = { Expand-Section $secBenchmark $hdrBenchmark; Clear-GuiLog; Update-GuiNavActive "pageBenchExport"; Show-PageBenchExport }
    "navAll"          = { Clear-GuiLog; Update-GuiNavActive "pageAll"; Show-PageAll }
    "navClean"        = { Clear-GuiLog; Update-GuiNavActive "pageClean"; Show-PageClean }
    "navNetwork"      = { Clear-GuiLog; Update-GuiNavActive "pageNetwork"; Show-PageNetwork }
    "navStartup"      = { Clear-GuiLog; Update-GuiNavActive "pageStartup"; Show-PageStartup }
    "navSettings"     = { Clear-GuiLog; Update-GuiNavActive "pageSettings"; Show-PageSettings }
}

foreach ($n in $navNames) {
    if ($navHandlers.ContainsKey($n) -and $navButtons.ContainsKey($n)) {
        $navButtons[$n].Add_Click($navHandlers[$n])
    }
}
#endregion

#region SIDEBAR ACCORDION
# Chevron glyphs (Segoe MDL2 Assets): collapsed = right-pointing, expanded = down-pointing.
$Script:ChevronCollapsed = [string][char]0xE76C
$Script:ChevronExpanded = [string][char]0xE70D

# Wires a sidebar section header (e.g. "System", "Tools") so clicking it shows/hides the
# associated collapsible $section panel and updates the header's chevron icon accordingly.
function Toggle-SidebarSection {
    param($header, $section)
    $header.Add_Click({
                         if ($section.Visibility -eq 'Collapsed') {
                                 $section.Visibility = 'Visible'
                             } else {
                                 $section.Visibility = 'Collapsed'
                             }
                         Set-SidebarHeaderIcon $header $section
                         }.GetNewClosure())
}

# Updates the chevron glyph on a sidebar section $header to reflect whether $section is
# currently collapsed (right-pointing arrow) or expanded (down-pointing arrow).
function Set-SidebarHeaderIcon {
    param($header, $section)
    # Header content is a StackPanel with the chevron as its first child.
    $panel = $header.Content
    if ($panel -and $panel.Children -and $panel.Children.Count -gt 0) {
        $chevron = $panel.Children[0]
        if ($chevron) {
            $chevron.Text = if ($section.Visibility -eq 'Collapsed') { $Script:ChevronCollapsed } else { $Script:ChevronExpanded }
        }
    }
}

# Used by: nav click handlers above, to auto-expand the sidebar section containing the page
# being navigated to. Does nothing if $section is already visible.
function Expand-Section {
    param($section, $header)
    if ($section -and $section.Visibility -eq 'Collapsed') {
        $section.Visibility = 'Visible'
        if ($header) { Set-SidebarHeaderIcon $header $section }
    }
}

$hdrYourPC = $Window.FindName("hdrYourPC")
$secYourPC = $Window.FindName("secYourPC")
$hdrQuick = $Window.FindName("hdrQuick")
$hdrInstallers = $Window.FindName("hdrInstallers")
$secInstallers = $Window.FindName("secInstallers")
$hdrSystem = $Window.FindName("hdrSystem")
$secSystem = $Window.FindName("secSystem")
$hdrShortcuts = $Window.FindName("hdrShortcuts")
$secShortcuts = $Window.FindName("secShortcuts")
$hdrTools = $Window.FindName("hdrTools")
$secTools = $Window.FindName("secTools")
$hdrBenchmark = $Window.FindName("hdrBenchmark")
$secBenchmark = $Window.FindName("secBenchmark")

if ($hdrYourPC -and $secYourPC) { Toggle-SidebarSection $hdrYourPC $secYourPC }
if ($hdrInstallers -and $secInstallers) { Toggle-SidebarSection $hdrInstallers $secInstallers }
if ($hdrSystem -and $secSystem) { Toggle-SidebarSection $hdrSystem $secSystem }
if ($hdrShortcuts -and $secShortcuts) { Toggle-SidebarSection $hdrShortcuts $secShortcuts }
if ($hdrTools -and $secTools) { Toggle-SidebarSection $hdrTools $secTools }
if ($hdrBenchmark -and $secBenchmark) { Toggle-SidebarSection $hdrBenchmark $secBenchmark }
#endregion

#region SIDEBAR SEARCH
# First item in the sidebar: typing filters the nav itself, leaving only the matching items and
# the section(s) they belong to. Sections are expanded while filtering and restored to their
# previous collapsed state when the box is cleared. Headers match too ("bench" shows Benchmark).
$Script:SidebarGroups = @(
    @{ Name='Quick';      Header=$hdrQuick;      Section=$null;         Keys=@('navHome','navAll','navClean','navNetwork','navStartup') }
    @{ Name='YourPC';     Header=$hdrYourPC;     Section=$secYourPC;     Keys=@('navYourPCSystem','navYourPCSensors','navYourPCGpu','navYourPCCpu','navYourPCDisks','navYourPCEnergy') }
    @{ Name='Installers'; Header=$hdrInstallers; Section=$secInstallers; Keys=@('navInstallers','navGpuProgs','navCpuProgs','navAllInstallers') }
    @{ Name='System';     Header=$hdrSystem;     Section=$secSystem;     Keys=@('navPerformance','navNetworkPrivacy','navSystemTweaks','navWindows') }
    @{ Name='Shortcuts';  Header=$hdrShortcuts;  Section=$secShortcuts;  Keys=@('navWinShortcuts') }
    @{ Name='Tools';      Header=$hdrTools;      Section=$secTools;      Keys=@('navUtilities','navPlaybooks') }
    @{ Name='Benchmark';  Header=$hdrBenchmark;  Section=$secBenchmark;  Keys=@('navBenchCpu','navBenchGpu','navBenchRam','navBenchDisk','navBenchExport') }
)
$Script:SidebarSectionState = @{}

# Nav buttons hold a StackPanel (icon + label); headers and QUICK hold one or two TextBlocks.
function Get-SidebarLabel {
    param($Button)
    if (-not $Button) { return '' }
    $content = $Button.Content
    if ($content -is [System.Windows.Controls.TextBlock]) { return [string]$content.Text }
    if ($content -is [System.Windows.Controls.StackPanel] -and $content.Children.Count -ge 2) {
        $label = $content.Children[$content.Children.Count - 1]
        if ($label -is [System.Windows.Controls.TextBlock]) { return [string]$label.Text }
    }
    return [string]$content
}

function Update-SidebarSearch {
    param([string]$Query)
    $q = ([string]$Query).Trim().ToLowerInvariant()
    $filtering = $q.Length -gt 0
    foreach ($group in $Script:SidebarGroups) {
        $headerMatches = $false
        if ($filtering -and $group.Header) {
            $headerMatches = (Get-SidebarLabel $group.Header).ToLowerInvariant().Contains($q)
        }
        $visible = 0
        foreach ($key in $group.Keys) {
            $button = $navButtons[$key]
            if (-not $button) { continue }
            $match = (-not $filtering) -or $headerMatches -or (Get-SidebarLabel $button).ToLowerInvariant().Contains($q)
            $button.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
            if ($match) { $visible++ }
        }
        if ($group.Header) {
            $group.Header.Visibility = if ((-not $filtering) -or $visible -gt 0) { 'Visible' } else { 'Collapsed' }
        }
        if ($group.Section) {
            if ($filtering) {
                if (-not $Script:SidebarSectionState.ContainsKey($group.Name)) {
                    $Script:SidebarSectionState[$group.Name] = $group.Section.Visibility
                }
                $group.Section.Visibility = if ($visible -gt 0) { 'Visible' } else { 'Collapsed' }
            } elseif ($Script:SidebarSectionState.ContainsKey($group.Name)) {
                $group.Section.Visibility = $Script:SidebarSectionState[$group.Name]
            } else {
                $group.Section.Visibility = 'Collapsed'
            }
            if ($group.Header) { Set-SidebarHeaderIcon $group.Header $group.Section }
        }
    }
    if ($navButtons['navSettings']) {
        $settingsButton = $navButtons['navSettings']
        $showSettings = (-not $filtering) -or ((Get-SidebarLabel $settingsButton).ToLowerInvariant().Contains($q))
        $settingsButton.Visibility = if ($showSettings) { 'Visible' } else { 'Collapsed' }
    }
}

$txtNavSearch = $Window.FindName('txtNavSearch')
if ($txtNavSearch) {
    $txtNavSearch.Add_TextChanged({ param($s, $e) Update-SidebarSearch -Query $s.Text })
}
#endregion
