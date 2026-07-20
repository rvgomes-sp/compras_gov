# Arquitetura do GSB Monitor V2.5

## Fluxo autorizado

1. O endpoint oficial de resultados de itens do Dados Abertos Compras.gov enumera o D-1 por `dataResultadoPncpInicial` e `dataResultadoPncpFinal`.
2. A descoberta preserva páginas brutas e produz identificadores únicos `cnpj`, `ano` e `sequencial`.
3. O caminho de cada lote completo é fornecido explicitamente ao executor.
4. O coletor consulta contratação, itens, resultados e histórico no núcleo PNCP 2.5.
5. O EVT007 é selecionado exclusivamente por `dataResultado` no D-1 configurado.
6. O histórico confirma inclusão do resultado e origem Compras.gov.
7. Os dados brutos e o checkpoint são gravados localmente.
8. O qualificador aplica catálogo, valores, regras de lotes e rotas comerciais.
9. O monitor consome apenas uma saída nova produzida pelo V2.5.

## Separação de responsabilidades

- `src/Descobrir_EVT007_D1.ps1`: enumeração nacional, paginação, checkpoint e conversão da chave oficial.
- `src/Coletar_EVT007.ps1`: confirmação factual no núcleo PNCP 2.5.
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

A descoberta permanece separada do coletor. Uma saída `PARCIAL` nunca pode acionar o núcleo automaticamente. Somente a conclusão de todas as páginas gera `candidatos_tecnicos.csv` e lotes de até 500 chaves; cada lote ainda precisa ser informado expressamente em `-CandidateCsv`.
