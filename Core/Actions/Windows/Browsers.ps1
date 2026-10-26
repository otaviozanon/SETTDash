
# ================================================
#region WINDOWS - BROWSER TWEAKS
# ================================================
# Used by: Windows ("Optimize Brave")
function Invoke-BraveTweaks {
    Set-GuiProgress 10 "Optimizing Brave..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveRewardsDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveWalletDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveVPNDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\BraveSoftware\Brave";Name="BraveAIChatEnabled";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $reg -Label "Brave Tweaks"
    Write-GuiLog "Brave optimized" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Optimize Chrome")
function Invoke-ChromeTweaks {
    Set-GuiProgress 10 "Optimizing Chrome..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\Google\Chrome";Name="SearchSuggestEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Google\Chrome";Name="PromotionalTabsEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Google\Chrome";Name="MetricsReportingEnabled";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $reg -Label "Chrome Tweaks"
    Write-GuiLog "Chrome optimized" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Optimize Edge")
function Invoke-EdgeTweaks {
    Set-GuiProgress 10 "Optimizing Edge..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="SyncDisabled";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="WalletEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="HubsSidebarEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="WebWidgetEnabled";Type="DWORD";Value=0}
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge";Name="HideFirstRunExperience";Type="DWORD";Value=1}
    )
    Invoke-RegistryApply -Settings $reg -Label "Edge Tweaks"
    Write-GuiLog "Edge optimized" "OK"
    Set-GuiProgress 0
}

# Used by: Windows ("Optimize Firefox")
function Invoke-FirefoxTweaks {
    Set-GuiProgress 10 "Optimizing Firefox..."
    $reg = @(
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="DisableTelemetry";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="DisablePocket";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="DisableFirefoxStudies";Type="DWORD";Value=1}
        @{Path="HKLM:\SOFTWARE\Policies\Mozilla\Firefox";Name="SearchSuggestEnabled";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $reg -Label "Firefox Tweaks"
    Write-GuiLog "Firefox optimized" "OK"
    Set-GuiProgress 0
}
#endregion
