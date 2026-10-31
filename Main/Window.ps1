#
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$Script:CachedSystemInfo = $null
# Benchmark result caches (set by each Bench*.ps1 page's "Run Benchmark" handler, read by
# BenchExport.ps1). Initialized here so Set-StrictMode -Version Latest does not throw
# "cannot be retrieved because it has not been set" when the Export page is opened before any
# benchmark has run.
$Global:BenchCpuLastResult = $null
$Global:BenchGpuLastResult = $null
$Global:BenchRamLastResult = $null
$Global:BenchDiskLastResult = $null
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================
# SETTDash v4.0
# ============================================
$Script:AppVersion = "4.0.0"
$Script:AppDir = try {
    [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
} catch { }
if ([string]::IsNullOrEmpty($Script:AppDir)) { $Script:AppDir = if ($PSScriptRoot) { $PSScriptRoot } }
if ([string]::IsNullOrEmpty($Script:AppDir)) { $Script:AppDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } }
if ([string]::IsNullOrEmpty($Script:AppDir)) { $Script:AppDir = Split-Path -Parent $PSCommandPath }
if ([string]::IsNullOrEmpty($Script:AppDir)) { $Script:AppDir = Get-Location | Select-Object -ExpandProperty Path }
$Script:TempDir = Join-Path $env:TEMP "SETTDash"
if (-not (Test-Path $Script:TempDir)) { New-Item -Path $Script:TempDir -ItemType Directory -Force | Out-Null }




#region XAML PARSER
$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Get named controls
$navButtons = @{}
$controls = @(
    "btnClose","btnMin","progressBar","txtLog","pnlContent","pnlNav","btnLogCopy","btnLogClear"
)
foreach ($name in $controls) { Set-Variable -Name $name -Value $Window.FindName($name) }

# Shared app icon (exe's own embedded icon) - used for both the window/taskbar icon and the tray
# icon so they always match, regardless of which .ico was baked in at compile time (-iconFile).
$Script:AppIcon = $null
try { $Script:AppIcon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {}
if ($Script:AppIcon) {
    try {
        $Window.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
            $Script:AppIcon.Handle, [System.Windows.Int32Rect]::Empty,
            [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
    } catch {}
}

#region SYSTEM TRAY
# Hidden by default - only shown while the window is hidden due to "Minimize to tray" (Settings).
# $Script:ForceExit lets the tray's "Exit" item bypass the minimize-to-tray behavior in Startup.ps1.
$Script:ForceExit = $false
$Script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
if ($Script:AppIcon) { $Script:TrayIcon.Icon = $Script:AppIcon }
$Script:TrayIcon.Text = "SETTDash"
$Script:TrayIcon.Visible = $false
$Script:TrayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$trayOpenItem = $Script:TrayMenu.Items.Add("Open SETTDash")
$trayExitItem = $Script:TrayMenu.Items.Add("Exit")
$Script:TrayIcon.ContextMenuStrip = $Script:TrayMenu
$Script:TrayRestoreHandler = {
    $Window.Show()
    $Window.WindowState = 'Normal'
    $Window.Activate()
    $Script:TrayIcon.Visible = $false
}
$trayOpenItem.Add_Click($Script:TrayRestoreHandler)
$Script:TrayIcon.Add_DoubleClick($Script:TrayRestoreHandler)
$trayExitItem.Add_Click({ $Script:ForceExit = $true; $Window.Close() })
#endregion

$navNames = @("navPerformance","navNetworkPrivacy","navSystemTweaks","navWindows",
    "navPlaybooks","navAll","navClean","navNetwork","navSettings","navHome","navInstallers","navGpuProgs","navCpuProgs","navAllInstallers","navUtilities","navWinShortcuts",
    "navYourPCSystem","navYourPCSensors","navYourPCGpu","navYourPCCpu","navYourPCDisks","navYourPCEnergy",
    "navBenchCpu","navBenchGpu","navBenchRam","navBenchDisk","navBenchExport")
foreach ($n in $navNames) { $navButtons[$n] = $Window.FindName($n) }
#endregion

