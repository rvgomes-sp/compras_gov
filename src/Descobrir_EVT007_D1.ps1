param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$DataResultado,
    [ValidateRange(1,500)]
    [int]$TamanhoPagina = 10,
    [ValidateRange(1,10000)]
    [int]$MaxPaginas = 1,
    [switch]$TodasPaginas,
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$configPath = Join-Path $Root "config\api\descoberta_comprasgov_dados_abertos.json"
$execPath = Join-Path $Root "config\execucao\teste_d1.json"
foreach ($path in @($configPath, $execPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Arquivo obrigatorio nao encontrado: $path" }
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$exec = Get-Content -LiteralPath $execPath -Raw -Encoding UTF8 | ConvertFrom-Json

$data = [datetime]::MinValue
if (-not [datetime]::TryParseExact($DataResultado, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$data)) {
    throw "DataResultado invalida. Use exatamente AAAA-MM-DD."
}
if ($DataResultado -ne [string]$exec.dataResultadoInicial -or $DataResultado -ne [string]$exec.dataResultadoFinal) {
    throw "A descoberta deve usar o mesmo D-1 definido em config\execucao\teste_d1.json: $($exec.dataResultadoInicial)."
}
if ($TamanhoPagina -gt [int]$config.parametrosPaginacao.tamanhoPaginaMaximo) {
    throw "TamanhoPagina excede o maximo oficial de $($config.parametrosPaginacao.tamanhoPaginaMaximo)."
}

$dataCompacta = $DataResultado.Replace('-', '')
$runName = "evt007_$dataCompacta"
$runRoot = Join-Path $Root "data\descoberta\$runName"
$rawRoot = Join-Path $runRoot "raw"
$batchRoot = Join-Path $runRoot "lotes"
$checkpointPath = Join-Path $runRoot "checkpoint.json"
$auditPath = Join-Path $runRoot "auditoria.json"
$partialCsvPath = Join-Path $runRoot "candidatos_tecnicos_PARCIAL.csv"
$completeCsvPath = Join-Path $runRoot "candidatos_tecnicos.csv"

if ($Reiniciar -and (Test-Path -LiteralPath $runRoot)) {
    Remove-Item -LiteralPath $runRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $rawRoot, $batchRoot | Out-Null

function Save-JsonAtomic {
    param([Parameter(Mandatory=$true)]$Value, [Parameter(Mandatory=$true)][string]$Path)
    $temp = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Save-CandidatesAtomic {
    param([Parameter(Mandatory=$true)][hashtable]$Candidates, [Parameter(Mandatory=$true)][string]$Path)
    $temp = "$Path.tmp"
    $linhas = [System.Collections.Generic.List[string]]::new()
    $linhas.Add('cnpj;ano;sequencial')
    foreach ($key in @($Candidates.Keys | Sort-Object)) {
        $candidate = $Candidates[$key]
        $linhas.Add("$($candidate.cnpj);$($candidate.ano);$($candidate.sequencial)")
    }
    $linhas | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Save-Batches {
    param([Parameter(Mandatory=$true)][hashtable]$Candidates, [Parameter(Mandatory=$true)][string]$Path)
    Get-ChildItem -LiteralPath $Path -Filter 'candidatos_lote_*.csv' -File -ErrorAction SilentlyContinue | Remove-Item -Force
    $keys = @($Candidates.Keys | Sort-Object)
    $batchSize = [int]$exec.maximoCandidatosPorRodada
    for ($offset = 0; $offset -lt $keys.Count; $offset += $batchSize) {
        $numeroLote = [int]([math]::Floor($offset / $batchSize) + 1)
        $fim = [math]::Min($offset + $batchSize - 1, $keys.Count - 1)
        $lote = @{}
        foreach ($index in $offset..$fim) {
            $key = $keys[$index]
            $lote[$key] = $Candidates[$key]
        }
        $pathLote = Join-Path $Path ("candidatos_lote_{0:D3}.csv" -f $numeroLote)
        Save-CandidatesAtomic -Candidates $lote -Path $pathLote
    }
}

function Parse-NumeroControlePNCPCompra {
    param([string]$NumeroControle)
    if ([string]::IsNullOrWhiteSpace($NumeroControle)) { return $null }
    $match = [regex]::Match($NumeroControle, '^(?<cnpj>\d{14})-\d+-(?<sequencial>\d+)/(?<ano>\d{4})$')
    if (-not $match.Success) { return $null }
    return [pscustomobject]@{
        cnpj = $match.Groups['cnpj'].Value
        ano = [int]$match.Groups['ano'].Value
        sequencial = [int]$match.Groups['sequencial'].Value
    }
}

$state = if (Test-Path -LiteralPath $checkpointPath) {
    Get-Content -LiteralPath $checkpointPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    [pscustomobject]@{
        runName = $runName
        fonte = [string]$config.fonte
        dataResultadoPncpInicial = $DataResultado
        dataResultadoPncpFinal = $DataResultado
        tamanhoPagina = $TamanhoPagina
        paginasConcluidas = @()
        candidatos = @()
        totalRegistrosInformado = $null
        totalPaginasInformado = $null
        counters = [pscustomobject]@{
            registrosLidos = 0
            registrosDataResultado = 0
            registrosDataDivergente = 0
            numerosControleInvalidos = 0
            resultadosSemFornecedor = 0
            resultadosSemDataInclusaoPncp = 0
        }
        startedAt = (Get-Date).ToString('o')
        updatedAt = (Get-Date).ToString('o')
        status = 'RUNNING'
    }
}
if ([int]$state.tamanhoPagina -ne $TamanhoPagina) {
    throw "Checkpoint criado com tamanhoPagina=$($state.tamanhoPagina). Use o mesmo valor ou execute com -Reiniciar."
}

$completedPages = @{}
foreach ($page in @($state.paginasConcluidas)) { $completedPages[[int]$page] = $true }
$candidates = @{}
foreach ($candidate in @($state.candidatos)) {
    $key = "$($candidate.cnpj)|$($candidate.ano)|$($candidate.sequencial)"
    $candidates[$key] = [pscustomobject]@{ cnpj=[string]$candidate.cnpj; ano=[int]$candidate.ano; sequencial=[int]$candidate.sequencial }
}

$counters = [ordered]@{
    paginasConcluidas = $completedPages.Count
    registrosLidos = [int64]$state.counters.registrosLidos
    registrosDataResultado = [int64]$state.counters.registrosDataResultado
    registrosDataDivergente = [int64]$state.counters.registrosDataDivergente
    numerosControleInvalidos = [int64]$state.counters.numerosControleInvalidos
    resultadosSemFornecedor = [int64]$state.counters.resultadosSemFornecedor
    resultadosSemDataInclusaoPncp = [int64]$state.counters.resultadosSemDataInclusaoPncp
    candidatosUnicos = $candidates.Count
}

Add-Type -AssemblyName System.Net.Http
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $true
$handler.MaxAutomaticRedirections = 10
$handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(120)
$client.DefaultRequestHeaders.Accept.Clear()
$client.DefaultRequestHeaders.Accept.ParseAdd('application/json')

function Invoke-DadosAbertosJson {
    param([Parameter(Mandatory=$true)][string]$Uri)
    $ultimaFalha = $null
    for ($tentativa = 1; $tentativa -le [int]$exec.tentativas; $tentativa++) {
        $response = $null
        try {
            $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
            $status = [int]$response.StatusCode
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $effectiveUri = $response.RequestMessage.RequestUri.AbsoluteUri
            if (([System.Uri]$effectiveUri).Scheme -ne 'https') { throw "Redirecionamento recusado por nao usar HTTPS: $effectiveUri" }
            if ($status -ge 200 -and $status -lt 300) {
                Start-Sleep -Milliseconds ([int]$exec.pausaMilissegundos)
                if ([string]::IsNullOrWhiteSpace($body)) { throw "Resposta vazia: $Uri" }
                return ($body | ConvertFrom-Json)
            }
            if ($status -eq 429) {
                $ultimaFalha = "HTTP 429 ao consultar $Uri"
                $espera = [int]$exec.pausa429Segundos * $tentativa
                Write-Warning "HTTP 429. Aguardando $espera segundos. Tentativa $tentativa/$($exec.tentativas)."
                Start-Sleep -Seconds $espera
                continue
            }
            if ($status -in @(408,425,500,502,503,504)) {
                $ultimaFalha = "HTTP $status ao consultar $Uri"
                $espera = [math]::Min(60, [math]::Pow(2, $tentativa))
                Write-Warning "HTTP $status. Nova tentativa em $espera segundos."
                Start-Sleep -Seconds $espera
                continue
            }
            $snippet = if ([string]::IsNullOrWhiteSpace($body)) { '(resposta sem corpo)' } else { $body.Substring(0, [math]::Min(500, $body.Length)) }
            throw "HTTP $status ao consultar $Uri`n$snippet"
        } catch {
            $ultimaFalha = $_.Exception.Message
            if ($tentativa -lt [int]$exec.tentativas) {
                $espera = [math]::Min(60, [math]::Pow(2, $tentativa))
                Write-Warning "Falha de consulta. Nova tentativa em $espera segundos."
                Start-Sleep -Seconds $espera
                continue
            }
        } finally {
            if ($null -ne $response) { $response.Dispose() }
        }
    }
    throw "Falha apos $($exec.tentativas) tentativas: $Uri`n$ultimaFalha"
}

$totalPages = if ($null -ne $state.totalPaginasInformado) { [int]$state.totalPaginasInformado } else { 0 }
$statusFinal = 'INTERRUPTED'
try {
    $page = 1
    while ($true) {
        if ($totalPages -gt 0 -and $page -gt $totalPages) { break }
        if (-not $TodasPaginas -and $page -gt $MaxPaginas) { break }
        if ($completedPages.ContainsKey($page)) { $page++; continue }

        $base = ([string]$config.baseUrl).TrimEnd('/') + '/' + ([string]$config.endpoint).TrimStart('/')
        $query = @(
            "$($config.parametrosPaginacao.pagina)=$page",
            "$($config.parametrosPaginacao.tamanhoPagina)=$TamanhoPagina",
            "$($config.parametrosTemporais.inicial)=$DataResultado",
            "$($config.parametrosTemporais.final)=$DataResultado"
        ) -join '&'
        $uri = "$base`?$query"
        Write-Host "[Pagina $page] $uri"
        $payload = Invoke-DadosAbertosJson -Uri $uri

        if ($null -eq $payload.resultado -or $null -eq $payload.totalRegistros -or $null -eq $payload.totalPaginas) {
            throw "Resposta fora do contrato esperado na pagina ${page}: resultado, totalRegistros ou totalPaginas ausente."
        }
        if ($totalPages -eq 0) {
            $totalPages = [int]$payload.totalPaginas
            $state.totalPaginasInformado = $totalPages
            $state.totalRegistrosInformado = [int64]$payload.totalRegistros
        } elseif ($totalPages -ne [int]$payload.totalPaginas) {
            throw "totalPaginas mudou durante a rodada: $totalPages -> $($payload.totalPaginas)."
        }

        $rawPath = Join-Path $rawRoot ("pagina_{0:D5}.json" -f $page)
        Save-JsonAtomic -Value $payload -Path $rawPath
        foreach ($result in @($payload.resultado)) {
            $counters.registrosLidos++
            $resultDate = [string]$result.dataResultadoPncp
            if ($resultDate.Length -lt 10 -or $resultDate.Substring(0,10) -ne $DataResultado) {
                $counters.registrosDataDivergente++
                continue
            }
            $counters.registrosDataResultado++
            if (-not $result.niFornecedor -or -not $result.nomeRazaoSocialFornecedor) { $counters.resultadosSemFornecedor++ }
            if (-not $result.dataInclusaoPncp) { $counters.resultadosSemDataInclusaoPncp++ }

            $candidate = Parse-NumeroControlePNCPCompra -NumeroControle ([string]$result.numeroControlePNCPCompra)
            if ($null -eq $candidate) {
                $counters.numerosControleInvalidos++
                continue
            }
            $key = "$($candidate.cnpj)|$($candidate.ano)|$($candidate.sequencial)"
            $candidates[$key] = $candidate
        }

        $completedPages[$page] = $true
        $counters.paginasConcluidas = $completedPages.Count
        $counters.candidatosUnicos = $candidates.Count
        $state.paginasConcluidas = @($completedPages.Keys | Sort-Object)
        $state.candidatos = @($candidates.Keys | Sort-Object | ForEach-Object { $candidates[$_] })
        $state.counters = [pscustomobject]@{
            registrosLidos = $counters.registrosLidos
            registrosDataResultado = $counters.registrosDataResultado
            registrosDataDivergente = $counters.registrosDataDivergente
            numerosControleInvalidos = $counters.numerosControleInvalidos
            resultadosSemFornecedor = $counters.resultadosSemFornecedor
            resultadosSemDataInclusaoPncp = $counters.resultadosSemDataInclusaoPncp
        }
        $state.updatedAt = (Get-Date).ToString('o')
        $state.status = 'RUNNING'
        Save-JsonAtomic -Value $state -Path $checkpointPath
        Save-CandidatesAtomic -Candidates $candidates -Path $partialCsvPath
        $page++
    }

    $complete = ($totalPages -gt 0 -and $completedPages.Count -eq $totalPages)
    if ($complete) {
        Save-CandidatesAtomic -Candidates $candidates -Path $completeCsvPath
        Save-Batches -Candidates $candidates -Path $batchRoot
        if (Test-Path -LiteralPath $partialCsvPath) { Remove-Item -LiteralPath $partialCsvPath -Force }
        $statusFinal = 'COMPLETED'
    } else {
        Save-CandidatesAtomic -Candidates $candidates -Path $partialCsvPath
        $statusFinal = 'PARTIAL'
    }
} finally {
    $state.paginasConcluidas = @($completedPages.Keys | Sort-Object)
    $state.candidatos = @($candidates.Keys | Sort-Object | ForEach-Object { $candidates[$_] })
    $state.counters = [pscustomobject]@{
        registrosLidos = $counters.registrosLidos
        registrosDataResultado = $counters.registrosDataResultado
        registrosDataDivergente = $counters.registrosDataDivergente
        numerosControleInvalidos = $counters.numerosControleInvalidos
        resultadosSemFornecedor = $counters.resultadosSemFornecedor
        resultadosSemDataInclusaoPncp = $counters.resultadosSemDataInclusaoPncp
    }
    $state.updatedAt = (Get-Date).ToString('o')
    $state.status = $statusFinal
    Save-JsonAtomic -Value $state -Path $checkpointPath
    $coverage = if ($statusFinal -eq 'COMPLETED') { 'COMPLETA' } elseif ($statusFinal -eq 'PARTIAL') { 'PARCIAL' } else { 'INTERROMPIDA' }
    Save-JsonAtomic -Value ([ordered]@{
        runName = $runName
        fonte = [string]$config.fonte
        endpoint = ([string]$config.baseUrl).TrimEnd('/') + '/' + ([string]$config.endpoint).TrimStart('/')
        dataResultadoPncpInicial = $DataResultado
        dataResultadoPncpFinal = $DataResultado
        cobertura = $coverage
        totalRegistrosInformado = $state.totalRegistrosInformado
        totalPaginasInformado = $state.totalPaginasInformado
        paginasConcluidas = @($completedPages.Keys | Sort-Object)
        counters = $counters
        updatedAt = (Get-Date).ToString('o')
    }) -Path $auditPath
    $client.Dispose()
    $handler.Dispose()
}

if ($statusFinal -eq 'COMPLETED') {
    Write-Host "[OK] Descoberta D-1 completa: $completeCsvPath"
    Write-Host "[OK] Lotes de ate $($exec.maximoCandidatosPorRodada) candidatos: $batchRoot"
} else {
    Write-Warning "Descoberta PARCIAL. Nao representa cobertura nacional e nao deve ser apresentada como base comercial."
    Write-Host "[OK] Candidatos tecnicos parciais: $partialCsvPath"
}
Write-Host "[OK] Auditoria: $auditPath"
