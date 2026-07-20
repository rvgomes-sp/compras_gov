# Catálogos oficiais do Compras.gov.br

## Referência de 18/07/2026

Os arquivos recebidos foram identificados pelo usuário como atualizados em 18/07/2026.

| Catálogo | Registros | Uso no EVT007 | Arquivamento no Git |
|---|---:|---|---|
| CATSER | 3.095 serviços; 3.013 ativos e 82 inativos | Fonte oficial dos códigos e nomes de serviço | Sim: `fontes/catser_20260718.csv` |
| CATMAT | 343.601 materiais | Preservação e futura análise de materiais; não participa do filtro de serviços | Não: arquivo possui 125.646.629 bytes, acima do limite comum de 100 MB do Git |

Fonte institucional informada: `https://dadosabertos.compras.gov.br/`.

## Separação entre fonte e regra comercial

- As colunas `codigoGrupo`, `nomeGrupo`, `codigoClasse`, `nomeClasse`, `codigoServico`, `nomeServico` e `statusServico` são preservadas conforme o CATSER.
- As colunas iniciadas por `gsb` são classificações internas, auditáveis e alteráveis sem renomear a fonte oficial.
- `config/comercial/tabela_servicos_20260718.csv` conserva os 3.095 registros e a decisão inicial de cada código.
- `config/comercial/catalogo_servicos.json` é a visão compacta consumida pelo qualificador.
- A planilha `GSB_EVT007_Tabela_Servicos_CATSER_20260718.xlsx`, distribuída no pacote de atualização, permite conferir a seleção, a mão de obra terceirizada, o catálogo completo e as fontes.

## Regra de segurança

Somente registros `APROVADO` e com `gsbAtivoMotor=True` são promovidos diretamente pelo código. Registros em revisão exigem leitura do objeto e nunca são aprovados apenas por pertencerem a um grupo amplo.
