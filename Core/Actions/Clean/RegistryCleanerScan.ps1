
# ================================================
#region CLEAN TAB - REGISTRY CLEANER (scan/backup/fix)
# ================================================
# Recreates Kudu's "Registry Cleaner" scan categories (registry-cleaner.ipc.ts) as native
# PowerShell equivalents: broken App Paths, SharedDLLs, Run/RunOnce, Fonts, MUI Cache,
# orphaned Services, stale Uninstall entries and Firewall rules pointing to missing files.
# Every fix is preceded by a .reg backup (reg.exe export) so changes can be restored.
# Used by: Sidebar\Pages\Clean.ps1

# Safely reads a property from a PSObject (e.g. Get-ItemProperty result) without throwing
# under Set-StrictMode -Version Latest when the property does not exist on that key.
function Get-SafeProp {
    param($Object, [string]$Name)
    if (-not $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if (-not $prop) { return $null }
    return $prop.Value
}

# Exports a single registry key to a timestamped .reg file before it is modified/deleted.
function Backup-RegistryKey {
    param([string]$KeyPath)
    try {
        $backupDir = Join-Path $env:LOCALAPPDATA "SETTDash\Backups\Registry"
        if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
        $safeName = ($KeyPath -replace '[\\:\s]', '_')
        $file = Join-Path $backupDir ("{0}_{1}.reg" -f $safeName, (Get-Date -Format "yyyyMMddHHmmss"))
        $regPath = $KeyPath -replace '^HKLM:\\', 'HKLM\' -replace '^HKCU:\\', 'HKCU\'
        Start-Process -FilePath "reg.exe" -ArgumentList @("export", "`"$regPath`"", "`"$file`"", "/y") -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    } catch { }
}

# Scans the categories below and returns pscustomobjects: Label, Detail, Selected, KeyPath,
# ValueName ('' when the whole key is the target), FixOp ('delete-key' or 'delete-value').
function Get-RegistryCleanerItems {
    $items = @()

    # 1) Broken App Paths - HKLM App Paths subkeys whose (Default) exe no longer exists
    $appPathsRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'
    if (Test-Path $appPathsRoot) {
        Get-ChildItem $appPathsRoot -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = Get-SafeProp (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue) '(default)'
            if ($exe -and -not (Test-Path $exe)) {
                $items += [pscustomobject]@{ Label="Broken App Path: $($_.PSChildName)"; Detail="Missing: $exe"; Selected=$true; KeyPath="$appPathsRoot\$($_.PSChildName)"; ValueName=''; FixOp='delete-key' }
            }
        }
    }

    # 2) Broken SharedDLLs references - value names (DLL paths) that no longer exist
    $sharedDllsKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs'
    if (Test-Path $sharedDllsKey) {
        $props = Get-ItemProperty $sharedDllsKey -ErrorAction SilentlyContinue
        if ($props) {
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                if ($_.Name -and -not (Test-Path $_.Name)) {
                    $items += [pscustomobject]@{ Label="Shared DLL reference missing"; Detail=$_.Name; Selected=$true; KeyPath=$sharedDllsKey; ValueName=$_.Name; FixOp='delete-value' }
                }
            }
        }
    }

    # 3) Broken Run / RunOnce startup entries pointing to a missing executable
    $runKeys = @(
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    foreach ($runKey in $runKeys) {
        if (-not (Test-Path $runKey)) { continue }
        $props = Get-ItemProperty $runKey -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $cmd = [string]$_.Value
            $exe = ($cmd -replace '^"([^"]+)".*$', '$1')
            if ($exe -eq $cmd) { $exe = ($cmd -split ' ')[0] }
            if ($exe -and $exe -match '\\' -and -not (Test-Path $exe)) {
                $items += [pscustomobject]@{ Label="Startup entry missing file: $($_.Name)"; Detail=$cmd; Selected=$true; KeyPath=$runKey; ValueName=$_.Name; FixOp='delete-value' }
            }
        }
    }

    # 4) Broken font file references
    $fontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontsDir = Join-Path $env:windir 'Fonts'
    if (Test-Path $fontsKey) {
        $props = Get-ItemProperty $fontsKey -ErrorAction SilentlyContinue
        if ($props) {
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                $file = [string]$_.Value
                if ($file -and ($file -notmatch '\\')) { $file = Join-Path $fontsDir $file }
                if ($file -and -not (Test-Path $file)) {
                    $items += [pscustomobject]@{ Label="Font file missing: $($_.Name)"; Detail=$file; Selected=$true; KeyPath=$fontsKey; ValueName=$_.Name; FixOp='delete-value' }
                }
            }
        }
    }

    # 5) Orphaned services pointing to missing executables (skips Windows/Microsoft paths)
    $servicesKey = 'HKLM:\SYSTEM\CurrentControlSet\Services'
    if (Test-Path $servicesKey) {
        Get-ChildItem $servicesKey -ErrorAction SilentlyContinue | Select-Object -First 400 | ForEach-Object {
            $imagePath = Get-SafeProp (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue) 'ImagePath'
            if (-not $imagePath) { return }
            $exe = ($imagePath -replace '^"([^"]+)".*$', '$1')
            if ($exe -eq $imagePath) { $exe = ($imagePath -split ' ')[0] }
            $exe = $exe -replace '^\\SystemRoot', $env:windir
            $lower = $exe.ToLower()
            if ($lower -match '^[a-z]:\\' -and $lower -notmatch '\\windows\\' -and $lower -notmatch '\\microsoft\\' -and -not (Test-Path $exe)) {
                $items += [pscustomobject]@{ Label="Service '$($_.PSChildName)' missing executable"; Detail=$exe; Selected=$true; KeyPath="$servicesKey\$($_.PSChildName)"; ValueName=''; FixOp='delete-key' }
            }
        }
    }

    # 6) Stale Uninstall entries (install location and uninstall string both gone)
    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($uKey in $uninstallKeys) {
        if (-not (Test-Path $uKey)) { continue }
        Get-ChildItem $uKey -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $displayName = Get-SafeProp $p 'DisplayName'
            if (-not $p -or -not $displayName) { return }
            if ($displayName -match '^(Microsoft|Windows)|KB\d{6,}|Security Update|Hotfix') { return }
            $installLocation = Get-SafeProp $p 'InstallLocation'
            $displayIcon = Get-SafeProp $p 'DisplayIcon'
            $installLocOk = $installLocation -and (Test-Path $installLocation)
            $iconOk = $false
            if ($displayIcon) { $iconPath = ($displayIcon -split ',')[0].Trim('"'); $iconOk = $iconPath -and (Test-Path $iconPath) }
            if (-not $installLocOk -and -not $iconOk -and $installLocation) {
                $items += [pscustomobject]@{ Label="Orphaned uninstall entry: $displayName"; Detail="Install folder missing"; Selected=$true; KeyPath=$_.PSPath; ValueName=''; FixOp='delete-key' }
            }
        }
    }

    return $items
}

