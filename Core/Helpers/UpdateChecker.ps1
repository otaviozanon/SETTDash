# ================================================
#region AUTO-UPDATE
# ================================================
# Returns the latest version when it is a valid version newer than the current one; $null when it
# is the same/older, or when either side cannot be parsed. Pure so tests can exercise it without
# touching the network.
function Get-UpdateAvailability {
    param([string]$CurrentVersion, [string]$LatestTag)
    $current = $null; $latest = $null
    if (-not [version]::TryParse([string]$CurrentVersion, [ref]$current)) { return $null }
    $tag = ([string]$LatestTag).TrimStart('v')
    if (-not [version]::TryParse($tag, [ref]$latest)) { return $null }
    if ($latest -le $current) { return $null }
    return $tag
}

# Used by: Startup (checks GitHub for a newer release every launch)
# Compares $Script:AppVersion against the latest GitHub release tag for
# otaviozanon/SETTDash. If a newer .exe is published, asks the user for
# confirmation (MessageBox Yes/No) before handing off to Invoke-SelfUpdate.
function Invoke-CheckForUpdates {
    param(
        [string]$RepoOwner = "otaviozanon",
        [string]$RepoName  = "SETTDash"
    )
    # Unattended runs (tests\Test-Smoke.ps1 walks every page in the compiled exe) must not depend on
    # GitHub state: when a release newer than the local build exists, the "update available" dialog
    # below is a blocking modal with nobody to answer it, so the whole sweep hangs until the test
    # times out. The switch skips only this check - nothing else in the app behaves differently.
    if ($env:SETTDASH_NO_UPDATE_CHECK -eq '1') { return }
    Write-GuiLog (T "Checking for updates...") "STEP"
    try {
        # .NET Framework (the host WinPS 5.1 the compiled exe runs on) defaults to older TLS;
        # GitHub API/objects require TLS 1.2 or the asset download aborts mid-transfer.
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/$Script:AppVersion" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10

        $latestTag = Get-UpdateAvailability -CurrentVersion $Script:AppVersion -LatestTag ([string]$release.tag_name)
        if (-not $latestTag) {
            # Either this build is current, or a tag/version string could not be parsed.
            Write-GuiLog ((T "SETTDash is up to date (v{0})") -f $Script:AppVersion) "OK"
            return
        }

        Write-GuiLog ((T "Update available: v{0} (current v{1})") -f $latestTag, $Script:AppVersion) "WARN"
        $asset = $release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
        if (-not $asset) { Write-GuiLog (T "No .exe asset found in latest release") "ERR"; return }

        if (-not (Show-UpdateConfirmDialog -CurrentVersion $Script:AppVersion -NewVersion $latestTag)) {
            Write-GuiLog (T "Update postponed by user") "INFO"
            return
        }

        Invoke-SelfUpdate -DownloadUrl $asset.browser_download_url -NewVersion $latestTag -ExpectedSize ([long]$asset.size) -ExpectedSha256 ([string](Get-SafeProp $asset 'digest'))
    } catch {
        Write-GuiLog ((T "Update check failed: {0}") -f $_) "WARN"
    }
}

