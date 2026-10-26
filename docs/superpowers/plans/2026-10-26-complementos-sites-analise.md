# Complementos Sites de Análise (v3.3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `fin-db` with 7 new tables, 1 bridge table, 2 table alterations for fees/benchmarks, 1 ETF holding enhancement with view, and 20 fundamentalist metric seeds as specified in the SDD (`diyfin1.txt`), ensuring full compatibility with the existing PostgreSQL 18 / TimescaleDB schema in Neon DB without duplication or data loss.

**Architecture:** Add a new modular migration stage `sql/05_coverage_v3.3/` containing idempotent, non-breaking SQL scripts (`IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `ON CONFLICT DO NOTHING`). Integrate this stage into `scripts/migrate.py`, execute against the Neon PostgreSQL instance, enhance `scripts/verify_db.py` to validate new objects, and document the additions in `docs/04_complementos_sites_analise_v3.3.md` and `README.md`.

**Tech Stack:** PostgreSQL 18, Neon Serverless, Python 3, `psycopg[binary]`, TimescaleDB, pg_trgm, pgcrypto.

**Spec:** `/Users/rafaelaparecido/Desktop/diyfin1.txt` (SDD — Complementos ao fin-db para Cobertura de Sites de Análise)

## Global Constraints

- Scope: Strictly additive (new tables, new columns, new seeds). No deletions, renames, or column alterations of existing structures.
- Idempotency: All DDL must use `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and `INSERT ... ON CONFLICT DO NOTHING`.
- Types & Keys: Primary keys use UUID `gen_random_uuid()` unless referencing an existing serial/bigint table (e.g. `analytics.score_ativo.id_score`). Timestamps use `timestamptz DEFAULT now()`.
- Reference Mapping: Foreign keys must point to existing canonical tables: `canonical.instrument(instrument_id)`, `canonical.government_bond(instrument_id)`, `canonical.legal_entity(legal_entity_id)`, `raw.payload(payload_id)`, and `analytics.score_ativo(id_score)`.
- No Duplication: Reuse existing tables where applicable (`canonical.fund_holding` for ETF holdings; views instead of duplicate tables).

## Review Focus

1. `analytics.score_eixo` foreign key references `analytics.score_ativo(id_score)` (type `bigint`), NOT `id` (type `uuid`).
2. `canonical.government_bond_quote` foreign key references `canonical.government_bond(instrument_id)` (type `uuid`), NOT `id`.
3. `canonical.news_article_instrument`, `analytics.valuation`, `canonical.insider_transaction`, `canonical.institutional_holding` reference `canonical.instrument(instrument_id)`, NOT `core.instrument(id)`.
4. `asset_details.mercado_imobiliario_indicador` unique constraint on `(uf, cidade, coalesce(regiao, ''), tipo_imovel, data_referencia, source)` must use a PostgreSQL expression index (`CREATE UNIQUE INDEX`) because table-level `UNIQUE (...)` cannot evaluate functions.
5. `canonical.metric_definition` seeds must map to existing columns (`code`, `name`, `category`, `default_unit`, `description`, `calculation_note`) and add optional `higher_is_better boolean` safely via `ADD COLUMN IF NOT EXISTS`.

---

### Task 1: Document the Specification in the Repository

**Files:**
- Create: `docs/04_complementos_sites_analise_v3.3.md`

- [ ] **Step 1: Copy and format the SDD from `~/Desktop/diyfin1.txt` to `docs/04_complementos_sites_analise_v3.3.md`**
- [ ] **Step 2: Verify file existence and readability**

---

### Task 2: Create SQL Migration Scripts in `sql/05_coverage_v3.3/`

**Files:**
- Create: `sql/05_coverage_v3.3/01_canonical_government_bond_quote.sql`
- Create: `sql/05_coverage_v3.3/02_asset_details_mercado_imobiliario.sql`
- Create: `sql/05_coverage_v3.3/03_canonical_news_article.sql`
- Create: `sql/05_coverage_v3.3/04_analytics_valuation.sql`
- Create: `sql/05_coverage_v3.3/05_analytics_score_eixo.sql`
- Create: `sql/05_coverage_v3.3/06_canonical_insider_transaction.sql`
- Create: `sql/05_coverage_v3.3/07_canonical_institutional_holding.sql`
- Create: `sql/05_coverage_v3.3/08_alter_fund_profile_fees.sql`
- Create: `sql/05_coverage_v3.3/09_alter_detalhe_fii_fees.sql`
- Create: `sql/05_coverage_v3.3/10_alter_fund_holding_etf_view.sql`
- Create: `sql/05_coverage_v3.3/11_seeds_metric_definition.sql`

- [ ] **Step 1: Write `01_canonical_government_bond_quote.sql`** (M1: `canonical.government_bond_quote`)
- [ ] **Step 2: Write `02_asset_details_mercado_imobiliario.sql`** (M2: `asset_details.mercado_imobiliario_indicador`)
- [ ] **Step 3: Write `03_canonical_news_article.sql`** (M3: `canonical.news_article` and `canonical.news_article_instrument`)
- [ ] **Step 4: Write `04_analytics_valuation.sql`** (M4: `analytics.valuation`)
- [ ] **Step 5: Write `05_analytics_score_eixo.sql`** (M5: `analytics.score_eixo`)
- [ ] **Step 6: Write `06_canonical_insider_transaction.sql`** (M6: `canonical.insider_transaction`)
- [ ] **Step 7: Write `07_canonical_institutional_holding.sql`** (M7: `canonical.institutional_holding`)
- [ ] **Step 8: Write `08_alter_fund_profile_fees.sql`** (M8: fees and benchmarks for FI-Infra/FIAGRO)
- [ ] **Step 9: Write `09_alter_detalhe_fii_fees.sql`** (M9: fees and benchmarks for FIIs)
- [ ] **Step 10: Write `10_alter_fund_holding_etf_view.sql`** (M11: `etf_instrument_id` column + `asset_details.etf_composicao` view)
- [ ] **Step 11: Write `11_seeds_metric_definition.sql`** (M10: 20 metric definition seeds with `ON CONFLICT DO NOTHING`)

---

### Task 3: Update `scripts/migrate.py` and `scripts/verify_db.py`

**Files:**
- Modify: `scripts/migrate.py`
- Modify: `scripts/verify_db.py`

- [ ] **Step 1: Add `05_coverage_v3.3` to `MIGRATION_STAGES` in `scripts/migrate.py`**
- [ ] **Step 2: Add new tables and column checks in `scripts/verify_db.py`**

---

### Task 4: Execute Migrations on Neon DB and Verify

- [ ] **Step 1: Execute migrations on Neon DB using `scripts/migrate.py`**
- [ ] **Step 2: Run `scripts/verify_db.py` and verify all new tables, views, and seed records**
- [ ] **Step 3: Query Neon DB to confirm all 12 target sites' data points are supported**

---

### Task 5: Update `README.md` and Git Commit

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update `README.md` object counts and stage description**
- [ ] **Step 2: Git status and review diff**
- [ ] **Step 3: Commit all changes cleanly**
