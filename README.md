# GSB Monitor V2.5

Motor orientado por eventos para observar contratações públicas, preservar evidências e formar casos comerciais submetidos a decisão humana.

## Estado operacional

O único evento ativo nesta versão é o `EVT-007 — Homologação / Adjudicação`.

O fluxo diário:

1. consulta o endpoint oficial de resultados de itens do Dados Abertos Compras.gov pela data do resultado;
2. preserva todas as páginas retornadas e a auditoria da cobertura;
3. consolida uma camada factual por resultado, contratação e fornecedor;
4. não gera base comercial antes do enriquecimento oficial e da validação humana.

O repositório não contém dados de execução, listas de oportunidades, checkpoints ou saídas comerciais.

## Execução diária

No Windows PowerShell, a partir da raiz do projeto:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Executar_EVT007_D1.ps1
```

Sem `-DataResultado`, o executor usa o dia civil anterior no relógio local. Para reproduzir uma data específica:

```powershell
.\Executar_EVT007_D1.ps1 -DataResultado "2026-07-17"
```

O executor exige cobertura completa por padrão. `-PermitirCoberturaParcial` existe apenas para auditoria técnica e não autoriza uso comercial.

## Estrutura

- `src/Descobrir_EVT007_D1.ps1`: paginação, checkpoint e preservação das respostas oficiais.
- `src/Consolidar_EVT007_DadosAbertos.ps1`: consolidação local da camada factual.
- `src/Qualificar_EVT007.ps1`: guarda que bloqueia qualificação prematura.
- `config/api/`: contratos das fontes públicas.
- `config/execucao/`: controles técnicos da rodada diária.
- `config/governanca/`: matriz estável dos 14 eventos.
- `governanca/`: decisões canônicas e regras de negócio.
- `docs/`: Manual PNCP 2.5, OpenAPI, endpoints e fotografias de domínio.
- `prototypes/`: interfaces sem dados reais e sem função operacional.

## Regras incontornáveis

- `dataResultadoPncp` define o EVT-007; publicação ou atualização não a substituem.
- nenhuma modalidade é excluída, inclusive Pregão Eletrônico;
- ausência de dado não produz descarte automático;
- o domínio da fonte não confirma sozinho a plataforma original da contratação;
- fornecedor sem nome e identificação não segue para uso comercial;
- coleta factual, enriquecimento e decisão comercial são camadas distintas;
- nenhuma abordagem ocorre sem validação humana.

As decisões completas estão em `governanca/REGRAS_NEGOCIO_EVT007.md` e `config/governanca/event_data_map.json`.
