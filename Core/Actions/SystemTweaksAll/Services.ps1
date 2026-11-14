
# ================================================
#region SYSTEMTWEAKSALL - SERVICE CONFIGURATION
# ================================================
# Used by: SystemTweaksAll ("Disable Services")
function Invoke-ServicesApply {
    Set-GuiProgress 10 "Configuring services..."
    Write-GuiLog (T "Configuring services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\TapiSrv";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FontCache3.0.0.0";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WpcMonSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SEMgrSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PNRPsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WEPHOSTSVC";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\p2psvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\p2pimsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PhoneSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Wecsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SensorDataService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SensrSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\perceptionsimulation";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\StiSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WMPNetworkSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\icssvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DusmSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MapsBroker";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SensorService";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\shpamsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\svsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MSiSCSI";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CscService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\ssh-agent";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NfsClnt";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\wisvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\defragsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\autotimesvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\ALG";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\QWAVE";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\IpxlatCfgSvc";Name="Start";Type="DWORD";Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedRealitySvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RetailDemo";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lltdsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\TrkWks";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Fax";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SCardSvr";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration";Name="Status";Type="DWORD";Value=0}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AssignedAccessManagerSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BthAvctpSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BTAGService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\bthserv";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\brave";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\bravem";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevQueryBroker";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\diagsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DialogBlockingService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DiscordSystemHelper";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DisplayEnhancementService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\EFS";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\fhsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FoxitReaderUpdateService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\GoogleChromeElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\InventorySvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MessagingService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AppVClient";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MsKeyboardFilter";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetTcpPortSharing";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintDeviceConfigurationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Spooler";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintNotify";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintScanBrokerService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\wercplsupport";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PcaSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RmSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\TroubleshootingSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RemoteRegistry";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\ScDeviceEnum";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lmhosts";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UpcElevationService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UevAgentService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\wcncsvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FontCache";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\whesvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WpnService";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WSAIFabricSvc";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblAuthManager";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave";Name="Start";Type="DWORD";Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc";Name="Start";Type="DWORD";Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Services"
    Write-GuiLog ((T "{0} services configured") -f $svc.Count) "OK"
    Set-NavStatus "Services" $true
    Set-GuiProgress 0
}

# Used by: SystemTweaksAll ("Revert Services")
function Invoke-ServicesRevert {
    Set-GuiProgress 10 "Restoring services to defaults..."
    Write-GuiLog (T "Restoring services to defaults...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\TapiSrv"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FontCache3.0.0.0"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WpcMonSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SEMgrSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PNRPsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WEPHOSTSVC"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\p2psvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\p2pimsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PhoneSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Wecsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SensorDataService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SensrSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\perceptionsimulation"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\StiSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\OneSyncSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UnistoreSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WMPNetworkSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\icssvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DusmSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MapsBroker"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SensorService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\shpamsvc"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\svsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MSiSCSI"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CscService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\ssh-agent"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NfsClnt"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\wisvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\defragsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\autotimesvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BcastDVRUserService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DeviceAssociationBrokerSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\ALG"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\QWAVE"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\IpxlatCfgSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedRealitySvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RetailDemo"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lltdsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\TrkWks"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Fax"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SCardSvr"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name="Status"; Type="DWORD"; Value=1}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AssignedAccessManagerSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BthAvctpSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BTAGService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\bthserv"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\brave"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\bravem"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\CDPSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DevQueryBroker"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\diagsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DialogBlockingService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DiscordSystemHelper"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\DisplayEnhancementService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\EFS"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\fhsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FoxitReaderUpdateService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\GoogleChromeElevationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\InventorySvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MessagingService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\AppVClient"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\MsKeyboardFilter"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetTcpPortSharing"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintDeviceConfigurationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Spooler"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintNotify"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintScanBrokerService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\wercplsupport"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PcaSvc"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RmSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\TroubleshootingSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RemoteRegistry"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\ScDeviceEnum"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\lmhosts"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UpcElevationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\UevAgentService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\wcncsvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\FontCache"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\whesvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WpnService"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WSAIFabricSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblAuthManager"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Restoring Services"
    Write-GuiLog ((T "{0} services restored to defaults") -f $svc.Count) "OK"
    Set-NavStatus "Services" $false
    Set-GuiProgress 0
}
#endregion

#region Printer
function Enable-Printer {
    Set-GuiProgress 10 "Enabling Printer services..."
    Write-GuiLog (T "Enabling Printer services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Spooler"; Name="Start"; Type="DWORD"; Value=2}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintNotify"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintScanBrokerService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintDeviceConfigurationService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Printer"
    Write-GuiLog ((T "{0} printer services enabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}

function Disable-Printer {
    Set-GuiProgress 10 "Disabling Printer services..."
    Write-GuiLog (T "Disabling Printer services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Spooler"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintNotify"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintScanBrokerService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintDeviceConfigurationService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Printer"
    Write-GuiLog ((T "{0} printer services disabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}
#endregion 

#region Notifications
function Enable-Notifications {
    Set-GuiProgress 10 "Enabling Notifications service..."
    Write-GuiLog (T "Enabling Notifications service...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WpnService"; Name="Start"; Type="DWORD"; Value=2}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Notifications"
    Write-GuiLog ((T "{0} notification service enabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}

function Disable-Notifications {
    Set-GuiProgress 10 "Disabling Notifications service..."
    Write-GuiLog (T "Disabling Notifications service...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\WpnService"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Notifications"
    Write-GuiLog ((T "{0} notification service disabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}
#endregion

#region Bluetooth
function Enable-Bluetooth {
    Set-GuiProgress 10 "Enabling Bluetooth services..."
    Write-GuiLog (T "Enabling Bluetooth services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\bthserv"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BthAvctpSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BTAGService"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RmSvc"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Bluetooth"
    Write-GuiLog ((T "{0} bluetooth services enabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}

function Disable-Bluetooth {
    Set-GuiProgress 10 "Disabling Bluetooth services..."
    Write-GuiLog (T "Disabling Bluetooth services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\bthserv"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BthAvctpSvc"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BTAGService"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\RmSvc"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\BluetoothUserService"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Bluetooth"
    Write-GuiLog ((T "{0} bluetooth services disabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}
#endregion

#region Enable Game Pass
function Enable-GamePass {
    Set-GuiProgress 10 "Enabling Game Pass / Xbox services..."
    Write-GuiLog (T "Enabling Game Pass / Xbox services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblAuthManager"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave"; Name="Start"; Type="DWORD"; Value=3}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc"; Name="Start"; Type="DWORD"; Value=3}
    )
    Invoke-RegistryApply -Settings $svc -Label "Enabling Game Pass"
    Write-GuiLog ((T "{0} Game Pass services enabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}

function Disable-GamePass {
    Set-GuiProgress 10 "Disabling Game Pass / Xbox services..."
    Write-GuiLog (T "Disabling Game Pass / Xbox services...") "STEP"
    $svc = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblAuthManager"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave"; Name="Start"; Type="DWORD"; Value=4}
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc"; Name="Start"; Type="DWORD"; Value=4}
    )
    Invoke-RegistryApply -Settings $svc -Label "Disabling Game Pass"
    Write-GuiLog ((T "{0} Game Pass services disabled (reboot required)") -f $svc.Count) "OK"
    Set-GuiProgress 0
}
#endregion