# Shared XAML snippet used by both update popups: dark card with a custom
# title bar (matches Main\Layout.ps1 palette/typography) instead of the
# native Windows chrome. {0}=width {1}=title {2}=extra body XAML
function script:Get-UpdatePopupXaml {
    param([int]$Width, [string]$Title, [string]$BodyXaml, [bool]$ShowCloseButton = $true)

    # Theme-aware chrome: these custom popups are plain XamlReader Windows (not part of the
    # main $Window visual tree), so they can't use {DynamicResource} against $Window.Resources.
    # Instead, bake the CURRENT theme's colors in as literal values each time a popup is built.
    $t = $Script:Themes[$Script:CurrentTheme]
    if (-not $t) { $t = $Script:Themes["Default"] }
    $fontFamily = if ($t.FontFamily -eq "MONO") { "Consolas" } else { "Segoe UI" }
    $radius = $t.CornerRadius

    $closeBtnXaml = ""
    if ($ShowCloseButton) {
        $closeBtnXaml = "<Button x:Name=`"btnDialogClose`" Grid.Column=`"1`" Content=`"&#xE8BB;`" Width=`"40`" Height=`"32`" Background=`"Transparent`" Foreground=`"$($t.TextSecondary)`" FontFamily=`"Segoe MDL2 Assets`" FontSize=`"10`" BorderThickness=`"0`" Cursor=`"Hand`"><Button.Template><ControlTemplate TargetType=`"Button`"><Border x:Name=`"b`" Background=`"{TemplateBinding Background}`"><ContentPresenter HorizontalAlignment=`"Center`" VerticalAlignment=`"Center`"/></Border><ControlTemplate.Triggers><Trigger Property=`"IsMouseOver`" Value=`"True`"><Setter TargetName=`"b`" Property=`"Background`" Value=`"$($t.DangerHover)`"/><Setter Property=`"Foreground`" Value=`"White`"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Button.Template></Button>"
    }
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="$Width" SizeToContent="Height"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" Topmost="True"
        TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="Grayscale">
    <Window.Resources>
        <Style x:Key="DialogPrimaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="$($t.Accent)"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontFamily" Value="$fontFamily"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="MinWidth" Value="104"/>
            <Setter Property="Padding" Value="18,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}" MinWidth="{TemplateBinding MinWidth}"
                                CornerRadius="$radius">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DialogSecondaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="$($t.TextPrimary)"/>
            <Setter Property="FontFamily" Value="$fontFamily"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="MinWidth" Value="104"/>
            <Setter Property="Padding" Value="18,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="$($t.Border)"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}" MinWidth="{TemplateBinding MinWidth}"
                                CornerRadius="$radius">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="$($t.Accent)"/>
                                <Setter Property="Foreground" Value="$($t.Accent)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border x:Name="rootBorder" Background="$($t.WindowBg)" BorderBrush="$($t.Border)" BorderThickness="1" CornerRadius="$radius">
        <Border.Effect>
            <DropShadowEffect Color="$($t.Shadow)" BlurRadius="22" ShadowDepth="4" Opacity="0.45"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Border x:Name="titleBar" Grid.Row="0" Background="$($t.TitleBarBg)" BorderBrush="$($t.Border)" BorderThickness="0,0,0,1">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="$Title" Foreground="$($t.TextPrimary)" FontFamily="$fontFamily" FontSize="12" FontWeight="SemiBold"
                               VerticalAlignment="Center" Margin="16,0,0,0"/>
                    $closeBtnXaml
                </Grid>
            </Border>
            <StackPanel Grid.Row="1" Margin="22">
                $BodyXaml
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
}

# Returns the active theme's color hashtable, used by popup body builders (Show-UpdateConfirmDialog,
# Invoke-SelfUpdate, Show-PawnIOInstallPrompt) so text/icon colors inside the body also follow the
# currently selected theme (Default / Terminal Retro), matching the chrome built by Get-UpdatePopupXaml.
function script:Get-CurrentThemeColors {
    $t = $Script:Themes[$Script:CurrentTheme]
    if (-not $t) { $t = $Script:Themes["Default"] }
    return $t
}

# Wires DragMove on a popup's custom title bar (skips drag when clicking the close button).
function script:Register-UpdatePopupDrag {
    param($PopupWindow, $TitleBar)
    $TitleBar.Add_MouseLeftButtonDown({
        $source = $_.OriginalSource
        while ($source -ne $null -and $source -ne $TitleBar) {
            if ($source -is [System.Windows.Controls.Button]) { return }
            $source = [System.Windows.Media.VisualTreeHelper]::GetParent($source)
        }
        if ($_.LeftButton -eq 'Pressed') { $PopupWindow.DragMove() }
    }.GetNewClosure())
}

