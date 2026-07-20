# Descoberta do EVT007 no Dados Abertos Compras.gov

## Objetivo

Enumerar, com cobertura mensurável, os resultados de itens cuja `dataResultadoPncp` pertence exatamente ao D-1 autorizado. Essa etapa forma a lista técnica de contratações que será confirmada pelo núcleo PNCP 2.5.

## Fonte e parâmetros oficiais

```text
GET https://dadosabertos.compras.gov.br/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133
```

| Elemento | Nomenclatura oficial | Uso no V2.5 |
|---|---|---|
| Data inicial | `dataResultadoPncpInicial` | Igual ao D-1 configurado. |
| Data final | `dataResultadoPncpFinal` | Igual à data inicial; janela de um único dia. |
| Página | `pagina` | Paginação reiniciável e auditável. |
| Tamanho | `tamanhoPagina` | 10 no teste inicial; até 500 após autorização da rodada completa. |
| Coleção | `resultado` | Resultados de itens retornados na página. |
| Total de registros | `totalRegistros` | Denominador de cobertura informado pela fonte. |
| Total de páginas | `totalPaginas` | Condição de conclusão da descoberta. |
| Chave PNCP | `numeroControlePNCPCompra` | Origina `cnpj`, `ano` e `sequencial`. |
| Data do evento | `dataResultadoPncp` | Deve coincidir com o D-1 solicitado. |
| Data de entrada | `dataInclusaoPncp` | Preservada e auditada; não substitui a data do evento. |

## Evidência do teste manual

Para `2026-07-17`, a exportação manual fornecida apresentou `totalRegistros = 7744`, `totalPaginas = 775` com página de 10 registros e `paginasRestantes = 774`. Esses números descrevem resultados de itens, não 7.744 contratações únicas.

## Barreira entre descoberta e núcleo

- A descoberta não aplica modalidade, objeto, catálogo, valor, lote ou rota comercial.
- O arquivo `candidatos_tecnicos_PARCIAL.csv` é diagnóstico e não pode alimentar base comercial.
- Apenas a conclusão de todas as páginas gera `candidatos_tecnicos.csv` e lotes.
- O núcleo PNCP 2.5 consulta 10.5, 10.13, 10.17 e 10.19 para confirmar modalidade, itens, resultado, `dataInclusao`, histórico e origem Compras.gov.
- O vencedor deve possuir `niFornecedor` e `nomeRazaoSocialFornecedor` na confirmação factual.
- `dataPublicacaoPncp` e `dataAtualizacao` não são fallback.

## Sequência controlada

1. Validar a estrutura.
2. Executar uma página de 10 registros.
3. Conferir `auditoria.json`, página bruta e CSV parcial.
4. Autorizar explicitamente todas as páginas com tamanho 500.
5. Conferir cobertura completa e os lotes deduplicados.
6. Executar cada lote no núcleo PNCP 2.5.
7. Qualificar comercialmente somente os resultados confirmados.
