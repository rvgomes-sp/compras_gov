param(
    [string]$Root = $PSScriptRoot,
    [string]$DataResultado = "",
    [ValidateRange(1,500)]
    [int]$TamanhoPagina = 500,
    [switch]$PermitirCoberturaParcial,
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DataResultado)) {
    $DataResultado = (Get-Date).Date.AddDays(-1).ToString('yyyy-MM-dd')
}

Write-Host "[1/3] Validacao estrutural"
& (Join-Path $Root "tests\Validar_Estrutura.ps1") -Root $Root

Write-Host "[2/3] Descoberta completa EVT007 D-1: $DataResultado"
& (Join-Path $Root "src\Descobrir_EVT007_D1.ps1") `
    -Root $Root `
    -DataResultado $DataResultado `
    -TamanhoPagina $TamanhoPagina `
    -TodasPaginas `
    -Reiniciar:$Reiniciar

Write-Host "[3/3] Consolidacao factual EVT007 D-1"
& (Join-Path $Root "src\Consolidar_EVT007_DadosAbertos.ps1") `
    -Root $Root `
    -DataResultado $DataResultado `
    -PermitirCoberturaParcial:$PermitirCoberturaParcial `
    -Reiniciar:$Reiniciar

Write-Host "[OK] Camada factual D-1 concluida."
Write-Host "[ATENCAO] Nenhuma base comercial foi gerada. Itens, CATSER/CATMAT, modalidade, objeto e origem da plataforma ainda exigem enriquecimento oficial."
