# ================================================
#region STARTUP
# ================================================
Set-GuiTheme (Get-GuiThemePref)

Write-GuiLog "SETT OPTIMIZER Dashboard v4.0 - Ready" "INFO"
Write-GuiLog "Select a category from the sidebar to begin" "INFO"
$sysInfo = Get-SystemInfo

Show-UpdateAppliedNotice
if (Get-GuiAutoUpdateCheckPref) { Invoke-CheckForUpdates }

Extract-EmbeddedPrograms

# Load default page (Settings > "Default Startup Page", falls back to Home when unset/invalid).
$Script:DefaultStartupNavKey = Get-GuiDefaultStartupPagePref
if ($navHandlers.ContainsKey($Script:DefaultStartupNavKey)) {
    & $navHandlers[$Script:DefaultStartupNavKey]
} else {
    Show-PageHome
    Update-GuiNavActive "pageHome"
}

# Live metrics refresh timer (updates Home dashboard bars every 2s while visible)
$Script:LiveMetricsTimer = New-Object System.Windows.Threading.DispatcherTimer
$Script:LiveMetricsTimer.Interval = [TimeSpan]::FromSeconds(2)
$Script:LiveMetricsTimer.Add_Tick({ Update-GuiLiveMetrics })
$Script:LiveMetricsTimer.Start()

$Window.Add_Closing({
    # "Minimize to tray" (Settings): hide the window and keep running in the background instead of
    # exiting, unless the user picked "Exit" from the tray icon's context menu ($Script:ForceExit).
    if ((Get-GuiMinimizeToTrayPref) -and -not $Script:ForceExit) {
        $_.Cancel = $true
        $Window.Hide()
        if ($Script:TrayIcon) {
            $Script:TrayIcon.Visible = $true
            try { $Script:TrayIcon.ShowBalloonTip(2000, "SETTDash", "Still running in the background. Double-click the tray icon to reopen.", [System.Windows.Forms.ToolTipIcon]::Info) } catch {}
        }
        return
    }
    try { $Script:LiveMetricsTimer.Stop() } catch {}
    Stop-GuiMetricsRunspace
    if ($Script:TrayIcon) { $Script:TrayIcon.Visible = $false; $Script:TrayIcon.Dispose() }
})

# NOTE: must use Show() + a manual Dispatcher message loop here instead of ShowDialog().
# WPF forbids calling Window.Hide() on a window displayed via ShowDialog() (it throws
# InvalidOperationException) - and since this app has no System.Windows.Application object to
# catch a Dispatcher-thread unhandled exception, that exception used to silently crash the whole
# process the moment "Minimize to Tray" tried to Hide() the window from the Closing handler above.
$Window.Add_Closed({ try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() } catch {} })
$Window.Show()
[System.Windows.Threading.Dispatcher]::Run()
#endregion

