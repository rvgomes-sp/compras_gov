param(
    [string]$SourceRoot = "C:\GSB\monitor_v2",
    [string]$TargetRoot = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$TargetRoot = [System.IO.Path]::GetFullPath($TargetRoot)

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "Pasta de origem nao encontrada: $SourceRoot"
}

$pastas = @(
    "manual_2_5",
    "config\api",
    "config\comercial",
    "config\execucao",
    "data\candidatos",
    "data\raw",
    "data\state",
    "output\comercial",
    "migration\referencia_v2",
    "src",
    "tests"
)

foreach ($pasta in $pastas) {
    New-Item -ItemType Directory -Force -Path (Join-Path $TargetRoot $pasta) | Out-Null
}

$manifestoPath = Join-Path $TargetRoot "migration\manifesto_migracao_v2_v2_5.json"
if (-not (Test-Path -LiteralPath $manifestoPath)) {
    throw "Manifesto nao encontrado: $manifestoPath"
}

$manifesto = Get-Content -LiteralPath $manifestoPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inventarioPath = Join-Path $TargetRoot "migration\inventario_v2.csv"
$hashPath = Join-Path $TargetRoot "migration\hash_referencias_v2.csv"
$referenciaRoot = Join-Path $TargetRoot "migration\referencia_v2"

$arquivos = Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not $_.FullName.StartsWith($TargetRoot, [System.StringComparison]::OrdinalIgnoreCase) }

$inventario = foreach ($arquivo in $arquivos) {
    [pscustomobject]@{
        caminhoRelativo = $arquivo.FullName.Substring($SourceRoot.Length).TrimStart('\')
        tamanhoBytes = $arquivo.Length
        ultimaAlteracao = $arquivo.LastWriteTime.ToString("s")
    }
}

$inventario | Sort-Object caminhoRelativo |
    Export-Csv -LiteralPath $inventarioPath -Delimiter ';' -NoTypeInformation -Encoding UTF8

$hashes = @()
foreach ($relativo in $manifesto.copiarComoReferencia) {
    $origem = Join-Path $SourceRoot ([string]$relativo)
    if (-not (Test-Path -LiteralPath $origem)) {
        Write-Warning "Referencia nao localizada no V2: $relativo"
        continue
    }

    $nomeDestino = ([string]$relativo) -replace '[\\/:*?"<>|]', '__'
    $destino = Join-Path $referenciaRoot $nomeDestino
    Copy-Item -LiteralPath $origem -Destination $destino -Force
    $hash = Get-FileHash -LiteralPath $destino -Algorithm SHA256
    $hashes += [pscustomobject]@{
        origem = $origem
        destino = $destino
        algoritmo = $hash.Algorithm
        hash = $hash.Hash
    }
}

$hashes | Export-Csv -LiteralPath $hashPath -Delimiter ';' -NoTypeInformation -Encoding UTF8

Write-Host "[OK] Estrutura V2.5 preparada em: $TargetRoot"
Write-Host "[OK] Inventario do V2: $inventarioPath"
Write-Host "[OK] Referencias copiadas sem ativacao: $referenciaRoot"
Write-Host "[OK] Nenhum script antigo foi ativado."

