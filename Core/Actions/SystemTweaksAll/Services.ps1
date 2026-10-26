
# ================================================
#region SYSTEMTWEAKSALL - SERVICE CONFIGURATION
# ================================================
# Used by: SystemTweaksAll ("Disable Services")
function Invoke-ServicesApply {
    Set-GuiProgress 10 "Configuring services..."
    Write-GuiLog "Configuring services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TapiSrv";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2psvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Wecsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorDataService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensrSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\StiSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\icssvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DusmSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MapsBroker";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdate";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorService";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\shpamsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\svsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CscService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ssh-agent";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NfsClnt";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wisvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\defragsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\autotimesvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ALG";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\QWAVE";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RetailDemo";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lltdsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TrkWks";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Fax";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SCardSvr";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration";Name="Status";Type="DWORD";Value=0}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Services"
    Write-GuiLog "$($svc.Count) services configured" "OK"
    Set-NavStatus "Services" $true
    Set-GuiProgress 0
}

# Used by: SystemTweaksAll ("Revert Services")
function Invoke-ServicesRevert {
    Set-GuiProgress 10 "Re-enabling services to defaults..."
    Write-GuiLog "Re-enabling services to defaults..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TapiSrv"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2psvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Wecsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorDataService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensrSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\StiSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\icssvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DusmSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MapsBroker"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdate"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\shpamsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\svsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CscService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ssh-agent"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NfsClnt"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wisvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\defragsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\autotimesvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ALG"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\QWAVE"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RetailDemo"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lltdsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TrkWks"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Fax"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SCardSvr"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name="Status"; Type="DWORD"; Value=1}
    )
    Invoke-RegistryApply -Settings $svc -Label "Re-enabling Services"
    Write-GuiLog "$($svc.Count) services restored to Automatic" "OK"
    Set-NavStatus "Services" $false
    Set-GuiProgress 0
}
#endregion
