# Arquitetura do GSB Monitor V2.5

## Fluxo autorizado

1. Uma descoberta limpa produz identificadores `cnpj`, `ano` e `sequencial`.
2. O caminho desse CSV é fornecido explicitamente ao executor.
3. O coletor consulta contratação, itens, resultados e histórico.
4. O EVT007 é selecionado exclusivamente por `dataResultado` no D-1 configurado.
5. O histórico confirma inclusão do resultado e origem Compras.gov.
6. Os dados brutos e o checkpoint são gravados localmente.
7. O qualificador aplica catálogo, valores, regras de lotes e rotas comerciais.
8. O monitor consome apenas uma saída nova produzida pelo V2.5.

## Separação de responsabilidades

- `src/Coletar_EVT007.ps1`: comunicação com a API e auditoria factual.
- `src/Qualificar_EVT007.ps1`: interpretação comercial posterior à coleta.
- `config/api/`: nomenclatura oficial da API.
- `config/comercial/`: regras GSB, sem alteração dos nomes oficiais.
- `config/execucao/`: janela e controles técnicos.
- `monitor/`: apresentação, sem dados embarcados.
- `docs/`: fontes locais do Manual 2.5 e OpenAPI.

## Barreira de contaminação

O repositório não contém nem deve aceitar:

- candidatos importados do V2;
- checkpoints ou bases históricas do V2;
- feeds reais ou simulados do monitor antigo;
- SQLite, JSONL, CSV de resultados ou arquivos ZIP;
- fallback automático para janela superior a D-1;
- `dataPublicacaoPncp` como substituta de `dataResultado`.

A geração nacional da amostra limpa ainda é uma etapa independente do coletor. Até que esse componente seja aprovado, o motor somente executa com `-CandidateCsv` informado expressamente.

