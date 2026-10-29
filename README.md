# fin-db — Estrutura PostgreSQL

Repositório de estrutura para o banco da plataforma financeira: schemas, tipos, tabelas, colunas, constraints, índices, views, hypertables, políticas e funções necessárias ao modelo. As migrações não carregam dados de demonstração, catálogos ou dados operacionais.

## Escopo

- Contém apenas DDL de criação e evolução do schema.
- Não há rotinas de ingestão, sincronização, seeds ou scripts que povoem tabelas.
- O executor valida checksums e aplica **cada arquivo SQL em sua própria transação**. Se um arquivo falhar, somente ele é revertido; arquivos anteriores já confirmados permanecem aplicados.
- O histórico é guardado como metadado de comentário no schema `fin_db_migrations`, sem criar uma tabela de controle ou linhas de dados.
- A pasta `sql/rollback/` contém comandos de rollback para execução manual; ela não é percorrida pelo executor.
- A rotina de escrita da auditoria transacional foi removida junto com os comandos de gravação. As tabelas de auditoria permanecem parte da estrutura, sem trigger de gravação automática.

## Organização

```text
sql/
├── 00_baseline/                 # extensões, schemas e estrutura canônica existente
├── 01_core_schema/              # tipos, tabelas centrais e views
├── 02_improvements_v3.1/        # constraints, RLS, índices e evoluções
├── 03_platform_v3.2/            # reconciliação, SCD, UX, segurança e analytics
├── 05_coverage_v3.3/            # cobertura adicional de instrumentos e indicadores
├── 06_rea_coverage_v3.4/        # estrutura para fontes e métricas adicionais
├── 07_portfolio_graph_reconciliation_v3.5/
├── 08_status_invest_coverage_v3.6/
├── 09_fundamentus_coverage_v3.7/
├── 10_oceans14_coverage_v3.8/
├── 11_analise_de_acoes_coverage_v3.9/
├── 12_etfs_brasil_coverage_v4.0/
├── 13_billing_and_auth_v4.1/
├── 14_ingestion_control_and_data_quality_v4.2/
├── 15_dbt_raw_landing_views_v4.3/
├── 16_market_data_quality_v4.4/
├── 17_orders_idempotency/
├── 18_empty_materialized_views/ # views não populadas
└── rollback/                    # scripts down manuais, fora do fluxo normal

scripts/
├── migrate.py                   # planejamento, checksums e aplicação transacional
├── preflight_extensions.py      # verificações somente leitura
├── validate_sql.py              # gramática PostgreSQL e política DDL-only
└── verify_db.py                  # inventário e verificação opcional de tabelas vazias
tests/
└── test_migrate_plan.py
```

Os schemas cobrem o modelo canônico e bruto (`canonical`, `raw`), cadastros e transações (`core`, `wealth`), mercado e detalhes de ativos (`market`, `asset_details`), analytics, camada social, data warehouse, sistema e os schemas adicionais declarados pelas migrações.

## Requisitos

- Python 3.10+
- `psycopg` 3 com driver binary para conexão e migrações
- `pglast` para validar a gramática PostgreSQL localmente

```bash
python3 -m pip install 'psycopg[binary]' pglast
```

## Aplicação

Configure a URL do banco no ambiente ou em `.env`; não há URL de conexão fixa no código.

```bash
export DATABASE_URL='postgresql://USER:PASSWORD@HOST/neondb?sslmode=require'
python3 scripts/migrate.py --dry-run
python3 scripts/migrate.py
```

O runner converte endpoints Neon com `-pooler` para o endpoint direto na verificação inicial do TimescaleDB, cuja criação precisa ser a primeira instrução SQL da conexão. Depois, aplica as migrações em ordem de dependência. Para executar apenas uma etapa:

```bash
python3 scripts/migrate.py --stage 01_core_schema
```

O executor interrompe a execução no primeiro erro, preserva os arquivos já confirmados e não tenta reverter etapas anteriores. Se o checksum de um arquivo já aplicado tiver mudado, a execução é recusada para evitar replay silencioso.

## Verificações

Validação offline de sintaxe e da política sem mutações de linhas:

```bash
python3 scripts/validate_sql.py
python3 -m unittest discover -s tests -v
```

Preflight somente leitura e inventário:

```bash
python3 scripts/preflight_extensions.py
python3 scripts/verify_db.py
```

Para verificar que todas as tabelas de aplicação permanecem sem linhas:

```bash
python3 scripts/verify_db.py --assert-empty
```

## Observações

- TimescaleDB é obrigatório para a estrutura temporal; o runner não instala um stub silencioso como fallback.
- O `--assert-empty` faz consultas somente leitura de existência de linhas, sem alterar o banco.
- A remoção de seeds e carregadores significa que tabelas de referência também começam vazias; a aplicação não pode depender de catálogos previamente populados.
