# Test-BenchExport.ps1
# The Benchmark > Export page builds its categories as SCRIPTBLOCKS and hands them to
# Show-GuiCategoryDetailPage, which invokes them from the pill click handler - i.e. after
# Show-PageBenchExport has already returned. A plain scriptblock only keeps its own scope, so any
# variable of the page function ("$fmtStatus", "$fmtTime", "$categories") is gone by then and every
# click threw "The variable '$fmtStatus' cannot be retrieved because it has not been set." That
# regression shipped because nothing exercised the categories outside the page function.
#
# This test does exactly that: it calls Show-PageBenchExport with the UI helpers stubbed out, then
# invokes every captured category the way the click handler does, and finally runs the "Export
# Report" path, which walks the same scriptblocks to build the HTML.
#
# Nothing here touches the real user profile or the machine's hardware: the benchmark results are
# fixtures with the same shape the pages cache in $Global:Bench*LastResult.

[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }
$RepoRoot = (Resolve-Path $RepoRoot).Path
. (Join-Path $PSScriptRoot "Common.ps1")

# Same mode the app runs under: a stale variable access must fail here too.
Set-StrictMode -Version Latest

# Load the real helper file FIRST: it defines Add-GuiPageTitle etc., which the stubs below must
# replace (the other order would let the real, WPF-bound helpers win).
. (Join-Path $RepoRoot "Core\Helpers\Cards.ps1")
. (Join-Path $RepoRoot "Core\Helpers\Localization.ps1")
$Script:CurrentLanguage = "EN"

# ---- stubs ---------------------------------------------------------------------------------------
function Clear-GuiContent { }
function Add-GuiPageTitle { param([string]$Title) }
function Write-GuiLog { param([string]$Text, [string]$Level = "INFO") }

$script:Captured = $null
function Show-GuiCategoryDetailPage {
    param($PageTitle, $Categories)
    $script:Captured = @{ PageTitle = $PageTitle; Categories = $Categories }
}

# The export path opens the report in the browser; record the path instead of launching anything.
$script:OpenedPath = $null
function Start-Process { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) $script:OpenedPath = [string]$Rest[0] }

# Theme/lookup tables Export-GuiSystemReport reads from script scope.
$Script:Themes = @{
    Default = [pscustomobject]@{
        WindowBg = "#0D1117"; CardBg = "#161B22"; CardBorder = "#30363D"; TextPrimary = "#E6EDF3"
        TextSecondary = "#8B949E"; Accent = "#F0883E"; Divider = "#282E36"; CornerRadius = 6
        FontFamily = "Segoe UI"
    }
}
$Script:CurrentTheme = "Default"
$Script:AppVersion = "0.0.0-test"

. (Join-Path $RepoRoot "Sidebar\Pages\BenchExport.ps1")

# ---- fixtures ------------------------------------------------------------------------------------
function New-FakeProfile {
    param([string]$Unit)
    [pscustomobject]@{
        Kernel = "K"; SingleScore = 400; MultiScore = 4000; Unit = $Unit; MtStRatio = 10
        MedianSingle = 400; MedianMulti = 4000
    }
}

