param(
    [string]$Root = $PSScriptRoot,
    [string]$DataResultado = "",
    [string]$DiscoveryRoot = "",
    [switch]$PermitirCoberturaParcial,
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DataResultado)) {
    $DataResultado = (Get-Date).Date.AddDays(-1).ToString('yyyy-MM-dd')
}

& (Join-Path $Root "src\Consolidar_EVT007_DadosAbertos.ps1") `
    -Root $Root `
    -DataResultado $DataResultado `
    -DiscoveryRoot $DiscoveryRoot `
    -PermitirCoberturaParcial:$PermitirCoberturaParcial `
    -Reiniciar:$Reiniciar
