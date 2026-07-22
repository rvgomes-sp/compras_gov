param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$DataResultado = "",
    [string]$DiscoveryRoot = "",
    [switch]$PermitirCoberturaParcial,
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$configPath = Join-Path $Root "config\api\factual_evt007_dados_abertos.json"
foreach ($path in @($configPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio nao encontrado: $path" }
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($DataResultado)) {
    $DataResultado = (Get-Date).Date.AddDays(-1).ToString('yyyy-MM-dd')
}

$dataD1 = [datetime]::MinValue
if (-not [datetime]::TryParseExact($DataResultado, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$dataD1)) {
    throw "DataResultado invalida. Use exatamente AAAA-MM-DD."
}

$dataCompacta = $DataResultado.Replace('-', '')
$runName = "evt007_$dataCompacta"
if ([string]::IsNullOrWhiteSpace($DiscoveryRoot)) {
    $DiscoveryRoot = Join-Path $Root "data\descoberta\$runName"
}
$rawRoot = Join-Path $DiscoveryRoot ([string]$config.diretorioPaginasBrutas)
$sourceAuditPath = Join-Path $DiscoveryRoot ([string]$config.arquivoAuditoriaDescoberta)
$outputRoot = Join-Path $Root "output\factual\$runName"

foreach ($path in @($DiscoveryRoot, $rawRoot, $sourceAuditPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Entrada obrigatoria da descoberta nao encontrada: $path" }
}

$sourceAudit = Get-Content -LiteralPath $sourceAuditPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$sourceAudit.dataResultadoPncpInicial -ne $DataResultado -or [string]$sourceAudit.dataResultadoPncpFinal -ne $DataResultado) {
    throw "A auditoria da descoberta nao corresponde ao D-1 solicitado."
}
if ([string]$sourceAudit.fonte -ne [string]$config.fonte) {
    throw "A fonte da descoberta nao corresponde a $($config.fonte)."
}
if ([string]$sourceAudit.cobertura -ne 'COMPLETA' -and -not $PermitirCoberturaParcial) {
    throw "Cobertura da descoberta nao e COMPLETA. Para auditoria tecnica parcial, use explicitamente -PermitirCoberturaParcial."
}

$rawFiles = @(Get-ChildItem -LiteralPath $rawRoot -File -Filter ([string]$config.padraoPaginasBrutas) | Sort-Object Name)
if ($rawFiles.Count -eq 0) { throw "Nenhuma pagina bruta encontrada em: $rawRoot" }
if ([string]$sourceAudit.cobertura -eq 'COMPLETA' -and $rawFiles.Count -ne [int]$sourceAudit.totalPaginasInformado) {
    throw "Paginas brutas divergentes da auditoria: arquivos=$($rawFiles.Count), informado=$($sourceAudit.totalPaginasInformado)."
}

if (Test-Path -LiteralPath $outputRoot) {
    if (-not $Reiniciar) { throw "Saida factual ja existe: $outputRoot. Use -Reiniciar para reconstrui-la a partir das paginas preservadas." }
    Remove-Item -LiteralPath $outputRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

function Save-JsonAtomic {
    param([Parameter(Mandatory=$true)]$Value, [Parameter(Mandatory=$true)][string]$Path)
    $temp = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Export-CsvAtomic {
    param(
        [Parameter(Mandatory=$true)][object[]]$Rows,
        [Parameter(Mandatory=$true)][string[]]$Columns,
        [Parameter(Mandatory=$true)][string]$Path
    )
    $temp = "$Path.tmp"
    if ($Rows.Count -gt 0) {
        $Rows | Select-Object $Columns | Export-Csv -LiteralPath $temp -Delimiter ';' -NoTypeInformation -Encoding UTF8
    } else {
        Set-Content -LiteralPath $temp -Value (($Columns | ForEach-Object { '"' + $_ + '"' }) -join ';') -Encoding UTF8
    }
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Convert-ToOfficialDateTime {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [datetime]::MinValue
    $formats = @('yyyy-MM-ddTHH:mm:ss','yyyy-MM-ddTHH:mm:ss.fff','yyyy-MM-dd')
    foreach ($format in $formats) {
        if ([datetime]::TryParseExact($Value, $format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed
        }
    }
    return $null
}

function Get-DecimalSum {
    param([object[]]$Values)
    $total = [decimal]0
    foreach ($value in @($Values)) {
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { $total += [decimal]$value }
    }
    return $total
}

$officialColumns = @($config.camposOficiaisResultado | ForEach-Object { [string]$_ })
$gsbResultColumns = @(
    'gsbChaveResultado',
    'gsbFonte',
    'gsbDataResultadoD1Confirmada',
    'gsbDeltaInclusaoHoras',
    'gsbCancelado',
    'gsbFornecedorIdentificado',
    'gsbRegistroFactualUtilizavel',
    'gsbOrigemPlataforma',
    'gsbStatusEnriquecimentoItem',
    'gsbClassificacaoComercial',
    'gsbBaseComercial'
)
$resultColumns = @($officialColumns + $gsbResultColumns)

$counters = [ordered]@{
    paginasLidas = 0
    registrosLidos = 0
    registrosDataDivergente = 0
    registrosSemChave = 0
    registrosDuplicados = 0
    registrosSemFornecedor = 0
    registrosSemDataInclusaoPncp = 0
    registrosInclusaoAnteriorResultado = 0
    registrosCancelados = 0
    registrosFatuaisIntegrais = 0
    registrosFatuaisUtilizaveis = 0
}
$seen = @{}
$resultados = [System.Collections.Generic.List[object]]::new()
$resultadosUtilizaveis = [System.Collections.Generic.List[object]]::new()
$inputManifest = [System.Collections.Generic.List[object]]::new()

foreach ($rawFile in $rawFiles) {
    $payload = Get-Content -LiteralPath $rawFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $collectionField = [string]$config.campoColecao
    if ($null -eq $payload.PSObject.Properties[$collectionField]) {
        throw "Pagina sem a colecao oficial $($config.campoColecao): $($rawFile.FullName)"
    }
    $counters.paginasLidas++
    $inputManifest.Add([pscustomobject][ordered]@{
        arquivo = $rawFile.Name
        sha256 = (Get-FileHash -LiteralPath $rawFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        registros = @($payload.resultado).Count
        totalRegistrosInformado = $payload.totalRegistros
        totalPaginasInformado = $payload.totalPaginas
    })

    foreach ($result in @($payload.resultado)) {
        $counters.registrosLidos++
        foreach ($field in $officialColumns) {
            if ($null -eq $result.PSObject.Properties[$field]) { throw "Campo oficial ausente no resultado: $field. Arquivo: $($rawFile.Name)" }
        }

        $resultDateText = [string]$result.dataResultadoPncp
        if ($resultDateText.Length -lt 10 -or $resultDateText.Substring(0,10) -ne $DataResultado) {
            $counters.registrosDataDivergente++
            continue
        }

        $keyParts = @(
            [string]$result.idCompraItem,
            [string]$result.sequencialResultado,
            [string]$result.niFornecedor,
            [string]$result.dataResultadoPncp
        )
        if ([string]::IsNullOrWhiteSpace($keyParts[0]) -or [string]::IsNullOrWhiteSpace($keyParts[1]) -or [string]::IsNullOrWhiteSpace([string]$result.numeroControlePNCPCompra)) {
            $counters.registrosSemChave++
            continue
        }
        $key = $keyParts -join '|'
        if ($seen.ContainsKey($key)) {
            $counters.registrosDuplicados++
            continue
        }
        $seen[$key] = $true

        $fornecedorIdentificado = -not [string]::IsNullOrWhiteSpace([string]$result.niFornecedor) -and -not [string]::IsNullOrWhiteSpace([string]$result.nomeRazaoSocialFornecedor)
        if (-not $fornecedorIdentificado) { $counters.registrosSemFornecedor++ }
        $cancelado = -not [string]::IsNullOrWhiteSpace([string]$result.dataCancelamentoPncp)
        if ($cancelado) { $counters.registrosCancelados++ }

        $resultadoData = Convert-ToOfficialDateTime -Value ([string]$result.dataResultadoPncp)
        $inclusaoData = Convert-ToOfficialDateTime -Value ([string]$result.dataInclusaoPncp)
        $deltaHoras = $null
        if ($null -eq $inclusaoData) {
            $counters.registrosSemDataInclusaoPncp++
        } elseif ($null -ne $resultadoData) {
            $deltaHoras = [math]::Round(($inclusaoData - $resultadoData).TotalHours, 2)
            if ($deltaHoras -lt 0) { $counters.registrosInclusaoAnteriorResultado++ }
        }

        $utilizavel = $fornecedorIdentificado -and -not $cancelado
        $row = [ordered]@{}
        foreach ($field in $officialColumns) { $row[$field] = $result.$field }
        $row['gsbChaveResultado'] = $key
        $row['gsbFonte'] = [string]$config.fonte
        $row['gsbDataResultadoD1Confirmada'] = $true
        $row['gsbDeltaInclusaoHoras'] = $deltaHoras
        $row['gsbCancelado'] = $cancelado
        $row['gsbFornecedorIdentificado'] = $fornecedorIdentificado
        $row['gsbRegistroFactualUtilizavel'] = $utilizavel
        $row['gsbOrigemPlataforma'] = [string]$config.regras.origemPlataforma
        $row['gsbStatusEnriquecimentoItem'] = [string]$config.regras.enriquecimentoItem
        $row['gsbClassificacaoComercial'] = [string]$config.regras.classificacaoComercial
        $row['gsbBaseComercial'] = $false
        $factual = [pscustomobject]$row
        $resultados.Add($factual)
        $counters.registrosFatuaisIntegrais++
        if ($utilizavel) {
            $resultadosUtilizaveis.Add($factual)
            $counters.registrosFatuaisUtilizaveis++
        }
    }
}

if ([string]$sourceAudit.cobertura -eq 'COMPLETA' -and $counters.registrosLidos -ne [int64]$sourceAudit.totalRegistrosInformado) {
    throw "Quantidade lida diverge da auditoria: lidos=$($counters.registrosLidos), informado=$($sourceAudit.totalRegistrosInformado)."
}

$contratacoes = [System.Collections.Generic.List[object]]::new()
foreach ($group in @($resultados | Group-Object { [string]$_.numeroControlePNCPCompra } | Sort-Object Name)) {
    $rows = @($group.Group)
    $usableRows = @($rows | Where-Object { [bool]$_.gsbRegistroFactualUtilizavel })
    $first = $rows[0]
    $inclusionDates = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.dataInclusaoPncp) } | ForEach-Object { [string]$_.dataInclusaoPncp } | Sort-Object)
    $contratacoes.Add([pscustomobject][ordered]@{
        numeroControlePNCPCompra = [string]$first.numeroControlePNCPCompra
        idContratacaoPNCP = [string]$first.idContratacaoPNCP
        idCompra = [string]$first.idCompra
        orgaoEntidadeCnpj = [string]$first.orgaoEntidadeCnpj
        unidadeOrgaoCodigoUnidade = [string]$first.unidadeOrgaoCodigoUnidade
        unidadeOrgaoUfSigla = [string]$first.unidadeOrgaoUfSigla
        dataResultadoPncp = $DataResultado
        gsbQuantidadeResultadosD1 = $rows.Count
        gsbQuantidadeResultadosUtilizaveisD1 = $usableRows.Count
        gsbQuantidadeItensComResultadoD1 = @($rows | Select-Object -ExpandProperty idCompraItem -Unique).Count
        gsbQuantidadeFornecedoresD1 = @($usableRows | Select-Object -ExpandProperty niFornecedor -Unique).Count
        gsbValorHomologadoResultadosD1 = Get-DecimalSum -Values @($usableRows | Select-Object -ExpandProperty valorTotalHomologado)
        gsbDataInclusaoPncpInicial = if ($inclusionDates.Count -gt 0) { $inclusionDates[0] } else { $null }
        gsbDataInclusaoPncpFinal = if ($inclusionDates.Count -gt 0) { $inclusionDates[-1] } else { $null }
        gsbResultadosSemFornecedor = @($rows | Where-Object { -not [bool]$_.gsbFornecedorIdentificado }).Count
        gsbResultadosCancelados = @($rows | Where-Object { [bool]$_.gsbCancelado }).Count
        gsbPossuiRegistroFactualUtilizavel = ($usableRows.Count -gt 0)
        gsbOrigemPlataforma = [string]$config.regras.origemPlataforma
        gsbStatusEnriquecimentoItem = [string]$config.regras.enriquecimentoItem
        gsbClassificacaoComercial = [string]$config.regras.classificacaoComercial
        gsbBaseComercial = $false
    })
}

$fornecedores = [System.Collections.Generic.List[object]]::new()
foreach ($group in @($resultadosUtilizaveis | Group-Object { [string]$_.niFornecedor } | Sort-Object Name)) {
    $rows = @($group.Group)
    $first = $rows[0]
    $fornecedores.Add([pscustomobject][ordered]@{
        niFornecedor = [string]$first.niFornecedor
        nomeRazaoSocialFornecedor = [string]$first.nomeRazaoSocialFornecedor
        tipoPessoa = [string]$first.tipoPessoa
        porteFornecedorId = $first.porteFornecedorId
        porteFornecedorNome = [string]$first.porteFornecedorNome
        naturezaJuridicaId = [string]$first.naturezaJuridicaId
        naturezaJuridicaNome = [string]$first.naturezaJuridicaNome
        gsbQuantidadeContratacoesD1 = @($rows | Select-Object -ExpandProperty numeroControlePNCPCompra -Unique).Count
        gsbQuantidadeItensComResultadoD1 = @($rows | Select-Object -ExpandProperty idCompraItem -Unique).Count
        gsbQuantidadeResultadosD1 = $rows.Count
        gsbValorHomologadoResultadosD1 = Get-DecimalSum -Values @($rows | Select-Object -ExpandProperty valorTotalHomologado)
        gsbOrigemPlataforma = [string]$config.regras.origemPlataforma
        gsbStatusEnriquecimentoItem = [string]$config.regras.enriquecimentoItem
        gsbClassificacaoComercial = [string]$config.regras.classificacaoComercial
        gsbBaseComercial = $false
    })
}

$resultsPath = Join-Path $outputRoot "${runName}_resultados_fatuais.csv"
$usablePath = Join-Path $outputRoot "${runName}_resultados_fatuais_utilizaveis.csv"
$contractsPath = Join-Path $outputRoot "${runName}_contratacoes_fatuais.csv"
$suppliersPath = Join-Path $outputRoot "${runName}_fornecedores_fatuais.csv"
$auditPath = Join-Path $outputRoot "${runName}_auditoria_factual.json"

$contractColumns = @(
    'numeroControlePNCPCompra','idContratacaoPNCP','idCompra','orgaoEntidadeCnpj','unidadeOrgaoCodigoUnidade','unidadeOrgaoUfSigla','dataResultadoPncp',
    'gsbQuantidadeResultadosD1','gsbQuantidadeResultadosUtilizaveisD1','gsbQuantidadeItensComResultadoD1','gsbQuantidadeFornecedoresD1',
    'gsbValorHomologadoResultadosD1','gsbDataInclusaoPncpInicial','gsbDataInclusaoPncpFinal','gsbResultadosSemFornecedor','gsbResultadosCancelados',
    'gsbPossuiRegistroFactualUtilizavel','gsbOrigemPlataforma','gsbStatusEnriquecimentoItem','gsbClassificacaoComercial','gsbBaseComercial'
)
$supplierColumns = @(
    'niFornecedor','nomeRazaoSocialFornecedor','tipoPessoa','porteFornecedorId','porteFornecedorNome','naturezaJuridicaId','naturezaJuridicaNome',
    'gsbQuantidadeContratacoesD1','gsbQuantidadeItensComResultadoD1','gsbQuantidadeResultadosD1','gsbValorHomologadoResultadosD1',
    'gsbOrigemPlataforma','gsbStatusEnriquecimentoItem','gsbClassificacaoComercial','gsbBaseComercial'
)

Export-CsvAtomic -Rows @($resultados) -Columns $resultColumns -Path $resultsPath
Export-CsvAtomic -Rows @($resultadosUtilizaveis) -Columns $resultColumns -Path $usablePath
Export-CsvAtomic -Rows @($contratacoes) -Columns $contractColumns -Path $contractsPath
Export-CsvAtomic -Rows @($fornecedores) -Columns $supplierColumns -Path $suppliersPath

$outputManifest = @(@($resultsPath, $usablePath, $contractsPath, $suppliersPath) | ForEach-Object {
    [pscustomobject][ordered]@{
        arquivo = Split-Path -Leaf $_
        sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
$audit = [ordered]@{
    runName = $runName
    generatedAt = (Get-Date).ToString('o')
    fonte = [string]$config.fonte
    dataResultadoPncp = $DataResultado
    coberturaDescoberta = [string]$sourceAudit.cobertura
    baseFactual = $true
    baseComercial = $false
    origemPlataforma = [string]$config.regras.origemPlataforma
    statusEnriquecimentoItem = [string]$config.regras.enriquecimentoItem
    classificacaoComercial = [string]$config.regras.classificacaoComercial
    counters = $counters
    contratacoesFatuais = $contratacoes.Count
    fornecedoresFatuais = $fornecedores.Count
    valorHomologadoResultadosFatuaisUtilizaveisD1 = Get-DecimalSum -Values @($resultadosUtilizaveis | Select-Object -ExpandProperty valorTotalHomologado)
    auditoriaDescoberta = $sourceAuditPath
    entradas = @($inputManifest)
    saidas = $outputManifest
    ressalvas = @(
        'gsbValorHomologadoResultadosD1 soma somente resultados factuais utilizaveis do D-1; nao representa necessariamente o valor total da contratacao.',
        'A origem do endpoint e Compras.gov Dados Abertos, mas a plataforma de origem de cada contratacao nao esta confirmada no resultado.',
        'Descricao, materialOuServico, codigo CATSER ou CATMAT, objeto e modalidade permanecem pendentes de enriquecimento.',
        'Nenhuma regra comercial, corte de valor, rota ou qualificacao foi aplicada.'
    )
}
Save-JsonAtomic -Value $audit -Path $auditPath

Write-Host "[OK] Base factual integral: $resultsPath"
Write-Host "[OK] Base factual utilizavel: $usablePath"
Write-Host "[OK] Contratacoes factuais: $contractsPath"
Write-Host "[OK] Fornecedores factuais: $suppliersPath"
Write-Host "[OK] Auditoria factual: $auditPath"
Write-Host "[ATENCAO] Esta camada e factual. Enriquecimento de item e classificacao comercial ainda nao foram aplicados."
