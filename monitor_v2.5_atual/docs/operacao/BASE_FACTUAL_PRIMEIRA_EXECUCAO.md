# Primeira execução da base factual EVT007

## Pré-condição

Preservar sem alteração:

```text
C:\GSB\monitor_v2\monitor_v2.5_atual\data\descoberta\evt007_20260717\auditoria.json
C:\GSB\monitor_v2\monitor_v2.5_atual\data\descoberta\evt007_20260717\raw\pagina_*.json
```

## Instalação

Extrair o pacote de atualização diretamente em:

```text
C:\GSB\monitor_v2\monitor_v2.5_atual
```

Confirmar a substituição dos arquivos do motor. O pacote não contém a pasta `data` e não apaga a descoberta existente.

## Comandos

Copiar somente os comandos, sem o texto `PS C:\...>`:

```powershell
Set-Location "C:\GSB\monitor_v2\monitor_v2.5_atual"
Set-ExecutionPolicy -Scope Process Bypass
.\tests\Validar_Estrutura.ps1
.\Executar_EVT007_D1.ps1 -DataResultado "2026-07-17" -Reiniciar
```

## Conferência da auditoria

```powershell
$A = Get-Content ".\output\factual\evt007_20260717\evt007_20260717_auditoria_factual.json" -Raw | ConvertFrom-Json
[PSCustomObject]@{ Cobertura=$A.coberturaDescoberta; ResultadosLidos=$A.counters.registrosLidos; ResultadosFatuais=$A.counters.registrosFatuaisIntegrais; ResultadosUtilizaveis=$A.counters.registrosFatuaisUtilizaveis; Contratacoes=$A.contratacoesFatuais; Fornecedores=$A.fornecedoresFatuais; ValorResultadosD1=$A.valorHomologadoResultadosFatuaisUtilizaveisD1; BaseComercial=$A.baseComercial }
```

## Saídas esperadas

```text
output\factual\evt007_20260717\evt007_20260717_resultados_fatuais.csv
output\factual\evt007_20260717\evt007_20260717_resultados_fatuais_utilizaveis.csv
output\factual\evt007_20260717\evt007_20260717_contratacoes_fatuais.csv
output\factual\evt007_20260717\evt007_20260717_fornecedores_fatuais.csv
output\factual\evt007_20260717\evt007_20260717_auditoria_factual.json
```

## Interpretação

- `resultados_fatuais.csv` preserva todos os resultados válidos do D-1 para auditoria.
- `resultados_fatuais_utilizaveis.csv` contém apenas resultados não cancelados e com fornecedor identificado.
- `contratacoes_fatuais.csv` agrupa por `numeroControlePNCPCompra`.
- `fornecedores_fatuais.csv` agrupa por `niFornecedor`.
- `baseComercial` deve permanecer `false`.
- Não executar `src\Coletar_EVT007.ps1` nem `src\Qualificar_EVT007.ps1`.
