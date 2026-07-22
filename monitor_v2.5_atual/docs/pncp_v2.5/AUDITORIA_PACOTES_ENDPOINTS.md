# Auditoria dos pacotes locais de endpoints PNCP v. 2.5

## Escopo

Comparação realizada exclusivamente entre os três pacotes locais fornecidos ao projeto e a documentação versionada no repositório. Não houve consulta à internet nem execução da API do PNCP.

Pacotes examinados:

- `10_Endpoints_PNCP_2_5_Compras_files.zip`
- `11_11_Endpoites_pncp_v. 2.5.zip`
- `11_Atas_Endpoint_pncp_2_5_files.zip`

## Resultado do inventário

| Pacote | HTML | JSON | Arquivos auxiliares | Resultado |
|---|---:|---:|---:|---|
| `10_Endpoints_PNCP_2_5_Compras_files.zip` | 0 | 0 | 270, em 27 diretórios `_files` | Somente CSS e JavaScript repetidos; não contém páginas de endpoint. |
| `11_11_Endpoites_pncp_v. 2.5.zip` | 7 | 0 | 0 | As sete páginas já estavam versionadas e são idênticas às originais. |
| `11_Atas_Endpoint_pncp_2_5_files.zip` | 0 | 0 | 60, em 6 diretórios `_files` | Somente CSS e JavaScript repetidos; não contém páginas de endpoint. |

## Páginas substantivas conferidas

As páginas abaixo foram confrontadas por hash SHA-256 com os arquivos do pacote e não apresentam diferença:

| Seção | Arquivo versionado |
|---|---|
| 10.17 | `endpoints/compras/10.17_consultar_resultados_item.html` |
| 10.18 | `endpoints/compras/10.18_consultar_resultado_especifico_item.html` |
| 10.19 | `endpoints/compras/10.19_consultar_historico_contratacao.html` |
| 11.5 | `endpoints/atas/11.5_consultar_atas_por_compra.html` |
| 11.12 | `endpoints/atas/11.12_consultar_contratos_ata.html` |
| 11.13 | `endpoints/atas/11.13_inserir_parte_envolvida_ata.html` |
| 11.16 | `endpoints/atas/11.16_consultar_partes_envolvidas_ata.html` |

O Manual PNCP v. 2.5 completo e o OpenAPI integral também permanecem versionados em `manual/` e `openapi/`. Os pacotes ZIP e os diretórios `_files` não devem ser adicionados ao repositório, pois duplicam conteúdo e não acrescentam operações, parâmetros ou esquemas.

## Efeito sobre a descoberta do EVT007

A auditoria continua correta quanto ao seu escopo: o Manual PNCP 2.5 e seus endpoints de integração não apresentam operação nacional que enumere resultados por período.

Posteriormente foi identificada, fora do Manual PNCP 2.5 e dentro do serviço oficial de Dados Abertos do Compras.gov, a operação `Consultar resultado de itens de contratações`:

```text
GET https://dadosabertos.compras.gov.br/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133
```

Essa fonte aceita `dataResultadoPncpInicial` e `dataResultadoPncpFinal` e resolve a descoberta e a primeira camada factual. O retorno deve ser preservado integralmente. A consolidação factual valida `dataResultadoPncp`, preserva `dataInclusaoPncp`, fornecedor, valores e identificadores, sem retornar às rotas que permaneceram em HTTP 301. Objeto, modalidade, item, catálogo e plataforma de origem continuam pendentes de enriquecimento oficial; nenhuma regra comercial é aplicada nesta etapa.

É necessário distinguir as chaves por estágio:

| Estágio | Chave mínima | Utilidade |
|---|---|---|
| Descoberta de contratação para o fluxo atual | `cnpj;ano;sequencial` | Permite consultar a contratação, enumerar seus itens pelo endpoint 10.13 e então consultar resultados pelo 10.17. |
| Entrada direta no nível do item | `cnpj;ano;sequencial;numeroItem` | Permite consultar diretamente a coleção de resultados do item pelo endpoint 10.17. |
| Consulta direta de resultado específico | `cnpj;ano;sequencial;numeroItem;sequencialResultado` | Permite consultar um resultado específico pelo endpoint 10.18. |

Nenhuma dessas chaves comprova, isoladamente, que o registro pertence ao D-1, que a fonte é Compras.gov ou que o evento atende às regras comerciais. Essas condições devem ser confirmadas nos endpoints oficiais depois da descoberta auditável.

## Decisão

- Manter fora do controle de versão os três ZIPs e seus ativos `_files`.
- Manter as páginas HTML já organizadas em `endpoints/compras/` e `endpoints/atas/`.
- Usar o Dados Abertos Compras.gov como fonte oficial e auditável de descoberta, sem confundi-lo com o Manual PNCP 2.5.
- Preservar o bloqueio entre descoberta e coleta: arquivo parcial não aciona o núcleo.
- Não substituir `dataResultado` por `dataPublicacaoPncp`, `dataAtualizacao` ou qualquer outra data.