function Set-FakeResults {
    param([switch]$Cancelled, [switch]$NoTelemetry)
    $temp = if ($NoTelemetry) { $null } else { 71.5 }
    $gpuTemp = if ($NoTelemetry) { $null } else { 72.0 }

    $Global:BenchCpuLastResult = @{
        DeviceName = "Fake CPU"; DurationSeconds = 20; Threads = 16; Blocks = 6; ElapsedSeconds = 21.4
        Integer = (New-FakeProfile "Mops/s"); Float = (New-FakeProfile "Mflop/s"); Hash = (New-FakeProfile "MB/s")
        MaxTemp = $temp; MaxPower = 95.2; MaxClock = 4300; MaxLoad = 99.1
        Cancelled = [bool]$Cancelled; Timestamp = Get-Date
    }
    $Global:BenchGpuLastResult = @{
        DeviceName = "Fake GPU"; DurationSeconds = 20; ElapsedSeconds = 21.1
        Mode = "Direct3D11 (Level_11_0, SM 5.0)"; CompositeFps = 900.5; CompositeMs = 1.11
        Tests = @(
            [pscustomobject]@{ Name = "Alu"; Label = "ALU / fractal"; Fps = 1258.3; MedianMs = 0.795; Blocks = 63; FirstHalfFps = 1258.3; SecondHalfFps = 1258.3 }
            [pscustomobject]@{ Name = "Texture"; Label = "Texture 2K"; Fps = 2386.0; MedianMs = 0.419; Blocks = 90; FirstHalfFps = 2542.4; SecondHalfFps = 2589.6 }
            [pscustomobject]@{ Name = "Compute"; Label = "Compute 4M"; Fps = 278.2; MedianMs = 3.594; Blocks = 62; FirstHalfFps = 278.2; SecondHalfFps = 278.2 }
        )
        MaxTemp = $gpuTemp; MaxPower = 180.0; MaxClock = 1900; MaxLoad = 99.0
        ThrottlePct = 0.4; Throttling = $false
        Cancelled = [bool]$Cancelled; Timestamp = Get-Date
    }
    $Global:BenchRamLastResult = @{
        DeviceName = "RAM"; DurationSeconds = 20; BufferSizeMB = 512; Passes = 4
        WriteMBs = 41000; CopyMBs = 39000; ReadMBs = 44000; LatencyNs = 62
        MtBandwidthMBs = 61000; MtThreads = 16; Cancelled = [bool]$Cancelled; Timestamp = Get-Date
    }
    $Global:BenchDiskLastResult = @{
        DeviceName = "SSD"; DurationSeconds = 20; TotalSizeMB = 1024
        WriteMBs = 5200; ReadMBs = 6100; Write4kIops = 420000; Read4kIops = 380000
        QdReadIops = 900000; QdThreads = 8; Cancelled = [bool]$Cancelled; Timestamp = Get-Date
    }
}

function Get-CategoryRows {
    param([string]$Name)
    # The click handler does exactly this: invoke the scriptblock long after the page function
    # returned. A missing outer variable throws right here.
    return @(& $script:Captured.Categories[$Name])
}

function Get-RowValue {
    param($Rows, [string]$Label)
    $row = @($Rows | Where-Object { $_.Contains("Label") -and $_.Label -eq $Label }) | Select-Object -First 1
    if (-not $row) { return $null }
    return [string]$row.Value
}

# ---- every category survives being invoked after the page function returned -----------------------
Write-Section "Test-BenchExport: category scriptblocks outlive the page"
Set-FakeResults
Show-PageBenchExport

Assert-True ([bool]$script:Captured) "Show-PageBenchExport hands the categories to the detail page"
Assert-Equal "Benchmark Results" $script:Captured.PageTitle "Detail page title"

$expected = @("All", "CPU", "GPU", "RAM", "Disk")
Assert-Equal ($expected -join ",") ((@($script:Captured.Categories.Keys)) -join ",") "Category pills are All, CPU, GPU, RAM and Disk"

foreach ($name in $expected) {
    $err = $null
    try { $null = Get-CategoryRows $name } catch { $err = $_.Exception.Message }
    Assert-True (-not $err) "$name categories invoke outside the page scope" $err
}

foreach ($name in @("CPU", "GPU", "RAM", "Disk")) {
    $rows = Get-CategoryRows $name
    Assert-True ($rows.Count -ge 8) "$name category renders its rows" "got $($rows.Count)"
    Assert-Equal "Complete" (Get-RowValue $rows "Status") "$name category reports the run status"
}

$cpuRows = Get-CategoryRows "CPU"
# The value is rendered with the current culture, so 71.5 becomes "71,5 °C" on a pt-BR machine.
# Match the shape (either separator) instead of pinning one culture's formatting.
$cpuTemp = Get-RowValue $cpuRows "Max CPU Temp"
Assert-True ($cpuTemp -match '^71[.,]5 °C$') "CPU category reports the CPU temperature" "got '$cpuTemp'"
Assert-Equal "400 Mops/s" (Get-RowValue $cpuRows "Integer Single-Core") "CPU category lists the Integer kernel"
Assert-Equal "4000 Mflop/s" (Get-RowValue $cpuRows "Float All-Core") "CPU category lists the Float kernel"
Assert-Equal "4000 MB/s" (Get-RowValue $cpuRows "Hash All-Core") "CPU category lists the Hash kernel"

