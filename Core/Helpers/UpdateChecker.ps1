# ================================================
#region AUTO-UPDATE
# ================================================
# Used by: Startup (checks GitHub for a newer release every launch)
# Compares $Script:AppVersion against the latest GitHub release tag for
# otaviozanon/SETTDash. If a newer .exe is published, asks the user for
# confirmation (MessageBox Yes/No) before handing off to Invoke-SelfUpdate.
function Invoke-CheckForUpdates {
    param(
        [string]$RepoOwner = "otaviozanon",
        [string]$RepoName  = "SETTDash"
    )
    Write-GuiLog "Checking for updates..." "STEP"
    try {
        # .NET Framework (WinPS 5.1 under the compiled -x86 exe) defaults to older TLS;
        # GitHub API/objects require TLS 1.2 or the asset download aborts mid-transfer.
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
        $headers = @{ "User-Agent" = "SETTDash/$Script:AppVersion" }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10

        $latestTag = $release.tag_name.TrimStart('v')
        $current = $null; $latest = $null
        if (-not [version]::TryParse($Script:AppVersion, [ref]$current)) { return }
        if (-not [version]::TryParse($latestTag, [ref]$latest)) { return }

        if ($latest -le $current) {
            # Also logged by Show-UpdateAppliedNotice path; keep wording aligned with popup text.
            Write-GuiLog "SETTDash is up to date (v$Script:AppVersion)" "OK"
            return
        }

        Write-GuiLog "Update available: v$latestTag (current v$Script:AppVersion)" "WARN"
        $asset = $release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
        if (-not $asset) { Write-GuiLog "No .exe asset found in latest release" "ERR"; return }

        if (-not (Show-UpdateConfirmDialog -CurrentVersion $Script:AppVersion -NewVersion $latestTag)) {
            Write-GuiLog "Update postponed by user" "INFO"
            return
        }

        Invoke-SelfUpdate -DownloadUrl $asset.browser_download_url -NewVersion $latestTag -ExpectedSize ([long]$asset.size)
    } catch {
        Write-GuiLog "Update check failed: $_" "WARN"
    }
}

