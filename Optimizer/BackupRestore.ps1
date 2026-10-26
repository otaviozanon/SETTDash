Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $env:USERPROFILE "Documents\Backup"
$Timestamp = Get-Date -Format "dd-MM-yyyy-HHmm"
$BackupZip = Join-Path $BackupDir "backup-$Timestamp.zip"
$TempDir = Join-Path $env:TEMP "backup-restore-temp"
$script:Cancelled = $false

trap {
    $script:Cancelled = $true
    Write-Host ""
    Write-Host "[*] Operacao interrompida pelo usuario." -ForegroundColor Yellow
    Cleanup-Temp
    continue
}

function Get-BrowserProfileDirs {
    $chromeBrowsers = @(
        @{ Name = "Brave";  Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
        @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ Name = "Edge";   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ Name = "Vivaldi";Path = "$env:LOCALAPPDATA\Vivaldi\User Data" },
        @{ Name = "Opera";  Path = "$env:APPDATA\Opera Software\Opera Stable" }
    )
    $results = @()

    $firefoxBase = "$env:APPDATA\Mozilla\Firefox"
    $firefoxProfiles = Join-Path $firefoxBase "Profiles"
    if (Test-Path -LiteralPath $firefoxProfiles) {
        $results += $firefoxProfiles
    }
    $firefoxFiles = @("profiles.ini", "installs.ini")
    foreach ($ff in $firefoxFiles) {
        $ffPath = Join-Path $firefoxBase $ff
        if (Test-Path -LiteralPath $ffPath) {
            $results += $ffPath
        }
    }

    $rootFiles = @("Local State", "Variations", "First Run", "Last Version", "BrowserMetrics", "Shortcuts")
    foreach ($browser in $chromeBrowsers) {
        if (-not (Test-Path -LiteralPath $browser.Path)) { continue }

        foreach ($rf in $rootFiles) {
            $rfPath = Join-Path $browser.Path $rf
            if (Test-Path -LiteralPath $rfPath) {
                $results += $rfPath
            }
        }

        $profiles = Get-ChildItem -LiteralPath $browser.Path -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $profiles) {
            $results += $profile.FullName
        }
    }
    return $results
}

function Get-SteamUserDirs {
    $steamConfig = "${env:ProgramFiles(x86)}\Steam\config"
    $userdataRoot = "${env:ProgramFiles(x86)}\Steam\userdata"
    $results = @()
    if (Test-Path -LiteralPath $steamConfig) {
        $results += $steamConfig
    }
    if (-not (Test-Path -LiteralPath $userdataRoot)) {
        return $results
    }
    $uidDirs = Get-ChildItem -LiteralPath $userdataRoot -Directory -ErrorAction SilentlyContinue
    foreach ($uid in $uidDirs) {
        $cs2Dir = Join-Path $uid.FullName "730"
        if (Test-Path -LiteralPath $cs2Dir) {
            $results += $uid.FullName
        }
    }
    return $results
}

$Sources = @{
    "steam"        = (Get-SteamUserDirs)
    "discord"      = @(
        "$env:APPDATA\discord",
        "$env:LOCALAPPDATA\Discord"
    )
    "bookmarks"    = (Get-BrowserProfileDirs)
    "opencode"     = @(
        "$env:USERPROFILE\.config\opencode"
    )
    "gemini"       = @(
        "$env:APPDATA\gemini-cli",
        "$env:USERPROFILE\.gemini"
    )
    "aitools"      = @(
        "$env:USERPROFILE\.codex",
        "$env:USERPROFILE\.claude",
        "$env:USERPROFILE\.continue",
        "$env:USERPROFILE\.cursor",
        "$env:APPDATA\Cursor\User",
        "$env:APPDATA\Claude"
    )
    "vscode"       = @(
        "$env:APPDATA\Code\User",
        "$env:USERPROFILE\.vscode"
    )
    "userdata"     = @(
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Pictures",
        "$env:USERPROFILE\Music",
        "$env:USERPROFILE\Videos"
    )
}

function Get-SizeString {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) {
        return '{0:N2} GB' -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return '{0:N2} MB' -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return '{0:N2} KB' -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes B"
    }
}

