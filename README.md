# GSB Monitor V2.5 — EVT007

Motor de coleta, auditoria e qualificação comercial do evento de resultado de item homologado no PNCP.

## Fonte normativa

- Manual de Integração do PNCP v. 2.5.
- `dataResultado` define o EVT007.
- `dataInclusao` é preservada para medir a entrada do resultado no PNCP.
- `logManutencaoDataInclusao` registra a manutenção do recurso.
- `dataPublicacaoPncp` não substitui `dataResultado`.
- A origem Compras.gov é confirmada por `usuarioNome` no histórico da contratação.

## Proteção contra contaminação do V2

Este repositório não contém:

- candidatos extraídos do GSB Monitor V2;
- importador de candidatos do V2;
- checkpoints, resultados, feeds ou bases do V2;
- caminho padrão que possa reutilizar silenciosamente uma amostra anterior.

O arquivo de candidatos deve ser criado por uma nova coleta limpa e informado explicitamente na execução. O formato técnico exigido pelos endpoints é:

```text
cnpj;ano;sequencial
```

A presença desses identificadores apenas habilita a consulta. Ela não comprova homologação, D-1, origem Compras.gov nem qualificação comercial.

## Fluxo do EVT007

1. Receber uma amostra limpa e auditável de contratações.
2. Consultar a contratação pelo endpoint 10.5.
3. Consultar os itens pelo endpoint 10.13.
4. Consultar os resultados pelo endpoint 10.17.
5. Selecionar exclusivamente `dataResultado` do D-1 configurado.
6. Confirmar inclusão e origem Compras.gov pelo endpoint 10.19.
7. Gravar respostas brutas, resultados e checkpoint.
8. Aplicar catálogo, cortes de valor e rotas comerciais.
9. Gerar base detalhada, base comercial e auditoria.

## Execução

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\GSB\monitor_v2\monitor_v2.5
.\Executar_EVT007_D1.ps1 -CandidateCsv "C:\caminho\amostra_limpa.csv"
```

Não execute o motor sem uma amostra limpa identificada e autorizada.

## Estrutura

- `src/Coletar_EVT007.ps1`: coleta e auditoria do EVT007.
- `src/Qualificar_EVT007.ps1`: qualificação comercial posterior à coleta.
- `config/api/`: contrato de endpoints e campos do Manual 2.5.
- `config/comercial/`: catálogo e regras comerciais.
- `config/execucao/`: janela, modalidades e controles da rodada.
- `tests/`: validações contra janelas indevidas e herança do V2.
- `monitor/`: interface do monitor, sem feeds ou dados antigos.
- `docs/pncp_v2.5/`: Manual 2.5, OpenAPI e referências de endpoints.

## Saídas locais

- `data/raw/evt007_AAAAMMDD/*.json`: respostas integrais por contratação.
- `data/state/evt007_AAAAMMDD_resultados.jsonl`: resultados válidos acumulados.
- `data/state/evt007_AAAAMMDD_checkpoint.json`: retomada controlada.
- `output/comercial/*_detalhado_*.csv`: visão por item e resultado.
- `output/comercial/*_base_comercial_*.csv`: registros qualificados.
- `output/comercial/*_auditoria_*.json`: cobertura, falhas e contagens.

Uma lista vazia ou incompleta de identificadores nunca pode ser apresentada como prova de zero homologações nacionais.
