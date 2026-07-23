# API CNPJ

Fonte documental oficial para o enriquecimento cadastral dos fornecedores.

- OpenAPI: `openapi/api-docs.json`
- título: `APIs CNPJ (Básica, QSA e Empresa)`
- versão: `2.0.2`
- autenticação documentada: OAuth2 `clientCredentials`
- situação operacional: documentada; execução ainda não ativada

## Contrato comercial

A consulta `Empresa` deve ser usada para o enriquecimento principal. O retorno
será mapeado sem inferência:

| Campo comercial | Campo da API |
|---|---|
| confirmação do CNPJ | igualdade entre o CNPJ factual e `ni` |
| nome fantasia | `nomeFantasia` |
| situação cadastral | `situacaoCadastral` |
| natureza jurídica | `naturezaJuridica` |
| data de abertura | `dataAbertura` |
| CNAE principal | `cnaePrincipal` |
| endereço | `endereco` |
| município de jurisdição | `municipioJurisdicao` |
| telefone | `telefone` |
| correio eletrônico | `correioEletronico` |
| capital social | `capitalSocial` |
| porte da empresa | `porte` |
| situação especial | `situacaoEspecial` |
| data da situação especial | `dataSituacaoEspecial` |
| sócios | `socios` |

Campos ausentes permanecem nulos com estado de coleta. A documentação não
contém nem autoriza versionamento de credenciais.
