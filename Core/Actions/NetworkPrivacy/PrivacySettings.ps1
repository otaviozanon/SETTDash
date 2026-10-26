
# ================================================
#region NETWORKPRIVACY - PRIVACY SETTINGS
# ================================================
# Used by: NetworkPrivacy ("Apply Privacy Settings")
function Invoke-PrivacyApply {
    Set-GuiProgress 10 "Applying privacy settings..."
    Write-GuiLog "Applying privacy settings..." "STEP"
    $priv = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo";Name="Enabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";Name="AllowCortana";Type="DWORD";Value=0}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo";Name="Enabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer";Name="HideRecentlyAddedApps";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent";Name="DisableThirdPartySuggestions";Type="DWORD";Value=1}
    )
    Invoke-RegistryApply -Settings $priv -Label "Privacy Protection"
    Write-GuiLog "Privacy settings applied" "OK"
    Set-NavStatus "Privacy" $true
    Set-GuiProgress 0
}

# Used by: NetworkPrivacy ("Revert Privacy")
function Invoke-PrivacyRevert {
    Set-GuiProgress 10 "Reverting privacy settings..."
    Write-GuiLog "Reverting privacy settings..." "STEP"
    $revert = @(
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name="Enabled"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name="Enabled"; Value=1; Type="DWORD"}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name="AllowCortana"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $revert -Label "Privacy Revert"
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecentlyAddedApps" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Cortana and advertising re-enabled" "OK"
    } catch { }
    Write-GuiLog "Privacy settings reverted" "OK"
    Set-NavStatus "Privacy" $false
    Set-GuiProgress 0
}
#endregion
