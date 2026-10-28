# Oceans14 Full-Stack Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete Oceans14 portal feature set (Equities 10-year financials matrix, Consistency Filter "Sem Prejuízo", Rankings, Multi-Criteria Screener, Ibovespa P/E corridor, B3 Investor Flows, Macro/Credit indicators Bacen/Tesouro, and FII Vacancy/Yields) across `fin-db`, `fin-ingestion`, `fin-api`, and `fin-web` with end-to-end verification.

**Architecture:** Database-first migration adding optimized TimescaleDB hypertables, canonical accounting statement matrix tables, and materialized views; Ingestion pipelines with Bacen/Tesouro/B3/CVM data handlers; High-performance FastAPI endpoints with caching; High-density terminal-grade Next.js 15 UI with virtualized tables, sticky columns, and interactive charts.

**Tech Stack:** 
- Database: PostgreSQL 18 + TimescaleDB 2.24 (Neon DB)
- Ingestion: Python 3.12 / Pandas / Pydantic / Asyncpg (`fin-ingestion`)
- Backend: FastAPI / SQLAlchemy 2.0 Async / Pydantic v2 / Redis (`fin-api`)
- Frontend: Next.js 15 / TypeScript / Tailwind CSS / Lucide / Turbopack (`fin-web`)

**Spec:** `docs/06_rea_reversa_12_sites_e_orgaos_oficiais_especificacao.md` and Oceans14 Architecture Gap Analysis

## Global Constraints

- Preserve all existing 316 database objects, test suites, and operational configurations.
- Use PostgreSQL-safe idempotent DDL (`IF NOT EXISTS`, conditional triggers and unique constraints).
- Use proper TypeScript typing (`no implicit any`) and maintain `pnpm build` clean without lint/type errors.
- Ensure all API endpoints handle empty states and nonexistent tickers gracefully with standard HTTP 404/422 responses.
- Follow tabular monospace numerals (`mono-nums`) for all financial and quantitative metrics.

## Review Focus

1. Matrix accounting time-series query latency for tickers with 10+ years of DRE/BP/DFC must respond in < 50ms.
2. Ingestion pipeline must be idempotent (re-running does not duplicate rows in hypertables or statement series).
3. Consistency Filter "Sem Prejuízo" materialized view must handle companies with partial history (< 5 years) correctly.
4. Ibovespa P/E historical calculations must handle negative aggregate earnings periods without division by zero.
5. Next.js responsive UI must support high data density on desktop and horizontal scroll with pinned header on mobile.

---

### Task 1: Database Migration `v3.8` in `fin-db` (Oceans14 Coverage)

**Files:**
- Create: `sql/10_oceans14_coverage_v3.8/01_oceans14_tables_and_views.sql`
- Create: `scripts/verify_10_migration.py`
- Test: `scripts/verify_10_migration.py`

**Interfaces:**
- Produces: Tables `market.historico_pl_indice`, `market.fluxo_investidor_b3`, `market.agenda_resultados`, `market.contas_publicas_governo`, `market.credito_sistema_financeiro`, `analytics.demonstrativo_padronizado_serie`, `asset_details.fii_historico_vacancia`, and materialized view `analytics.mv_acoes_consistencia_lucro`.

- [ ] **Step 1: Write SQL migration `sql/10_oceans14_coverage_v3.8/01_oceans14_tables_and_views.sql`**
  Include all tables, constraints, hypertables, and initial seed records for testing.
- [ ] **Step 2: Write test/verification script `scripts/verify_10_migration.py`**
  Connect to Neon DB, execute the migration idempotently, verify table existence, check indexes, and validate materialized view.
- [ ] **Step 3: Run `verify_10_migration.py` and ensure all objects exist**
- [ ] **Step 4: Commit `fin-db` changes**

---

### Task 2: Data Ingestion Pipelines & Calculators in `fin-ingestion`

**Files:**
- Create: `../fin-ingestion/fin_ingestion/pipelines/oceans14_macro_market_pipeline.py`
- Create: `../fin-ingestion/fin_ingestion/pipelines/financial_matrix_pipeline.py`
- Create: `../fin-ingestion/tests/test_oceans14_pipelines.py`

**Interfaces:**
- Consumes: Raw macroeconomic series (Bacen SGS, Tesouro Transparente), B3 investor flow data, and CVM DFP/ITR normalized statements.
- Produces: Populated rows in `market.historico_pl_indice`, `market.fluxo_investidor_b3`, `market.contas_publicas_governo`, `market.credito_sistema_financeiro`, and `analytics.demonstrativo_padronizado_serie`.

