param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$DataResultado = "2026-07-17"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$dataCompacta = $DataResultado.Replace('-', '')
$runName = "evt007_$dataCompacta"
$jsonlPath = Join-Path $Root "data\state\${runName}_resultados.jsonl"
$rawRoot = Join-Path $Root "data\raw\$runName"
$rulesPath = Join-Path $Root "config\comercial\regras_comerciais.json"
$catalogPath = Join-Path $Root "config\comercial\catalogo_servicos.json"
$outputRoot = Join-Path $Root "output\comercial"

foreach ($path in @($jsonlPath, $rulesPath, $catalogPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio nao encontrado: $path" }
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$rules = Get-Content -LiteralPath $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$catalog = @(Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json)
$registros = @(Get-Content -LiteralPath $jsonlPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })

$catalogMap = @{}
foreach ($entry in $catalog) { $catalogMap[[string]$entry.catalogoCodigoItem] = $entry }

function Convert-ToSearchText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $formD = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder
    foreach ($char in $formD.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }
    return $builder.ToString().Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
}

function Test-MaoDeObraDedicada {
    param([string]$Texto)
    $normalizado = Convert-ToSearchText -Text $Texto
    foreach ($termo in @($rules.termosMaoDeObraDedicada)) {
        if ($normalizado.Contains((Convert-ToSearchText -Text ([string]$termo)))) { return $true }
    }
    return $false
}

$itemTotalsByCase = @{}
if (Test-Path -LiteralPath $rawRoot) {
    foreach ($rawFile in Get-ChildItem -LiteralPath $rawRoot -File -Filter '*.json') {
        $raw = Get-Content -LiteralPath $rawFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $numeroControle = [string]$raw.contratacao.numeroControlePNCP
        if (-not $numeroControle) { continue }
        $totais = @{}
        foreach ($prop in $raw.resultadosPorItem.PSObject.Properties) {
            $total = [decimal]0
            foreach ($resultado in @($prop.Value)) {
                if ($null -ne $resultado.dataCancelamento -and [string]$resultado.dataCancelamento) { continue }
                if ($null -ne $resultado.valorTotalHomologado) { $total += [decimal]$resultado.valorTotalHomologado }
            }
            $totais[[string]$prop.Name] = $total
        }
        $itemTotalsByCase[$numeroControle] = $totais
    }
}

$detalhado = @()
$comercial = @()

