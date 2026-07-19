# GSB Monitor V2.5 — EVT007

Pacote de transição controlada do GSB Monitor V2 para o V2.5.

## Regra central

- O evento EVT007 é identificado por `dataResultado`, campo do resultado do item.
- `dataInclusao` é preservada para medir quando o resultado entrou no PNCP.
- `logManutencaoDataInclusao` registra a operação de manutenção do recurso.
- `dataPublicacaoPncp` não é usada como data do EVT007.
- A fonte Compras.gov é confirmada pelo `usuarioNome` do histórico da contratação.
- O coletor utiliza somente nomes de endpoints, parâmetros e campos do Manual PNCP 2.5.
- Regras comerciais são aplicadas depois da coleta e ficam em arquivos separados.

## Limitação documentada do Manual 2.5

O Manual 2.5 apresenta `dataResultado` como campo de retorno de resultado de item, mas não oferece uma consulta nacional que receba `dataResultado` como parâmetro. Os endpoints 10.13, 10.17 e 10.19 exigem a identificação prévia da contratação (`cnpj`, `ano`, `sequencial`).

Por isso o fluxo é deliberadamente dividido:

1. formar uma lista auditável de contratações candidatas;
2. consultar os itens pelo endpoint 10.13;
3. consultar os resultados pelo endpoint 10.17;
4. selecionar somente `dataResultado` do D-1;
5. confirmar a inclusão do resultado e a origem Compras.gov pelo endpoint 10.19;
6. qualificar comercialmente sem nova consulta ao PNCP.

Uma lista vazia ou incompleta de candidatos não pode ser apresentada como “zero homologações nacionais”.

## Instalação

Copie todo este pacote para:

`C:\GSB\monitor_v2\monitor_v2.5`

Abra o Windows PowerShell como administrador e execute:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd C:\GSB\monitor_v2\monitor_v2.5
.\Migrar_V2_para_V2_5.ps1
```

O script cria o inventário do V2, calcula hashes e copia para referência apenas os arquivos autorizados. Nenhum script antigo é ativado.

## Preparação dos candidatos

O arquivo de entrada usa somente os parâmetros oficiais dos endpoints:

`data\candidatos\candidatos_evt007.csv`

Cabeçalho:

```text
cnpj;ano;sequencial
```

Para reaproveitar automaticamente contratações já presentes nos JSONs do V2:

```powershell
.\Importar_Candidatos_V2.ps1
```

Essa importação apenas reaproveita `numeroControlePNCP` já gravado; ela não consulta internet e não garante cobertura nacional de D-1.

## Execução D-1

Configuração inicial: 17/07/2026.

```powershell
.\Executar_EVT007_D1.ps1
```

O teste grava cada contratação imediatamente em `data\raw`, mantém checkpoint em `data\state` e preserva resultados mesmo se a execução for interrompida.

## Saídas

- `data\raw\...\*.json`: respostas integrais por contratação.
- `data\state\evt007_20260717_resultados.jsonl`: resultados válidos acumulados.
- `output\comercial\evt007_20260717_detalhado_*.csv`: visão por item/resultado.
- `output\comercial\evt007_20260717_base_comercial_*.csv`: somente registros qualificados.
- `output\comercial\evt007_20260717_auditoria_*.json`: cobertura, falhas e contagens.

## Sequência segura

1. Rodar D-1.
2. Conferir cobertura de candidatos, erros e origem.
3. Conferir uma amostra no PNCP.
4. Liberar a base comercial.
5. Somente depois autorizar D-2.
6. Qualquer janela maior exige alteração explícita da configuração e nova autorização.

