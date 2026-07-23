param([string]$Root = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$paths = [ordered]@{
    exec = Join-Path $Root "config\execucao\evt007_diario.json"
    discoveryConfig = Join-Path $Root "config\api\descoberta_comprasgov_dados_abertos.json"
    factualConfig = Join-Path $Root "config\api\factual_evt007_dados_abertos.json"
    discovery = Join-Path $Root "src\Descobrir_EVT007_D1.ps1"
    consolidator = Join-Path $Root "src\Consolidar_EVT007_DadosAbertos.ps1"
    executor = Join-Path $Root "Executar_EVT007_D1.ps1"
    collector = Join-Path $Root "src\Coletar_EVT007.ps1"
    qualifier = Join-Path $Root "src\Qualificar_EVT007.ps1"
    catalogSource = Join-Path $Root "docs\catalogo_compras_gov\fontes\catser_20260718.csv"
    catalogRuntime = Join-Path $Root "config\comercial\catalogo_servicos.json"
    governance = Join-Path $Root "config\governanca\architecture_governance.json"
    eventMap = Join-Path $Root "config\governanca\event_data_map.json"
    manual = Join-Path $Root "docs\pncp_v2.5\manual\manual_integracao_pncp_v2.5.html"
    openapi = Join-Path $Root "docs\pncp_v2.5\openapi\api-docs.json"
}

foreach ($path in $paths.Values) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio ausente: $path" }
}

$exec = Get-Content -LiteralPath $paths.exec -Raw -Encoding UTF8 | ConvertFrom-Json
$discoveryConfig = Get-Content -LiteralPath $paths.discoveryConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$factualConfig = Get-Content -LiteralPath $paths.factualConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$governance = Get-Content -LiteralPath $paths.governance -Raw -Encoding UTF8 | ConvertFrom-Json
$eventMap = Get-Content -LiteralPath $paths.eventMap -Raw -Encoding UTF8 | ConvertFrom-Json
$discovery = Get-Content -LiteralPath $paths.discovery -Raw -Encoding UTF8
$consolidator = Get-Content -LiteralPath $paths.consolidator -Raw -Encoding UTF8
$executor = Get-Content -LiteralPath $paths.executor -Raw -Encoding UTF8
$collector = Get-Content -LiteralPath $paths.collector -Raw -Encoding UTF8
$qualifier = Get-Content -LiteralPath $paths.qualifier -Raw -Encoding UTF8

if ([string]$exec.modoDataResultado -ne 'PARAMETRO_OU_D1_LOCAL') {
    throw "A execucao diaria deve aceitar data explicita ou calcular D-1 local."
}
if ($null -eq $exec.PSObject.Properties['filtrarModalidade'] -or [bool]$exec.filtrarModalidade) {
    throw "O EVT007 nao pode aplicar filtro de modalidade."
}
if (@($exec.modalidadeIdPermitida).Count -ne 0 -or @($exec.modalidadeIdExcluida).Count -ne 0) {
    throw "Listas de modalidade devem permanecer vazias."
}
if ($exec.executarD2 -or $exec.permitirJanelaSuperior) {
    throw "D-2 e janelas superiores devem permanecer desativados."
}
if ([bool]$exec.qualificacaoComercialAutomatica) {
    throw "Qualificacao comercial automatica deve permanecer bloqueada."
}

if ([string]$discoveryConfig.baseUrl -ne 'https://dadosabertos.compras.gov.br') {
    throw "Fonte de descoberta diferente do Dados Abertos oficial do Compras.gov."
}
if ([string]$discoveryConfig.endpoint -ne '/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133') {
    throw "Endpoint de resultados de itens nao confere."
}
if ([string]$discoveryConfig.parametrosTemporais.inicial -ne 'dataResultadoPncpInicial' -or [string]$discoveryConfig.parametrosTemporais.final -ne 'dataResultadoPncpFinal') {
    throw "Parametros temporais da descoberta nao conferem."
}
foreach ($trecho in @('dataResultadoPncpInicial','dataResultadoPncpFinal','numeroControlePNCPCompra','candidatos_tecnicos_PARCIAL.csv')) {
    if ($discovery -notmatch [regex]::Escape($trecho)) { throw "Descoberta nao referencia: $trecho" }
}
if ($discovery -match 'contratacoes/publicacao|dataPublicacaoPncp|Importar_Candidatos_V2|candidatos_evt007\.csv') {
    throw "Descoberta contem fallback ou fonte proibida."
}

