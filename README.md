# 📦 fin-db — Engenharia de Dados & Modelo Relacional para Plataforma Financeira

Repositório central de arquitetura, esquemas relacionais, séries temporais (TimescaleDB), vetores (pgvector) e migrações do ecossistema **fin-db** (plataforma analítica e transacional de investimentos brasileira e internacional).

Implementado e testado em produção no **PostgreSQL 18 (Neon Serverless)** com suporte a **TimescaleDB**, **pgvector**, **pg_trgm** e **pgcrypto**.

---

## 🏛️ Visão Geral da Arquitetura

O banco de dados é estruturado em **12 schemas modulares**, totalizando **303 tabelas e views**, com **36 hypertables** de alta performance para dados temporais:

```
                               ┌────────────────────────────────┐
                               │          FIN-DB CORE           │
                               └────────────────┬───────────────┘
                                                │
         ┌───────────────────┬──────────────────┼──────────────────┬──────────────────┐
         ▼                   ▼                  ▼                  ▼                  ▼
   ┌───────────┐       ┌───────────┐      ┌───────────┐      ┌───────────┐      ┌───────────┐
   │ canonical │       │   core    │      │  market   │      │   asset   │      │ analytics │
   │  & raw    │       │  & wealth │      │ & series  │      │  details  │      │   & ML    │
   └───────────┘       └───────────┘      └───────────┘      └───────────┘      └───────────┘
         │                   │                  │                  │                  │
         └───────────────────┴──────────────────┼──────────────────┴──────────────────┘
                                                ▼
                               ┌────────────────────────────────┐
                               │     social, system & dw        │
                               └────────────────────────────────┘
```

### Schemas e Responsabilidades

| Schema | Objs | Descrição |
|---|:---:|---|
| **`canonical`** | 25 | Modelo canônico unificado para ingestão padronizada de instrumentos, ativos, emissores, cotações de títulos, notícias e fontes |
| **`raw`** | 2 | Camada *bronze* de ingestão bruta (payloads JSONB, lotes de captura, auditoria de ingestão) |
| **`core`** | 26 | Cadastros mestres: usuários, emissores, administradores, remuneração executiva, diretoria CVM, ativos, carteiras, custódia, notas, lotes fiscais e ordens |
| **`market`** | 32 | Cotações diárias/intraday, books, negócios, proventos, recompras, subscrições, fluxo de opções, negociação por modalidade/termo, macro e curvas |
| **`asset_details`**| 28 | Extensões 1:1 e 1:N especializadas: Ações, FIIs (imóveis físicos, SiiLA vendas/locações, contratos, CRIs, DRE trimestral, gestoras), Fundos CVM 175, ETFs, BDRs, Opções, Tesouro, Renda Fixa, Cripto |
| **`analytics`** | 41 | DFP/ITR, segmentos de negócio/geografia, KPIs operacionais, múltiplos, valuation, scores por eixo, checklists Buy & Hold, médias setoriais, consenso de analistas, candlestick, risco |
| **`wealth`** | 26 | Open Finance, contas bancárias, cartões, bens, IR (DARF, prejuízos), reconciliação, aportes |
| **`social`** | 32 | Watchlists customizadas, anotações do investidor, comunidades, mensagens diretas, kanban de teses |
| **`dw`** | 8 | Data warehouse: agregações históricas diárias/mensais de patrimônio, rentabilidade e posições |
| **`system`** | 70 | Autenticação (MFA/OAuth), rate limiting, device fingerprint, RBAC, auditoria, LGPD, pagamentos, suporte |

---

## ⚡ Hypertables & Séries Temporais (TimescaleDB)

O banco provisiona **36 hypertables** particionadas por tempo para suportar alta volumetria:

- **Mercado:** `market.cotacao_diaria`, `market.cotacao_intraday`, `market.book_ordens`, `market.negocio_intraday`, `market.after_market`, `market.ajuste_intraday`, `market.serie_macroeconomica`, `market.aluguel_acoes`, `market.benchmark_serie`
- **FIIs & Fundos:** `asset_details.historico_vacancia_fii`, `asset_details.historico_patrimonio_fii`, `asset_details.etf_nav`, `asset_details.etf_fluxo_cotas`
- **Analytics:** `analytics.historico_indicador_fundamentalista`, `analytics.historico_indicador_tecnico`, `analytics.historico_risco`, `analytics.evento_usuario`, `analytics.recomendacao`
- **Wealth:** `wealth.transacao_bancaria`
- **Data Warehouse:** `dw.historico_posicao`, `dw.historico_carteira`, `dw.historico_patrimonio`, `dw.historico_rentabilidade`, `dw.ranking`, `dw.historico_indicador`
- **Segurança & Auditoria:** `system.uso_api`, `system.auditoria_log`, `system.log_acesso`, `system.tentativa_login`, `system.api_key_uso`, `system.alerta_disparo`, `system.evento_seguranca`, `system.rate_limit`, `system.inbox`, `system.envio_campanha`, `social.mensagem_direta`

