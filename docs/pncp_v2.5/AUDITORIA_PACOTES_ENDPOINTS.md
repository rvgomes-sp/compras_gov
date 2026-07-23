# Auditoria documental PNCP 2.5

## Fontes canônicas

| Fonte | SHA-256 | Cobertura |
|---|---|---|
| Manual PNCP 2.5 completo | `26d5a5cff042faf28c09fd10e9edc32eaeca38f565ea8926699aab932e121449` | Documento integral |
| OpenAPI `api-docs.json` | `dfe448f39a3d6602d688465d2159fa75233ac56aa447dee115fbbcd2eb4fe7af` | 109 rotas e 190 operações |

## Decisão de consolidação

Em 22 de julho de 2026, os recortes HTML numerados das famílias de compras,
atas e órgãos foram retirados do repositório. Eles repetiam conteúdo já
preservado no Manual completo e no OpenAPI e criavam duas referências possíveis
para a mesma API.

A ausência do antigo diretório `endpoints/` passou a ser verificada pelos testes
do repositório. A documentação PNCP somente será atualizada pela substituição
controlada de uma fonte integral, com conferência de versão, cobertura e hash.

## Regras permanentes

- preservar uma única cópia do Manual e do OpenAPI;
- não versionar recortes HTML, ZIPs, diretórios `_files`, CSS ou JavaScript da documentação;
- manter endpoints de escrita somente como referência, sem autorização de execução;
- não substituir `dataResultadoPncp` por publicação ou atualização;
- ativar novas famílias em eventos posteriores apenas após regra e teste próprios.
