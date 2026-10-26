#region EMBEDDED PROGRAMS
$Script:EmbeddedPrograms = @{}

# Called once at startup (Main/Startup.ps1). Decodes/decompresses every entry in
# $Script:EmbeddedPrograms (base64 + gzip blobs baked into this script) into $Script:TempDir\Programs,
# skipping any file that's already extracted there.
function Extract-EmbeddedPrograms {
    $progDir = Join-Path $Script:TempDir "Programs"
    if (-not (Test-Path $progDir)) { New-Item -Path $progDir -ItemType Directory -Force | Out-Null }
    foreach ($key in $Script:EmbeddedPrograms.Keys) {
        $outPath = Join-Path $progDir $key
        if (Test-Path $outPath) { continue }
        try {
            $bytes = [Convert]::FromBase64String($Script:EmbeddedPrograms[$key])
            $ms = New-Object System.IO.MemoryStream(,$bytes)
            $gs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $fs = New-Object System.IO.FileStream($outPath, [System.IO.FileMode]::Create)
            $gs.CopyTo($fs)
            $fs.Close(); $gs.Close(); $ms.Close()
            Write-GuiLog "Extracted: $key" "INFO"
        } catch { Write-GuiLog "Failed to extract $key : $_" "ERR" }
    }
}
#endregion
