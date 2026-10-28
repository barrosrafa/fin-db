# Análise de Ações Full-Stack Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete feature set of the portal *Análise de Ações* (`analisedeacoes.com`) covering all 22 analyzed routes (Stocks/REITs US with 30% withholding tax, Mapa de Sazonalidade de Dividendos, Simulador Composto com Magic Number, Teste de Suitability CVM 30, Diretório de Corretoras com tarifas, CMS Dicionário/Livros/Artigos/Notícias, e fluxos de Auth/Paywall) across `fin-db`, `fin-ingestion`, `fin-api`, and `fin-web` with comprehensive verification.

**Architecture:** 
- **Database (`fin-db`):** PostgreSQL 18 + TimescaleDB (Neon Serverless) with schemas `cms`, `suitability`, extensions to `market`, `asset_details`, `analytics`, `system`, and pre-aggregated seasonality table `analytics.mapa_sazonalidade_dividendo`.
- **Ingestion (`fin-ingestion`):** Python pipelines for PTAX FX rate ingestion, US Stocks/REITs SEC/market data, CVM material facts, and monthly dividend recurrence aggregation.
- **Backend (`fin-api`):** FastAPI async routers for Dividend Simulator (compound interest + inflation + DGR), Dividend Map heatmap query, Suitability scoring engine, Brokers directory, CMS (Glossary/Books/Articles/Tickets), and Entitlements.
- **Frontend (`fin-web`):** Next.js 16 App Router with modern cyber-financial dark theme, virtualized data tables, interactive SVG heatmap grid, compound calculator sliders with dual-curve charts, multi-step suitability wizard, and soft-paywall gates.

**Tech Stack:**
- Database: PostgreSQL 18 / TimescaleDB (Neon Serverless)
- Ingestion: Python 3.12 / Pydantic v2 / Asyncpg / Httpx (`fin-ingestion`)
- Backend: FastAPI / SQLAlchemy 2.0 Async / Redis / ARQ (`fin-api`)
- Frontend: Next.js 16 / React 19 / TypeScript 5 / Tailwind CSS v4 (`fin-web`)

**Spec:** Gap Analysis Técnico & REA Specification (`analisedeacoes.com`)

## Global Constraints

