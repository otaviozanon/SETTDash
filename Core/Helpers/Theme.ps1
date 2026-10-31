# ================================================
#region THEME SYSTEM
# Defines the available visual themes and applies them by writing SolidColorBrush/FontFamily/
# CornerRadius values into $Window.Resources. All colors in Layout.ps1 are bound via
# {DynamicResource ...}, so updating a resource here repaints every already-rendered control
# immediately - no page reload needed.
# ================================================

$Script:Themes = @{
    "Default" = @{
        DisplayName   = "Default (Dark)"
        WindowBg      = "#0D1117"
        Border        = "#30363D"
        SidebarBg     = "#0D1117"
        CardBg        = "#11151B"
        CardBorder    = "#21262D"
        TextPrimary   = "#E6EDF3"
        TextSecondary = "#8B949E"
        TextMuted     = "#6E7681"
        Accent        = "#1F6FEB"
        NavActiveBg   = "#14181F"
        TitleBarBg    = "#161B22"
        LogBg         = "#0D1117"
        LogBorder     = "#30363D"
        LogText       = "#8B949E"
        HoverBg       = "#161B22"
        PressedBg     = "#1C2128"
        Disabled      = "#484F58"
        GaugeTrack    = "#242A32"
        GaugeDot      = "#1F6FEB"
        ProgressTrack = "#21262D"
        Divider       = "#282E36"
        ScrollThumb   = "#30363D"
        Danger        = "#6E2C2C"
        DangerHover   = "#F85149"
        DangerPressed = "#A32D2A"
        CornerRadius  = 6
        FontFamily    = "Segoe UI"
        Retro         = $false
    }
    "TerminalRetro" = @{
        # Only the accent orange is meant to "pop" (active nav, highlights, borders-on-hover,
        # log, scrollbar). Body text/borders stay neutral gray/white so the whole UI doesn't
        # read as a single flat orange wash.
        DisplayName   = "Terminal Retro"
        WindowBg      = "#1E1E1E"
        Border        = "#4A4A4A"
        SidebarBg     = "#181818"
        CardBg        = "#242424"
        CardBorder    = "#3C3C3C"
        TextPrimary   = "#E8E8E8"
        TextSecondary = "#A8A8A8"
        TextMuted     = "#787878"
        Accent        = "#FF8C00"
        NavActiveBg   = "#2E2E2E"
        TitleBarBg    = "#141414"
        LogBg         = "#141414"
        LogBorder     = "#4A4A4A"
        LogText       = "#FF9D33"
        HoverBg       = "#2E2416"
        PressedBg     = "#3A2C16"
        Disabled      = "#5A5A5A"
        GaugeTrack    = "#3A3A3A"
        GaugeDot      = "#FFFFFF"
        ProgressTrack = "#2A2A2A"
        Divider       = "#4A4A4A"
        ScrollThumb   = "#FF8C00"
        Danger        = "#B23A2E"
        DangerHover   = "#FF5A3C"
        DangerPressed = "#7A2219"
        CornerRadius  = 0
        FontFamily    = "MONO"
        Retro         = $true
    }
}

# Converts a hex color string into a SolidColorBrush usable as a resource value.
function ConvertTo-GuiBrush { param([string]$Hex)
    New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex))
}

# Builds a tiled "LED segments" DrawingBrush drawn on top of the progress bar fill, simulating a
# retro/8-bit blocky indicator (thin dark separators repeating every few pixels) instead of a
# smooth gradient bar. Returns a plain transparent brush when $Retro is $false.
function New-GuiProgressOverlayBrush { param([bool]$Retro)
    if (-not $Retro) { return [System.Windows.Media.Brushes]::Transparent }
    $db = New-Object System.Windows.Media.DrawingBrush
    $db.Viewport = New-Object System.Windows.Rect(0, 0, 6, 10)
    $db.ViewportUnits = [System.Windows.Media.BrushMappingMode]::Absolute
    $db.TileMode = [System.Windows.Media.TileMode]::Tile
    $gd = New-Object System.Windows.Media.GeometryDrawing
    $gd.Geometry = New-Object System.Windows.Media.RectangleGeometry (New-Object System.Windows.Rect(0, 0, 2, 10))
    $gd.Brush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(150, 0, 0, 0))
    $db.Drawing = $gd
    $db.Freeze()
    return $db
}

# Returns the path to the persisted settings file (created on demand), under %APPDATA%\SETTDash.
function Get-GuiSettingsPath {
    $dir = Join-Path $env:APPDATA "SETTDash"
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    Join-Path $dir "settings.json"
}

# Reads the full settings.json as a hashtable (empty hashtable if missing/corrupt). Used so a
# single persisted key (e.g. Theme) can be updated without clobbering the others (e.g. MinimizeToTray).
function Get-GuiSettingsData {
    $data = @{}
    try {
        $path = Get-GuiSettingsPath
        if (Test-Path $path) {
            $json = Get-Content -Path $path -Raw | ConvertFrom-Json
            if ($json) { $json.PSObject.Properties | ForEach-Object { $data[$_.Name] = $_.Value } }
        }
    } catch {}
    return $data
}

# Merges $Key/$Value into settings.json, preserving every other previously saved key.
function Save-GuiSettingValue {
    param([string]$Key, $Value)
    try {
        $data = Get-GuiSettingsData
        $data[$Key] = $Value
        $data | ConvertTo-Json | Set-Content -Path (Get-GuiSettingsPath) -Encoding UTF8
    } catch {}
}

# Persists the chosen theme name so it's restored on the next launch.
function Save-GuiThemePref { param([string]$ThemeName) Save-GuiSettingValue -Key "Theme" -Value $ThemeName }