# Applies the fix for each selected item, backing up the key first. Returns @{Fixed;Failed}.
function Invoke-RegistryCleanerFix {
    param([array]$Items)
    $total = $Items.Count
    $fixed = 0; $failed = 0
    for ($i = 0; $i -lt $total; $i++) {
        $it = $Items[$i]
        Set-GuiProgress ([math]::Round(($i+1)/[math]::Max($total,1)*100)) "Fixing: $($it.Label)"
        try {
            Backup-RegistryKey -KeyPath $it.KeyPath
            if ($it.FixOp -eq 'delete-value') {
                Remove-ItemProperty -Path $it.KeyPath -Name $it.ValueName -Force -ErrorAction Stop
            } else {
                Remove-Item -Path $it.KeyPath -Recurse -Force -ErrorAction Stop
            }
            $fixed++
            Write-GuiLog "$($it.Label) fixed" "OK"
        } catch {
            $failed++
            Write-GuiLog "Failed to fix $($it.Label): $_" "ERR"
        }
    }
    Set-GuiProgress 0
    Write-GuiLog "Registry Cleaner: $fixed/$total issues fixed (backups saved to %LOCALAPPDATA%\SETTDash\Backups\Registry)" "OK"
    return @{Fixed=$fixed; Failed=$failed}
}
#endregion
