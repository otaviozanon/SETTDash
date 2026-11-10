#region EMBEDDED PROGRAMS
$Script:EmbeddedPrograms = @{}

# Decodes a base64 + GZip blob into the original file bytes.
# The streams are disposed in a finally block: a failed extraction must not leak handles that keep
# the destination file locked for the rest of the session.
function Expand-EmbeddedBlob {
    param([string]$Data)
    $raw = [Convert]::FromBase64String($Data)
    $ms = New-Object System.IO.MemoryStream(,$raw)
    $gs = $null
    $out = $null
    try {
        $gs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
        $out = New-Object System.IO.MemoryStream
        $gs.CopyTo($out)
        return $out.ToArray()
    } finally {
        if ($out) { $out.Dispose() }
        if ($gs) { $gs.Dispose() }
        $ms.Dispose()
    }
}

# Runtime files live under a folder named after the running version. A new release never reuses
# an old extracted binary, and an extracted file that no longer matches its embedded blob is
# rewritten instead of trusted (the folder is user-writable, so a stale or swapped file must not
# be executed as-is).
function Get-EmbeddedRuntimeDir {
    $tag = [string]$Script:AppVersion
    if (-not $tag) { $tag = "dev" }
    $tag = $tag -replace '[^0-9A-Za-z._-]', '_'
    $dir = Join-Path $Script:TempDir ("v" + $tag)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    return $dir
}

# Writes $Bytes to $Path only when the file is missing or its content differs from the blob.
# Returns $true when the file was (re)written. Hashing the decompressed bytes means an updated
# embedded tool replaces the old copy on the next launch instead of being skipped forever.
function Save-EmbeddedFile {
    param([string]$Path, [byte[]]$Bytes)
    $current = $false
    try {
        if (Test-Path -LiteralPath $Path) {
            $existing = [System.IO.File]::ReadAllBytes($Path)
            if ($existing.Length -eq $Bytes.Length) {
                $sha = [System.Security.Cryptography.SHA256]::Create()
                try {
                    $current = ([BitConverter]::ToString($sha.ComputeHash($existing)) -eq
                                [BitConverter]::ToString($sha.ComputeHash($Bytes)))
                } finally { $sha.Dispose() }
            }
        }
    } catch { $current = $false }
    if ($current) { return $false }

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllBytes($Path, $Bytes)
    return $true
}

# Returns the verified path of one embedded program, extracting/replacing it when needed.
# Callers launch this path instead of joining $Script:TempDir themselves, so a file swapped while
# the app is running is detected at the moment it would be executed.
function Get-EmbeddedProgramPath {
    param([string]$Name)
    $blob = $Script:EmbeddedPrograms[$Name]
    if (-not $blob) { return $null }
    $outPath = Join-Path (Join-Path (Get-EmbeddedRuntimeDir) "Programs") $Name
    try {
        if (Save-EmbeddedFile -Path $outPath -Bytes (Expand-EmbeddedBlob $blob)) {
            if (Get-Command Write-GuiLog -CommandType Function -ErrorAction SilentlyContinue) {
                Write-GuiLog "Extracted: $Name" "INFO"
            }
        }
        return $outPath
    } catch {
        if (Get-Command Write-GuiLog -CommandType Function -ErrorAction SilentlyContinue) {
            Write-GuiLog "Failed to extract $Name : $_" "ERR"
        }
        return $null
    }
}

# Called once at startup (Main/Startup.ps1). Extracts the missing entries of
# $Script:EmbeddedPrograms (base64 + gzip blobs baked into this script) into
# <runtime>\v<version>\Programs. Existing files are left alone here: Get-EmbeddedProgramPath
# re-verifies (and replaces) the one file a caller is about to run, so startup does not pay for
# decompressing and hashing every embedded binary on each launch.
function Extract-EmbeddedPrograms {
    $programsDir = Join-Path (Get-EmbeddedRuntimeDir) "Programs"
    foreach ($key in @($Script:EmbeddedPrograms.Keys)) {
        if (Test-Path -LiteralPath (Join-Path $programsDir $key)) { continue }
        [void](Get-EmbeddedProgramPath $key)
    }
}
#endregion
