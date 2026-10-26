# Build.ps1
# Concatena os arquivos modulares (Main/, Sidebar/, Core/) na ordem correta
# e gera o SETTDash.ps1 final (usado como entrada do ps2exe).
# NAO edite SETTDash.ps1 diretamente - ele e gerado por este script.

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Ordem de carregamento (dependencias devem vir antes de quem as usa):
#   1. Main/Window.ps1         - setup inicial, XAML, embedded programs, inicializacao da janela
#   2. Core/GuiHelpers.ps1     - helpers de GUI (log, progress, nav, cards, botoes)
#   3. Core/Actions.ps1        - funcoes Invoke-*/Get-* de acoes (apply/revert, cache cleaner, network, playbooks)
#   4. Core/GuiGauges.ps1      - geradores de metric bar / gauge circular (usados pela Home)
#   5. Core/InstallActions.ps1 - actions compartilhadas (Installers, AllInstallers, GpuSoftware, CPU)
#   6. Sidebar/Pages/*.ps1     - uma funcao Show-Page* por arquivo
#   7. Main/Startup.ps1        - wiring do sidebar e startup da aplicacao
$parts = @(
    "Main\Window.ps1",
    "Core\GuiHelpers.ps1",
    "Core\Actions.ps1",
    "Core\GuiGauges.ps1",
    "Core\InstallActions.ps1",
    "Sidebar\Pages\Home.ps1",
    "Sidebar\Pages\Installers.ps1",
    "Sidebar\Pages\AllInstallers.ps1",
    "Sidebar\Pages\GpuSoftware.ps1",
    "Sidebar\Pages\CPU.ps1",
    "Sidebar\Pages\Performance.ps1",
    "Sidebar\Pages\NetworkPrivacy.ps1",
    "Sidebar\Pages\SystemTweaksAll.ps1",
    "Sidebar\Pages\Windows.ps1",
    "Sidebar\Pages\Utilities.ps1",
    "Sidebar\Pages\WinShortcuts.ps1",
    "Sidebar\Pages\Playbooks.ps1",
    "Sidebar\Pages\All.ps1",
    "Main\Startup.ps1"
)

$output = foreach ($part in $parts) {
    $path = Join-Path $root $part
    if (-not (Test-Path $path)) { throw "Arquivo nao encontrado: $path" }
    Get-Content -Path $path -Encoding UTF8
}

$outFile = Join-Path $root "SETTDash.ps1"
$output | Set-Content -Path $outFile -Encoding UTF8

Write-Host "SETTDash.ps1 gerado com sucesso ($($output.Count) linhas)." -ForegroundColor Green
