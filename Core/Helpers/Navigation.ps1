# Shows/hides the small "applied" status dot next to a sidebar nav item named "status<Name>",
# used to indicate that a given page's tweaks are currently active.
function Set-NavStatus { param([string]$Name, [bool]$Applied)
    $indicator = $Window.FindName("status$Name")
    if ($indicator) { $indicator.Visibility = if ($Applied) { 'Visible' } else { 'Collapsed' } }
}

# Highlights the currently active sidebar nav button by swapping its style to NavButtonActiveStyle
# (and resets all others to NavButtonStyle), based on matching $btn.Tag to $activeTag.
function Update-GuiNavActive { param([string]$activeTag)
    foreach ($n in $navNames) {
        $btn = $navButtons[$n]
        if ($btn) {
            $activeStyle = $Window.FindResource("NavButtonActiveStyle"); $normalStyle = $Window.FindResource("NavButtonStyle")
            if ($activeStyle -and $normalStyle) { $btn.Style = if ($btn.Tag -eq $activeTag) { $activeStyle } else { $normalStyle } }
        }
    }
}

# Wipes the main content panel ($pnlContent) before rendering a new page, and resets the
# Home page gauge references so stale gauge objects aren't updated by the metrics timer.
# Also stops any live-refresh timer started by the page being left (Sensors/CPU/GPU pages'
# sensor auto-refresh - see $Script:LivePageTimer) so it doesn't keep polling/rendering into
# a page that's no longer on screen.
function Clear-GuiContent {
    $pnlContent.Children.Clear()
    $Script:HomeCpuGauge = $null
    $Script:HomeRamGauge = $null
    $Script:HomeGpuGauges = @()
    if ((Get-Variable -Name LivePageTimer -Scope Script -ErrorAction SilentlyContinue) -and $Script:LivePageTimer) {
        $Script:LivePageTimer.Stop()
        $Script:LivePageTimer = $null
    }
    if ((Get-Variable -Name LivePageTimerCleanup -Scope Script -ErrorAction SilentlyContinue) -and $Script:LivePageTimerCleanup) {
        try { & $Script:LivePageTimerCleanup } catch {}
        $Script:LivePageTimerCleanup = $null
    }
}