> [!NOTE]
> No Neon Serverless (licença Apache 2.0 do TimescaleDB), hypertables e funções de partição (`time_bucket`, `first()`, `last()`, `drop_chunks`) funcionam nativamente. Para continuous aggregates, o repositório provisiona Materialized Views convencionais equivalentes.

---

## 📂 Estrutura do Repositório

```
fin-db/
├── docs/                               # Especificações, roadmaps e diagramas originais
│   ├── 01_pacote_completo_diyfin.md   # DDL base, mapeamento de APIs, roadmap MVP
│   ├── 02_melhorias_ddl_v3.1.md        # Melhorias v3.1: Tax lot, RLS, triggers, auditoria
│   ├── 03_melhorias_ddl_v3.2_analise.md# DDL v3.2: Reconciliação, SCD, UX, segurança
│   ├── 04_complementos_sites_analise_v3.3.md # SDD v3.3: Cobertura inicial de sites de análise
│   └── 05_rea_12_sites_coverage_v3.4.md      # SDD & REA v3.4: Engenharia Reversa completa dos 12 sites
├── sql/
│   ├── 00_baseline/                    # Schemas pré-existentes e extensões
│   │   ├── 00_extensions_and_schemas.sql
│   │   ├── 01_existing_canonical_raw_schema.sql
│   │   └── 02_existing_seeds.sql
│   ├── 01_core_schema/                 # Schemas fundamentais (v1)
│   │   ├── 00_types.sql
│   │   ├── 01_core.sql
│   │   ├── 02_market.sql
│   │   ├── 03_asset_details.sql
│   │   ├── 04_analytics.sql
│   │   ├── 05_wealth.sql
│   │   ├── 06_social.sql
│   │   ├── 07_dw.sql
│   │   ├── 08_system.sql
│   │   └── 09_views_and_aggregates.sql
│   ├── 02_improvements_v3.1/           # Evolução v3.1 (transações, RLS, regras fiscais)
│   │   ├── 01_corrections_and_constraints.sql
│   │   ├── 02_core_tax_lots_and_orders.sql
│   │   ├── 03_market_benchmarks_and_calendar.sql
│   │   ├── 04_analytics_international_and_features.sql
│   │   ├── 05_social_watchlists_and_notes.sql
│   │   ├── 06_wealth_recurring_investments.sql
│   │   ├── 07_system_auth_security_support.sql
│   │   └── 08_triggers_rls_views.sql
│   ├── 03_platform_v3.2/               # Plataforma analítica v3.2
│   │   ├── 01_reconciliation.sql
│   │   ├── 02_scd_history.sql
│   │   ├── 03_fraud_and_security.sql
│   │   ├── 04_product_and_ux.sql
│   │   ├── 05_marketing_and_lgpd.sql
│   │   ├── 06_news_and_advanced_metrics.sql
│   │   └── 07_ai_foundation.sql
│   ├── 04_seeds/                       # Cargas iniciais de dados estáticos
│   │   ├── 01_core_currencies_and_timezones.sql
│   │   ├── 02_market_benchmarks.sql
│   │   ├── 03_analytics_tags.sql
│   │   └── 04_system_oauth.sql
│   ├── 05_coverage_v3.3/               # Cobertura v3.3 de sites de análise de investimentos
│   │   ├── 01_canonical_government_bond_quote.sql
│   │   ├── 02_asset_details_mercado_imobiliario.sql
│   │   ├── 03_canonical_news_article.sql
│   │   ├── 04_analytics_valuation.sql
│   │   ├── 05_analytics_score_eixo.sql
│   │   ├── 06_canonical_insider_transaction.sql
│   │   ├── 07_canonical_institutional_holding.sql
│   │   ├── 08_alter_fund_profile_fees.sql
│   │   ├── 09_alter_detalhe_fii_fees.sql
│   │   ├── 10_alter_fund_holding_etf_view.sql
│   │   └── 11_seeds_metric_definition.sql
│   └── 06_rea_coverage_v3.4/           # REA profundo dos 12 sites de análise (v3.4)
│       ├── 01_enums_and_core_governance.sql
│       ├── 02_market_buybacks_btc_termo_options.sql
│       ├── 03_asset_details_fii_real_estate_deep.sql
│       ├── 04_asset_details_funds_etfs_bonds_crypto.sql
│       ├── 05_analytics_segments_consensus_technical_checklists.sql
│       └── 06_seeds_metrics_and_benchmarks.sql
├── scripts/
│   ├── migrate.py                      # Runner automatizado de migrações
│   └── verify_db.py                    # Healthcheck completo do banco de dados
├── .env.example                        # Template de variáveis de ambiente
└── README.md
```

