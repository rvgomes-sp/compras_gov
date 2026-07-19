param(
    [string]$Root = $PSScriptRoot,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$CandidateCsv,
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "[1/3] Validacao estrutural"
& (Join-Path $Root "tests\Validar_Estrutura.ps1") -Root $Root

Write-Host "[2/3] Coleta EVT007 D-1"
& (Join-Path $Root "src\Coletar_EVT007.ps1") -Root $Root -CandidateCsv $CandidateCsv -Reiniciar:$Reiniciar

$exec = Get-Content -LiteralPath (Join-Path $Root "config\execucao\teste_d1.json") -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "[3/3] Qualificacao comercial"
& (Join-Path $Root "src\Qualificar_EVT007.ps1") -Root $Root -DataResultado ([string]$exec.dataResultadoInicial)

Write-Host "[OK] Rodada D-1 concluida."
Write-Host "[ATENCAO] A cobertura nacional depende da lista de candidatos utilizada."
