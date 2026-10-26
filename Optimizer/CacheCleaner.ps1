#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host

$Script:Col = @{
    OK    = "Green"
    X     = "Red"
    WARN  = "DarkYellow"
    INFO  = "Cyan"
    STEP  = "Yellow"
    TITLE = "White"
    CAT   = "White"
    HEAD  = "DarkGray"
}

function OK   { param($M) Write-Host "[OK] " -ForegroundColor $Script:Col.OK -NoNewline; Write-Host $M -ForegroundColor $Script:Col.OK }
function X    { param($M) Write-Host "[X]  " -ForegroundColor $Script:Col.X   -NoNewline; Write-Host $M -ForegroundColor $Script:Col.X }
function Warn { param($M) Write-Host "[*]  " -ForegroundColor $Script:Col.WARN -NoNewline; Write-Host $M -ForegroundColor $Script:Col.WARN }
function I    { param($M) Write-Host "[i]  " -ForegroundColor $Script:Col.INFO -NoNewline; Write-Host $M -ForegroundColor $Script:Col.INFO }
function S    { param($M) Write-Host "[+]  " -ForegroundColor $Script:Col.STEP -NoNewline; Write-Host $M -ForegroundColor $Script:Col.STEP }
function ShowHeader { param($M) Write-Host ""; Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD; Write-Host "  $M" -ForegroundColor $Script:Col.TITLE; Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD; Write-Host "" }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host "  CACHE CLEANER" -ForegroundColor $Script:Col.TITLE
    Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
    Write-Host ""
    Write-Host "  [1] Clean Cache (Full Menu)" -ForegroundColor White
    Write-Host "  [2] Advanced System Cleanup" -ForegroundColor White
    Write-Host "  [3] Device Cleanup" -ForegroundColor White
    Write-Host "  [0] Exit" -ForegroundColor Red
    Write-Host ""
}

# === FUNCAO AUXILIAR: Limpar Diretorio (OTIMIZADO) ===
function Remove-DirectoryContent {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path $Path)) {
        Warn "$Description not found"
        return
    }

    S "Cleaning: $Description"

    try {
        Remove-Item -Path "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
        OK "$Description cleaned"
    }
    catch {
        X "Error cleaning $Description"
    }
}

