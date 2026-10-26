# Appends a colored, timestamped-style line to the log RichTextBox ($txtLog) and auto-scrolls to the end.
# $Type controls prefix/color: OK (green), ERR (red), WARN (yellow), STEP (purple), default/INFO (gray).
function Write-GuiLog {
    param([string]$Message, [string]$Type="INFO")
    $prefix = switch ($Type) { "OK" { "[OK]  " } "ERR" { "[ERR] " } "WARN" { "[WRN] " } "STEP" { "[>]   " } default { "[i]   " } }
    $color = switch ($Type) { "OK" { "#3FB950" } "ERR" { "#F85149" } "WARN" { "#D29922" } "STEP" { "#A371F7" } default { "#8B949E" } }
    
    $para = New-Object System.Windows.Documents.Paragraph
    $para.Margin = "0"
    $para.LineHeight = 16
    $run = New-Object System.Windows.Documents.Run("$prefix$Message")
    $colorObj = [System.Windows.Media.ColorConverter]::ConvertFromString($color)
    $run.Foreground = New-Object System.Windows.Media.SolidColorBrush($colorObj)
    $para.Inlines.Add($run)
    $txtLog.Document.Blocks.Add($para)
    $txtLog.ScrollToEnd()
}

# Updates the main progress bar value and, if provided, logs a STEP message. Forces a UI render
# by invoking an empty action at Background priority so the bar visibly updates during long loops.
function Set-GuiProgress { param([double]$Value, [string]$Status)
    $progressBar.Value = $Value
    if ($Status) { Write-GuiLog $Status "STEP" }
    $Window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Resets the log RichTextBox to a fresh, empty FlowDocument (clears all previous log lines).
function Clear-GuiLog {
    $doc = New-Object System.Windows.Documents.FlowDocument
    $txtLog.Document = $doc
}

if ($btnLogCopy) {
    $btnLogCopy.Add_Click({
        try {
            $range = New-Object System.Windows.Documents.TextRange($txtLog.Document.ContentStart, $txtLog.Document.ContentEnd)
            [System.Windows.Clipboard]::SetText($range.Text)
            Write-GuiLog "Log copied to clipboard" "OK"
        } catch { Write-GuiLog "Failed to copy log: $_" "ERR" }
    })
}

if ($btnLogClear) {
    $btnLogClear.Add_Click({ Clear-GuiLog })
}
