# Regras de negócio — EVT007

## Evento e tempo

- Evento: resultado de item homologado.
- Data determinante: `dataResultado`.
- Janela inicial: somente D-1 configurado.
- `dataInclusao`: preservada para medir entrada no PNCP.
- `logManutencaoDataInclusao`: preservada para auditar a manutenção.
- `dataAtualizacao`: não define o evento.
- `dataPublicacaoPncp`: não define nem substitui o EVT007.

## Origem e vencedor

- Fonte comercial permitida: Compras.gov.
- Confirmação: `usuarioNome` no histórico.
- Tipo de manutenção: inclusão (`tipoLogManutencao = 0`).
- Categoria: resultado do item (`categoriaLogManutencao = 5`).
- Campos comerciais obrigatórios: `niFornecedor` e `nomeRazaoSocialFornecedor`.
- Resultado cancelado não entra na base comercial.

## Modalidades do teste

- Permitidas: 2, 4, 5, 7, 10, 16, 17, 18 e 19.
- Excluída: 6 — Pregão Eletrônico.

## Cortes e rotas

- Valor mínimo por item ou lote homologado: R$ 1.000.000,00.
- Total de R$ 1 milhão a R$ 10 milhões: `VIEIRA_MENDONCA`.
- Total acima de R$ 10 milhões: `VAZQUEZ_FONSECA`.
- A tese de limite de crédito aplica-se a todos os segmentos, especialmente construtoras com carteira simultânea de obras e redução de capacidade de emissão.
- A tese de cobertura trabalhista aplica-se quando houver mão de obra dedicada, dedicação exclusiva, postos de trabalho, terceirização ou serviço continuado.

## Contratações com itens ou lotes

- A soma homologada da contratação define a rota inicial.
- Cada item ou lote precisa atender individualmente ao corte de valor e ao catálogo.
- Entre R$ 1 milhão e R$ 10 milhões, item fora do corte pode descartar a contratação inteira.
- Acima de R$ 10 milhões, item fora do corte permite o rebaixamento para `VIEIRA_MENDONCA`.
- Todo descarte ou rebaixamento deve conservar seu motivo na auditoria.

## Catálogo

- Chave oficial: `catalogoCodigoItem`.
- Status: `APROVADO`, `REVISAO_MAO_DE_OBRA`, `NAO_PRIORITARIO` ou `NAO_LOCALIZADO`.
- Item não localizado nunca é aprovado automaticamente.
- Palavras-chave auxiliam a tese comercial, mas não substituem o código oficial do catálogo.