# === MENU: Clean Cache (Menu Completo) ===
function Show-CleanCacheMenu {
    do {
        Clear-Host
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
        Write-Host "  CLEAN CACHE MENU" -ForegroundColor $Script:Col.TITLE
        Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
        Write-Host ""
        Write-Host "  [1] Temporary Files" -ForegroundColor White
        Write-Host "  [2] Browser Cache" -ForegroundColor White
        Write-Host "  [3] Windows Update Cache" -ForegroundColor White
        Write-Host "  [4] Prefetch Files" -ForegroundColor White
        Write-Host "  [5] Windows Store Cache" -ForegroundColor White
        Write-Host "  [6] Windows Log Files" -ForegroundColor White
        Write-Host "  [7] Memory Dump Files" -ForegroundColor White
        Write-Host "  [8] Delivery Optimization" -ForegroundColor White
        Write-Host "  [9] DirectX Shader Cache" -ForegroundColor White
        Write-Host "  [0] Back" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "  Escolha"

        switch ($choice) {
            "1" {
                Clear-Host
                S "Cleaning Temporary Files..."
                Write-Host ""
                Remove-DirectoryContent -Path $env:TEMP -Description "User TEMP"
                $winTemp = Join-Path $env:windir "Temp"
                Remove-DirectoryContent -Path $winTemp -Description "Windows TEMP"
                Write-Host ""
                Read-Host "  Press ENTER"
            }
            "2" { Show-BrowserCacheMenu }
            "3" { Clear-UpdateCache }
            "4" { Clear-PrefetchFiles }
            "5" { Clear-StoreCache }
            "6" { Clear-LogFiles }
            "7" { Clear-MemoryDump }
            "8" { Clear-DeliveryOptimization }
            "9" { Clear-ShaderCache }
            "0" { return }
            default {
                X "Invalid option"
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

function Show-BrowserCacheMenu {
    do {
        Clear-Host
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
        Write-Host "  BROWSER CACHE MENU" -ForegroundColor $Script:Col.TITLE
        Write-Host ("=" * 60) -ForegroundColor $Script:Col.HEAD
        Write-Host ""
        Write-Host "  [1] Google Chrome" -ForegroundColor White
        Write-Host "  [2] Mozilla Firefox" -ForegroundColor White
        Write-Host "  [3] Opera GX" -ForegroundColor White
        Write-Host "  [4] Brave" -ForegroundColor White
        Write-Host "  [0] Back" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "  Choice"

        switch ($choice) {
            "1" {
                $chromePath = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Cache"
                Clear-BrowserCache -Browser "Chrome" -Path $chromePath
            }
            "2" { Clear-FirefoxCache }
            "3" {
                $operaPath = Join-Path $env:APPDATA "Opera Software\Opera GX Stable\Cache"
                Clear-BrowserCache -Browser "Opera GX" -Path $operaPath
            }
            "4" {
                $bravePath = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\Default\Cache"
                Clear-BrowserCache -Browser "Brave" -Path $bravePath
            }
            "0" { return }
            default {
                X "Invalid option"
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

function Clear-BrowserCache {
    param([string]$Browser, [string]$Path)

    Clear-Host
    S "Cleaning $Browser Cache..."
    Write-Host ""
    Remove-DirectoryContent -Path $Path -Description "$Browser Cache"
    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-FirefoxCache {
    Clear-Host
    S "Cleaning Firefox Cache..."
    Write-Host ""

    $firefoxPath = Join-Path ${env:ProgramFiles} "Mozilla Firefox\firefox.exe"
    if (Test-Path $firefoxPath) {
        try {
            Write-Progress -Activity "Cleaning Firefox Cache" -Status "Running..." -PercentComplete 50
            Start-Process -FilePath $firefoxPath -ArgumentList '-P "default" -no-remote -safe-mode -jsconsole -clearcache' -Wait -WindowStyle Hidden
            Write-Progress -Activity "Cleaning Firefox Cache" -Completed
            OK "Firefox Cache cleaned"
        }
        catch {
            X "Error cleaning Firefox Cache: $_"
        }
    } else {
        Warn "Firefox not found"
    }

    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-UpdateCache {
    Clear-Host
    S "Cleaning Windows Update Cache..."
    Write-Host ""

    try {
        Stop-Service -Name wuauserv, UsoSvc -Force -ErrorAction SilentlyContinue

        $updatePath = Join-Path $env:windir "SoftwareDistribution\Download"
        Remove-DirectoryContent -Path $updatePath -Description "Update Cache"

        Start-Service -Name wuauserv, UsoSvc -ErrorAction SilentlyContinue
        OK "Services restarted"
    }
    catch {
        X "Error cleaning Update Cache: $_"
    }

    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-PrefetchFiles {
    Clear-Host
    S "Cleaning Prefetch Files..."
    Write-Host ""
    $prefetchPath = Join-Path $env:windir "Prefetch"
    Remove-DirectoryContent -Path $prefetchPath -Description "Prefetch Files"
    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-StoreCache {
    Clear-Host
    S "Cleaning Windows Store Cache..."
    Write-Host ""

    Start-Process "wsreset.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
    OK "Store Cache reset"

    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-LogFiles {
    Clear-Host
    S "Cleaning Log Files..."
    Write-Host ""

    try {
        $logsPath = Join-Path $env:windir "Logs"
        Remove-DirectoryContent -Path $logsPath -Description "Log Files"

        Write-Progress -Activity "Log Files" -Status "Searching for .log in C:\..." -PercentComplete 50
        $currentLocation = Get-Location
        Set-Location C:\
        Remove-Item -Path "*.log" -Recurse -Force -ErrorAction SilentlyContinue
        Set-Location $currentLocation
        Write-Progress -Activity "Log Files" -Completed
    }
    catch {
        X "Error cleaning Log Files: $_"
    }

    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-MemoryDump {
    Clear-Host
    S "Cleaning Memory Dump Files..."
    Write-Host ""
    $dumpPath = Join-Path $env:windir "Minidump"
    Remove-DirectoryContent -Path $dumpPath -Description "Memory Dump Files"
    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-DeliveryOptimization {
    Clear-Host
    S "Cleaning Delivery Optimization..."
    Write-Host ""

    try {
        Stop-Service -Name dosvc -Force -ErrorAction SilentlyContinue

        $deliveryPath = Join-Path $env:windir "SoftwareDistribution\DeliveryOptimization"
        Remove-DirectoryContent -Path $deliveryPath -Description "Delivery Optimization"

        Start-Service -Name dosvc -ErrorAction SilentlyContinue
    }
    catch {
        X "Error cleaning Delivery Optimization: $_"
    }

    Write-Host ""
    Read-Host "  Press ENTER"
}

function Clear-ShaderCache {
    Clear-Host
    S "Cleaning DirectX Shader Cache..."
    Write-Host ""
    $shaderPath = Join-Path $env:LOCALAPPDATA "D3DSCache"
    Remove-DirectoryContent -Path $shaderPath -Description "Shader Cache"
    Write-Host ""
    Read-Host "  Press ENTER"
}

function Invoke-CleanSystem {
    Clear-Host
    ShowHeader "ADVANCED SYSTEM CLEANUP"

    $windir = $env:windir
    $paths = @(
        (Join-Path $windir "Prefetch"),
        (Join-Path $windir "Spool\Printers"),
        (Join-Path $windir "History"),
        (Join-Path $windir "Cookies"),
        (Join-Path $windir "Tmp")
    )

    $files = @(
        "C:\WIN386.SWP",
        (Join-Path $windir "ff*.tmp")
    )

    S "Step 1/3: Cleaning extra files..."
    Write-Host ""

    $total = $paths.Count + $files.Count
    $idx = 0
    foreach ($item in $paths) {
        $idx++
        Write-Progress -Activity "Advanced Cleanup" -Status "Step 1/3" -PercentComplete (($idx / $total) * 100)
        if (Test-Path $item) {
            Remove-Item -Path "$item\*" -Recurse -Force -ErrorAction SilentlyContinue
            OK "Cleaned: $item"
        }
    }

    foreach ($file in $files) {
        $idx++
        Write-Progress -Activity "Advanced Cleanup" -Status "Step 1/3" -PercentComplete (($idx / $total) * 100)
        if (Test-Path $file) {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            OK "Removed: $file"
        }
    }
    Write-Progress -Activity "Advanced Cleanup" -Completed

    Write-Host ""
    S "Step 2/3: Cleaning TEMP..."
    Write-Host ""
    Write-Progress -Activity "Advanced Cleanup" -Status "Step 2/3" -PercentComplete 66

    Remove-DirectoryContent -Path $env:TEMP -Description "User TEMP"
    $winTemp = Join-Path $env:windir "Temp"
    Remove-DirectoryContent -Path $winTemp -Description "Windows TEMP"
    Write-Progress -Activity "Advanced Cleanup" -Completed

    Write-Host ""
    S "Step 3/3: Cleaning Event Logs..."
    Write-Host ""
    Write-Progress -Activity "Advanced Cleanup" -Status "Step 3/3" -PercentComplete 90

    $logs = wevtutil el 2>$null
    if ($logs) {
        foreach ($log in $logs) {
            wevtutil cl "$log" 2>$null
        }
        OK "Event logs cleaned"
    }
    Write-Progress -Activity "Advanced Cleanup" -Completed

    Write-Host ""
    OK "Advanced cleanup completed"
    Write-Host ""
    Read-Host "  Press ENTER"
}

function Invoke-DeviceCleanup {
    $deviceCleanup = Join-Path $ScriptDir "Programs\DeviceCleanup.exe"

    if (-not (Test-Path $deviceCleanup)) {
        X "DeviceCleanup.exe not found: $deviceCleanup"
        Read-Host "  Press ENTER"
        return
    }

    S "Launching DeviceCleanup..."
    try {
        Start-Process -FilePath $deviceCleanup -ErrorAction Stop
        OK "DeviceCleanup launched"
    } catch {
        X "Could not launch DeviceCleanup (blocked by UAC/SmartScreen)"
    }
    Read-Host "  Press ENTER"
}

# === LOOP PRINCIPAL ===
do {
    Show-Menu
    $choice = Read-Host "  Choice"

    switch ($choice) {
        "1" { Show-CleanCacheMenu }
        "2" { Invoke-CleanSystem }
        "3" { Invoke-DeviceCleanup }
        "0" {
            Clear-Host
            I "Goodbye!"
            Start-Sleep -Milliseconds 500
            exit 0
        }
        default {
            X "Invalid option"
            Start-Sleep -Milliseconds 800
        }
    }
} while ($true)
