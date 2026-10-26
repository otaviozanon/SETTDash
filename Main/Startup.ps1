# ================================================
#region STARTUP
# ================================================
Write-GuiLog "SETT OPTIMIZER Dashboard v3.2 - Ready" "INFO"
Write-GuiLog "Select a category from the sidebar to begin" "INFO"
$sysInfo = Get-SystemInfo

Extract-EmbeddedPrograms

# Load default page
Show-PageHome
Update-GuiNavActive "pageHome"

# Live metrics refresh timer (updates Home dashboard bars every 2s while visible)
$Script:LiveMetricsTimer = New-Object System.Windows.Threading.DispatcherTimer
$Script:LiveMetricsTimer.Interval = [TimeSpan]::FromSeconds(2)
$Script:LiveMetricsTimer.Add_Tick({ Update-GuiLiveMetrics })
$Script:LiveMetricsTimer.Start()

$Window.Add_Closing({
    try { $Script:LiveMetricsTimer.Stop() } catch {}
    Stop-GuiMetricsRunspace
})

$Window.ShowDialog() | Out-Null
#endregion

