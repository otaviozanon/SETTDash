# ================================================
#region ERROR LOG (on-disk report, written only when something fails)
# ================================================
# Nothing is written to disk on a healthy run: the last few hundred in-app log lines are kept in a
# memory ring buffer instead. The moment something actually fails - a step that reports ERR, an
# exception caught by a button handler, or an unhandled/background exception - that buffer is
# dumped into %LOCALAPPDATA%\SETTDash\logs\error-settdash-<date>.log together with the exception
# details, so even a crash that closes the window leaves a readable report behind (with the
# context of what the app was doing right before).
# Deliberately NOT under %TEMP%: "Full Cleanup" wipes that folder mid-run.
$Script:LogBuffer = New-Object System.Collections.Queue
$Script:LogBufferMax = 400
$Script:ErrorLogPath = $null
$Script:ErrorLogLock = New-Object System.Object
$Script:ErrorLogEncoding = New-Object System.Text.UTF8Encoding($false)

# Returns the error report path for today (one file per day, created on first error). $null on failure.
function Get-ErrorLogPath {
    if ($Script:ErrorLogPath) { return $Script:ErrorLogPath }
    try {
        $dir = Join-Path $env:LOCALAPPDATA "SETTDash\logs"
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $path = Join-Path $dir ("error-settdash-{0}.log" -f (Get-Date -Format "yyyyMMdd"))
        # Keep reports small enough to be shareable: roll over once a day-file passes 5 MB.
        if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -gt 5MB) {
            Move-Item -LiteralPath $path -Destination "$path.old" -Force -ErrorAction SilentlyContinue
        }
        $Script:ErrorLogPath = $path
    } catch { }
    return $Script:ErrorLogPath
}

# Keeps one log line in memory only (no disk I/O). Called for every non-error Write-GuiLog line.
function Add-LogBuffer {
    param([string]$Text)
    try {
        $q = $Script:LogBuffer
        if (-not $q) { return }
        $q.Enqueue(("{0} {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $Text))
        while ($q.Count -gt $Script:LogBufferMax) { [void]$q.Dequeue() }
    } catch { }
}

# Writes an error entry to the report file, creating the file on first use. When the file is
# created, the buffered log lines are written first so the report shows what happened before.
# Returns $true when a new file was created (used to tell the user where the report went).
# Never throws: logging must not be able to break a feature, and this also runs on crash paths.
function Write-ErrorLog {
    param([string]$Text)
    $created = $false
    try {
        $path = Get-ErrorLogPath
        if (-not $path) { return $false }
        $lock = $Script:ErrorLogLock
        if ($lock) { [System.Threading.Monitor]::Enter($lock) }
        try {
            $enc = $Script:ErrorLogEncoding
            if (-not $enc) { $enc = New-Object System.Text.UTF8Encoding($false) }
            $created = -not (Test-Path -LiteralPath $path)
            $sb = New-Object System.Text.StringBuilder
            if ($created) {
                [void]$sb.AppendLine("=========================================================")
                [void]$sb.AppendLine(" SETTDash error report | $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
                [void]$sb.AppendLine(" context: last $($Script:LogBuffer.Count) in-app log lines before the error")
                [void]$sb.AppendLine("=========================================================")
                foreach ($line in $Script:LogBuffer) { [void]$sb.AppendLine($line) }
                [void]$sb.AppendLine("------------------------- error -------------------------")
                $Script:LogBuffer.Clear()
            }
            [void]$sb.AppendLine(("{0} {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $Text))
            [System.IO.File]::AppendAllText($path, $sb.ToString(), $enc)
        } finally {
            if ($lock) { [System.Threading.Monitor]::Exit($lock) }
        }
    } catch { }
    return $created
}
#endregion

# Appends a colored, timestamped-style line to the log RichTextBox ($txtLog) and auto-scrolls to the end.
# $Type controls prefix/color: OK (green), ERR (red), WARN (yellow), STEP (purple), default/INFO (gray).
function Write-GuiLog {
    param([string]$Message, [string]$Type="INFO")
    # Only failures reach the disk: ERR lines are appended to the error report (creating it on the
    # first one, together with the buffered context); everything else stays in memory.
    $reportCreated = $false
    if ($Type -eq "ERR") { try { $reportCreated = Write-ErrorLog "[ERR] $Message" } catch { } }
    else { try { Add-LogBuffer "[$Type] $Message" } catch { } }
    $prefix = switch ($Type) { "OK" { "[OK]  " } "ERR" { "[ERR] " } "WARN" { "[WRN] " } "STEP" { "[>]   " } default { "[i]   " } }
    # Colors come from the active theme (same Brush_* resources the rest of the UI uses), so the
    # log follows Default/Terminal Retro instead of freezing one palette into the runs.
    $colorKey = switch ($Type) { "OK" { "Brush_AccentGreen" } "ERR" { "Brush_AccentRed" } "WARN" { "Brush_AccentAmber" } "STEP" { "Brush_AccentPurple" } default { "Brush_TextSecondary" } }
    $brush = $null
    try { $brush = $Window.FindResource($colorKey) } catch { }
    if (-not $brush) { $brush = [System.Windows.Media.Brushes]::Gray }

    try {
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = "0"
        $para.LineHeight = 16
        $run = New-Object System.Windows.Documents.Run("$prefix$Message")
        $run.Foreground = $brush
        $para.Inlines.Add($run)
        $txtLog.Document.Blocks.Add($para)
    } catch {
        # The file report above already has the line; a UI rendering failure must never break a
        # feature or bubble up into the click handler (that used to crash the app).
        Write-ErrorLog "GUI log render failed: $($_.Exception.Message)"
        return
    }
    try {
        $txtLog.ScrollToEnd()
    } catch {
        # Glyph measurement reads the font file on every layout pass. If that file vanished (e.g.
        # deleted by a cleaner), every new line throws "Unable to find the specified file." - drop
        # to a stock font once so the log keeps working instead of killing the app.
        Add-LogBuffer "GUI log scroll failed ($($_.Exception.Message)); falling back to Consolas"
        try {
            $txtLog.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
            $txtLog.ScrollToEnd()
        } catch { }
    }
    # Tells the user where the report went, so a failure is never a dead end (the path is stable
    # per day, but nobody has to remember it).
    if ($reportCreated) { Write-GuiLog ((T "Error report saved to {0}") -f (Get-ErrorLogPath)) "INFO" }
}

# Updates the main progress bar value and, if provided, logs a STEP message. Forces a UI render
# by invoking an empty action at Background priority so the bar visibly updates during long loops.
function Set-GuiProgress { param([double]$Value, [string]$Status)
    try { $progressBar.Value = $Value } catch { }
    if ($Status) { Write-GuiLog $Status "STEP" }
    try { $Window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { }
}

# Resets the log RichTextBox to a fresh, empty FlowDocument (clears all previous log lines).
function Clear-GuiLog {
    try {
        $doc = New-Object System.Windows.Documents.FlowDocument
        $txtLog.Document = $doc
    } catch { Write-ErrorLog "GUI log clear failed: $($_.Exception.Message)" }
}

if ($btnLogCopy) {
    $btnLogCopy.Add_Click({
        try {
            $range = New-Object System.Windows.Documents.TextRange($txtLog.Document.ContentStart, $txtLog.Document.ContentEnd)
            [System.Windows.Clipboard]::SetText($range.Text)
            Write-GuiLog (T "Log copied to clipboard") "OK"
        } catch { Write-GuiLog ((T "Failed to copy log: {0}") -f $_) "ERR" }
    })
}

if ($btnLogClear) {
    $btnLogClear.Add_Click({ Clear-GuiLog })
}

