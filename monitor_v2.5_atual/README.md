# GSB Monitor V2.5 — EVT007

Motor de descoberta e consolidação factual do evento de resultado de item homologado no PNCP.

## Princípios preservados

- `dataResultadoPncp` define o EVT007.
- `dataInclusaoPncp` é preservada para medir a entrada do resultado.
- `dataPublicacaoPncp` não substitui `dataResultadoPncp`.
- D-1 é a única janela ativa no primeiro teste.
- Nenhuma modalidade é excluída; Pregão Eletrônico permanece no fluxo.
- Nenhum candidato ou resultado do V2 pode entrar na execução.
- Os nomes oficiais da API são preservados; campos calculados usam prefixo `gsb`.

## Descoberta D-1

Fonte oficial utilizada:

```text
GET https://dadosabertos.compras.gov.br/modulo-contratacoes/3_consultarResultadoItensContratacoes_PNCP_14133
```

Filtros temporais oficiais:

- `dataResultadoPncpInicial`;
- `dataResultadoPncpFinal`.

Execução completa:

```powershell
.\Descobrir_EVT007_D1.ps1 -DataResultado "2026-07-17" -TamanhoPagina 500 -TodasPaginas -Reiniciar
```

A descoberta preserva cada página em `data\descoberta\evt007_AAAAMMDD\raw` e grava uma auditoria de cobertura. Uma saída parcial não pode ser apresentada como cobertura completa.

## Primeira base factual utilizável

A consolidação factual lê somente as páginas D-1 já preservadas. Ela não repete a descoberta e não chama as rotas `/api/pncp/v1` que permaneceram em HTTP 301 sem `Location`.

Comando principal:

```powershell
.\Executar_EVT007_D1.ps1 -DataResultado "2026-07-17" -Reiniciar
```

Comando direto equivalente:

```powershell
.\Consolidar_EVT007_D1.ps1 -DataResultado "2026-07-17" -Reiniciar
```

Por padrão, a camada factual exige `cobertura = COMPLETA` na auditoria da descoberta. `-PermitirCoberturaParcial` existe somente para auditoria técnica explícita e não converte uma amostra parcial em base completa.

## Saídas factuais

Diretório:

```text
output\factual\evt007_AAAAMMDD
```

Arquivos:

- `*_resultados_fatuais.csv`: todos os resultados D-1 deduplicados, incluindo cancelados e registros sem fornecedor para auditoria.
- `*_resultados_fatuais_utilizaveis.csv`: subconjunto não cancelado e com `niFornecedor` e `nomeRazaoSocialFornecedor`.
- `*_contratacoes_fatuais.csv`: consolidação por `numeroControlePNCPCompra`.
- `*_fornecedores_fatuais.csv`: consolidação por `niFornecedor`.
- `*_auditoria_factual.json`: contagens, hashes, cobertura, valor factual e ressalvas.

`gsbValorHomologadoResultadosD1` significa somente a soma dos resultados factuais utilizáveis localizados no D-1. Não representa necessariamente o valor total da contratação.

## Limite atual

A camada é factual, não comercial. O endpoint de resultados não entrega descrição do item, `materialOuServico`, código CATSER/CATMAT, objeto, modalidade ou confirmação da plataforma de origem. Por isso:

- `gsbOrigemPlataforma = NAO_CONFIRMADA_NO_RESULTADO`;
- `gsbStatusEnriquecimentoItem = PENDENTE_ENRIQUECIMENTO_ITEM`;
- `gsbClassificacaoComercial = NAO_APLICADA`;
- `gsbBaseComercial = false`.

O antigo coletor por `CandidateCsv` e a qualificação comercial estão bloqueados para impedir repetição do HTTP 301 e geração prematura de uma base comercial.

## Catálogo

- CATSER oficial de 18/07/2026: 3.095 serviços, sendo 3.013 ativos e 82 inativos.
- CATMAT permanece separado.
- O catálogo só poderá ser aplicado depois que o enriquecimento oficial fornecer o tipo e o código do item.

## Validação

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tests\Validar_Estrutura.ps1
```

## Estrutura relevante

- `src/Descobrir_EVT007_D1.ps1`: consulta paginada e preservação da descoberta.
- `src/Consolidar_EVT007_DadosAbertos.ps1`: construção local da camada factual.
- `src/Coletar_EVT007.ps1`: bloqueio explícito do fluxo que recebeu HTTP 301.
- `src/Qualificar_EVT007.ps1`: bloqueio da qualificação antes do enriquecimento.
- `config/api/factual_evt007_dados_abertos.json`: campos oficiais, chave e proteções da base factual.
- `governanca/BASE_FACTUAL_EVT007.md`: contrato da camada factual.
- `tests/Validar_Estrutura.ps1`: barreiras de tempo, modalidade, V2, rede e comercialização prematura.
