# Referência de fornecedor — Dados Abertos Compras.gov

## Situação da captura

A exportação manual recebida em 20/07/2026 é uma amostra de esquema, não uma base completa:

| Métrica oficial | Valor |
|---|---:|
| `totalRegistros` | 106.320 |
| `totalPaginas` | 10.632 |
| `paginasRestantes` | 10.631 |
| Registros preservados na amostra | 10 |

Campos observados, com a mesma nomenclatura da resposta:

`ativo`, `cnpj`, `codigoCnae`, `cpf`, `habilitadoLicitar`, `naturezaJuridicaId`, `naturezaJuridicaNome`, `nomeCnae`, `nomeMunicipio`, `nomeRazaoSocialFornecedor`, `porteEmpresaId`, `porteEmpresaNome`, `ufSigla`.

## Decisão de governança

- A consulta de fornecedor não participa da descoberta temporal do EVT007.
- `niFornecedor` e `nomeRazaoSocialFornecedor` continuam obrigatórios no resultado confirmado.
- O fornecedor poderá ser enriquecido posteriormente por CNPJ para apoiar leitura comercial de porte, CNAE, município, situação e habilitação.
- A amostra parcial não pode ser usada para afirmar ausência de fornecedor nem cobertura nacional.
- O campo `cpf` exige tratamento restritivo caso venha preenchido; nenhuma base integral de fornecedores deve ser versionada no repositório.

Integridade da exportação recebida: SHA-256 `5293af30b63bec80ba7623ab3c93cda223cdd3ae5f8b1f08dee7fa77e7a761dd`.
