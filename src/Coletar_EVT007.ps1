param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCsv = "",
    [string]$ExecutionConfig = "",
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $CandidateCsv) { $CandidateCsv = Join-Path $Root "data\candidatos\candidatos_evt007.csv" }
if (-not $ExecutionConfig) { $ExecutionConfig = Join-Path $Root "config\execucao\teste_d1.json" }
$apiConfigPath = Join-Path $Root "config\api\evt007_manual_2_5.json"

foreach ($path in @($CandidateCsv, $ExecutionConfig, $apiConfigPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio nao encontrado: $path" }
}

$api = Get-Content -LiteralPath $apiConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$exec = Get-Content -LiteralPath $ExecutionConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$candidatos = @(Import-Csv -LiteralPath $CandidateCsv -Delimiter ';')

if ($candidatos.Count -eq 0) {
    throw "A lista de candidatos esta vazia. O Manual 2.5 nao permite consulta nacional direta por dataResultado; informe cnpj, ano e sequencial antes da coleta."
}
if ($candidatos.Count -gt [int]$exec.maximoCandidatosPorRodada) {
    throw "A lista possui $($candidatos.Count) candidatos e excede o limite controlado de $($exec.maximoCandidatosPorRodada). Divida a rodada antes de executar."
}

$dataInicio = [string]$exec.dataResultadoInicial
$dataFim = [string]$exec.dataResultadoFinal
if ($dataInicio -ne $dataFim) { throw "Este coletor inicial aceita somente um dia de dataResultado." }

$dataCompacta = $dataInicio.Replace('-', '')
$runName = "evt007_$dataCompacta"
$rawRoot = Join-Path $Root "data\raw\$runName"
$stateRoot = Join-Path $Root "data\state"
$statePath = Join-Path $stateRoot "${runName}_checkpoint.json"
$jsonlPath = Join-Path $stateRoot "${runName}_resultados.jsonl"
$auditPath = Join-Path $stateRoot "${runName}_coleta_auditoria.json"

New-Item -ItemType Directory -Force -Path $rawRoot, $stateRoot | Out-Null

if ($Reiniciar) {
    foreach ($path in @($statePath, $jsonlPath, $auditPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

function Save-JsonAtomic {
    param([Parameter(Mandatory=$true)]$Value, [Parameter(Mandatory=$true)][string]$Path)
    $temp = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function New-State {
    [pscustomobject]@{
        runName = $runName
        dataResultadoInicial = $dataInicio
        dataResultadoFinal = $dataFim
        startedAt = (Get-Date).ToString('o')
        updatedAt = (Get-Date).ToString('o')
        status = 'RUNNING'
        totalCandidates = $candidatos.Count
        completedCandidates = @()
        resultKeys = @()
    }
}

$state = if (Test-Path -LiteralPath $statePath) {
    Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    New-State
}

$completed = @{}
foreach ($key in @($state.completedCandidates)) { $completed[[string]$key] = $true }
$resultKeys = @{}
foreach ($key in @($state.resultKeys)) { $resultKeys[[string]$key] = $true }
if (Test-Path -LiteralPath $jsonlPath) {
    foreach ($linhaExistente in Get-Content -LiteralPath $jsonlPath -Encoding UTF8) {
        if (-not $linhaExistente.Trim()) { continue }
        try {
            $existente = $linhaExistente | ConvertFrom-Json
            $chaveExistente = "$($existente.historico.compraOrgaoCnpj)|$($existente.historico.compraAno)|$($existente.historico.compraSequencial)|$($existente.resultado.numeroItem)|$($existente.resultado.sequencialResultado)|$($existente.resultado.niFornecedor)|$(([string]$existente.resultado.dataResultado).Substring(0,10))"
            $resultKeys[$chaveExistente] = $true
        } catch {
            Write-Warning "Linha JSONL invalida preservada para auditoria: $jsonlPath"
        }
    }
}
$auditoria = @()

Add-Type -AssemblyName System.Net.Http
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$script:pncpHttpHandler = [System.Net.Http.HttpClientHandler]::new()
$script:pncpHttpHandler.AllowAutoRedirect = $true
$script:pncpHttpHandler.MaxAutomaticRedirections = 10
$script:pncpHttpHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
$script:pncpHttpClient = [System.Net.Http.HttpClient]::new($script:pncpHttpHandler)
$script:pncpHttpClient.Timeout = [TimeSpan]::FromSeconds(60)
$script:pncpHttpClient.DefaultRequestHeaders.Accept.Clear()
$script:pncpHttpClient.DefaultRequestHeaders.Accept.ParseAdd('*/*')

function Invoke-ApiJson {
    param([Parameter(Mandatory=$true)][string]$Uri)

    $ultimaFalha = $null
    for ($tentativa = 1; $tentativa -le [int]$exec.tentativas; $tentativa++) {
        $httpResponse = $null
        try {
            $httpResponse = $script:pncpHttpClient.GetAsync($Uri).GetAwaiter().GetResult()
            $status = [int]$httpResponse.StatusCode
            $conteudo = $httpResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $uriEfetiva = $httpResponse.RequestMessage.RequestUri.AbsoluteUri
        } catch {
            $ultimaFalha = $_.Exception.Message
            if ($tentativa -lt [int]$exec.tentativas) {
                $espera = [math]::Min(60, [math]::Pow(2, $tentativa))
                Write-Warning "Falha de transporte. Nova tentativa em $espera segundos."
                Start-Sleep -Seconds $espera
                continue
            }
            break
        }

        try {
            if (([System.Uri]$uriEfetiva).Scheme -ne 'https') {
                throw "Redirecionamento recusado por nao usar HTTPS: $uriEfetiva"
            }

            if ($status -ge 200 -and $status -lt 300) {
                Start-Sleep -Milliseconds ([int]$exec.pausaMilissegundos)
                if ([string]::IsNullOrWhiteSpace($conteudo)) { return $null }
                return ($conteudo | ConvertFrom-Json)
            }

            if ($status -in @(301, 302, 307, 308)) {
                $ultimaFalha = "HTTP $status ao consultar $Uri"
                $location = $null
                if ($null -ne $httpResponse.Headers.Location) {
                    $location = [string]$httpResponse.Headers.Location
                }
                if (-not $location) {
                    throw "HTTP $status permaneceu apos redirecionamento automatico e veio sem cabecalho Location: $Uri"
                }
                $redirectUri = ([System.Uri]::new([System.Uri]$Uri, $location)).AbsoluteUri
                if (([System.Uri]$redirectUri).Scheme -ne 'https') {
                    throw "Redirecionamento recusado por nao usar HTTPS: $redirectUri"
                }
                Write-Warning "HTTP $status. Seguindo redirecionamento informado pelo PNCP."
                $Uri = $redirectUri
                continue
            }
            if ($status -eq 429) {
                $ultimaFalha = "HTTP 429 ao consultar $Uri"
                $espera = [int]$exec.pausa429Segundos * $tentativa
                Write-Warning "HTTP 429. Aguardando $espera segundos. Tentativa $tentativa/$($exec.tentativas)."
                Start-Sleep -Seconds $espera
                continue
            }
            if ($status -in @(408, 425, 500, 502, 503, 504)) {
                $ultimaFalha = "HTTP $status ao consultar $Uri"
                $espera = [math]::Min(60, [math]::Pow(2, $tentativa))
                Write-Warning "HTTP $status. Nova tentativa em $espera segundos."
                Start-Sleep -Seconds $espera
                continue
            }
            $trechoResposta = if ([string]::IsNullOrWhiteSpace($conteudo)) { '(resposta sem corpo)' } else { $conteudo.Substring(0, [math]::Min(500, $conteudo.Length)) }
            throw "HTTP $status ao consultar $Uri`n$trechoResposta"
        } finally {
            if ($null -ne $httpResponse) { $httpResponse.Dispose() }
        }
    }

    throw "Falha apos $($exec.tentativas) tentativas: $Uri`n$ultimaFalha"
}

function Expand-Endpoint {
    param([string]$Template, [string]$Cnpj, [int]$Ano, [int]$Sequencial, $NumeroItem)
    $path = $Template.Replace('{cnpj}', $Cnpj).Replace('{ano}', [string]$Ano).Replace('{sequencial}', [string]$Sequencial)
    if ($null -ne $NumeroItem) { $path = $path.Replace('{numeroItem}', [string]$NumeroItem) }
    return ([string]$api.baseUrl).TrimEnd('/') + '/' + $path.TrimStart('/')
}

function Get-PagedList {
    param([Parameter(Mandatory=$true)][string]$BaseUri)
    $todos = @()
    $pagina = 1
    $tamanho = [int]$exec.tamanhoPagina
    while ($pagina -le 100) {
        $separador = if ($BaseUri.Contains('?')) { '&' } else { '?' }
        $uri = "$BaseUri${separador}pagina=$pagina&tamanhoPagina=$tamanho"
        $payload = Invoke-ApiJson -Uri $uri
        $lote = @($payload)
        if ($lote.Count -eq 0) { break }
        $todos += $lote
        if ($lote.Count -lt $tamanho) { break }
        $pagina++
    }
    if ($pagina -gt 100) { throw "Paginacao excedeu a trava tecnica de 100 paginas: $BaseUri" }
    return @($todos)
}

function Test-UsuarioComprasGov {
    param($Historico)
    if ($null -eq $Historico.usuarioNome) { return $false }
    return ([string]$Historico.usuarioNome).IndexOf([string]$exec.usuarioNomeContem, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Find-HistoricoResultado {
    param([object[]]$Historico, [int]$NumeroItem, [int]$SequencialResultado)
    foreach ($h in $Historico) {
        if ([string]$h.categoriaLogManutencao -ne '5') { continue }
        if ([int]$h.itemResultadoNumero -ne $NumeroItem) { continue }
        if ([int]$h.itemResultadoSequencial -ne $SequencialResultado) { continue }
        if ($exec.somenteTipoLogManutencaoInclusao -and [string]$h.tipoLogManutencao -ne '0') { continue }
        if (-not (Test-UsuarioComprasGov -Historico $h)) { continue }
        return $h
    }
    return $null
}

$contadores = [ordered]@{
    candidatosInformados = $candidatos.Count
    candidatosConcluidos = $completed.Count
    modalidadesExcluidas = 0
    itensConsultados = 0
    resultadosConsultados = 0
    resultadosDataResultado = 0
    resultadosFonteComprasGov = 0
    resultadosSemFonteConfirmada = 0
    resultadosSemDataInclusao = 0
    resultadosSemLogManutencaoDataInclusao = 0
    resultadosCancelados = 0
    falhas = 0
}

try {
    $indice = 0
    $falhasConsecutivas = 0
    foreach ($candidato in $candidatos) {
        $indice++
        if (-not $candidato.cnpj -or -not $candidato.ano -or -not $candidato.sequencial) {
            throw "Candidato sem cnpj, ano ou sequencial na linha $indice."
        }

        $cnpj = [string]$candidato.cnpj
        $ano = [int]$candidato.ano
        $sequencial = [int]$candidato.sequencial
        $candidateKey = "$cnpj|$ano|$sequencial"
        if ($completed.ContainsKey($candidateKey)) { continue }

        Write-Host "[$indice/$($candidatos.Count)] $candidateKey"
        $caseAudit = [ordered]@{
            cnpj = $cnpj
            ano = $ano
            sequencial = $sequencial
            startedAt = (Get-Date).ToString('o')
            status = 'RUNNING'
            itens = 0
            resultados = 0
            resultadosD1 = 0
            resultadosComprasGov = 0
            error = $null
            finishedAt = $null
        }

        try {
            $uriContratacao = Expand-Endpoint -Template $api.endpoints.contratacao -Cnpj $cnpj -Ano $ano -Sequencial $sequencial -NumeroItem $null
            $uriItens = Expand-Endpoint -Template $api.endpoints.itens -Cnpj $cnpj -Ano $ano -Sequencial $sequencial -NumeroItem $null
            $uriHistorico = Expand-Endpoint -Template $api.endpoints.historico -Cnpj $cnpj -Ano $ano -Sequencial $sequencial -NumeroItem $null

            $contratacao = Invoke-ApiJson -Uri $uriContratacao
            $modalidadeId = [int]$contratacao.modalidadeId
            if (-not (@($exec.modalidadeIdPermitida) -contains $modalidadeId) -or (@($exec.modalidadeIdExcluida) -contains $modalidadeId)) {
                $contadores.modalidadesExcluidas++
                $caseAudit.status = 'MODALIDADE_EXCLUIDA'
                $completed[$candidateKey] = $true
                $falhasConsecutivas = 0
                continue
            }

            $itens = @(Get-PagedList -BaseUri $uriItens)
            $historico = @(Get-PagedList -BaseUri $uriHistorico)
            $resultadosPorItem = [ordered]@{}
            $caseAudit.itens = $itens.Count
            $contadores.itensConsultados += $itens.Count

            foreach ($item in $itens) {
                if ($null -eq $item.numeroItem) { continue }
                if ($null -ne $item.temResultado -and -not [bool]$item.temResultado) { continue }

                $numeroItem = [int]$item.numeroItem
                $uriResultados = Expand-Endpoint -Template $api.endpoints.resultados -Cnpj $cnpj -Ano $ano -Sequencial $sequencial -NumeroItem $numeroItem
                $resultados = @(Invoke-ApiJson -Uri $uriResultados)
                $resultadosPorItem[[string]$numeroItem] = $resultados
                $caseAudit.resultados += $resultados.Count
                $contadores.resultadosConsultados += $resultados.Count

                foreach ($resultado in $resultados) {
                    if ($null -eq $resultado.dataResultado) { continue }
                    $diaResultado = ([string]$resultado.dataResultado).Substring(0, [math]::Min(10, ([string]$resultado.dataResultado).Length))
                    if ($diaResultado -lt $dataInicio -or $diaResultado -gt $dataFim) { continue }
                    $caseAudit.resultadosD1++
                    $contadores.resultadosDataResultado++

                    if ($null -ne $resultado.dataCancelamento -and [string]$resultado.dataCancelamento) {
                        $contadores.resultadosCancelados++
                        continue
                    }
                    if (-not $resultado.niFornecedor -or -not $resultado.nomeRazaoSocialFornecedor) { continue }
                    if ($null -eq $resultado.dataInclusao -or -not [string]$resultado.dataInclusao) {
                        $contadores.resultadosSemDataInclusao++
                    }

                    $sequencialResultado = [int]$resultado.sequencialResultado
                    $eventoHistorico = Find-HistoricoResultado -Historico $historico -NumeroItem $numeroItem -SequencialResultado $sequencialResultado
                    if ($null -eq $eventoHistorico) {
                        $contadores.resultadosSemFonteConfirmada++
                        continue
                    }
                    if ($null -eq $eventoHistorico.logManutencaoDataInclusao -or -not [string]$eventoHistorico.logManutencaoDataInclusao) {
                        $contadores.resultadosSemLogManutencaoDataInclusao++
                        continue
                    }

                    $caseAudit.resultadosComprasGov++
                    $contadores.resultadosFonteComprasGov++
                    $resultKey = "$candidateKey|$numeroItem|$sequencialResultado|$($resultado.niFornecedor)|$diaResultado"
                    if ($resultKeys.ContainsKey($resultKey)) { continue }

                    $registro = [ordered]@{
                        contratacao = $contratacao
                        item = $item
                        resultado = $resultado
                        historico = $eventoHistorico
                        coleta = [ordered]@{
                            runName = $runName
                            capturedAt = (Get-Date).ToString('o')
                            endpointContratacao = $uriContratacao
                            endpointItens = $uriItens
                            endpointResultados = $uriResultados
                            endpointHistorico = $uriHistorico
                        }
                    }
                    Add-Content -LiteralPath $jsonlPath -Value ($registro | ConvertTo-Json -Depth 100 -Compress) -Encoding UTF8
                    $resultKeys[$resultKey] = $true
                }
            }

            $rawPath = Join-Path $rawRoot ("{0}_{1}_{2}.json" -f $cnpj, $ano, $sequencial)
            Save-JsonAtomic -Path $rawPath -Value ([ordered]@{
                contratacao = $contratacao
                itens = $itens
                resultadosPorItem = $resultadosPorItem
                historico = $historico
                coleta = [ordered]@{
                    runName = $runName
                    capturedAt = (Get-Date).ToString('o')
                    dataResultadoInicial = $dataInicio
                    dataResultadoFinal = $dataFim
                }
            })

            $caseAudit.status = 'COMPLETED'
            $completed[$candidateKey] = $true
            $falhasConsecutivas = 0
        } catch {
            $contadores.falhas++
            $falhasConsecutivas++
            $caseAudit.status = 'FAILED'
            $caseAudit.error = $_.Exception.Message
            Write-Warning "Falha em ${candidateKey}: $($_.Exception.Message)"
            if ($falhasConsecutivas -ge 3) {
                throw "Interrupcao preventiva: tres candidatos consecutivos falharam. Ultima falha: $($_.Exception.Message)"
            }
        } finally {
            $caseAudit.finishedAt = (Get-Date).ToString('o')
            $auditoria += [pscustomobject]$caseAudit
            $state.completedCandidates = @($completed.Keys | Sort-Object)
            $state.resultKeys = @($resultKeys.Keys | Sort-Object)
            $state.updatedAt = (Get-Date).ToString('o')
            $state.status = 'RUNNING'
            Save-JsonAtomic -Value $state -Path $statePath
            Save-JsonAtomic -Value ([ordered]@{ runName=$runName; updatedAt=(Get-Date).ToString('o'); counters=$contadores; candidates=$auditoria }) -Path $auditPath
        }
    }
    $state.status = 'COMPLETED'
} catch {
    $state.status = 'INTERRUPTED'
    throw
} finally {
    $state.updatedAt = (Get-Date).ToString('o')
    $state.completedCandidates = @($completed.Keys | Sort-Object)
    $state.resultKeys = @($resultKeys.Keys | Sort-Object)
    Save-JsonAtomic -Value $state -Path $statePath
    Save-JsonAtomic -Value ([ordered]@{ runName=$runName; updatedAt=(Get-Date).ToString('o'); status=$state.status; counters=$contadores; candidates=$auditoria }) -Path $auditPath
    if ($null -ne $script:pncpHttpClient) { $script:pncpHttpClient.Dispose() }
    if ($null -ne $script:pncpHttpHandler) { $script:pncpHttpHandler.Dispose() }
}

Write-Host "[OK] Coleta concluida."
Write-Host "[OK] Resultados Compras.gov em dataResultado=${dataInicio}: $($contadores.resultadosFonteComprasGov)"
Write-Host "[OK] Dados acumulados: $jsonlPath"
Write-Host "[OK] Auditoria: $auditPath"
