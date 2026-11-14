
# ================================================
#region CONFIRM DIALOG
# ================================================
# Themed confirmation used only before irreversible actions (Full Cleanup, delete selected startup
# items/tasks, registry fix, Optimize All). Reuses the update popup chrome (Get-UpdatePopupXaml /
# Register-UpdatePopupDrag) so it matches the active theme instead of a native MessageBox, which
# appears nowhere else in the app.
function Show-GuiConfirm {
    param(
        [string]$Title = (T "Confirm"),
        [string]$Message,
        [string]$ConfirmText = (T "Confirm"),
        [string]$CancelText = (T "Cancel"),
        [string]$Icon = "&#xE7BA;"
    )
    # XAML text nodes: escape so a message containing & or < cannot break the popup.
    $enc = { param($s) [System.Security.SecurityElement]::Escape([string]$s) }
    $t = Get-CurrentThemeColors
    $body = @"
        <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <Border Width="40" Height="40" CornerRadius="$($t.CornerRadius)" Background="$($t.HoverBg)">
                <TextBlock Text="$Icon" FontFamily="Segoe MDL2 Assets" FontSize="18" Foreground="$($t.Accent)"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="$(& $enc $Title)" FontFamily="JetBrains Mono, Consolas" Foreground="$($t.TextPrimary)" FontSize="14" FontWeight="Bold"/>
            </StackPanel>
        </StackPanel>
        <TextBlock Text="$(& $enc $Message)" Foreground="$($t.TextSecondary)" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,22"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnCancel" Content="$(& $enc $CancelText)" Style="{StaticResource DialogSecondaryButtonStyle}" Margin="0,0,12,0"/>
            <Button x:Name="btnOk" Content="$(& $enc $ConfirmText)" Style="{StaticResource DialogPrimaryButtonStyle}"/>
        </StackPanel>
"@
    [xml]$xaml = Get-UpdatePopupXaml -Width 440 -Title "SETTDash" -BodyXaml $body
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $dlg = [Windows.Markup.XamlReader]::Load($reader)

    $titleBar = $dlg.FindName("titleBar")
    $btnClose = $dlg.FindName("btnDialogClose")
    $btnCancel = $dlg.FindName("btnCancel")
    $btnOk = $dlg.FindName("btnOk")
    Register-UpdatePopupDrag -PopupWindow $dlg -TitleBar $titleBar

    $state = [pscustomobject]@{ Confirmed = $false }
    $btnOk.Add_Click({ $state.Confirmed = $true; $dlg.Close() }.GetNewClosure())
    $btnCancel.Add_Click({ $dlg.Close() }.GetNewClosure())
    $btnClose.Add_Click({ $dlg.Close() }.GetNewClosure())

    $dlg.ShowDialog() | Out-Null
    return $state.Confirmed
}
#endregion
