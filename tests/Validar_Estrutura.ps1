param([string]$Root = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$apiPath = Join-Path $Root "config\api\evt007_manual_2_5.json"
$execPath = Join-Path $Root "config\execucao\teste_d1.json"
$collectorPath = Join-Path $Root "src\Coletar_EVT007.ps1"

foreach ($path in @($apiPath, $execPath, $collectorPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio ausente: $path" }
}

$api = Get-Content -LiteralPath $apiPath -Raw -Encoding UTF8 | ConvertFrom-Json
$exec = Get-Content -LiteralPath $execPath -Raw -Encoding UTF8 | ConvertFrom-Json
$collector = Get-Content -LiteralPath $collectorPath -Raw -Encoding UTF8

if ($exec.dataResultadoInicial -ne $exec.dataResultadoFinal) {
    throw "O teste inicial deve usar exatamente um dia de dataResultado."
}
if (@($exec.modalidadeIdPermitida) -contains 6) {
    throw "A modalidade 6 nao pode estar na lista permitida."
}
if (-not (@($exec.modalidadeIdExcluida) -contains 6)) {
    throw "A modalidade 6 deve estar explicitamente excluida."
}
if ($exec.executarD2 -or $exec.permitirJanelaSuperior) {
    throw "D-2 e janelas superiores devem permanecer desativados no primeiro teste."
}
foreach ($campo in @('dataResultado','dataInclusao','niFornecedor','nomeRazaoSocialFornecedor','valorTotalHomologado')) {
    if (-not (@($api.camposEvento) -contains $campo)) { throw "Campo oficial ausente da configuracao: $campo" }
}
foreach ($trecho in @('dataResultado','logManutencaoDataInclusao','categoriaLogManutencao','usuarioNome')) {
    if ($collector -notmatch [regex]::Escape($trecho)) { throw "Coletor nao referencia o campo oficial obrigatorio: $trecho" }
}
if ($collector -match 'DiscoveryDays|result-days|90\s*dias|120\s*dias') {
    throw "O coletor contem vestigio de janela historica proibida."
}

Write-Host "[OK] Estrutura validada."
Write-Host "[OK] EVT007 usa dataResultado."
Write-Host "[OK] Modalidade 6 excluida."
Write-Host "[OK] D-2 e janelas superiores desativados."

