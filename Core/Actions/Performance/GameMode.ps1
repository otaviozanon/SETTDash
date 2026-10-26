
# ================================================
#region PERFORMANCE - GAME MODE & GAME BAR
# ================================================
# Used by: Performance ("Apply Game Mode")
function Invoke-GameModeApply {
    Set-GuiProgress 10 "Configuring Game Mode..."
    Write-GuiLog "Configuring Game Mode..." "STEP"
    $settings = @(
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AllowAutoGameMode"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AutoGameModeEnabled"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="ShowStartupPanel"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="GamePanelStartupTipIndex"; Value=3; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="UseNexusForGameBarEnabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKToggleGameBar"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKMToggleGameBar"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKToggleRecording"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="VKMToggleRecording"; Value=0; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"; Value=2; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_HonorUserFSEBehaviorMode"; Value=1; Type="DWORD"}
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_DXGIHonorFSEWindowsCompatible"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $settings -Label "Game Mode"
    Write-GuiLog "Game Mode configured" "OK"
    Set-NavStatus "GameMode" $true
    Set-GuiProgress 0
}

# Used by: Performance ("Revert Game Mode")
function Invoke-GameModeRevert {
    Set-GuiProgress 10 "Reverting Game Mode settings to defaults..."
    Write-GuiLog "Reverting Game Mode settings to defaults..." "STEP"
    $settings = @(
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AllowAutoGameMode"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AutoGameModeEnabled"; Value=0; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="ShowStartupPanel"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="UseNexusForGameBarEnabled"; Value=1; Type="DWORD"}
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"; Value=1; Type="DWORD"}
    )
    Invoke-RegistryApply -Settings $settings -Label "Game Mode Revert"
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKToggleGameBar" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKMToggleGameBar" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKToggleRecording" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "VKMToggleRecording" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Game Bar hotkey overrides removed" "OK"
    } catch { }
    try {
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "GameDVR overrides removed" "OK"
    } catch { }
    Write-GuiLog "Game Mode reverted to defaults" "OK"
    Set-NavStatus "GameMode" $false
    Set-GuiProgress 0
}
#endregion