$gpuRows = Get-CategoryRows "GPU"
Assert-Equal "72 °C" (Get-RowValue $gpuRows "Max GPU Temp") "GPU category reports the GPU temperature"
Assert-Equal "Stable" (Get-RowValue $gpuRows "Stability") "GPU category reports stability"
Assert-True ((Get-RowValue $gpuRows "Alu - ALU / fractal") -match '^1258[.,]3 FPS \(0[.,]795 ms/frame, 63 blocks\)$') "GPU category lists the ALU sub-test"

# ---- "All" concatenates the four sections -------------------------------------------------------
$allRows = Get-CategoryRows "All"
$headers = @($allRows | Where-Object { $_.Contains("IsHeader") -and $_.IsHeader } | ForEach-Object { $_.Label })
Assert-Equal "CPU,GPU,RAM,Disk" ($headers -join ",") "All category adds one header per device"
Assert-Equal ($allRows.Count) (($cpuRows.Count + $gpuRows.Count + (Get-CategoryRows "RAM").Count + (Get-CategoryRows "Disk").Count + 4)) "All category contains every section row"

# ---- stopped runs, and runs without LibreHardwareMonitor telemetry -------------------------------
Write-Section "Test-BenchExport: stopped runs and missing telemetry"
Set-FakeResults -Cancelled -NoTelemetry
Show-PageBenchExport
$cpuRows = Get-CategoryRows "CPU"
Assert-Equal "Stopped (partial)" (Get-RowValue $cpuRows "Status") "A cancelled run is reported as stopped"
Assert-True ($null -eq (Get-RowValue $cpuRows "Max CPU Temp")) "No temperature row when telemetry is unavailable"
$gpuRows = Get-CategoryRows "GPU"
Assert-True ($null -eq (Get-RowValue $gpuRows "Max GPU Temp")) "No GPU temperature row when telemetry is unavailable"

# ---- no data at all ------------------------------------------------------------------------------
Write-Section "Test-BenchExport: no cached results"
$Global:BenchCpuLastResult = $null
$Global:BenchGpuLastResult = $null
$Global:BenchRamLastResult = $null
$Global:BenchDiskLastResult = $null
Show-PageBenchExport
foreach ($name in $expected) {
    $err = $null
    try { $null = Get-CategoryRows $name } catch { $err = $_.Exception.Message }
    Assert-True (-not $err) "$name category with no data does not throw" $err
}
$row = Get-CategoryRows "CPU"
Assert-True ((Get-RowValue $row "Status") -like "No data*") "Empty CPU category explains what to run first"

# ---- the "Export Report" button walks the same scriptblocks --------------------------------------
Write-Section "Test-BenchExport: HTML export"
Set-FakeResults -NoTelemetry
Show-PageBenchExport

$reportDir = Join-Path $PSScriptRoot ".tools\report-test"
if (Test-Path $reportDir) { Remove-Item $reportDir -Recurse -Force }
New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
$originalTemp = $env:TEMP
try {
    $env:TEMP = $reportDir
    $script:OpenedPath = $null
    Assert-NoThrow { Export-GuiSystemReport -Categories $script:Captured.Categories -PageTitle "Benchmark Results" } "Export Report builds the HTML report"
    $html = if ($script:OpenedPath -and (Test-Path $script:OpenedPath)) { Get-Content -Path $script:OpenedPath -Raw } else { "" }
    Assert-True ([bool]$html) "Export Report wrote the HTML file" "path '$($script:OpenedPath)'"
    Assert-True ($html -match "<h2>CPU</h2>") "Report contains the CPU section"
    Assert-True ($html -match "<h2>GPU</h2>") "Report contains the GPU section"
    Assert-True ($html -match "<h2>RAM</h2>") "Report contains the RAM section"
    Assert-True ($html -match "<h2>Disk</h2>") "Report contains the Disk section"
    Assert-True (-not ($html -match "<h2>All</h2>")) "Report skips the All aggregate (no duplicated rows)"
    Assert-Equal 4 ([regex]::Matches($html, '<section class="card">').Count) "Report has one card per device"
} finally {
    $env:TEMP = $originalTemp
    if (Test-Path $reportDir) { Remove-Item $reportDir -Recurse -Force }
}

Complete-Tests "Test-BenchExport"