if ([string]$factualConfig.campoTemporalEvento -ne 'dataResultadoPncp' -or [string]$factualConfig.campoTemporalInclusao -ne 'dataInclusaoPncp') {
    throw "Campos temporais da camada factual nao conferem."
}
foreach ($campo in @('idCompraItem','idCompra','idContratacaoPNCP','numeroItemPncp','sequencialResultado','niFornecedor','nomeRazaoSocialFornecedor','valorTotalHomologado','dataInclusaoPncp','dataCancelamentoPncp','dataResultadoPncp','numeroControlePNCPCompra','orgaoEntidadeCnpj')) {
    if (-not (@($factualConfig.camposOficiaisResultado) -contains $campo)) { throw "Campo oficial ausente: $campo" }
}
if ($consolidator -match 'Invoke-WebRequest|Invoke-RestMethod|HttpClient|api/pncp|dataPublicacaoPncp') {
    throw "A consolidacao factual deve ler somente paginas locais preservadas."
}
if ($executor -notmatch 'Descobrir_EVT007_D1\.ps1' -or $executor -notmatch 'Consolidar_EVT007_DadosAbertos\.ps1' -or $executor -notmatch 'TodasPaginas') {
    throw "O executor diario deve descobrir todas as paginas e consolidar a camada factual."
}
if ($collector -notmatch 'COLETOR DESATIVADO' -or $collector -notmatch 'HTTP 301') {
    throw "O coletor antigo deve permanecer bloqueado."
}
if ($qualifier -notmatch 'QUALIFICACAO COMERCIAL BLOQUEADA') {
    throw "A qualificacao comercial deve permanecer bloqueada ate o enriquecimento oficial."
}

if (-not [bool]$governance.fixed_event_matrix -or [int]$governance.total_events -ne 14) {
    throw "GOV-001 deve preservar a matriz fixa de 14 eventos."
}
$eventNames = @($eventMap.events.PSObject.Properties.Name)
if ($eventNames.Count -ne 14 -or -not ($eventNames -contains 'EVT-007') -or -not ($eventNames -contains 'EVT-014')) {
    throw "Mapa de eventos incompleto."
}

$catalogRows = @(Import-Csv -LiteralPath $paths.catalogSource -Delimiter ';' -Encoding UTF8)
if ($catalogRows.Count -ne 3095) { throw "CATSER deve conter 3095 registros. Encontrados: $($catalogRows.Count)" }
if (@($catalogRows | Where-Object { $_.statusServico -eq 'True' }).Count -ne 3013) { throw "Contagem de servicos ativos nao confere." }
$runtime = @(Get-Content -LiteralPath $paths.catalogRuntime -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($runtime.Count -ne 164) { throw "Catalogo runtime deve conter 164 registros classificados." }
foreach ($codigo in @('8729','14397','5380')) {
    $registro = @($runtime | Where-Object { [string]$_.catalogoCodigoItem -eq $codigo })
    if ($registro.Count -ne 1 -or [string]$registro[0].status -ne 'APROVADO' -or -not [bool]$registro[0].statusServico) {
        throw "Codigo essencial ausente ou nao aprovado: $codigo"
    }
}

$hashes = @(
    [pscustomobject]@{ path=$paths.manual; expected='26d5a5cff042faf28c09fd10e9edc32eaeca38f565ea8926699aab932e121449' },
    [pscustomobject]@{ path=$paths.openapi; expected='dfe448f39a3d6602d688465d2159fa75233ac56aa447dee115fbbcd2eb4fe7af' },
    [pscustomobject]@{ path=$paths.catalogSource; expected='f3cd884220115be97fd7782a25e799d8c64390786794d27c3fef53806e67f264' }
)
foreach ($entry in $hashes) {
    $actual = (Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.expected) { throw "Hash divergente: $($entry.path)" }
}

foreach ($forbidden in @('data','output')) {
    if (Test-Path -LiteralPath (Join-Path $Root $forbidden)) { throw "Diretorio operacional nao deve estar versionado: $forbidden" }
}
foreach ($forbidden in @('Importar_Candidatos_V2.ps1','candidatos_evt007.csv')) {
    if (Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $forbidden -ErrorAction SilentlyContinue) { throw "Contaminacao V2 detectada: $forbidden" }
}

Write-Host "[OK] Estrutura canônica validada."
Write-Host "[OK] Execução diária calcula D-1 ou recebe data explícita."
Write-Host "[OK] Nenhuma modalidade excluída; Pregão Eletrônico permanece."
Write-Host "[OK] Descoberta completa e consolidação factual estão encadeadas."
Write-Host "[OK] Qualificação comercial permanece bloqueada."
Write-Host "[OK] Matriz de 14 eventos preservada."
Write-Host "[OK] Manual, OpenAPI e CATSER conferidos por SHA-256."