# Shared XAML snippet used by both update popups: dark card with a custom
# title bar (matches Main\Layout.ps1 palette/typography) instead of the
# native Windows chrome. {0}=width {1}=title {2}=extra body XAML
function script:Get-UpdatePopupXaml {
    param([int]$Width, [string]$Title, [string]$BodyXaml, [bool]$ShowCloseButton = $true)
    $closeBtnXaml = ""
    if ($ShowCloseButton) {
        $closeBtnXaml = '<Button x:Name="btnDialogClose" Grid.Column="1" Content="&#xE8BB;" Width="40" Height="32" Background="Transparent" Foreground="#8B949E" FontFamily="Segoe MDL2 Assets" FontSize="10" BorderThickness="0" Cursor="Hand"><Button.Template><ControlTemplate TargetType="Button"><Border x:Name="b" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#DA3633"/><Setter Property="Foreground" Value="White"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Button.Template></Button>'
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
            <Setter Property="Background" Value="#1F6FEB"/>
            <Setter Property="Foreground" Value="White"/>
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
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#388BFD"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1158C7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DialogSecondaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#C9D1D9"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Height" Value="34"/>
            <Setter Property="MinWidth" Value="104"/>
            <Setter Property="Padding" Value="18,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#30363D"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                Padding="{TemplateBinding Padding}" MinWidth="{TemplateBinding MinWidth}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="#58A6FF"/>
                                <Setter Property="Foreground" Value="#58A6FF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border x:Name="rootBorder" Background="#0D1117" BorderBrush="#30363D" BorderThickness="1" CornerRadius="8">
        <Border.Effect>
            <DropShadowEffect Color="#000000" BlurRadius="22" ShadowDepth="4" Opacity="0.45"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Border x:Name="titleBar" Grid.Row="0" Background="#161B22" BorderBrush="#30363D" BorderThickness="0,0,0,1">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="$Title" Foreground="#E6EDF3" FontSize="12" FontWeight="SemiBold"
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

    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="8" Background="#132040">
                <TextBlock Text="&#xE895;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#58A6FF"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="Update Available" FontFamily="JetBrains Mono, Consolas" Foreground="#E6EDF3" FontSize="14" FontWeight="Bold"/>
                <TextBlock x:Name="txtVersions" FontFamily="JetBrains Mono, Consolas" Text="v$CurrentVersion &#8594; v$NewVersion" Foreground="#6E7681" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
        </StackPanel>
        <TextBlock Text="A new version of SETTDash is ready to install. Do you want to update now?"
                   Foreground="#C9D1D9" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnLater" Content="Later" Style="{StaticResource DialogSecondaryButtonStyle}" Margin="0,0,12,0"/>
            <Button x:Name="btnUpdate" Content="Update Now" Style="{StaticResource DialogPrimaryButtonStyle}"/>
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
    param([string]$DownloadUrl, [string]$NewVersion, [long]$ExpectedSize = 0)

    $currentExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $newExe = Join-Path $Script:TempDir "SETTDash_v$NewVersion.exe"

    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="8" Background="#132040">
                <TextBlock Text="&#xE896;" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="#58A6FF"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock x:Name="txtTitle" FontFamily="JetBrains Mono, Consolas" Text="Downloading update v$NewVersion" Foreground="#E6EDF3" FontSize="14" FontWeight="Bold"/>
                <TextBlock x:Name="txtStatus" FontFamily="JetBrains Mono, Consolas" Text="Connecting..." Foreground="#6E7681" FontSize="11" Margin="0,3,0,0"/>
            </StackPanel>
        </StackPanel>
        <Grid Height="8" Margin="0,2,0,0">
            <Border Background="#21262D" CornerRadius="4"/>
            <Border x:Name="progressFill" Background="#1F6FEB" CornerRadius="4" HorizontalAlignment="Stretch" RenderTransformOrigin="0,0.5">
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

    # Download state carried in ONE reference object (accessible from the async
    # event handler's closure); gauge/version/UI element refs are captured once.
    $dlState = [pscustomobject]@{ Attempt = 0; MaxAttempts = 3; Url = $DownloadUrl; Dest = $newExe }

    $wc = New-Object System.Net.WebClient
    $wc.add_DownloadProgressChanged({
        param($s, $e)
        $progressScale.ScaleX = $e.ProgressPercentage / 100
        $recvMB = [math]::Round($e.BytesReceived / 1MB, 1)
        $totalMB = [math]::Round($e.TotalBytesToReceive / 1MB, 1)
        $txtStatus.Text = "$($e.ProgressPercentage)% ($recvMB MB / $totalMB MB)"
    }.GetNewClosure())

    $wc.add_DownloadFileCompleted({
        param($s, $e)
        # Validate: PS 5.1/.NET FW sometimes drops the transfer mid-receive and still
        # raises "completed" without e.Error, leaving a truncated file behind.
        $reason = $null
        if ($e.Error) { $reason = $e.Error.Message }
        elseif ($ExpectedSize -gt 0) {
            $got = (Get-Item $dlState.Dest -ErrorAction SilentlyContinue).Length
            if ($got -ne $ExpectedSize) { $reason = "incomplete download ($got / $ExpectedSize bytes)" }
        }

        if ($reason) {
            $dlState.Attempt = $dlState.Attempt + 1
            if ($dlState.Attempt -lt $dlState.MaxAttempts) {
                Write-GuiLog "Attempt $($dlState.Attempt) failed ($reason), retrying [$($dlState.Attempt + 1)/$($dlState.MaxAttempts)]..." "WARN"
                $txtStatus.Text = "Retrying download ($($dlState.Attempt + 1)/$($dlState.MaxAttempts))..."
                Remove-Item $dlState.Dest -Force -ErrorAction SilentlyContinue
                $s.DownloadFileAsync([Uri]$dlState.Url, $dlState.Dest)
                return
            }
            Write-GuiLog "Update download failed after $($dlState.MaxAttempts) attempts: $reason" "ERR"
            $txtStatus.Text = "Download failed. Closing..."
            Start-Sleep -Milliseconds 1500
            $progressWin.Close()
            return
        }

        $progressScale.ScaleX = 1
        $txtTitle.Text = "Update downloaded"
        $txtStatus.Text = "Restarting SETTDash to apply v$NewVersion..."

        try {
            $markerPath = Join-Path $Script:TempDir "update_applied.txt"
            Set-Content -Path $markerPath -Value $NewVersion -Encoding UTF8 -Force

            $currentPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
            $updaterPath = Join-Path $Script:TempDir "SETTDash_Updater.ps1"
            $logPath = Join-Path $env:LOCALAPPDATA "SETTDash\Backups\updater.log"
            $updaterScript = @"
`$ErrorActionPreference = 'Stop'
New-Item -Path '$(Split-Path $logPath -Parent)' -ItemType Directory -Force | Out-Null
function Write-UpdLog { param(`$m) try { Add-Content -Path '$logPath' -Value ((Get-Date -Format 'HH:mm:ss') + ' ' + `$m) -Encoding UTF8 } catch {} }
try { Wait-Process -Id $currentPid -Timeout 15 } catch {}
Start-Sleep -Seconds 1
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
try { Start-Process -FilePath '$currentExe'; Write-UpdLog 'RELAUNCH OK' } catch { Write-UpdLog ('RELAUNCH FAILED: ' + `$_.Exception.Message) }
Remove-Item -Path '$newExe' -Force -ErrorAction SilentlyContinue
Remove-Item -Path '$updaterPath' -Force -ErrorAction SilentlyContinue
"@
            Set-Content -Path $updaterPath -Value $updaterScript -Encoding UTF8

            Start-Process -FilePath "powershell.exe" -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$updaterPath`""
            )
        } catch {
            Write-GuiLog "Self-update failed: $_" "ERR"
            $progressWin.Close()
            return
        }

        Start-Sleep -Milliseconds 1200
        $progressWin.Close()
        # Called before $Window.ShowDialog() during startup, so just terminate the
        # process outright rather than closing an unshown Window (Close() would throw).
        [System.Environment]::Exit(0)
    }.GetNewClosure())

    try {
        $wc.DownloadFileAsync([Uri]$DownloadUrl, $newExe)
    } catch {
        Write-GuiLog "Failed to start update download: $_" "ERR"
        return
    }

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
            if ($updatedVersion) { Write-GuiLog "Updated to v$updatedVersion successfully!" "OK" }
        } catch {}
        Remove-Item $markerPath -Force -ErrorAction SilentlyContinue
    }
}
#endregion