# Used by: Invoke-CheckForUpdates
# Styled Yes/No confirmation popup (matches dashboard look) asking the user
# whether to install the newly detected release. Returns $true/$false.
function Show-UpdateConfirmDialog {
    param([string]$CurrentVersion, [string]$NewVersion)

    $t = Get-CurrentThemeColors
    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="$($t.CornerRadius)" Background="$($t.HoverBg)">
                <TextBlock Text="&#xE895;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="$($t.Accent)"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="$(T 'Update Available')" FontFamily="JetBrains Mono, Consolas" Foreground="$($t.TextPrimary)" FontSize="14" FontWeight="Bold"/>
                <TextBlock x:Name="txtVersions" FontFamily="JetBrains Mono, Consolas" Text="v$CurrentVersion &#8594; v$NewVersion" Foreground="$($t.TextMuted)" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
        </StackPanel>
        <TextBlock Text="$(T 'A new version of SETTDash is ready to install. Do you want to update now?')"
                   Foreground="$($t.TextSecondary)" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnLater" Content="$(T 'Later')" Style="{StaticResource DialogSecondaryButtonStyle}" Margin="0,0,12,0"/>
            <Button x:Name="btnUpdate" Content="$(T 'Update Now')" Style="{StaticResource DialogPrimaryButtonStyle}"/>
        </StackPanel>
"@

    [xml]$xaml = Get-UpdatePopupXaml -Width 420 -Title "SETTDash Update" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $btnLater = $dlg.FindName("btnLater")
    $btnUpdate = $dlg.FindName("btnUpdate")

    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar

    $state = [pscustomobject]@{ Confirmed = $false }
    $btnLater.Add_Click({ $state.Confirmed = $false; $dlg.Close() }.GetNewClosure())
    $btnUpdate.Add_Click({ $state.Confirmed = $true; $dlg.Close() }.GetNewClosure())
    $btnClose.Add_Click({ $state.Confirmed = $false; $dlg.Close() }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
    return $state.Confirmed
}

# Used by: Invoke-CheckForUpdates
# Shows a styled progress popup (matches dashboard look) while downloading the
# new .exe to %TEMP%\SETTDash. On success, writes an "update applied" marker
# (read back by Show-UpdateAppliedNotice on next launch), spawns a detached
# helper PowerShell process that waits for this process to exit, overwrites
# the current executable in place, relaunches it, and cleans up after itself.
function Invoke-SelfUpdate {
    param([string]$DownloadUrl, [string]$NewVersion, [long]$ExpectedSize = 0, [string]$ExpectedSha256 = "")
    # GitHub's asset.digest is "sha256:<hex>" (and is absent on older releases). The exe is run
    # elevated right after this, so a truncated/corrupted download must never be launched: only a
    # full 64-hex digest is accepted, anything else disables the check and is logged loudly.
    if ($ExpectedSha256 -match '^(?:sha256:)?([0-9A-Fa-f]{64})$') {
        $expectedHash = $Matches[1].ToLower()
    } else {
        $expectedHash = ""
        if ($ExpectedSha256) { Write-GuiLog ((T "Update: unusable digest '{0}' - integrity check disabled") -f $ExpectedSha256) "WARN" }
        else { Write-GuiLog (T "Update: release publishes no SHA-256 digest - integrity check unavailable") "WARN" }
    }
    # Plain local (NOT $Script:) values used inside the ContentRendered closure below:
    # 'Script: variables are not readable there - that scope expression resolves against
    # the closure MODULE's script scope (null), which corrupted 'Join-Path' with
    # "Cannot bind argument to parameter 'Path' because it is null".
    $tempDir = $Script:TempDir

    $currentExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $newExe = Join-Path $tempDir "SETTDash_v$NewVersion.exe"

    $t = Get-CurrentThemeColors
    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="$($t.CornerRadius)" Background="$($t.HoverBg)">
                <TextBlock Text="&#xE896;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="$($t.Accent)"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock x:Name="txtTitle" FontFamily="JetBrains Mono, Consolas" Text="$(T 'Downloading update') v$NewVersion" Foreground="$($t.TextPrimary)" FontSize="14" FontWeight="Bold"/>
                <TextBlock x:Name="txtStatus" FontFamily="JetBrains Mono, Consolas" Text="$(T 'Connecting...')" Foreground="$($t.TextMuted)" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
        </StackPanel>
        <Grid Height="8" Margin="0,2,0,0">
            <Border Background="$($t.ProgressTrack)" CornerRadius="4"/>
            <Border x:Name="progressFill" Background="$($t.Accent)" CornerRadius="4" HorizontalAlignment="Stretch" RenderTransformOrigin="0,0.5">
                <Border.RenderTransform>
                    <ScaleTransform x:Name="progressScale" ScaleX="0"/>
                </Border.RenderTransform>
            </Border>
        </Grid>
"@

    [xml]$xaml = Get-UpdatePopupXaml -Width 420 -Title "SETTDash Update" -BodyXaml $body -ShowCloseButton $false
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $progressWin = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $progressWin.FindName("titleBar")
    $txtTitle = $progressWin.FindName("txtTitle")
    $txtStatus = $progressWin.FindName("txtStatus")
    $progressScale = $progressWin.FindName("progressScale")
    Register-UpdatePopupDrag -PopupWindow $progressWin -TitleBar $titleBar

    # Synchronous download, scheduled only once the popup has rendered (Add_ContentRendered,
    # so "Blocking..." text is visible while the UI thread is inside the sync request).
    # Rationale: the async WebClient (DownloadFileAsync) under the compiled exe's WinPS 5.1 host
    # aborted the 5.4MB asset transfer at ~20% on every attempt back when the exe was built
    # 32-bit; the exact same URL downloaded synchronously completes fine, so the sync path is
    # kept (it works under both 32- and 64-bit hosts).
    $progressWin.Add_ContentRendered({
        param($pw, $evt)
        $ok = $false; $lastReason = ''
        foreach ($tryN in 1..3) {
            try {
                $wc2 = New-Object System.Net.WebClient
                try { $wc2.DownloadFile([Uri]$DownloadUrl, $newExe) } catch { throw } finally { $wc2.Dispose() }
                $got = (Get-Item $newExe -ErrorAction Stop).Length
                if ($ExpectedSize -gt 0 -and $got -ne $ExpectedSize) { throw "incomplete download ($got / $ExpectedSize bytes)" }
                if ($expectedHash) {
                    $actual = (Get-FileHash -Path $newExe -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower()
                    if ($actual -ne $expectedHash) { throw "SHA-256 mismatch (expected $expectedHash, got $actual)" }
                    Write-GuiLog (T "Update: SHA-256 verified") "OK"
                }
                $ok = $true
                break
            } catch {
                $lastReason = $_.Exception.Message
                Write-GuiLog ((T "Download attempt {0} failed: {1}") -f $tryN, $lastReason) "WARN"
                Remove-Item $newExe -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 800
            }
        }
        if (-not $ok) {
            Write-GuiLog ((T "Update download failed after 3 attempts: {0}") -f $lastReason) "ERR"
            $pw.Close()
            return
        }

        $txtTitle.Text = T "Update downloaded"
        $txtStatus.Text = "$(T 'Restarting SETTDash to apply') v$NewVersion..."

        try {
            $markerPath = Join-Path $tempDir "update_applied.txt"
            Set-Content -Path $markerPath -Value $NewVersion -Encoding UTF8 -Force

            $currentPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
            $logPath = Join-Path $env:LOCALAPPDATA "SETTDash\Backups\updater.log"
            # The helper is passed to powershell.exe as -EncodedCommand instead of being written to a
            # .ps1 next to the downloaded exe: a script file in a user-writable folder could be edited
            # between the write and the launch, and then it would run with the old process gone.
            $updaterScript = @"
`$ErrorActionPreference = 'Stop'
New-Item -Path '$(Split-Path $logPath -Parent)' -ItemType Directory -Force | Out-Null
function Write-UpdLog { param(`$m) try { Add-Content -Path '$logPath' -Value ((Get-Date -Format 'HH:mm:ss') + ' ' + `$m) -Encoding UTF8 } catch {} }
try { Wait-Process -Id $currentPid -Timeout 15 } catch {}
Start-Sleep -Seconds 1
# Re-verify the downloaded file right before it replaces the running exe.
if ('$expectedHash') {
  try { `$srcHash = (Get-FileHash -Path '$newExe' -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower() }
  catch { Write-UpdLog ('SOURCE HASH ERROR: ' + `$_.Exception.Message); exit 1 }
  if (`$srcHash -ne '$expectedHash') { Write-UpdLog 'SOURCE HASH MISMATCH - aborting'; exit 1 }
}
# Copy with retries: the just-exited exe can remain briefly locked by AV/indexer.
`$copied = `$false
for (`$i = 0; `$i -lt 20 -and -not `$copied; `$i++) {
  try {
    Copy-Item -Path '$newExe' -Destination '$currentExe' -Force -ErrorAction Stop
    `$copied = `$true
    Write-UpdLog 'COPY OK'
  } catch {
    Write-UpdLog ("COPY RETRY " + (`$i + 1) + ": " + `$_.Exception.Message)
    Start-Sleep -Milliseconds 500
  }
}
if (-not `$copied) {
  Write-UpdLog 'COPY FAILED - aborting relaunch'
  exit 1
}
# What landed on disk is what gets relaunched: a partial copy would break the app silently.
if ('$expectedHash') {
  try { `$dstHash = (Get-FileHash -Path '$currentExe' -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower() }
  catch { Write-UpdLog ('DEST HASH ERROR: ' + `$_.Exception.Message); exit 1 }
  if (`$dstHash -ne '$expectedHash') { Write-UpdLog 'DEST HASH MISMATCH - aborting relaunch'; exit 1 }
}
try { Start-Process -FilePath '$currentExe'; Write-UpdLog 'RELAUNCH OK' } catch { Write-UpdLog ('RELAUNCH FAILED: ' + `$_.Exception.Message) }
Remove-Item -Path '$newExe' -Force -ErrorAction SilentlyContinue
"@
            $encodedUpdater = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($updaterScript))
            Start-Process -FilePath "powershell.exe" -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-EncodedCommand", $encodedUpdater
            )
        } catch {
            Write-GuiLog ((T "Self-update failed: {0}") -f $_) "ERR"
            $pw.Close()
            return
        }

        Start-Sleep -Milliseconds 800
        $pw.Close()
        # Called before $Window.ShowDialog() during startup, so just terminate the
        # process outright rather than closing an unshown Window (Close() would throw).
        [System.Environment]::Exit(0)
    }.GetNewClosure())

    $progressWin.ShowDialog() | Out-Null
}

# Used by: Startup (runs before Invoke-CheckForUpdates)
# If the previous run just self-updated (marker file left by Invoke-SelfUpdate),
# logs a visible confirmation so the user knows the update actually applied,
# then removes the marker.
function Show-UpdateAppliedNotice {
    $markerPath = Join-Path $Script:TempDir "update_applied.txt"
    if (Test-Path $markerPath) {
        try {
            $updatedVersion = (Get-Content $markerPath -Raw).Trim()
            if ($updatedVersion) { Write-GuiLog ((T "Updated to v{0} successfully!") -f $updatedVersion) "OK" }
        } catch {}
        Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
    }
}
#endregion