function Get-ElapsedString {
    param([timespan]$Elapsed)
    if ($Elapsed.TotalSeconds -lt 60) {
        return '{0:N1}s' -f $Elapsed.TotalSeconds
    }
    elseif ($Elapsed.TotalMinutes -lt 60) {
        return '{0}m {1}s' -f [math]::Floor($Elapsed.TotalMinutes), $Elapsed.Seconds
    }
    else {
        return '{0}h {1}m {2}s' -f [math]::Floor($Elapsed.TotalHours), $Elapsed.Minutes, $Elapsed.Seconds
    }
}

function Cleanup-Temp {
    if ((Test-Path -LiteralPath $TempDir)) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-PathsExist {
    param([hashtable]$SourceMap)
    $found = @()
    $missing = @()
    $appList = @($SourceMap.Keys)
    $total = 0
    foreach ($app in $appList) {
        $total += $SourceMap[$app].Count
    }
    $current = 0
    foreach ($app in $appList) {
        foreach ($path in $SourceMap[$app]) {
            $current++
            $pct = [int](($current / $total) * 100)
            Write-Progress -Activity "Verificando paths de configuracao..." -Status "$app" -PercentComplete $pct
            $expanded = [Environment]::ExpandEnvironmentVariables($path)
            if (Test-Path -LiteralPath $expanded) {
                $isFile = (Test-Path -LiteralPath $expanded -PathType Leaf)
                $found += [PSCustomObject]@{ App = $app; Path = $expanded; IsFile = $isFile }
            }
            else {
                $missing += [PSCustomObject]@{ App = $app; Path = $expanded }
            }
        }
    }
    Write-Progress -Activity "Verificando paths..." -Completed
    return @{ Found = $found; Missing = $missing }
}

function Write-Section {
    param([string]$Title)
    $line = "=" * 48
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

function Get-BlockingAppName {
    param([string]$Path, [string]$AppKey)
    if ($AppKey -eq "bookmarks") {
        if ($Path -like "*BraveSoftware*")  { return "Brave" }
        if ($Path -like "*Google\Chrome*")  { return "Chrome" }
        if ($Path -like "*Microsoft\Edge*") { return "Edge" }
        if ($Path -like "*Mozilla\Firefox*") { return "Firefox" }
        if ($Path -like "*Vivaldi*")        { return "Vivaldi" }
        if ($Path -like "*Opera*")          { return "Opera" }
        return "o navegador"
    }
    if ($AppKey -eq "discord")   { return "Discord" }
    if ($AppKey -eq "steam")     { return "Steam" }
    if ($AppKey -eq "opencode")  { return "OpenCode" }
    if ($AppKey -eq "vscode")    { return "VS Code" }
    return $AppKey
}

function Compress-NativeWithProgress {
    param([string]$TempDir, [string]$BackupZip)
    $totalSrc = 0
    Get-ChildItem -LiteralPath $TempDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $totalSrc += $_.Length }
    $job = Start-Job -ScriptBlock {
        param($src, $dst)
        Compress-Archive -Path "$src\*" -DestinationPath $dst -Force -CompressionLevel Optimal
    } -ArgumentList $TempDir, $BackupZip
    while ($job.State -eq 'Running') {
        if (Test-Path -LiteralPath $BackupZip) {
            $current = (Get-Item -LiteralPath $BackupZip).Length
            if ($totalSrc -gt 0) {
                $pct = [Math]::Min(99, [int](($current / $totalSrc) * 100))
                Write-Progress -Activity "Compactando (Windows)..." -Status "$pct% concluido" -PercentComplete $pct
            }
        }
        Start-Sleep -Milliseconds 500
    }
    $job | Receive-Job -ErrorAction SilentlyContinue | Out-Null
    $job | Remove-Job -ErrorAction SilentlyContinue
    Write-Progress -Activity "Compactando (Windows)..." -Completed
}

function Invoke-Backup {
    Write-Section "VERIFICANDO PATHS DE ORIGEM"
    $result = Test-PathsExist -SourceMap $Sources

    if ($result.Found.Count -eq 0) {
        Write-Host "`n[X] Nenhum path de configuracao encontrado." -ForegroundColor Red
        Write-Host "[X] Backup cancelado." -ForegroundColor Red
        Pause
        return
    }

    $browserNames = @()
    foreach ($item in ($result.Found | Where-Object { $_.App -eq "bookmarks" })) {
        $bn = Get-BlockingAppName -Path $item.Path -AppKey "bookmarks"
        if ($bn -and $browserNames -notcontains $bn) {
            $browserNames += $bn
        }
    }
    if ($browserNames.Count -gt 0) {
        $divider = "!" * 56
        Write-Host "`n$divider" -ForegroundColor Red
        Write-Host "  ATENCAO: FECHE OS NAVEGADORES ABAIXO ANTES DE PROSSEGUIR!" -ForegroundColor Red
        foreach ($bn in $browserNames) {
            Write-Host "    - $bn" -ForegroundColor Yellow
        }
        Write-Host "  Arquivos em uso nao serao copiados corretamente!" -ForegroundColor Red
        Write-Host $divider -ForegroundColor Red
    }

    Write-Host "`n[+] Paths encontrados ($($result.Found.Count)):" -ForegroundColor Green
    $itemsList = @()
    $idx = 0
    foreach ($item in $result.Found) {
        $idx++
        $size = 0
        if (Test-Path -LiteralPath $item.Path) {
            if ($item.IsFile) {
                $size = (Get-Item -LiteralPath $item.Path).Length
            }
            else {
                $size = if (Test-Path -LiteralPath $item.Path) {
                    (Get-ChildItem -LiteralPath $item.Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum)
                } else { 0 }
            }
        }
        $itemsList += [PSCustomObject]@{
            Index = $idx
            App = $item.App
            Path = $item.Path
            IsFile = $item.IsFile
            Size = $size
            Excluded = $false
        }
    }

    function Show-SelectionTotals {
        Clear-Host
        Write-Section "VERIFICANDO PATHS DE ORIGEM"
        Write-Host "`n[+] Paths encontrados ($($itemsList.Count)):" -ForegroundColor Green

        $includedTotal = 0
        $excludedTotal = 0
        $displayIdx = 0
        foreach ($entry in $itemsList) {
            $displayIdx++
            $sizeStr = Get-SizeString -Bytes $entry.Size
            $paddedSize = $sizeStr.PadLeft(9)
            $typeLabel = if ($entry.IsFile) { "FILE " } else { " DIR " }
            $typeColor = if ($entry.IsFile) { "Magenta" } else { "Cyan" }
            $numStr = "[$displayIdx".PadRight(5)
            $mark = if ($entry.Excluded) { " " } else { "x" }
            $markColor = if ($entry.Excluded) { "DarkGray" } else { "Green" }
            $appColor = if ($entry.Excluded) { "DarkGray" } else { "Gray" }
            $sizeColor = if ($entry.Excluded) { "DarkGray" } else { "White" }
            Write-Host "  $numStr" -NoNewline
            Write-Host "$mark" -NoNewline -ForegroundColor $markColor
            Write-Host "] [" -NoNewline
            Write-Host $typeLabel -NoNewline -ForegroundColor $typeColor
            Write-Host "] " -NoNewline
            Write-Host $entry.App.PadRight(12) -NoNewline -ForegroundColor $appColor
            Write-Host $paddedSize -NoNewline -ForegroundColor $sizeColor
            Write-Host "  $($entry.Path)" -ForegroundColor DarkGray
            if ($entry.Excluded) { $excludedTotal += $entry.Size }
            else { $includedTotal += $entry.Size }
        }

        $includedStr = Get-SizeString -Bytes $includedTotal
        $excludedStr = Get-SizeString -Bytes $excludedTotal
        Write-Host "`n[=] Incluido: $includedStr" -NoNewline -ForegroundColor White
        Write-Host "  (excluido: $excludedStr)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  [Enter] Confirmar  [num] Excluir/Incluir  [0] Cancelar" -ForegroundColor DarkGray
    }

    Show-SelectionTotals

    while ($true) {
        $choice = Read-Host ">"

        if ($choice -eq "0") {
            Write-Host "[*] Backup cancelado pelo usuario." -ForegroundColor Yellow
            return
        }
        if ([string]::IsNullOrWhiteSpace($choice)) { break }

        $num = 0
        $isNum = [int]::TryParse($choice, [ref]$num)
        if ($isNum -and $num -ge 1 -and $num -le $itemsList.Count) {
            $target = $itemsList[$num - 1]
            $target.Excluded = -not $target.Excluded
            $label = if ($target.Excluded) { "EXCLUIDO" } else { "INCLUIDO" }
            $color = if ($target.Excluded) { "Yellow" } else { "Green" }
            Write-Host "  [$label] $num : $($target.App) :: $($target.Path)" -ForegroundColor $color
            Show-SelectionTotals
        }
    }

    # Build final filtered list
    $filtered = @($itemsList | Where-Object { -not $_.Excluded })
    if ($filtered.Count -eq 0) {
        Write-Host "`n[X] Todos os itens foram excluidos. Backup cancelado." -ForegroundColor Red
        Pause
        return
    }

    if ($filtered.Count -lt $itemsList.Count) {
        $includedTotal = ($filtered | Measure-Object -Property Size -Sum).Sum
        $filteredStr = Get-SizeString -Bytes $includedTotal
        Write-Host "`n[i] $($filtered.Count) de $($itemsList.Count) item(ns) selecionados ($filteredStr)" -ForegroundColor Cyan
    }

    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    Write-Section "CRIANDO BACKUP"
    Write-Host "Destino: $BackupZip" -ForegroundColor White
    Write-Host ""

    Cleanup-Temp
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $total = $filtered.Count
    $current = 0
    $copiedBytes = 0

    foreach ($entry in $filtered) {
        if ($script:Cancelled) {
            Cleanup-Temp
            return
        }

        $current++
        $pct = [int](($current / $total) * 100)
        $leaf = Split-Path -Leaf $entry.Path
        $status = "[$current/$total] $($entry.App) :: $leaf"
        Write-Progress -Activity "Copiando arquivos..." -Status $status -PercentComplete $pct

        $destDir = Join-Path $TempDir $entry.App
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        $itemSize = 0
        $skipItem = $false
        $savedPref = $ErrorActionPreference

        while (-not $skipItem) {
            $ErrorActionPreference = "Stop"
            try {
                if ($entry.IsFile) {
                    Copy-Item -LiteralPath $entry.Path -Destination $destDir -Force
                    $itemSize = (Get-Item -LiteralPath $entry.Path).Length
                }
                else {
                    $destSub = Join-Path $destDir (Split-Path -Leaf $entry.Path)
                    Copy-Item -LiteralPath $entry.Path -Destination $destSub -Recurse -Force
                    $itemSize = (Get-ChildItem -LiteralPath $destSub -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum)
                }
                break
            }
            catch {
                $ErrorActionPreference = "Continue"
                $blocking = Get-BlockingAppName -Path $entry.Path -AppKey $entry.App
                Write-Host ""
                Write-Host "  [" -NoNewline
                Write-Host " !! " -NoNewline -ForegroundColor Red
                Write-Host "] $($entry.App) :: $leaf  - ARQUIVOS EM USO!" -ForegroundColor Red
                Write-Host "        Feche o $blocking e tente novamente." -ForegroundColor Yellow
                $choice = Read-Host "        [Enter] Tentar novamente  [s] Pular  [c] Cancelar backup"
                if ($choice -eq "s" -or $choice -eq "S") {
                    Write-Host "  [" -NoNewline
                    Write-Host " -- " -NoNewline -ForegroundColor DarkYellow
                    Write-Host "] $($entry.App) :: $leaf -> pulado (arquivos em uso)" -ForegroundColor Yellow
                    $skipItem = $true
                }
                elseif ($choice -eq "c" -or $choice -eq "C") {
                    Cleanup-Temp
                    return
                }
            }
        }
        $ErrorActionPreference = $savedPref
        if ($skipItem) { continue }
        $copiedBytes += $itemSize

        $paddedSize = (Get-SizeString -Bytes $itemSize).PadLeft(9)
        Write-Host "  [" -NoNewline
        Write-Host " OK " -NoNewline -ForegroundColor Green
        Write-Host "] " -NoNewline
        Write-Host $entry.App.PadRight(12) -NoNewline -ForegroundColor Gray
        Write-Host $paddedSize -NoNewline -ForegroundColor White
        Write-Host "  $leaf" -ForegroundColor DarkGray
    }

    Write-Progress -Activity "Copiando arquivos..." -Completed
    Write-Host ""

    Write-Host "Capturando lista de pacotes npm globais..." -ForegroundColor Cyan
    $npmDir = Join-Path $TempDir "npmpackages"
    New-Item -ItemType Directory -Path $npmDir -Force | Out-Null
    $npmJsonFile = Join-Path $npmDir "npm-global.json"
    try {
        $npmOutput = cmd /c "npm list -g --depth=0 --json 2>nul"
        if ($LASTEXITCODE -eq 0 -and $npmOutput) {
            $npmOutput | Out-File -LiteralPath $npmJsonFile -Encoding UTF8
            $npmJson = $npmOutput | ConvertFrom-Json
            if ($npmJson -and $npmJson.dependencies) {
                $npmPkgCount = $npmJson.dependencies.PSObject.Properties.Count
            }
            else {
                $npmPkgCount = 0
            }
            Write-Host "  [ OK ] npmpackages" -NoNewline -ForegroundColor Green
            $pkgCountStr = "$npmPkgCount pacotes"
            Write-Host "                  " -NoNewline
            Write-Host $pkgCountStr -NoNewline -ForegroundColor Gray
            Write-Host "  npm-global.json" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  [ -- ] npmpackages" -NoNewline -ForegroundColor DarkYellow
            Write-Host "                  " -NoNewline
            Write-Host "npm indisponivel ou sem pacotes, pulando." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  [ -- ] npmpackages" -NoNewline -ForegroundColor DarkYellow
        Write-Host "                  " -NoNewline
        Write-Host "erro ao capturar npm: $_" -ForegroundColor Yellow
    }

    $7zExe = $null
    $rarExe = $null
    $7zPaths = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    $rarPaths = @(
        "$env:ProgramFiles\WinRAR\WinRAR.exe",
        "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
    )
    foreach ($p in $7zPaths) {
        if (Test-Path -LiteralPath $p) { $7zExe = $p; break }
    }
    if (-not $7zExe) {
        foreach ($p in $rarPaths) {
            if (Test-Path -LiteralPath $p) { $rarExe = $p; break }
        }
    }

    if ($7zExe) {
        Write-Host "Compactando com 7-Zip (multi-thread, CPU maximo)..." -ForegroundColor Cyan
        $pfErr = Join-Path $env:TEMP "backup-7z-err.txt"
        $proc = Start-Process -FilePath $7zExe `
            -ArgumentList "a -tzip -mx1 -mmt=on -bsp2 `"$BackupZip`" `"$TempDir\*`"" `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardError $pfErr
        $lastPct = -1
        while (-not $proc.HasExited) {
            if (Test-Path -LiteralPath $pfErr) {
                $lines = Get-Content -LiteralPath $pfErr -Tail 2 -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if ($line -and ($line -match '(\d{1,3})\s*%')) {
                        $pct = [int]$matches[1]
                        if ($pct -ne $lastPct) {
                            $lastPct = $pct
                            Write-Progress -Activity "Compactando com 7-Zip..." -Status "$pct% concluido" -PercentComplete $pct
                        }
                    }
                }
            }
            Start-Sleep -Milliseconds 200
        }
        $proc.WaitForExit() | Out-Null
        Write-Progress -Activity "Compactando com 7-Zip..." -Completed
        Remove-Item -LiteralPath $pfErr -ErrorAction SilentlyContinue
        $zipOk = (Test-Path -LiteralPath $BackupZip) -and ((Get-Item -LiteralPath $BackupZip).Length -gt 0)
        if (-not $zipOk) {
            Write-Host "[!] 7-Zip falhou. Usando Compress-Archive..." -ForegroundColor Yellow
            Compress-NativeWithProgress -TempDir $TempDir -BackupZip $BackupZip
        }
    }
    elseif ($rarExe) {
        Write-Host "Compactando com WinRAR (multi-thread, CPU maximo)..." -ForegroundColor Cyan
        $pfOut = Join-Path $env:TEMP "backup-rar-out.txt"
        $proc = Start-Process -FilePath $rarExe `
            -ArgumentList "a -afzip -m1 -mt16 `"$BackupZip`" `"$TempDir\*`"" `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $pfOut
        $lastPct = -1
        while (-not $proc.HasExited) {
            if (Test-Path -LiteralPath $pfOut) {
                $lines = Get-Content -LiteralPath $pfOut -Tail 2 -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if ($line -and ($line -match '(\d{1,3})\s*%')) {
                        $pct = [int]$matches[1]
                        if ($pct -ne $lastPct) {
                            $lastPct = $pct
                            Write-Progress -Activity "Compactando com WinRAR..." -Status "$pct% concluido" -PercentComplete $pct
                        }
                    }
                }
            }
            Start-Sleep -Milliseconds 200
        }
        $proc.WaitForExit() | Out-Null
        Write-Progress -Activity "Compactando com WinRAR..." -Completed
        Remove-Item -LiteralPath $pfOut -ErrorAction SilentlyContinue
        $zipOk = (Test-Path -LiteralPath $BackupZip) -and ((Get-Item -LiteralPath $BackupZip).Length -gt 0)
        if (-not $zipOk) {
            Write-Host "[!] WinRAR falhou. Usando Compress-Archive..." -ForegroundColor Yellow
            Compress-NativeWithProgress -TempDir $TempDir -BackupZip $BackupZip
        }
    }
    else {
        Write-Host "Compactando com Compress-Archive (Windows)..." -ForegroundColor Cyan
        Compress-NativeWithProgress -TempDir $TempDir -BackupZip $BackupZip
    }

    $stopwatch.Stop()
    Cleanup-Temp

    $zipSize = (Get-Item -LiteralPath $BackupZip).Length
    $zipSizeStr = Get-SizeString -Bytes $zipSize
    $elapsed = Get-ElapsedString -Elapsed $stopwatch.Elapsed

    Write-Host ""
    Write-Host "[+] Backup criado com sucesso!" -ForegroundColor Green
    Write-Host "    Arquivo : $BackupZip" -ForegroundColor White
    Write-Host "    Tamanho : $zipSizeStr" -ForegroundColor White
    Write-Host "    Tempo   : $elapsed" -ForegroundColor White
    $filteredTotalStr = Get-SizeString -Bytes ($filtered | Measure-Object -Property Size -Sum).Sum
    Write-Host "    Origem  : $filteredTotalStr em $($filtered.Count) item(ns)" -ForegroundColor White
    Pause
}

function Invoke-Restore {
    Write-Section "RESTAURAR BACKUP"

    $zips = @(Get-ChildItem -LiteralPath $BackupDir -Filter "backup-*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($zips.Count -eq 0) {
        Write-Host "`n[!] Nenhum arquivo backup-*.zip encontrado em:" -ForegroundColor Red
        Write-Host "    $BackupDir" -ForegroundColor Red
        Pause
        return
    }

    Write-Host "`nBackups disponiveis:" -ForegroundColor White
    for ($i = 0; $i -lt $zips.Count; $i++) {
        $zipName = $zips[$i].Name
        $zipSize = '{0:N2} MB' -f ($zips[$i].Length / 1MB)
        $zipDate = $zips[$i].LastWriteTime.ToString("dd/MM/yyyy HH:mm")
        $zipIndex = $i + 1
        Write-Host "  [$zipIndex] $zipName  ($zipSize  $zipDate)"
    }
    Write-Host "  [0] Cancelar"

    $choice = Read-Host "`nEscolha o numero do backup"
    if ($choice -eq "0" -or [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "[*] Restauracao cancelada." -ForegroundColor Yellow
        return
    }

    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $zips.Count) {
        Write-Host "[!] Opcao invalida." -ForegroundColor Red
        Pause
        return
    }

    $selectedZip = $zips[$index]
    $zipSizeStr = '{0:N2} MB' -f ($selectedZip.Length / 1MB)
    Write-Host "`nSelecionado: $($selectedZip.Name)  ($zipSizeStr)" -ForegroundColor White

    $confirm = Read-Host "Confirma a restauracao? Arquivos existentes serao renomeados como backup. [S/n]"
    if ($confirm -ne "" -and $confirm -ne "S" -and $confirm -ne "s") {
        Write-Host "[*] Restauracao cancelada pelo usuario." -ForegroundColor Yellow
        return
    }

    Write-Section "RESTAURANDO"

    $extractedDirName = $selectedZip.BaseName
    $extractedDir = Join-Path $BackupDir $extractedDirName
    $useExisting = $false

    if ((Test-Path -LiteralPath $extractedDir) -and (Get-ChildItem -LiteralPath $extractedDir -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Host ""
        Write-Host "Pasta extraida encontrada: $extractedDir" -ForegroundColor Cyan
        $extractChoice = Read-Host "[Enter] Usar existente  [e] Extrair novamente"
        if ($extractChoice -ne "e" -and $extractChoice -ne "E") {
            $useExisting = $true
        }
    }

    Cleanup-Temp
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    if ($useExisting) {
        Write-Host "Copiando extracao existente..." -ForegroundColor White
        Write-Progress -Activity "Restaurando backup..." -Status "Copiando extracao existente..." -PercentComplete 10
        Copy-Item -LiteralPath "$extractedDir\*" -Destination $TempDir -Recurse -Force
        Write-Progress -Activity "Restaurando backup..." -Status "Copia concluida." -PercentComplete 20
    }
    else {
        Write-Host "Extraindo backup..." -ForegroundColor White
        Write-Progress -Activity "Restaurando backup..." -Status "Extraindo $($selectedZip.Name)..." -PercentComplete 10
        Expand-Archive -LiteralPath $selectedZip.FullName -DestinationPath $TempDir -Force
        Write-Progress -Activity "Restaurando backup..." -Status "Extraido com sucesso." -PercentComplete 30
    }

    $apps = @(Get-ChildItem -LiteralPath $TempDir -Directory)
    $total = $apps.Count
    $current = 0
    $restoredCount = 0
    $skippedCount = 0

    foreach ($app in $apps) {
        if ($script:Cancelled) {
            Cleanup-Temp
            return
        }

        $current++
        $pct = 30 + [int](($current / $total) * 60)
        $appName = $app.Name
        Write-Progress -Activity "Restaurando backup..." -Status "Processando $appName ($current/$total)" -PercentComplete $pct

        if (-not $Sources.ContainsKey($appName)) {
            Write-Host "  [" -NoNewline
            Write-Host " -- " -NoNewline -ForegroundColor DarkYellow
            Write-Host "] " -NoNewline
            Write-Host $appName.PadRight(12) -NoNewline -ForegroundColor Gray
            Write-Host "app desconhecida, pulando." -ForegroundColor Yellow
            $skippedCount++
            continue
        }

        $items = Get-ChildItem -LiteralPath $app.FullName
        foreach ($item in $items) {
            $sourcePaths = $Sources[$appName]
            $matched = $false
            $destPath = $null
            $destParent = $null
            foreach ($src in $sourcePaths) {
                $expanded = [Environment]::ExpandEnvironmentVariables($src)
                $parent = Split-Path -Parent $expanded
                $leaf = Split-Path -Leaf $expanded
                if ($item.Name -eq $leaf) {
                    $destPath = $expanded
                    $destParent = $parent
                    $matched = $true
                    break
                }
            }

            if (-not $matched) {
                Write-Host "  [" -NoNewline
                Write-Host " -- " -NoNewline -ForegroundColor DarkYellow
                Write-Host "] " -NoNewline
                Write-Host $appName.PadRight(12) -NoNewline -ForegroundColor Gray
                Write-Host "$($item.Name) -> destino nao identificado, pulando." -ForegroundColor Yellow
                $skippedCount++
                continue
            }

            if (-not (Test-Path -LiteralPath $destParent)) {
                Write-Host "  [" -NoNewline
                Write-Host " -- " -NoNewline -ForegroundColor DarkYellow
                Write-Host "] " -NoNewline
                Write-Host $appName.PadRight(12) -NoNewline -ForegroundColor Gray
                Write-Host "diretorio pai nao existe." -ForegroundColor Yellow
                Write-Host "         " -NoNewline
                Write-Host $destParent -ForegroundColor DarkGray
                $skippedCount++
                continue
            }

            if (Test-Path -LiteralPath $destPath) {
                $backupExisting = "$destPath.backup-$Timestamp"
                Rename-Item -LiteralPath $destPath -NewName (Split-Path -Leaf $backupExisting) -Force
                Write-Host "  [" -NoNewline
                Write-Host " ~ " -NoNewline -ForegroundColor DarkYellow
                Write-Host "] " -NoNewline
                Write-Host $appName.PadRight(12) -NoNewline -ForegroundColor Gray
                Write-Host "backup existente renomeado" -ForegroundColor Yellow
            }

            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $item.FullName -Destination $destPath -Recurse -Force
            }
            else {
                Copy-Item -LiteralPath $item.FullName -Destination $destParent -Force
            }
            Write-Host "  [" -NoNewline
            Write-Host " + " -NoNewline -ForegroundColor Green
            Write-Host "] " -NoNewline
            Write-Host $appName.PadRight(12) -NoNewline -ForegroundColor Gray
            Write-Host "$($item.Name) -> restaurado" -ForegroundColor White
            $restoredCount++
        }
    }

    $npmRestoreFile = Join-Path $TempDir "npmpackages\npm-global.json"
    if (Test-Path -LiteralPath $npmRestoreFile) {
        Write-Host ""
        Write-Host "Pacotes npm globais encontrados no backup." -ForegroundColor Cyan
        $restoreNpm = Read-Host "Reinstalar pacotes npm globais? [S/n]"
        if ($restoreNpm -eq "" -or $restoreNpm -eq "S" -or $restoreNpm -eq "s") {
            try {
                $npmData = Get-Content -LiteralPath $npmRestoreFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($npmData.dependencies) {
                    $npmPkgs = $npmData.dependencies.PSObject.Properties
                    Write-Host "  Instalando $($npmPkgs.Count) pacote(s) npm..." -ForegroundColor White
                    foreach ($pkg in $npmPkgs) {
                        $pkgSpec = "$($pkg.Name)@$($pkg.Value.version)"
                        Write-Host "  [ .. ] $pkgSpec" -NoNewline
                        $installResult = cmd /c "npm install -g $pkgSpec 2>&1"
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "`r  [ OK ] $pkgSpec" -ForegroundColor Green
                        }
                        else {
                            Write-Host "`r  [ !! ] $pkgSpec -> falhou" -ForegroundColor Red
                        }
                    }
                }
            }
            catch {
                Write-Host "  [ !! ] Erro ao processar npm-global.json: $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  [ -- ] Reinstalacao npm ignorada." -ForegroundColor DarkYellow
        }
    }

    Write-Progress -Activity "Restaurando backup..." -Completed
    Cleanup-Temp

    Write-Host ""
    Write-Host "[+] Restauracao concluida!" -ForegroundColor Green
    Write-Host "    Itens restaurados : $restoredCount" -ForegroundColor White
    if ($skippedCount -gt 0) {
        Write-Host "    Itens ignorados   : $skippedCount" -ForegroundColor Yellow
    }
    Write-Host "    Backups anteriores renomeados com extensao .backup-$Timestamp" -ForegroundColor Yellow
    Pause
}

function Write-Banner {
    Clear-Host
    $width = 48
    $line = "=" * $width
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  BACKUP / RESTORE - CONFIGURACOES" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Banner
    Write-Host "  AI TOOLS" -ForegroundColor Yellow
    Write-Host "    opencode | gemini | codex | claude | continue | cursor" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  DEVELOPMENT" -ForegroundColor Yellow
    Write-Host "    Visual Studio Code (settings + extensions)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  BROWSER DATA (FULL PROFILE)" -ForegroundColor Yellow
    Write-Host "    Brave | Chrome | Edge | Firefox | Opera | Vivaldi" -ForegroundColor Gray
    Write-Host "    (TUDO: bookmarks, extensoes, senhas, cookies, historico, sessoes)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  OTHER" -ForegroundColor Yellow
    Write-Host "    Steam (config + CS2/CSGO profiles) | Discord" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  USER DATA" -ForegroundColor Yellow
    Write-Host "    Documents | Downloads | Pictures | Music | Videos" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Backup dir: $BackupDir" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Fazer Backup" -ForegroundColor White
    Write-Host "  [2] Restaurar Backup" -ForegroundColor White
    Write-Host "  [0] Sair" -ForegroundColor White
    Write-Host ""
}

try {
    $backupCount = @(Get-ChildItem -LiteralPath $BackupDir -Filter "backup-*.zip" -ErrorAction SilentlyContinue).Count
    Write-Host "[i] $backupCount backup(s) existente(s) em $BackupDir" -ForegroundColor DarkGray

    do {
        Show-Menu
        $op = Read-Host "Escolha uma opcao"

        switch ($op) {
            "1" {
                $script:Cancelled = $false
                try {
                    Invoke-Backup
                }
                catch {
                    Write-Warning "Erro durante backup: $_"
                    Cleanup-Temp
                    Pause
                }
            }
            "2" {
                $script:Cancelled = $false
                try {
                    Invoke-Restore
                }
                catch {
                    Write-Warning "Erro durante restauracao: $_"
                    Cleanup-Temp
                    Pause
                }
            }
            "0" {
                Write-Host "`nSaindo..." -ForegroundColor Cyan
                break
            }
            default {
                Write-Host "[!] Opcao invalida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($op -ne "0")
    exit 0
}
catch {
    Write-Warning "Erro inesperado: $_"
    Cleanup-Temp
    Pause
    exit 1
}