foreach ($grupo in ($registros | Group-Object { [string]$_.contratacao.numeroControlePNCP })) {
    $linhas = @($grupo.Group)
    $contratacao = $linhas[0].contratacao
    $numeroControle = [string]$contratacao.numeroControlePNCP
    $valorContratacao = if ($null -ne $contratacao.valorTotalHomologado) { [decimal]$contratacao.valorTotalHomologado } else { [decimal]0 }

    $itemTotals = if ($itemTotalsByCase.ContainsKey($numeroControle)) { $itemTotalsByCase[$numeroControle] } else { @{} }
    if ($valorContratacao -le 0) {
        foreach ($linha in $linhas) { $valorContratacao += [decimal]$linha.resultado.valorTotalHomologado }
    }

    $temItemAbaixoMinimo = $false
    foreach ($valorItem in $itemTotals.Values) {
        if ([decimal]$valorItem -lt [decimal]$rules.valorMinimo) { $temItemAbaixoMinimo = $true; break }
    }

    $rota = ''
    $decisaoContratacao = ''
    if ($valorContratacao -lt [decimal]$rules.valorMinimo) {
        $decisaoContratacao = 'FORA_CORTE_VALOR'
    } elseif ($temItemAbaixoMinimo -and $valorContratacao -le [decimal]$rules.valorLimiteRota) {
        $decisaoContratacao = 'DESCARTAR_ITEM_FORA_CORTE'
    } elseif ($temItemAbaixoMinimo -and $valorContratacao -gt [decimal]$rules.valorLimiteRota) {
        $rota = [string]$rules.rotas.de1a10milhoes
        $decisaoContratacao = 'REBAIXADA_PARA_1_A_10'
    } elseif ($valorContratacao -gt [decimal]$rules.valorLimiteRota) {
        $rota = [string]$rules.rotas.acima10milhoes
        $decisaoContratacao = 'ROTA_ACIMA_10'
    } else {
        $rota = [string]$rules.rotas.de1a10milhoes
        $decisaoContratacao = 'ROTA_1_A_10'
    }

    foreach ($linha in $linhas) {
        $codigoCatalogo = [string]$linha.item.catalogoCodigoItem
        $materialOuServico = [string]$linha.item.materialOuServico
        $materialOuServicoNome = [string]$linha.item.materialOuServicoNome
        $ehServicoCatser = ($materialOuServico -eq 'S') -or ((Convert-ToSearchText -Text $materialOuServicoNome).Contains('servico'))
        $catalogEntry = if ($ehServicoCatser -and $catalogMap.ContainsKey($codigoCatalogo)) { $catalogMap[$codigoCatalogo] } else { $null }
        $catalogStatus = if (-not $ehServicoCatser) { 'CATMAT_NAO_APLICAVEL' } elseif ($null -ne $catalogEntry) { [string]$catalogEntry.status } else { 'NAO_LOCALIZADO' }
        $textoObjeto = @(
            [string]$linha.contratacao.objetoCompra,
            [string]$linha.contratacao.informacaoComplementar,
            [string]$linha.item.descricao,
            [string]$linha.item.informacaoComplementar
        ) -join ' '
        $maoDeObra = $ehServicoCatser -and (Test-MaoDeObraDedicada -Texto $textoObjeto)
        $objetoAprovado = $ehServicoCatser -and (($catalogStatus -eq 'APROVADO') -or $maoDeObra)
        $valorItem = if ($itemTotals.ContainsKey([string]$linha.item.numeroItem)) { [decimal]$itemTotals[[string]$linha.item.numeroItem] } else { [decimal]$linha.resultado.valorTotalHomologado }

        $qualificado = $objetoAprovado -and $rota -and ($valorItem -ge [decimal]$rules.valorMinimo)
        $motivo = if (-not $rota) {
            $decisaoContratacao
        } elseif (-not $objetoAprovado) {
            'OBJETO_FORA_CATALOGO_E_SEM_MAO_DE_OBRA_DEDICADA'
        } elseif ($valorItem -lt [decimal]$rules.valorMinimo) {
            'ITEM_FORA_CORTE_VALOR'
        } else {
            'QUALIFICADO'
        }

        $row = [pscustomobject][ordered]@{
            numeroControlePNCP = [string]$linha.contratacao.numeroControlePNCP
            modalidadeId = $linha.contratacao.modalidadeId
            modalidadeNome = [string]$linha.contratacao.modalidadeNome
            objetoCompra = [string]$linha.contratacao.objetoCompra
            orgaoCnpj = [string]$linha.contratacao.orgaoEntidade.cnpj
            orgaoRazaoSocial = [string]$linha.contratacao.orgaoEntidade.razaoSocial
            unidadeCodigo = [string]$linha.contratacao.unidadeOrgao.codigoUnidade
            unidadeNome = [string]$linha.contratacao.unidadeOrgao.nomeUnidade
            numeroItem = $linha.resultado.numeroItem
            sequencialResultado = $linha.resultado.sequencialResultado
            descricao = [string]$linha.item.descricao
            materialOuServico = $materialOuServico
            materialOuServicoNome = $materialOuServicoNome
            itemCategoriaId = $linha.item.itemCategoriaId
            itemCategoriaNome = [string]$linha.item.itemCategoriaNome
            ncmNbsCodigo = [string]$linha.item.ncmNbsCodigo
            ncmNbsDescricao = [string]$linha.item.ncmNbsDescricao
            catalogoCodigoItem = $codigoCatalogo
            informacaoComplementar = [string]$linha.item.informacaoComplementar
            dataResultado = [string]$linha.resultado.dataResultado
            dataInclusao = [string]$linha.resultado.dataInclusao
            dataAtualizacao = [string]$linha.resultado.dataAtualizacao
            niFornecedor = [string]$linha.resultado.niFornecedor
            nomeRazaoSocialFornecedor = [string]$linha.resultado.nomeRazaoSocialFornecedor
            quantidadeHomologada = $linha.resultado.quantidadeHomologada
            valorUnitarioHomologado = $linha.resultado.valorUnitarioHomologado
            valorTotalHomologado = $linha.resultado.valorTotalHomologado
            situacaoCompraItemResultadoId = [string]$linha.resultado.situacaoCompraItemResultadoId
            situacaoCompraItemResultadoNome = [string]$linha.resultado.situacaoCompraItemResultadoNome
            logManutencaoDataInclusao = [string]$linha.historico.logManutencaoDataInclusao
            tipoLogManutencao = $linha.historico.tipoLogManutencao
            categoriaLogManutencao = $linha.historico.categoriaLogManutencao
            usuarioNome = [string]$linha.historico.usuarioNome
            gsbValorTotalHomologadoContratacao = $valorContratacao
            gsbValorTotalHomologadoItem = $valorItem
            gsbEhServicoCatser = $ehServicoCatser
            gsbCatalogoStatus = $catalogStatus
            gsbCatalogoNome = if ($null -ne $catalogEntry) { [string]$catalogEntry.nome } else { '' }
            gsbCatalogoCodigoGrupo = if ($null -ne $catalogEntry) { [string]$catalogEntry.codigoGrupo } else { '' }
            gsbCatalogoNomeGrupo = if ($null -ne $catalogEntry) { [string]$catalogEntry.nomeGrupo } else { '' }
            gsbCatalogoCodigoClasse = if ($null -ne $catalogEntry) { [string]$catalogEntry.codigoClasse } else { '' }
            gsbCatalogoNomeClasse = if ($null -ne $catalogEntry) { [string]$catalogEntry.nomeClasse } else { '' }
            gsbCatalogoEixoComercial = if ($null -ne $catalogEntry) { [string]$catalogEntry.eixoComercial } else { '' }
            gsbCatalogoReferencia = if ($null -ne $catalogEntry) { [string]$catalogEntry.catalogoReferencia } else { '' }
            gsbMaoDeObraDedicada = $maoDeObra
            gsbRota = $rota
            gsbDecisaoContratacao = $decisaoContratacao
            gsbQualificado = $qualificado
            gsbMotivo = $motivo
        }
        $detalhado += $row
        if ($qualificado) { $comercial += $row }
    }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$detailPath = Join-Path $outputRoot "${runName}_detalhado_$stamp.csv"
$commercialPath = Join-Path $outputRoot "${runName}_base_comercial_$stamp.csv"
$auditPath = Join-Path $outputRoot "${runName}_auditoria_$stamp.json"

$colunas = @(
    'numeroControlePNCP','modalidadeId','modalidadeNome','objetoCompra','orgaoCnpj','orgaoRazaoSocial',
    'unidadeCodigo','unidadeNome','numeroItem','sequencialResultado','descricao','materialOuServico',
    'materialOuServicoNome','itemCategoriaId','itemCategoriaNome','ncmNbsCodigo','ncmNbsDescricao',
    'catalogoCodigoItem','informacaoComplementar','dataResultado','dataInclusao','dataAtualizacao',
    'niFornecedor','nomeRazaoSocialFornecedor','quantidadeHomologada','valorUnitarioHomologado',
    'valorTotalHomologado','situacaoCompraItemResultadoId','situacaoCompraItemResultadoNome',
    'logManutencaoDataInclusao','tipoLogManutencao','categoriaLogManutencao','usuarioNome',
    'gsbValorTotalHomologadoContratacao','gsbValorTotalHomologadoItem','gsbEhServicoCatser','gsbCatalogoStatus',
    'gsbCatalogoNome','gsbCatalogoCodigoGrupo','gsbCatalogoNomeGrupo','gsbCatalogoCodigoClasse',
    'gsbCatalogoNomeClasse','gsbCatalogoEixoComercial','gsbCatalogoReferencia',
    'gsbMaoDeObraDedicada','gsbRota','gsbDecisaoContratacao','gsbQualificado','gsbMotivo'
)

if ($detalhado.Count -gt 0) {
    $detalhado | Select-Object $colunas | Export-Csv -LiteralPath $detailPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
} else {
    Set-Content -LiteralPath $detailPath -Value (($colunas | ForEach-Object { '"' + $_ + '"' }) -join ';') -Encoding UTF8
}
if ($comercial.Count -gt 0) {
    $comercial | Select-Object $colunas | Export-Csv -LiteralPath $commercialPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
} else {
    Set-Content -LiteralPath $commercialPath -Value (($colunas | ForEach-Object { '"' + $_ + '"' }) -join ';') -Encoding UTF8
}

$audit = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    dataResultado = $DataResultado
    registrosRecebidos = $registros.Count
    registrosDetalhados = $detalhado.Count
    registrosQualificados = $comercial.Count
    contratacoes = @($registros | Group-Object { $_.contratacao.numeroControlePNCP }).Count
    arquivoDetalhado = $detailPath
    arquivoComercial = $commercialPath
    observacaoCobertura = 'A cobertura depende da lista de candidatos. Zero resultados nao representa zero homologacoes nacionais.'
}
$audit | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $auditPath -Encoding UTF8

foreach ($par in @(
    @{ origem=$detailPath; destino=(Join-Path $outputRoot "${runName}_detalhado_latest.csv") },
    @{ origem=$commercialPath; destino=(Join-Path $outputRoot "${runName}_base_comercial_latest.csv") },
    @{ origem=$auditPath; destino=(Join-Path $outputRoot "${runName}_auditoria_latest.json") }
)) {
    try { Copy-Item -LiteralPath $par.origem -Destination $par.destino -Force }
    catch { Write-Warning "Nao foi possivel atualizar o arquivo latest, possivelmente aberto em outro programa: $($par.destino)" }
}

Write-Host "[OK] Detalhado: $detailPath"
Write-Host "[OK] Base comercial: $commercialPath"
Write-Host "[OK] Registros qualificados: $($comercial.Count)"
Write-Host "[OK] Auditoria: $auditPath"
