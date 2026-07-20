param([string]$Root = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$apiPath = Join-Path $Root "config\api\evt007_manual_2_5.json"
$execPath = Join-Path $Root "config\execucao\teste_d1.json"
$collectorPath = Join-Path $Root "src\Coletar_EVT007.ps1"
$discoveryConfigPath = Join-Path $Root "config\api\descoberta_comprasgov_dados_abertos.json"
$discoveryPath = Join-Path $Root "src\Descobrir_EVT007_D1.ps1"
$catalogSourcePath = Join-Path $Root "docs\catalogo_compras_gov\fontes\catser_20260718.csv"
$catalogTablePath = Join-Path $Root "config\comercial\tabela_servicos_20260718.csv"
$catalogRuntimePath = Join-Path $Root "config\comercial\catalogo_servicos.json"
$qualifierPath = Join-Path $Root "src\Qualificar_EVT007.ps1"
$importadorV2Path = Join-Path $Root "Importar_Candidatos_V2.ps1"
$candidatosV2Path = Join-Path $Root "data\candidatos\candidatos_evt007.csv"

foreach ($path in @($apiPath, $execPath, $collectorPath, $discoveryConfigPath, $discoveryPath, $catalogSourcePath, $catalogTablePath, $catalogRuntimePath, $qualifierPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio ausente: $path" }
}

$api = Get-Content -LiteralPath $apiPath -Raw -Encoding UTF8 | ConvertFrom-Json
$exec = Get-Content -LiteralPath $execPath -Raw -Encoding UTF8 | ConvertFrom-Json
$collector = Get-Content -LiteralPath $collectorPath -Raw -Encoding UTF8
$discoveryConfig = Get-Content -LiteralPath $discoveryConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$discovery = Get-Content -LiteralPath $discoveryPath -Raw -Encoding UTF8
$qualifier = Get-Content -LiteralPath $qualifierPath -Raw -Encoding UTF8

if ($exec.dataResultadoInicial -ne $exec.dataResultadoFinal) {
    throw "O teste inicial deve usar exatamente um dia de dataResultado."
}
if ($null -eq $exec.PSObject.Properties['filtrarModalidade'] -or [bool]$exec.filtrarModalidade) {
    throw "O EVT007 D-1 nao pode aplicar filtro de modalidade."
}
if (@($exec.modalidadeIdPermitida).Count -ne 0 -or @($exec.modalidadeIdExcluida).Count -ne 0) {
    throw "As listas de modalidade devem permanecer vazias quando o filtro esta desativado."
}
if ($collector -notmatch '\$filtrarModalidade\s+-and') {
    throw "O coletor deve condicionar qualquer filtro de modalidade a filtrarModalidade."
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
if (Test-Path -LiteralPath $importadorV2Path) {
    throw "Contaminacao detectada: importador de candidatos do V2 presente."
}
if (Test-Path -LiteralPath $candidatosV2Path) {
    throw "Contaminacao detectada: CSV de candidatos do V2 presente."
}
if ($collector -match 'candidatos_evt007\.csv') {
    throw "O coletor nao pode possuir caminho padrao para candidatos herdados."
}
if ([string]$discoveryConfig.baseUrl -ne 'https://dadosabertos.compras.gov.br') {
    throw "Fonte de descoberta diferente do Dados Abertos oficial do Compras.gov."
}
if ([string]$discoveryConfig.endpoint -ne '/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133') {
    throw "Endpoint oficial de resultados de itens nao confere."
}
if ([string]$discoveryConfig.parametrosTemporais.inicial -ne 'dataResultadoPncpInicial' -or [string]$discoveryConfig.parametrosTemporais.final -ne 'dataResultadoPncpFinal') {
    throw "Parametros temporais oficiais da descoberta nao conferem."
}
foreach ($trecho in @('dataResultadoPncpInicial','dataResultadoPncpFinal','numeroControlePNCPCompra','candidatos_tecnicos_PARCIAL.csv')) {
    if ($discovery -notmatch [regex]::Escape($trecho)) { throw "Descoberta nao referencia o elemento obrigatorio: $trecho" }
}
if ($discovery -match 'contratacoes/publicacao|dataPublicacaoPncp|Importar_Candidatos_V2|candidatos_evt007\.csv') {
    throw "Descoberta contem fallback ou fonte proibida."
}
$catalogRows = @(Import-Csv -LiteralPath $catalogTablePath -Delimiter ';' -Encoding UTF8)
if ($catalogRows.Count -ne 3095) {
    throw "A tabela CATSER deve conter exatamente 3095 servicos da referencia 2026-07-18. Encontrados: $($catalogRows.Count)"
}
if (@($catalogRows | Where-Object { $_.statusServico -eq 'True' }).Count -ne 3013) {
    throw "A contagem de servicos ativos do CATSER nao confere."
}
if (@($catalogRows | Where-Object { $_.gsbAtivoMotor -eq 'True' -and $_.statusServico -ne 'True' }).Count -ne 0) {
    throw "Servico CATSER inativo nao pode estar ativo no motor."
}
foreach ($codigo in @('8729','14397','5380')) {
    $registro = @($catalogRows | Where-Object { [string]$_.codigoServico -eq $codigo })
    if ($registro.Count -ne 1 -or [string]$registro[0].gsbStatus -ne 'APROVADO') {
        throw "Codigo essencial de mao de obra ausente ou nao aprovado: $codigo"
    }
}
foreach ($trecho in @('CATMAT_NAO_APLICAVEL','ehServicoCatser','materialOuServico')) {
    if ($qualifier -notmatch [regex]::Escape($trecho)) { throw "Qualificador nao separa CATMAT de CATSER: $trecho" }
}

Write-Host "[OK] Estrutura validada."
Write-Host "[OK] EVT007 usa dataResultado."
Write-Host "[OK] Nenhuma modalidade excluida; Pregao Eletronico permanece no EVT007."
Write-Host "[OK] D-2 e janelas superiores desativados."
Write-Host "[OK] Nenhum candidato ou importador do V2 esta ativo."
Write-Host "[OK] Descoberta D-1 usa o endpoint oficial de resultados do Dados Abertos Compras.gov."
Write-Host "[OK] CATSER 2026-07-18 validado: 3095 servicos; CATMAT separado."
