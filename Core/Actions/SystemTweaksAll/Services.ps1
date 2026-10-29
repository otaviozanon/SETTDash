
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
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\AppIDSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\AssignedAccessManagerSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BthAvctpSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BTAGService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\bthserv";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\brave";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\bravem";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CDPSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DiagTrack";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\dmwappushservice";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DevQueryBroker";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\diagsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DialogBlockingService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DiscordSystemHelper";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DisplayEnhancementService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\EFS";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\fhsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FoxitReaderUpdateService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\GoogleChromeElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedAccess";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\InventorySvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MessagingService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\AppVClient";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MsKeyboardFilter";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NetTcpPortSharing";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintDeviceConfigurationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Spooler";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintNotify";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintScanBrokerService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wercplsupport";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PcaSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RmSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TroubleshootingSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RemoteRegistry";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RemoteAccess";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ScDeviceEnum";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lmhosts";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\UpcElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\UevAgentService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wcncsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WerSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\whesvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpnService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WSAIFabricSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblAuthManager";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblGameSave";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XboxNetApiSvc";Name="Start";Type="DWORD";Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Services"
    Write-GuiLog "$($svc.Count) services configured" "OK"
    Set-NavStatus "Services" $true
    Set-GuiProgress 0
}

# Used by: SystemTweaksAll ("Revert Services")
function Invoke-ServicesRevert {
    Set-GuiProgress 10 "Restoring services to defaults..."
    Write-GuiLog "Restoring services to defaults..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TapiSrv"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache3.0.0.0"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpcMonSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SEMgrSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PNRPsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WEPHOSTSVC"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2psvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\p2pimsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PhoneSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Wecsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorDataService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensrSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\perceptionsimulation"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\StiSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\OneSyncSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WMPNetworkSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\icssvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DusmSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MapsBroker"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdate"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SensorService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\shpamsvc"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\svsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MSiSCSI"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CscService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ssh-agent"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\tzautoupdate"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NfsClnt"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wisvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\defragsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\autotimesvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\edgeupdatem"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MicrosoftEdgeElevationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ALG"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\QWAVE"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\IpxlatCfgSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedRealitySvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RetailDemo"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lltdsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TrkWks"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Fax"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SCardSvr"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name="Status"; Type="DWORD"; Value=1}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\AppIDSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\AssignedAccessManagerSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BthAvctpSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BTAGService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\bthserv"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\brave"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\bravem"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\CDPSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DiagTrack"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\dmwappushservice"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DevQueryBroker"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\diagsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DialogBlockingService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DiscordSystemHelper"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\DisplayEnhancementService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\EFS"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\fhsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FoxitReaderUpdateService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\GoogleChromeElevationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\SharedAccess"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\InventorySvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MessagingService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\AppVClient"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\MsKeyboardFilter"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\NetTcpPortSharing"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintDeviceConfigurationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Spooler"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintNotify"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintScanBrokerService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wercplsupport"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PcaSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RmSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\TroubleshootingSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RemoteRegistry"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RemoteAccess"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\ScDeviceEnum"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\lmhosts"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\UpcElevationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\UevAgentService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\wcncsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WerSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\FontCache"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\whesvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpnService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WSAIFabricSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblAuthManager"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblGameSave"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XboxNetApiSvc"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Restoring Services"
    Write-GuiLog "$($svc.Count) services restored to defaults" "OK"
    Set-NavStatus "Services" $false
    Set-GuiProgress 0
}
#endregion

#region Printer
function Enable-Printer {
    Set-GuiProgress 10 "Enabling Printer services..."
    Write-GuiLog "Enabling Printer services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Spooler"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintNotify"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintScanBrokerService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintDeviceConfigurationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Printer"
    Write-GuiLog "$($svc.Count) printer services enabled (reboot required)" "OK"
    Set-GuiProgress 0
}

function Disable-Printer {
    Set-GuiProgress 10 "Disabling Printer services..."
    Write-GuiLog "Disabling Printer services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\Spooler"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintNotify"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintScanBrokerService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\PrintDeviceConfigurationService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Printer"
    Write-GuiLog "$($svc.Count) printer services disabled (reboot required)" "OK"
    Set-GuiProgress 0
}
#endregion 

#region Notifications
function Enable-Notifications {
    Set-GuiProgress 10 "Enabling Notifications service..."
    Write-GuiLog "Enabling Notifications service..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpnService"; Name="Start"; Type="DWORD"; Value=2}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Notifications"
    Write-GuiLog "$($svc.Count) notification service enabled (reboot required)" "OK"
    Set-GuiProgress 0
}

function Disable-Notifications {
    Set-GuiProgress 10 "Disabling Notifications service..."
    Write-GuiLog "Disabling Notifications service..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\WpnService"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Notifications"
    Write-GuiLog "$($svc.Count) notification service disabled (reboot required)" "OK"
    Set-GuiProgress 0
}
#endregion

#region Bluetooth
function Enable-Bluetooth {
    Set-GuiProgress 10 "Enabling Bluetooth services..."
    Write-GuiLog "Enabling Bluetooth services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\bthserv"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BthAvctpSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BTAGService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RmSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Bluetooth"
    Write-GuiLog "$($svc.Count) bluetooth services enabled (reboot required)" "OK"
    Set-GuiProgress 0
}

function Disable-Bluetooth {
    Set-GuiProgress 10 "Disabling Bluetooth services..."
    Write-GuiLog "Disabling Bluetooth services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\bthserv"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BthAvctpSvc"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\BTAGService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\RmSvc"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Bluetooth"
    Write-GuiLog "$($svc.Count) bluetooth services disabled (reboot required)" "OK"
    Set-GuiProgress 0
}
#endregion

#region Enable Game Pass
function Enable-GamePass {
    Set-GuiProgress 10 "Enabling Game Pass / Xbox services..."
    Write-GuiLog "Enabling Game Pass / Xbox services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblAuthManager"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblGameSave"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XboxNetApiSvc"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Game Pass"
    Write-GuiLog "$($svc.Count) Game Pass services enabled (reboot required)" "OK"
    Set-GuiProgress 0
}

function Disable-GamePass {
    Set-GuiProgress 10 "Disabling Game Pass / Xbox services..."
    Write-GuiLog "Disabling Game Pass / Xbox services..." "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblAuthManager"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XblGameSave"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\ControlSet001\Services\XboxNetApiSvc"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Game Pass"
    Write-GuiLog "$($svc.Count) Game Pass services disabled (reboot required)" "OK"
    Set-GuiProgress 0
}
#endregion