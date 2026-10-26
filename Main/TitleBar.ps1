#region TITLE BAR EVENTS
# WindowStyle="None" + AllowsTransparency="True" breaks WPF's native WindowState=Maximized:
# the window covers the taskbar, and the custom title bar (with the maximize button) can be
# pushed off-screen or stop responding to further clicks. Instead of relying on WindowState,
# maximize/restore is implemented manually here by saving/restoring Left/Top/Width/Height and
# resizing the window to the monitor's work area (screen minus taskbar). This sidesteps the
# WindowState-related rendering/toggle bugs entirely.
$Script:IsMaximized = $false
$Script:RestoreBounds = $null

$btnClose.Add_Click({ $Window.Close() })
$btnMin.Add_Click({ $Window.WindowState = 'Minimized' })

$btnMax = $Window.FindName("btnMax")
if ($btnMax) {
    $btnMax.Add_Click({
        if (-not $Script:IsMaximized) {
            # Save current bounds, then resize to fill the work area (excludes the taskbar)
            $Script:RestoreBounds = @{
                Left = $Window.Left; Top = $Window.Top
                Width = $Window.Width; Height = $Window.Height
            }
            $workArea = [System.Windows.SystemParameters]::WorkArea
            $Window.Left = $workArea.Left
            $Window.Top = $workArea.Top
            $Window.Width = $workArea.Width
            $Window.Height = $workArea.Height
            $Script:IsMaximized = $true
            $btnMax.Content = [string]([char]0xE923)
        }
        else {
            # Restore previously saved bounds
            if ($Script:RestoreBounds) {
                $Window.Left = $Script:RestoreBounds.Left
                $Window.Top = $Script:RestoreBounds.Top
                $Window.Width = $Script:RestoreBounds.Width
                $Window.Height = $Script:RestoreBounds.Height
            }
            $Script:IsMaximized = $false
            $btnMax.Content = [string]([char]0xE922)
        }
    })
}

$titleBar = $Window.FindName("titleBar")
if ($titleBar) {
    $titleBar.Add_MouseLeftButtonDown({
        # Skip DragMove when the click originated on/within a title bar button (min/max/close),
        # otherwise DragMove() captures the mouse and breaks the button's own Click processing.
        $source = $_.OriginalSource
        while ($source -ne $null -and $source -ne $titleBar) {
            if ($source -is [System.Windows.Controls.Button]) { return }
            $source = [System.Windows.Media.VisualTreeHelper]::GetParent($source)
        }
        if ($_.LeftButton -eq 'Pressed') { $Window.DragMove() }
    })
}

$Window.Add_MouseLeftButtonDown({
    $source = $_.OriginalSource
    while ($source -ne $null -and $source -ne $Window) {
        if ($source -is [System.Windows.Controls.Button]) { return }
        $source = [System.Windows.Media.VisualTreeHelper]::GetParent($source)
    }
    if ($_.LeftButton -eq 'Pressed') { $Window.DragMove() }
})
#endregion
