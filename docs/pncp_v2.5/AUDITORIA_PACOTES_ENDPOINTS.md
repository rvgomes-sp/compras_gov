# Auditoria documental PNCP 2.5

## Fontes canônicas

| Fonte | SHA-256 | Resultado |
|---|---|---|
| Manual PNCP 2.5 completo | `26d5a5cff042faf28c09fd10e9edc32eaeca38f565ea8926699aab932e121449` | Íntegro |
| OpenAPI `api-docs.json` | `dfe448f39a3d6602d688465d2159fa75233ac56aa447dee115fbbcd2eb4fe7af` | Íntegro; 109 rotas e 190 operações na auditoria local |

O Manual completo reúne todas as famílias documentadas. Os HTML individuais são recortes de consulta e não condição de completude.

## Recortes acrescentados na consolidação

| Seção | Arquivo | SHA-256 |
|---|---|---|
| 11.11 | `endpoints/atas/11.11_consultar_historico_ata.html` | `316ddbcb2e12794f5acf3350f983e607bba0ea7b8f8eb35d1c772f4968e82107` |
| 14.6 | `endpoints/orgaos/14.6_consultar_unidade.html` | `bded39c423bd4a0fa2d72e0b6f967f94358384867f31e93cdde84d53c6d14f1f` |
| 14.7 | `endpoints/orgaos/14.7_consultar_unidades_orgao.html` | `051bc8c7bce8dc08067017463b1b4782f02bbb097bbe0c2fad0858d5dfbdc169` |

O arquivo recebido para 11.11 possuía extensão `.json`, mas seu conteúdo real é HTML completo; foi renomeado sem alterar os bytes.

## Decisões

- preservar uma única cópia do Manual e do OpenAPI;
- não versionar ZIPs, diretórios `_files`, CSS ou JavaScript repetidos da documentação;
- manter endpoints POST e PUT somente como referência, sem autorização de execução;
- não substituir `dataResultadoPncp` por publicação ou atualização;
- usar as famílias 11, 12 e 14 nos eventos posteriores apenas após regra e teste próprios.
