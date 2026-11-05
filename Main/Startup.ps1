# ================================================
#region STARTUP
# ================================================
Set-GuiTheme (Get-GuiThemePref)

Write-GuiLog "SETT OPTIMIZER Dashboard v4.0.0 - Ready" "INFO"
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

# Crash guard: there is no System.Windows.Application object here, so nothing catches an exception
# thrown on a UI callback that runs OUTSIDE Add-GuiBtn's try/catch (DispatcherTimer ticks, window
# events). Those used to reach ps2exe's generic crash MessageBox - the "Unable to find the
# specified file"-style popups - and take the whole process down. Record them and keep running.
$Window.Dispatcher.Add_UnhandledException({
    param($sender, $e)
    try {
        Write-GuiLog "Unhandled error: $($e.Exception.Message)" "ERR"
        if ($e.Exception.StackTrace) { Write-GuiLog $e.Exception.StackTrace "ERR" }
        Write-ErrorLog "DISPATCHER UNHANDLED: $($e.Exception.ToString())"
        Set-GuiProgress 0
        $e.Handled = $true
    } catch { }
})

# ---- Crash diagnostics (error report) -------------------------------------
# Nothing is written to disk on a healthy run (see Core/Helpers/Log.ps1): only failures create
# %LOCALAPPDATA%\SETTDash\logs\error-settdash-<date>.log, with the last in-app log lines as
# context. That is what makes a crash that closes the window still diagnosable afterwards.
try {
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { $isAdmin = $false }
Add-LogBuffer ("=" * 72)
Add-LogBuffer ("SETTDash {0} starting | pid {1} | 64-bit process: {2} | admin: {3}" -f $Script:AppVersion, $PID, [Environment]::Is64BitProcess, $isAdmin)

# NOTE: there is deliberately NO FirstChanceException hook here.
# One used to live at this spot ("catches failures that a try/catch swallows") and it turned out to
# be a crash source of its own. .NET raises a first-chance exception for every failed assembly
# probe - Get-CimInstance on a NON-ADMIN host does this by the hundred - and in the compiled ps2exe
# host each of those re-enters the PowerShell event handler synchronously. The stack never unwinds
# and the process dies with "a new guard page for the stack cannot be created", with no managed
# handler able to run, so no report is written either. Reproduced with a handler whose whole body
# increments a counter, so it cannot be made safe from script code: do not re-add it.
# Repro: run the app without elevation and open "Your PC > Disks".
# The handlers below cover what is actually actionable (unhandled UI/background errors), and the
# "a step silently did nothing" cases are reported by the code that performed the step.

# Exceptions raised on a thread that is not the UI dispatcher (background runspaces, timers, .NET
# callbacks) never reach the handler above and terminate the process with no in-app trace at all.
# This is the last chance to record one.
[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $e)
    try { Write-ErrorLog ("UNHANDLED (terminating: " + $e.IsTerminating + "): " + $e.ExceptionObject.ToString()) } catch { }
})

# NOTE: must use Show() + a manual Dispatcher message loop here instead of ShowDialog().
# WPF forbids calling Window.Hide() on a window displayed via ShowDialog() (it throws
# InvalidOperationException) - and since this app has no System.Windows.Application object to
# catch a Dispatcher-thread unhandled exception, that exception used to silently crash the whole
# process the moment "Minimize to Tray" tried to Hide() the window from the Closing handler above.
$Window.Add_Closed({ try { Add-LogBuffer "window closed - normal shutdown" } catch { }; try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() } catch {} })
$Window.Show()
[System.Windows.Threading.Dispatcher]::Run()
#endregion


