param(
    [string]$Root = $PSScriptRoot,
    [string]$DataResultado = "",
    [ValidateRange(1,500)]
    [int]$TamanhoPagina = 500,
    [ValidateRange(1,10000)]
    [int]$MaxPaginas = 1,
    [switch]$TodasPaginas,
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DataResultado)) {
    $DataResultado = (Get-Date).Date.AddDays(-1).ToString('yyyy-MM-dd')
}

& (Join-Path $Root "src\Descobrir_EVT007_D1.ps1") `
    -Root $Root `
    -DataResultado $DataResultado `
    -TamanhoPagina $TamanhoPagina `
    -MaxPaginas $MaxPaginas `
    -TodasPaginas:$TodasPaginas `
    -Reiniciar:$Reiniciar
