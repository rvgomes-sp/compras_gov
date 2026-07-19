param(
    [string]$SourceRoot = "C:\GSB\monitor_v2",
    [string]$OutputCsv = (Join-Path $PSScriptRoot "data\candidatos\candidatos_evt007.csv")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$exportsRoot = Join-Path $SourceRoot "exports"
if (-not (Test-Path -LiteralPath $exportsRoot)) {
    throw "Pasta de exports do V2 nao encontrada: $exportsRoot"
}

$porChave = @{}
if (Test-Path -LiteralPath $OutputCsv) {
    foreach ($linha in @(Import-Csv -LiteralPath $OutputCsv -Delimiter ';')) {
        if ($linha.cnpj -and $linha.ano -and $linha.sequencial) {
            $chave = "$($linha.cnpj)|$($linha.ano)|$($linha.sequencial)"
            $porChave[$chave] = [pscustomobject]@{
                cnpj = [string]$linha.cnpj
                ano = [int]$linha.ano
                sequencial = [int]$linha.sequencial
            }
        }
    }
}

$regexCampo = [regex]'"numeroControlePNCP"\s*:\s*"(?<numero>[^"]+)"'
$regexNumero = [regex]'^(?<cnpj>[A-Za-z0-9]+)-\d+-(?<sequencial>\d+)/(?<ano>\d{4})$'
$arquivosLidos = 0
$ocorrencias = 0

foreach ($arquivo in Get-ChildItem -LiteralPath $exportsRoot -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue) {
    $arquivosLidos++
    $texto = Get-Content -LiteralPath $arquivo.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $texto) { continue }

    foreach ($matchCampo in $regexCampo.Matches($texto)) {
        $matchNumero = $regexNumero.Match($matchCampo.Groups['numero'].Value)
        if (-not $matchNumero.Success) { continue }
        $ocorrencias++
        $cnpj = $matchNumero.Groups['cnpj'].Value
        $ano = [int]$matchNumero.Groups['ano'].Value
        $sequencial = [int]$matchNumero.Groups['sequencial'].Value
        $chave = "$cnpj|$ano|$sequencial"
        $porChave[$chave] = [pscustomobject]@{
            cnpj = $cnpj
            ano = $ano
            sequencial = $sequencial
        }
    }
}

$pastaSaida = Split-Path -Parent $OutputCsv
New-Item -ItemType Directory -Force -Path $pastaSaida | Out-Null
$porChave.Values | Sort-Object cnpj, ano, sequencial |
    Export-Csv -LiteralPath $OutputCsv -Delimiter ';' -NoTypeInformation -Encoding UTF8

Write-Host "[OK] Arquivos JSON examinados: $arquivosLidos"
Write-Host "[OK] Ocorrencias oficiais de numeroControlePNCP: $ocorrencias"
Write-Host "[OK] Contratacoes candidatas unicas: $($porChave.Count)"
Write-Host "[OK] Arquivo: $OutputCsv"
Write-Warning "Esta importacao nao comprova cobertura nacional do D-1. Ela apenas reaproveita candidatos ja observados no V2."

