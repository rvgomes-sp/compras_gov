param(
    [string]$Root = $PSScriptRoot,
    [string]$DataResultado = "",
    [string]$DiscoveryRoot = "",
    [switch]$PermitirCoberturaParcial,
    [switch]$Reiniciar,
    [string]$CandidateCsv = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not [string]::IsNullOrWhiteSpace($CandidateCsv)) {
    throw "O fluxo por CandidateCsv foi desativado apos o HTTP 301 do nucleo PNCP. Execute a consolidacao factual diretamente das paginas D-1 preservadas."
}

Write-Host "[1/2] Validacao estrutural"
& (Join-Path $Root "tests\Validar_Estrutura.ps1") -Root $Root

Write-Host "[2/2] Consolidacao factual EVT007 D-1"
& (Join-Path $Root "src\Consolidar_EVT007_DadosAbertos.ps1") `
    -Root $Root `
    -DataResultado $DataResultado `
    -DiscoveryRoot $DiscoveryRoot `
    -PermitirCoberturaParcial:$PermitirCoberturaParcial `
    -Reiniciar:$Reiniciar

Write-Host "[OK] Camada factual D-1 concluida."
Write-Host "[ATENCAO] Nenhuma base comercial foi gerada. Itens, CATSER/CATMAT, modalidade, objeto e origem da plataforma ainda exigem enriquecimento oficial."
