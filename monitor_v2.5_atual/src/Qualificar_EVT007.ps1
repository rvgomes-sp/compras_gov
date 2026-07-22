param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$DataResultado = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

throw "QUALIFICACAO COMERCIAL BLOQUEADA: a camada factual ainda nao possui descricao do item, materialOuServico, codigo CATSER/CATMAT, objeto, modalidade e confirmacao da plataforma de origem. Nenhuma base comercial deve ser gerada antes do enriquecimento oficial."
