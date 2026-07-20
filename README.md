# GSB Monitor V2.5 — EVT007

Motor de coleta, auditoria e qualificação comercial do evento de resultado de item homologado no PNCP.

## Fonte normativa

- Manual de Integração do PNCP v. 2.5.
- `dataResultado` define o EVT007.
- `dataInclusao` é preservada para medir a entrada do resultado no PNCP.
- `logManutencaoDataInclusao` registra a manutenção do recurso.
- `dataPublicacaoPncp` não substitui `dataResultado`.
- A origem Compras.gov é confirmada por `usuarioNome` no histórico da contratação.

## Descoberta nacional limpa

A enumeração nacional do D-1 é feita por uma camada separada no serviço oficial de Dados Abertos do Compras.gov:

```text
GET https://dadosabertos.compras.gov.br/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133
```

Os filtros temporais são exatamente `dataResultadoPncpInicial` e `dataResultadoPncpFinal`. A descoberta preserva as páginas JSON brutas e produz a chave técnica `cnpj;ano;sequencial`. Ela não substitui a confirmação pelo Manual PNCP 2.5.

Primeiro teste, limitado a uma página de 10 registros:

```powershell
.\Descobrir_EVT007_D1.ps1 -DataResultado "2026-07-17" -TamanhoPagina 10 -MaxPaginas 1 -Reiniciar
```

Essa execução gera uma saída marcada `PARCIAL`, que serve somente para validar estrutura, datas, paginação e conversão de chaves. Ela não é base nacional nem base comercial.

Após a conferência da auditoria, a paginação completa é autorizada expressamente com:

```powershell
.\Descobrir_EVT007_D1.ps1 -DataResultado "2026-07-17" -TamanhoPagina 500 -TodasPaginas -Reiniciar
```

## Proteção contra contaminação do V2

Este repositório não contém:

- candidatos extraídos do GSB Monitor V2;
- importador de candidatos do V2;
- checkpoints, resultados, feeds ou bases do V2;
- caminho padrão que possa reutilizar silenciosamente uma amostra anterior.

O arquivo de candidatos deve ser criado pela descoberta limpa e informado explicitamente na execução. O formato técnico exigido pelos endpoints é:

```text
cnpj;ano;sequencial
```

A presença desses identificadores apenas habilita a consulta. Ela não comprova homologação, D-1, origem Compras.gov nem qualificação comercial.

## Fluxo do EVT007

1. Enumerar resultados de itens pelo Dados Abertos com `dataResultadoPncpInicial = dataResultadoPncpFinal = D-1`.
2. Preservar cada página bruta e deduplicar `cnpj;ano;sequencial`.
3. Consultar a contratação pelo endpoint 10.5 do Manual PNCP 2.5.
4. Consultar os itens pelo endpoint 10.13.
5. Consultar os resultados pelo endpoint 10.17.
6. Confirmar exclusivamente `dataResultado` do D-1 configurado.
7. Confirmar inclusão e origem Compras.gov pelo endpoint 10.19.
8. Gravar respostas brutas, resultados e checkpoint.
9. Aplicar catálogo, cortes de valor, regras de lotes e rotas comerciais.
10. Gerar base detalhada, base comercial e auditoria.

## Execução

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\GSB\monitor_v2\monitor_v2.5_atual
.\Executar_EVT007_D1.ps1 -CandidateCsv "C:\caminho\amostra_limpa.csv"
```

Não execute o motor sem uma amostra limpa identificada e autorizada.

## Estrutura

- `src/Coletar_EVT007.ps1`: coleta e auditoria do EVT007.
- `src/Descobrir_EVT007_D1.ps1`: descoberta nacional controlada no Dados Abertos Compras.gov.
- `src/Qualificar_EVT007.ps1`: qualificação comercial posterior à coleta.
- `config/api/`: contrato de endpoints e campos do Manual 2.5.
- `config/comercial/`: catálogo e regras comerciais.
- `config/execucao/`: janela, modalidades e controles da rodada.
- `tests/`: validações contra janelas indevidas e herança do V2.
- `monitor/`: interface do monitor, sem feeds ou dados antigos.
- `docs/pncp_v2.5/`: Manual 2.5, OpenAPI e referências de endpoints.

## Saídas locais

- `data/raw/evt007_AAAAMMDD/*.json`: respostas integrais por contratação.
- `data/descoberta/evt007_AAAAMMDD/raw/*.json`: páginas brutas da descoberta.
- `data/descoberta/evt007_AAAAMMDD/auditoria.json`: cobertura e qualidade da descoberta.
- `data/descoberta/evt007_AAAAMMDD/candidatos_tecnicos_PARCIAL.csv`: teste incompleto, proibido como base comercial.
- `data/descoberta/evt007_AAAAMMDD/candidatos_tecnicos.csv`: saída somente quando todas as páginas foram concluídas.
- `data/descoberta/evt007_AAAAMMDD/lotes/*.csv`: lotes completos de até 500 contratações para o núcleo PNCP 2.5.
- `data/state/evt007_AAAAMMDD_resultados.jsonl`: resultados válidos acumulados.
- `data/state/evt007_AAAAMMDD_checkpoint.json`: retomada controlada.
- `output/comercial/*_detalhado_*.csv`: visão por item e resultado.
- `output/comercial/*_base_comercial_*.csv`: registros qualificados.
- `output/comercial/*_auditoria_*.json`: cobertura, falhas e contagens.

Uma lista vazia ou incompleta de identificadores nunca pode ser apresentada como prova de zero homologações nacionais.
