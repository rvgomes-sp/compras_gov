# Descoberta do EVT007 no Dados Abertos Compras.gov

## Objetivo

Enumerar, com cobertura mensurável, os resultados de itens cuja `dataResultadoPncp` pertence exatamente ao D-1 autorizado e preservar o retorno oficial para a consolidação factual local.

## Fonte e parâmetros oficiais

```text
GET https://dadosabertos.compras.gov.br/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133
```

| Elemento | Nomenclatura oficial | Uso no V2.5 |
|---|---|---|
| Data inicial | `dataResultadoPncpInicial` | Igual ao D-1 configurado |
| Data final | `dataResultadoPncpFinal` | Igual à data inicial |
| Página | `pagina` | Paginação reiniciável e auditável |
| Tamanho | `tamanhoPagina` | Até 500 |
| Coleção | `resultado` | Resultados de itens |
| Total de registros | `totalRegistros` | Denominador informado pela fonte |
| Total de páginas | `totalPaginas` | Condição de conclusão |
| Chave PNCP | `numeroControlePNCPCompra` | Identificação da contratação |
| Data do evento | `dataResultadoPncp` | Deve coincidir com o D-1 |
| Data de entrada | `dataInclusaoPncp` | Preservada; não substitui a data do evento |

## Evidência da rodada de 17/07/2026

- 16 páginas concluídas com `tamanhoPagina = 500`;
- 7.744 resultados lidos;
- 1.022 contratações únicas;
- cobertura da consulta marcada `COMPLETA` na auditoria local.

Esses números descrevem resultados de itens e contratações únicas encontradas no retorno. Não representam registros comercialmente qualificados.

## Barreira de qualidade

- A descoberta não aplica modalidade, objeto, catálogo, valor, lote ou rota comercial.
- `candidatos_tecnicos_PARCIAL.csv` é somente diagnóstico.
- A conclusão preserva `candidatos_tecnicos.csv`, lotes, páginas brutas e auditoria.
- A consolidação factual usa diretamente as páginas brutas; os lotes não acionam mais as rotas que retornaram HTTP 301.
- O subconjunto factual utilizável exige `niFornecedor` e `nomeRazaoSocialFornecedor` e exclui resultados cancelados.
- A fonte do endpoint não confirma, por si só, a plataforma de origem da contratação.
- `dataPublicacaoPncp` e `dataAtualizacaoPncp` não são fallback de `dataResultadoPncp`.
- Enriquecimento de item e qualificação comercial permanecem bloqueados.

## Sequência ativa

1. Validar a estrutura.
2. Concluir e auditar todas as páginas D-1.
3. Preservar `raw\pagina_*.json` e `auditoria.json`.
4. Executar `Consolidar_EVT007_D1.ps1`.
5. Conferir a auditoria factual e as visões por resultado, contratação e fornecedor.
6. Não executar qualificação comercial antes do enriquecimento oficial.