- [ ] **Step 1: Write test `../fin-ingestion/tests/test_oceans14_pipelines.py`**
- [ ] **Step 2: Implement `oceans14_macro_market_pipeline.py` and `financial_matrix_pipeline.py`**
- [ ] **Step 3: Run `uv run pytest tests/test_oceans14_pipelines.py` and verify PASS**
- [ ] **Step 4: Execute a seed/ingestion run to populate database with reference data**
- [ ] **Step 5: Commit `fin-ingestion` changes**

---

### Task 3: Backend API Routers & Business Logic in `fin-api`

**Files:**
- Create: `../fin-api/app/macro/schemas.py`
- Create: `../fin-api/app/macro/service.py`
- Create: `../fin-api/app/macro/router.py`
- Modify: `../fin-api/app/stocks/schemas.py` (Add matrix & consistency schemas)
- Modify: `../fin-api/app/stocks/service.py` (Add multi-year DRE/BP/DFC and ranking methods)
- Modify: `../fin-api/app/stocks/router.py` (Add `/screener/consistency`, `/ranking`, `/{ticker}/financials/matrix`, `/{ticker}/dividends/matrix`)
- Modify: `../fin-api/app/fiis/router.py` (Add `/ranking`, `/{ticker}/vacancy-history`)
- Modify: `../fin-api/app/market/router.py` (Add `/ibov-pe-history`, `/investor-flows`, `/earnings-calendar`)
- Modify: `../fin-api/app/comparator/router.py` (Multi-ticker real normalized base 100 returns)
- Modify: `../fin-api/app/main.py` (Register macro router)
- Test: `../fin-api/tests/test_oceans14_endpoints.py`

**Interfaces:**
- Produces REST endpoints for all Oceans14 equivalent features with validated Pydantic schemas.

- [ ] **Step 1: Write unit tests in `../fin-api/tests/test_oceans14_endpoints.py`**
- [ ] **Step 2: Implement schemas, services, and routers**
- [ ] **Step 3: Run `uv run pytest tests/test_oceans14_endpoints.py` and verify all pass**
- [ ] **Step 4: Commit `fin-api` changes**

---

### Task 4: Frontend Components & Pages in `fin-web`

**Files:**
- Create: `../fin-web/src/schemas/oceans14.ts`
- Modify: `../fin-web/src/lib/api.ts` (Add API client functions for all new endpoints)
- Create: `../fin-web/src/app/acoes/ranking/page.tsx`
- Create: `../fin-web/src/app/acoes/busca-avancada/page.tsx`
- Create: `../fin-web/src/app/acoes/sem-prejuizo/page.tsx`
- Create: `../fin-web/src/app/acoes/historico-pl-bovespa/page.tsx`
- Create: `../fin-web/src/app/acoes/participacao-investidores-b3/page.tsx`
- Create: `../fin-web/src/app/acoes/agenda-resultados/page.tsx`
- Create: `../fin-web/src/app/acoes/agenda-dividendos/page.tsx`
- Create: `../fin-web/src/app/fundos-imobiliarios/ranking/page.tsx`
- Create: `../fin-web/src/app/fundos-imobiliarios/busca-avancada/page.tsx`
- Create: `../fin-web/src/app/indicadores-economicos/page.tsx`
- Modify: `../fin-web/src/app/acoes/[ticker]/AcaoDetailClient.tsx` (Add 10-year Financial Matrix and Monthly Dividend Matrix)
- Modify: `../fin-web/src/app/comparador/page.tsx` (Multi-ticker base 100 comparison)
- Modify: `../fin-web/src/components/ui/Navbar.tsx` (Add navigation links)
- Test: `pnpm run build`

- [ ] **Step 1: Create TypeScript contracts in `src/schemas/oceans14.ts` and API methods in `src/lib/api.ts`**
- [ ] **Step 2: Implement Equities pages (Ranking, Busca Avançada, Sem Prejuízo, IBOV P/L, Investidores B3, Agendas)**
- [ ] **Step 3: Implement Real Estate (FIIs Ranking and Busca Avançada)**
- [ ] **Step 4: Implement Macro Dashboard (`/indicadores-economicos`)**
- [ ] **Step 5: Enhance `AcaoDetailClient.tsx` and `comparador/page.tsx` with high-density data matrix**
- [ ] **Step 6: Update `Navbar.tsx` navigation**
- [ ] **Step 7: Run `pnpm run build` and ensure zero errors**
- [ ] **Step 8: Commit `fin-web` changes**

---

### Task 5: End-to-End System Validation

- [ ] **Step 1: Verify database objects in Neon DB with `verify_10_migration.py`**
- [ ] **Step 2: Run all backend tests with `uv run pytest` across `fin-api`**
- [ ] **Step 3: Run all ingestion tests with `uv run pytest` across `fin-ingestion`**
- [ ] **Step 4: Run production build and typechecks in `fin-web`**
- [ ] **Step 5: Perform live end-to-end integration test querying the running API**