# Reads the previously saved theme name, falling back to "Default" if none/invalid.
function Get-GuiThemePref {
    $data = Get-GuiSettingsData
    if ($data.Theme -and $Script:Themes.ContainsKey($data.Theme)) { return $data.Theme }
    return "Default"
}

# Whether closing the main window should minimize to the system tray instead of exiting (default: off).
# NOTE: the extra inner parens matter - "[bool](Get-GuiSettingsData).MinimizeToTray" casts the
# hashtable itself to bool FIRST (cast binds to the parenthesized call, not the whole chain), then
# tries ".MinimizeToTray" on that boolean, which fails. Casting the final property value instead.
function Get-GuiMinimizeToTrayPref { return [bool]((Get-GuiSettingsData).MinimizeToTray) }
function Save-GuiMinimizeToTrayPref { param([bool]$Enabled) Save-GuiSettingValue -Key "MinimizeToTray" -Value $Enabled }

# Applies the named theme by updating $Window.Resources (DynamicResource targets refresh live),
# remembers it as the active theme, and saves the preference to disk.
function Set-GuiTheme {
    param([Parameter(Mandatory)][string]$ThemeName)
    $t = $Script:Themes[$ThemeName]
    if (-not $t) { return }

    # NOTE: We intentionally use Remove()+Add() instead of the indexer ($Window.Resources["Key"] = value).
    # Replacing a resource via the indexer while elements are bound to it with {DynamicResource} makes WPF
    # eagerly re-validate every direct (non-Style-Setter) consumer of that key synchronously, and on recent
    # .NET runtimes this throws "'<value>' is not a valid value for property 'X'" even though the value/type
    # is correct. Remove()+Add() avoids that in-place replacement code path.
    function Set-GuiResource { param([string]$Key, $Value)
        $Window.Resources.Remove($Key)
        $Window.Resources.Add($Key, $Value)
    }

    Set-GuiResource "Brush_WindowBg"      (ConvertTo-GuiBrush $t.WindowBg)
    Set-GuiResource "Brush_Border"        (ConvertTo-GuiBrush $t.Border)
    Set-GuiResource "Brush_SidebarBg"     (ConvertTo-GuiBrush $t.SidebarBg)
    Set-GuiResource "Brush_CardBg"        (ConvertTo-GuiBrush $t.CardBg)
    Set-GuiResource "Brush_CardBorder"    (ConvertTo-GuiBrush $t.CardBorder)
    Set-GuiResource "Brush_TextPrimary"   (ConvertTo-GuiBrush $t.TextPrimary)
    Set-GuiResource "Brush_TextSecondary" (ConvertTo-GuiBrush $t.TextSecondary)
    Set-GuiResource "Brush_TextMuted"     (ConvertTo-GuiBrush $t.TextMuted)
    Set-GuiResource "Brush_Accent"        (ConvertTo-GuiBrush $t.Accent)
    Set-GuiResource "Brush_NavActiveBg"   (ConvertTo-GuiBrush $t.NavActiveBg)
    Set-GuiResource "Brush_TitleBarBg"    (ConvertTo-GuiBrush $t.TitleBarBg)
    Set-GuiResource "Brush_LogBg"         (ConvertTo-GuiBrush $t.LogBg)
    Set-GuiResource "Brush_LogBorder"     (ConvertTo-GuiBrush $t.LogBorder)
    Set-GuiResource "Brush_LogText"       (ConvertTo-GuiBrush $t.LogText)
    Set-GuiResource "Brush_HoverBg"       (ConvertTo-GuiBrush $t.HoverBg)
    Set-GuiResource "Brush_PressedBg"     (ConvertTo-GuiBrush $t.PressedBg)
    Set-GuiResource "Brush_Disabled"      (ConvertTo-GuiBrush $t.Disabled)
    Set-GuiResource "Brush_GaugeTrack"    (ConvertTo-GuiBrush $t.GaugeTrack)
    Set-GuiResource "Brush_GaugeDot"      (ConvertTo-GuiBrush $t.GaugeDot)
    Set-GuiResource "Brush_ProgressTrack" (ConvertTo-GuiBrush $t.ProgressTrack)
    Set-GuiResource "Brush_Divider"       (ConvertTo-GuiBrush $t.Divider)
    Set-GuiResource "Brush_ScrollThumb"   (ConvertTo-GuiBrush $t.ScrollThumb)
    Set-GuiResource "Brush_Danger"        (ConvertTo-GuiBrush $t.Danger)
    Set-GuiResource "Brush_DangerHover"   (ConvertTo-GuiBrush $t.DangerHover)
    Set-GuiResource "Brush_DangerPressed" (ConvertTo-GuiBrush $t.DangerPressed)
    Set-GuiResource "Brush_ProgressOverlay" (New-GuiProgressOverlayBrush -Retro:$t.Retro)
    Set-GuiResource "Theme_CornerRadius"  (New-Object System.Windows.CornerRadius($t.CornerRadius))
    Set-GuiResource "Theme_IsRetro"       [bool]$t.Retro
    Set-GuiResource "Theme_FontFamily"    $(if ($t.FontFamily -eq "MONO" -and $Script:MonoFontFamily) {
        $Script:MonoFontFamily
    } else {
        New-Object System.Windows.Media.FontFamily($t.FontFamily)
    })

    # Toggle the scanline overlay (only meaningful/visible in the retro theme).
    if ($Window -and $Window.FindName("RetroScanlineOverlay")) {
        $overlay = $Window.FindName("RetroScanlineOverlay")
        $overlay.Visibility = if ($t.Retro) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }

    $Script:CurrentTheme = $ThemeName
    Save-GuiThemePref $ThemeName
}
#endregion