- Preserve all existing database objects (baseline, 01-10 stages), test suites, and operational configurations.
- Use idempotent PostgreSQL DDL (`IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `ON CONFLICT DO UPDATE/NOTHING`).
- Strict TypeScript typing without `any` and maintain clean `pnpm build` with zero compiler errors.
- Ensure all API endpoints handle empty query states and invalid tickers gracefully with RFC-7807 compliant error schemas.
- Ensure all financial numeric values use high-precision decimals (`NUMERIC(14,6)` / `NUMERIC(18,4)`) and tabular monospace numerals in UI.

## Review Focus

1. **Simulador de Dividendos:** Compound interest calculation must strictly account for withholding tax (0% for BR shares/FIIs, 30% for US REITs/Stocks) and calculate the Magic Number inflection point correctly.
2. **Mapa de Dividendos:** Pre-aggregated queries on `analytics.mapa_sazonalidade_dividendo` must respond in sub-15ms for both full heatmap and reverse month filter.
3. **Suitability Engine:** Scoring must correctly weight time horizon, loss tolerance, knowledge, and liquidity according to CVM Resolution 30 into Conservador, Moderado, and Arrojado.
4. **Paywall & SEO:** Protected premium analytics must remain crawlable by search engines via semantic SSR with visual overlay while restricting full raw data access for free users.
5. **Multi-Currency:** Stock and REIT catalog must correctly display USD quotes alongside BRL conversions computed via official BCB PTAX closing rates.

---

### Task 1: Database Migration `v3.9` in `fin-db` (Análise de Ações Coverage)

**Files:**
- Create: `sql/11_analise_de_acoes_coverage_v3.9/01_analise_de_acoes_tables_and_views.sql`
- Create: `scripts/verify_11_migration.py`
- Test: `scripts/verify_11_migration.py`

**Interfaces:**
- Produces: 
  - Schemas: `cms`, `suitability`
  - Tables: `market.cotacao_cambio_diaria`, `core.ativo_dupla_listagem`, `asset_details.detalhe_reit`, `analytics.mapa_sazonalidade_dividendo`, `cms.termo_glossario`, `cms.livro_investimento`, `cms.artigo_blog`, `cms.ticket_suporte`, `suitability.pergunta`, `suitability.opcao_resposta`, `suitability.categoria_risco`, `suitability.historico_respostas_usuario`, `system.plano_entitlement`, `system.webhook_evento_processado`
  - Column additions to `market.provento` and `core.instituicao_financeira`
  - Seeds for Glossary, Books, Suitability questions/options, Brokers, REIT details, and Dividend Map

- [ ] **Step 1: Write SQL migration `sql/11_analise_de_acoes_coverage_v3.9/01_analise_de_acoes_tables_and_views.sql`**
- [ ] **Step 2: Write test/verification script `scripts/verify_11_migration.py`**
- [ ] **Step 3: Execute migration and verify table existence and seed row counts**
- [ ] **Step 4: Commit `fin-db` changes**

---

### Task 2: Data Pipelines & Aggregators in `fin-ingestion`

**Files:**
- Create: `fin_ingestion/pipelines/analise_de_acoes_pipeline.py`
- Create: `fin_ingestion/pipelines/dividend_seasonality_pipeline.py`
- Create: `tests/test_analise_de_acoes_pipeline.py`

**Interfaces:**
- Produces:
  - `DividendSeasonalityAggregator.aggregate_seasonality(db_pool)`: Populates `analytics.mapa_sazonalidade_dividendo`
  - `PtaxExchangeRatePipeline.fetch_and_store_ptax(date, db_pool)`: Ingests BCB PTAX into `market.cotacao_cambio_diaria`
  - `USAssetsIngestionPipeline.sync_us_assets(tickers, db_pool)`: Populates US Stocks & REIT metrics

- [ ] **Step 1: Implement `dividend_seasonality_pipeline.py`**
- [ ] **Step 2: Implement `analise_de_acoes_pipeline.py`**
- [ ] **Step 3: Write and execute unit tests in `tests/test_analise_de_acoes_pipeline.py`**
- [ ] **Step 4: Commit `fin-ingestion` changes**

---

### Task 3: Backend Routers & Engines in `fin-api`

**Files:**
- Create: `app/analytics/router.py`
- Create: `app/analytics/schemas.py`
- Create: `app/analytics/service.py`
- Create: `app/cms/router.py`
- Create: `app/cms/schemas.py`
- Create: `app/cms/service.py`
- Create: `app/suitability/router.py`
- Create: `app/suitability/schemas.py`
- Create: `app/suitability/service.py`
- Create: `app/brokers/router.py`
- Create: `app/brokers/schemas.py`
- Create: `app/brokers/service.py`
- Modify: `app/stocks/router.py` (Add US stocks and REITs endpoints)
- Modify: `app/billing/router.py` (Add plans and entitlements list endpoint)
- Modify: `app/main.py` (Mount new routers)
- Create: `tests/test_analise_de_acoes_api.py`

**Interfaces:**
- Endpoints:
  - `POST /api/v1/analytics/simulate-dividends`: DividendSimulationRequest -> DividendSimulationResponse
  - `GET /api/v1/analytics/dividend-map`: Query params (month, min_probability) -> DividendMapResponse
  - `GET /api/v1/analytics/dividend-calendar`: Query params (start_date, end_date, event_type) -> List[DividendCalendarDetailItem]
  - `GET /api/v1/cms/glossary`: Query params (letter, q) -> GlossaryResponse
  - `GET /api/v1/cms/glossary/{slug}`: Term detail
  - `GET /api/v1/cms/books`: List of curated financial books
  - `GET /api/v1/cms/articles`: List of blog articles
  - `POST /api/v1/cms/support/ticket`: Submit support ticket
  - `GET /api/v1/suitability/questions`: Questions with weighted answer options
  - `POST /api/v1/suitability/evaluate`: Answers -> RiskProfileResult with target asset allocation
  - `GET /api/v1/brokers`: List of brokers with brokerage fees and platform ratings
  - `GET /api/v1/stocks/us`: US Equities with USD and BRL PTAX quotes
  - `GET /api/v1/reits`: US REITs with FFO, AFFO, P/FFO, and 30% withholding tax simulation
  - `GET /api/v1/billing/plans`: Subscription plans with feature entitlements

- [ ] **Step 1: Implement `app/analytics/` router, service, and schemas**
- [ ] **Step 2: Implement `app/cms/` router, service, and schemas**
- [ ] **Step 3: Implement `app/suitability/` router, service, and schemas**
- [ ] **Step 4: Implement `app/brokers/` router, service, and schemas**
- [ ] **Step 5: Extend `app/stocks/router.py` and `app/billing/router.py`**
- [ ] **Step 6: Mount routers in `app/main.py`**
- [ ] **Step 7: Write and run `tests/test_analise_de_acoes_api.py`**
- [ ] **Step 8: Commit `fin-api` changes**

---

### Task 4: Frontend Implementation in `fin-web` (All 22 Routes)

**Files:**
- Create: `src/app/agenda-dividendos/page.tsx`
- Create: `src/app/mapa-de-dividendos/page.tsx`
- Create: `src/app/simulador-de-dividendos/page.tsx`
- Create: `src/app/perfil-de-investidor/page.tsx`
- Create: `src/app/corretoras/page.tsx`
- Create: `src/app/stocks/page.tsx`
- Create: `src/app/reits/page.tsx`
- Create: `src/app/dicionario/page.tsx`
- Create: `src/app/dicionario/[slug]/page.tsx`
- Create: `src/app/livros-investimentos/page.tsx`
- Create: `src/app/artigos/page.tsx`
- Create: `src/app/noticias/page.tsx`
- Create: `src/app/cadastro/page.tsx`
- Create: `src/app/login/page.tsx`
- Create: `src/app/login/recuperacao/page.tsx`
- Create: `src/app/premium/page.tsx`
- Create: `src/app/sobre/page.tsx`
- Create: `src/app/contato/page.tsx`
- Create: `src/app/termos-de-uso/page.tsx`
- Create: `src/app/politica-de-privacidade/page.tsx`
- Modify: `src/components/ui/Navbar.tsx` (Add dropdown links to all modules)
- Modify: `src/components/ui/Footer.tsx` (Add sitemap links to all 22 routes)
- Modify: `src/lib/api.ts` (Add client fetchers for new endpoints)
- Create: `src/components/auth/PaywallGate.tsx` (Soft paywall component)

- [ ] **Step 1: Update `src/lib/api.ts` with new API client methods and TypeScript types**
- [ ] **Step 2: Create analytical tools pages: `/agenda-dividendos`, `/mapa-de-dividendos`, `/simulador-de-dividendos`**
- [ ] **Step 3: Create international markets pages: `/stocks`, `/reits`**
- [ ] **Step 4: Create educational and community pages: `/perfil-de-investidor`, `/corretoras`, `/dicionario`, `/livros-investimentos`, `/artigos`, `/noticias`**
- [ ] **Step 5: Create auth, commercial, and institutional pages: `/cadastro`, `/login`, `/login/recuperacao`, `/premium`, `/sobre`, `/contato`, `/termos-de-uso`, `/politica-de-privacidade`**
- [ ] **Step 6: Update `Navbar.tsx` and `Footer.tsx` navigation taxonomy**
- [ ] **Step 7: Run `pnpm build` and verify that all 22 routes compile statically/dynamically without errors**
- [ ] **Step 8: Commit `fin-web` changes**

---

### Task 5: End-to-End Functional Validation, Security Audit & Regression Testing

**Files:**
- Create: `tests/test_analise_de_acoes_e2e.py` (in `fin-api`)
- Test: Full test run across `fin-api`, `fin-ingestion`, `fin-db`, and `fin-web`

- [ ] **Step 1: Run comprehensive e2e test script validating all API contracts and calculation engines**
- [ ] **Step 2: Run full pytest suite in `fin-api` to ensure zero regressions**
- [ ] **Step 3: Run full pytest suite in `fin-ingestion`**
- [ ] **Step 4: Run production build `pnpm build` in `fin-web`**
- [ ] **Step 5: Final review of all 22 routes against requirements**
