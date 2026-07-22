# Contrato da primeira base factual utilizável — EVT007

## Fonte e janela

- Fonte: `COMPRASGOV_DADOS_ABERTOS`.
- Endpoint da descoberta: `3_consultarResultadoItensContratacoes_PNCP_14133`.
- Data do evento: `dataResultadoPncp`.
- Janela: somente D-1 configurado.
- Entrada da consolidação: páginas `pagina_*.json` já arquivadas e respectiva `auditoria.json`.
- Rede durante a consolidação: proibida.

## Unidade factual

A unidade factual é o resultado de item retornado pelo endpoint oficial. A chave de deduplicação é composta por:

- `idCompraItem`;
- `sequencialResultado`;
- `niFornecedor`;
- `dataResultadoPncp`.

## Base integral e base utilizável

| Saída | Conteúdo | Finalidade |
|---|---|---|
| Resultados factuais | Todos os resultados D-1 deduplicados | Auditoria e rastreabilidade |
| Resultados factuais utilizáveis | Resultado não cancelado e com fornecedor identificado | Uso factual imediato, ainda não comercial |
| Contratações factuais | Agrupamento por `numeroControlePNCPCompra` | Visão do evento por contratação |
| Fornecedores factuais | Agrupamento por `niFornecedor` | Visão dos vencedores informados no D-1 |

Nenhuma dessas saídas é uma base comercial qualificada.

## Campo de valor

`gsbValorHomologadoResultadosD1` soma `valorTotalHomologado` dos resultados factuais utilizáveis encontrados no D-1. O nome evita afirmar que se trata do valor total da contratação.

## Campos calculados

Todo campo não retornado diretamente pela fonte começa com `gsb`. Entre eles:

- `gsbChaveResultado`;
- `gsbDeltaInclusaoHoras`;
- `gsbCancelado`;
- `gsbFornecedorIdentificado`;
- `gsbRegistroFactualUtilizavel`;
- `gsbValorHomologadoResultadosD1`;
- `gsbOrigemPlataforma`;
- `gsbStatusEnriquecimentoItem`;
- `gsbClassificacaoComercial`;
- `gsbBaseComercial`.

## Ressalvas obrigatórias

1. O domínio do endpoint comprova a fonte da extração, mas não confirma a plataforma de origem da contratação.
2. O resultado não traz descrição, tipo e código de catálogo do item.
3. Modalidade e objeto permanecem pendentes.
4. CATSER e CATMAT não são aplicados nesta camada.
5. Nenhuma rota, corte de valor ou tese comercial é aplicada.
6. A consolidação padrão recusa cobertura parcial.
7. Hashes das entradas e saídas são registrados na auditoria.