---

## 🚀 Como Executar as Migrações

### Pré-requisitos

- Python 3.10+
- `psycopg` (versão 3 com binary):
  ```bash
  pip install "psycopg[binary]"
  # ou usando uv:
  uv run --with "psycopg[binary]" <script>
  ```

### 1. Configurar Conexão

Defina a variável `DATABASE_URL` no arquivo `.env` ou no terminal:

```bash
export DATABASE_URL="postgresql://neondb_owner:YOUR_KEY@ep-xxx-pooler.us-east-2.aws.neon.tech/neondb?sslmode=require"
```

### 2. Rodar Migrações

Para aplicar todos os estágios ordenados:

```bash
python3 scripts/migrate.py
```

Para aplicar apenas um estágio específico:

```bash
python3 scripts/migrate.py --stage 01_core_schema
```

### 3. Verificar o Estado do Banco (Healthcheck)

Execute o verificador para inspecionar schemas, hypertables, views e seeds:

```bash
python3 scripts/verify_db.py
```

Exemplo de saída do healthcheck:
```
=================================================================
           FIN-DB: NEON DATABASE HEALTHCHECK
=================================================================
Database: neondb
User:     neondb_owner
Engine:   PostgreSQL 18.6

--- Schema & Table Inventory ---
  • Schema analytics      :   41 tables/views
  • Schema asset_details  :   28 tables/views
  • Schema canonical      :   25 tables/views
  • Schema core           :   26 tables/views
  • Schema dw             :    8 tables/views
  • Schema market         :   32 tables/views
  • Schema neon_auth      :    9 tables/views
  • Schema raw            :    2 tables/views
  • Schema social         :   32 tables/views
  • Schema system         :   70 tables/views
  • Schema wealth         :   26 tables/views
  -------------------------------------
  TOTAL APPLICATION OBJECTS: 303

--- TimescaleDB Hypertables ---
  Total Hypertables: 36
...
=================================================================
           HEALTHCHECK COMPLETED SUCCESSFULLY
=================================================================
```

---

## 🔐 Segurança & Governança (RLS + LGPD)

- **Row Level Security (RLS):** Habilitado em todas as tabelas com segregação de usuário (`core.carteira`, `posicao_custodia`, `nota_corretagem`, `ordem`, `lote_ativo`, `wealth.apuracao_ir`, `social.watchlist`, `anotacao_ativo`, `system.api_key`, `dispositivo`).
- **Auditoria Transacional:** Triggers automáticos alimentam `system.auditoria_log` com snapshots JSONB (`old_value` / `new_value`).
- **LGPD:** Tabelas dedicadas para consentimento (`system.consentimento_lgpd`), versões de termos (`system.versao_termo`), opt-out granular por canal/finalidade (`system.opt_out`), registro de atividades ROPA (`system.ropa`) e gestão de solicitações do titular DSAR (`system.solicitacao_lgpd`).

---

## 📈 Roadmap & Fases de Implementação

1. **Fase 0 — Fundação:** Infraestrutura Neon, TimescaleDB, migrações e observabilidade.
2. **Fase 1 — MVP Ações & FIIs:** Cadastros B3/CVM, cotações EOD, proventos, múltiplos fundamentais, carteira básica.
3. **Fase 2 — Análise Avançada:** Screener multicritério, indicadores técnicos, risco (Beta/Sharpe/VaR), comparador.
4. **Fase 3 — Renda Fixa, Fundos & Macro:** Tesouro Direto, CDB/LCI/LCA/CRI/CRA, cotas CVM, ETTJ ANBIMA, SGS BCB.
5. **Fase 4 — Wealth & Open Finance:** Reconciliação bancária/custódia, DARF/IR mensal, consolidação patrimonial.
6. **Fase 5 — Social & Comunidades:** Fórum, perfis públicos, diário do investidor, kanban de teses.
7. **Fase 6 — Inteligência Artificial:** Feature store (`analytics.feature_store`), embeddings de ativos (`pgvector`), modelo preditivo.

---

## 📄 Licença & Conformidade

Este projeto é desenvolvido para plataformas financeiras de análise. Certifique-se de cumprir os termos de uso de fornecedores de dados de mercado (B3, CVM, BCB, ANBIMA e Open Finance Brasil).
