
# ================================================
#region NETWORKPRIVACY - TCP & QoS OPTIMIZATION
# ================================================
# Used by: NetworkPrivacy ("Apply Optimization")
function Invoke-InternetOptimize {
    Set-GuiProgress 10 "Starting Internet optimization..."
    Clear-GuiLog
    try {
        netsh int tcp set global autotuning=disabled | Out-Null
        Write-GuiLog "TCP autotuning disabled" "OK"
        $reg = @(
            @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"; Name="FastSendDatagramThreshold"; Type="DWORD"; Value=64000}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Version"; Type="String"; Value="1.0"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Application Name"; Type="String"; Value="VALORANT.exe"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Protocol"; Type="String"; Value="*"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="DSCP Value"; Type="DWORD"; Value=46}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"; Name="Throttle Rate"; Type="DWORD"; Value=-1}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Version"; Type="String"; Value="1.0"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Application Name"; Type="String"; Value="csgo.exe"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Protocol"; Type="String"; Value="*"}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="DSCP Value"; Type="DWORD"; Value=46}
            @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"; Name="Throttle Rate"; Type="DWORD"; Value=-1}
        )
        Invoke-RegistryApply -Settings $reg -Label "Internet QoS"
        Write-GuiLog "Internet optimization completed!" "OK"
    } catch { Write-GuiLog "Internet optimization failed: $_" "ERR" }
    Set-GuiProgress 0
}

# Used by: NetworkPrivacy ("Revert Internet")
function Invoke-InternetRevert {
    Write-GuiLog "Reverting internet optimizations..." "STEP"
    Set-GuiProgress 10 "Restoring TCP autotuning..."
    try {
        netsh int tcp set global autotuning=normal | Out-Null
        Write-GuiLog "TCP autotuning restored to normal" "OK"
    } catch { Write-GuiLog "Failed to restore TCP autotuning: $_" "ERR" }
    Set-GuiProgress 40 "Removing FastSendDatagramThreshold..."
    try {
        $afdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        Remove-ItemProperty -Path $afdPath -Name "FastSendDatagramThreshold" -Force -ErrorAction SilentlyContinue
        Write-GuiLog "FastSendDatagramThreshold removed" "OK"
    } catch { Write-GuiLog "Failed to remove FastSendDatagramThreshold: $_" "ERR" }
    Set-GuiProgress 70 "Removing QoS policies..."
    try {
        $qosValorant = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\ValorantPolicy"
        if (Test-Path $qosValorant) { Remove-Item -Path $qosValorant -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "Valorant QoS policy removed" "OK" }
        else { Write-GuiLog "Valorant QoS policy not found" "INFO" }
    } catch { Write-GuiLog "Failed to remove Valorant QoS: $_" "ERR" }
    try {
        $qosCSGO = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\CSGOPolicy"
        if (Test-Path $qosCSGO) { Remove-Item -Path $qosCSGO -Recurse -Force -ErrorAction SilentlyContinue; Write-GuiLog "CSGO QoS policy removed" "OK" }
        else { Write-GuiLog "CSGO QoS policy not found" "INFO" }
    } catch { Write-GuiLog "Failed to remove CSGO QoS: $_" "ERR" }
    Set-GuiProgress 0
    Write-GuiLog "Internet optimizations reverted" "OK"
}
#endregion
