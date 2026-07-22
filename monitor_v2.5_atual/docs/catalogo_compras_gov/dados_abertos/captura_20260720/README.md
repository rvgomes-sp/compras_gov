# Captura do Catálogo de Serviços — Dados Abertos Compras.gov

Arquivos exportados manualmente em 20/07/2026 e preservados sem alteração de conteúdo. A nomenclatura interna permanece exatamente como retornada pela fonte.

| Arquivo organizado | Nível | `totalRegistros` | Registros preservados | Cobertura |
|---|---|---:|---:|---|
| `servico_secao.json` | Seção | 6 | 6 | Completa |
| `servico_divisao.json` | Divisão | 40 | 40 | Completa |
| `servico_grupo.json` | Grupo | 148 | 148 | Completa |
| `servico_classe.json` | Classe | 313 | 313 | Completa |
| `servico_subclasse.json` | Subclasse | 281 | 281 | Completa |
| `servico_item_PARCIAL.json` | Item/serviço | 3.013 | 10 | Parcial: página 1 de 302 |

## Uso permitido

- Os cinco níveis completos servem para construir e validar a hierarquia oficial do catálogo.
- O arquivo de item serve somente para validar o esquema e a ligação entre códigos; não é catálogo completo e não pode ser usado como lista exaustiva de serviços.
- Nenhum nome ou código deve ser inferido fora dos campos oficiais presentes nos arquivos.
- A futura coleta integral de itens deve preservar todas as páginas e comprovar `paginasRestantes = 0` antes de substituir a marca `PARCIAL`.

## Integridade dos originais recebidos

| Exportação original | SHA-256 |
|---|---|
| `servico_servico-secao_2026-07-20T02-31-35.json` | `84f2406cc9ec0ed359b75a70cbb8ffbc198c4868c86cc32140c60f5d03fee7ef` |
| `servico_servico-divisao_2026-07-20T02-31-00.json` | `f1549c900e9aee47b9ff8ba4237f7f07b716ecbdabafc9d3e33e441fe1def496` |
| `servico_servico-grupo_2026-07-20T02-30-47.json` | `75a2bc9cb2fd9754807fc20fa34515dbdfe93b1c1c8c14a12c8b3af4e6abf82a` |
| `servico_servico-classe_2026-07-20T02-30-30.json` | `0746110840fdf91ea11a35b1428ed4896078378014cf55e946c1586de1426dbd` |
| `servico_servico-subclasse_2026-07-20T02-30-11.json` | `fa782840b09c41f73e0a7bab529a234ae88a9391a683fe70a5da09c6cc0ac1f3` |
| `servico_servico-item_2026-07-20T02-29-48.json` | `ee1bfdb6041994096641065f9a4a6273e910f9926f0ddb17bca7584b5ceba685` |
