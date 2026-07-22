param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCsv = "",
    [switch]$Reiniciar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

throw "COLETOR DESATIVADO: as rotas /api/pncp/v1 permaneceram em HTTP 301 sem Location. Nao repita lotes ou CandidateCsv. Use Consolidar_EVT007_D1.ps1 para construir a camada factual diretamente das paginas oficiais D-1 preservadas."
