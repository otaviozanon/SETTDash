
# ================================================
#region SYSTEM PATHS (WOW64-SAFE)
# ================================================
# The release .exe is compiled -x64 (.github/workflows/release.yml), but SETTDash can also be run
# from a 32-bit PowerShell host (SETTDash.ps1). In a 32-bit process Windows applies WOW64
# file-system redirection: every path under C:\Windows\System32 resolves to C:\Windows\SysWOW64.
# Tools that only ship as 64-bit binaries (wsreset.exe, msconfig.exe, ...) are not present there,
# so resolving them by name fails and Start-Process throws "The system cannot find the file
# specified" - which surfaced as a crash popup on Clean > System Cleaner > Full Cleanup (Store
# Cache step). These helpers resolve the real 64-bit location through the Sysnative alias, so the
# same code works no matter how the app is hosted (x86 or x64).

# Returns the full path of a System32 executable, or $null when it is absent from this machine.
# Resolution order: Sysnative (64-bit binaries, seen from a 32-bit process) -> System32 -> SysWOW64.
function Get-SystemToolPath {
    param([string]$Name)
    if (-not $Name) { return $null }
    $candidates = @()
    if (-not [Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) {
        $candidates += (Join-Path $env:windir "Sysnative\$Name")
    }
    $candidates += (Join-Path $env:windir "System32\$Name")
    $candidates += (Join-Path $env:windir "SysWOW64\$Name")
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

# Launches a System32 tool through Get-SystemToolPath. Logs (instead of throwing) when the tool
# is missing or the launch fails, so a missing external binary can never take the whole app down.
function Start-SystemTool {
    param(
        [string]$Name,
        [string]$Label = "",
        [string[]]$Arguments = @(),
        [string]$WindowStyle = "",
        [switch]$Wait
    )
    if (-not $Label) { $Label = $Name }
    $path = Get-SystemToolPath $Name
    if (-not $path) { Write-GuiLog ((T "{0} not available: {1} was not found") -f $Label, $Name) "WARN"; return $false }
    try {
        $startArgs = @{ FilePath = $path; ErrorAction = 'Stop' }
        # @(...) guards the caller passing $null instead of an array: $null.Count throws.
        if (@($Arguments).Count -gt 0) { $startArgs['ArgumentList'] = $Arguments }
        if ($WindowStyle) { $startArgs['WindowStyle'] = $WindowStyle }
        if ($Wait) { $startArgs['Wait'] = $true }
        Start-Process @startArgs
        Write-GuiLog ((T "{0} opened") -f $Label) "OK"
        return $true
    } catch {
        Write-GuiLog ((T "{0} failed to open: {1}") -f $Label, $_.Exception.Message) "ERR"
        return $false
    }
}

# Returns the real 64-bit "Program Files" root. Inside a 32-bit process $env:ProgramFiles is
# redirected to "Program Files (x86)", which is why 64-bit apps installed in "C:\Program Files"
# were never found; WOW64 exposes the real root as ProgramW6432.

function Get-ProgramFiles64Path {
    if ($env:ProgramW6432) { return $env:ProgramW6432 }
    return $env:ProgramFiles
}

# Finds an installed program by relative path (e.g. "Mozilla Firefox\firefox.exe"), checking the
# 64-bit Program Files root first and then the 32-bit one. Returns $null when not installed.
function Get-InstalledProgramPath {
    param([string]$RelativePath)
    if (-not $RelativePath) { return $null }
    $roots = @()
    $root64 = Get-ProgramFiles64Path
    if ($root64) { $roots += $root64 }
    if ($env:ProgramFiles) { $roots += $env:ProgramFiles }
    if (${env:ProgramFiles(x86)}) { $roots += ${env:ProgramFiles(x86)} }
    foreach ($root in ($roots | Select-Object -Unique)) {
        $candidate = Join-Path $root $RelativePath
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}
#endregion
