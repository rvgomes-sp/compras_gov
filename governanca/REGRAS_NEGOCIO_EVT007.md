# Regras de negócio — EVT007

## Evento e tempo

- Evento: resultado de item homologado.
- Data determinante na fonte de descoberta e na camada factual: `dataResultadoPncp`.
- Janela inicial: somente D-1 configurado.
- `dataInclusaoPncp`: preservada para medir entrada no PNCP.
- `logManutencaoDataInclusao`: preservada para auditar a manutenção.
- `dataAtualizacao`: não define o evento.
- `dataPublicacaoPncp`: não define nem substitui o EVT007.

## Origem e vencedor

- Fonte da camada factual: Compras.gov Dados Abertos.
- O domínio da fonte não confirma a plataforma de origem de cada contratação; o estado permanece `NAO_CONFIRMADA_NO_RESULTADO`.
- A confirmação histórica por `usuarioNome` permanece uma exigência comercial, mas a rota que a fornecia está bloqueada por HTTP 301 e não integra a primeira base factual.
- Campos comerciais obrigatórios: `niFornecedor` e `nomeRazaoSocialFornecedor`.
- Resultado cancelado permanece na base factual integral para auditoria e não entra no subconjunto factual utilizável.

## Barreira entre factual e comercial

- A primeira base factual não aplica catálogo, corte de valor, rota ou tese comercial.
- `gsbValorHomologadoResultadosD1` não é denominado valor total da contratação.
- A qualificação comercial permanece bloqueada enquanto descrição, `materialOuServico`, código CATSER/CATMAT, objeto, modalidade e origem não estiverem enriquecidos por fonte oficial.
- Ausência de dado não autoriza descarte automático, criação de evento posterior nem eliminação do caso.
- Falha temporária da fonte é registrada como estado técnico e não como decisão comercial.

## Modalidades do teste

- Nenhuma modalidade é excluída na descoberta, na confirmação ou na qualificação do EVT007.
- A antiga exclusão da modalidade 6 foi uma contenção técnica temporária para o endpoint anterior, após respostas HTTP 429; não constitui regra de negócio.
- A modalidade 6 — Pregão Eletrônico — permanece no fluxo, inclusive por concentrar serviços com mão de obra terceirizada relevantes para a tese de cobertura trabalhista.
- A modalidade é preservada no registro e na auditoria para análise, mas não funciona como filtro de entrada.

## Cortes e rotas

- Valor mínimo por item ou lote homologado: R$ 1.000.000,00.
- Total de R$ 1 milhão a R$ 10 milhões: `VIEIRA_MENDONCA`.
- Total acima de R$ 10 milhões: `VAZQUEZ_FONSECA`.
- A tese de limite de crédito aplica-se a todos os segmentos, especialmente construtoras com carteira simultânea de obras e redução de capacidade de emissão.
- A tese de cobertura trabalhista aplica-se quando houver mão de obra dedicada, dedicação exclusiva, postos de trabalho, terceirização ou serviço continuado.

## Prioridades e exclusões comerciais

- Prioridades: infraestrutura, obras, engenharia, saneamento, energia, portos, aeroportos, hidrelétricas, presídios, TIC crítica e serviços continuados com mão de obra dedicada.
- Material simples é não prioritário, sem exclusão automática da camada factual.
- Educação e concessões permanecem fora do recorte comercial atual, conservando-se o registro e o motivo.
- Federal é prioridade operacional; estadual e municipal permanecem elegíveis.
- Credenciamento não presume vencedor único.
- Sistema de Registro de Preços e ata direcionam o acompanhamento ao contrato ou instrumento derivado; não autorizam presumir contratação executada.

## Contratações com itens ou lotes

- A soma homologada da contratação define a rota inicial.
- Cada item ou lote precisa atender individualmente ao corte de valor e ao catálogo.
- Entre R$ 1 milhão e R$ 10 milhões, item fora do corte pode descartar a contratação inteira.
- Acima de R$ 10 milhões, item fora do corte permite o rebaixamento para `VIEIRA_MENDONCA`.
- Todo descarte ou rebaixamento deve conservar seu motivo na auditoria.

## Catálogo

- Chave oficial: `catalogoCodigoItem`.
- Para itens com `materialOuServico = S`, a chave é confrontada exclusivamente com o CATSER oficial.
- Materiais não são confrontados com códigos CATSER e recebem `CATMAT_NAO_APLICAVEL`.
- Status de execução: `APROVADO`, `REVISAO_MAO_DE_OBRA`, `NAO_PRIORITARIO`, `NAO_LOCALIZADO` ou `CATMAT_NAO_APLICAVEL`.
- A tabela integral também usa estados de governança que não promovem o item automaticamente: `REVISAO_SEGMENTO`, `NAO_CLASSIFICADO`, `INATIVO_CATSER` e `REVISAO_DIVERGENCIA_STATUS`.
- Item não localizado nunca é aprovado automaticamente.
- Palavras-chave auxiliam a tese comercial, mas não substituem o código oficial do catálogo.
- O arquivo oficial CATSER informado como atualizado em 18/07/2026 possui 3.095 serviços, dos quais 3.013 ativos e 82 inativos.
- Códigos e nomenclatura oficial permanecem intactos; os campos `gsb*` registram somente a decisão comercial interna.

## Controle e decisão humana

- Limites de páginas, requisições e casos são proteções técnicas; não são critérios comerciais.
- O radar só pode exibir casos registrados na fonte de verdade.
- Nenhuma oportunidade segue para abordagem sem validação humana expressa.
- A captura inicial de um caso em qualquer evento não apaga seus eventos anteriores ou posteriores; eventos são acumulativos.
