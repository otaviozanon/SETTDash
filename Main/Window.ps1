#
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$Script:CachedSystemInfo = $null
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
[System.Windows.Forms.Application]::EnableVisualStyles()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================
# SETTDash v3.2
# ============================================
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

$navNames = @("navPerformance","navNetworkPrivacy","navSystemTweaks","navWindows",
    "navPlaybooks","navAll","navHome","navInstallers","navGpuProgs","navCpuProgs","navAllInstallers","navUtilities","navWinShortcuts")
foreach ($n in $navNames) { $navButtons[$n] = $Window.FindName($n) }
#endregion

