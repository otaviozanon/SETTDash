
# ================================================
#region NETWORKPRIVACY - INTEGRATION KEYS CLEANUP
# ================================================
# Used by: NetworkPrivacy ("Clean Integrations")
function Invoke-IntegrationsApply {
    Set-GuiProgress 10 "Cleaning integration keys..."
    Write-GuiLog "Cleaning integration keys..." "STEP"
    $Keys = @(
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "Registry::HKEY_CLASSES_ROOT\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
    )
    $removed = 0
    foreach ($k in $Keys) {
        if (Test-Path $k) { try { Remove-Item -Path $k -Recurse -Force -ErrorAction Stop; $removed++ } catch { } }
    }
    Write-GuiLog "Integration cleanup: $removed / $($Keys.Count) keys removed" "OK"
    Set-GuiProgress 0
}

# Used by: NetworkPrivacy ("Revert Integrations")
function Invoke-IntegrationsRevert {
    Set-GuiProgress 50
    Write-GuiLog "Integration keys cannot be restored - they were permanently removed" "WARN"
    Set-GuiProgress 0
}
#endregion
