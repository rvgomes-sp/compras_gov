param(
    [string]$Root = $PSScriptRoot,
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

& (Join-Path $Root "src\Descobrir_EVT007_D1.ps1") `
    -Root $Root `
    -DataResultado $DataResultado `
    -TamanhoPagina $TamanhoPagina `
    -MaxPaginas $MaxPaginas `
    -TodasPaginas:$TodasPaginas `
    -Reiniciar:$Reiniciar
