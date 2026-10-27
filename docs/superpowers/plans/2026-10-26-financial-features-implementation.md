# 12 Financial Platforms Unified Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete catalog of deduplicated features from the 12 Brazilian financial analysis platforms across `fin-api`, `fin-web`, and `fin-ingestion`, ensuring zero gaps in endpoints, deep-dive views, and interactive calculation engines.

**Architecture:** 
1. `fin-api` exposes modular FastAPI routers under `/api/v1/` for FIIs (properties, SiiLA, contracts, CRIs, Brick Score), Stocks (DRE/DFC/BP, valuation, checklists, consensus), Funds (CVM 175, 10x10 risk matrix, CDA), ETFs (TER, NAV spread, flows), Derivatives (options chain with Greeks, BTC borrowing, buybacks), Fixed Income (treasury, yield curves), Screener, Comparator, and Intelligence.
2. `fin-web` provides Next.js 15 pages in Dark Obsidian aesthetic for all asset classes, adding missing deep-dives (`/fundos/[id]`, `/etfs/[ticker]`, `/derivativos`) and dynamic interactive calculators (Graham/Bazin/DCF sliders, Magic Number snowball calculator, Multi-asset comparator).
3. `fin-ingestion` analytics engines feed calculations and orchestrate ingestion seamlessly.

**Tech Stack:** Python 3.12, FastAPI, Pydantic v2, Redis, Next.js 15 (App Router, React 19), TypeScript, Tailwind/Pure CSS Tokens, Zod.

**Spec:** `/Users/rafaelaparecido/.gemini/antigravity/brain/29b740ee-32b3-44e0-938d-fe796cee41da/plano_abrangente_12_sites.md`

## Global Constraints
- Strictly additive & non-destructive implementations.
- No hallucinated data fields; adhere to exact empirical REA specifications of the 12 platforms.
- TypeScript strict typing without `any` workarounds in `fin-web`.
- Clean FastAPI dependency injection and Pydantic schemas in `fin-api`.

## Review Focus
1. Handling division by zero in financial valuation models (e.g. negative earnings for Graham, zero dividend for Bazin, growth rate >= cost of equity for Gordon).
2. Deep-dive dynamic routes in Next.js (`[id]` and `[ticker]`) with fallback when ticker is lowercase or not found.
3. Options Greeks calculations with extreme strikes (deep ITM or deep OTM).
4. Magic number calculation when monthly dividend is zero or negative.
5. Multi-asset comparator when normalizing assets with different start dates or trading calendars.

---

### Task 1: `fin-api` — Specialized Domain Routers & Schemas

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/fiis/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/fiis/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/fiis/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/stocks/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/stocks/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/stocks/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/funds/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/funds/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/funds/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/etfs/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/etfs/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/etfs/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/derivatives/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/derivatives/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/derivatives/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/fixed_income/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/fixed_income/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/fixed_income/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/intelligence/router.py`
- Modify: `/Users/rafaelaparecido/fin-api/app/main.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_specialized_routers.py`

**Interfaces:**
- Consumes: `app.core.database`, `app.core.redis`, `app.core.exceptions`
- Produces: REST endpoints mounted under `/api/v1/fiis`, `/api/v1/stocks`, `/api/v1/funds`, `/api/v1/etfs`, `/api/v1/derivatives`, `/api/v1/fixed-income`, `/api/v1/intelligence`

- [ ] **Step 1: Write tests for specialized routers in `fin-api`**
- [ ] **Step 2: Run pytest to verify initial tests fail**
- [ ] **Step 3: Implement schemas, services and routers for all specialized domains**
- [ ] **Step 4: Mount routers in `app/main.py`**
- [ ] **Step 5: Run pytest in `fin-api` and verify all tests pass**
- [ ] **Step 6: Commit changes in `fin-api`**

---

### Task 2: `fin-web` — Schemas & Missing Deep-Dive Pages

**Files:**
- Modify: `/Users/rafaelaparecido/fin-web/src/schemas/financial.ts`
- Modify: `/Users/rafaelaparecido/fin-web/src/data/mock/marketData.ts`
- Create: `/Users/rafaelaparecido/fin-web/src/app/fundos/[id]/page.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/app/fundos/[id]/FundDetailClient.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/app/etfs/[ticker]/page.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/app/etfs/[ticker]/ETFDetailClient.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/app/derivativos/page.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/app/derivativos/DerivativesClient.tsx`
- Modify: `/Users/rafaelaparecido/fin-web/src/components/ui/Navbar.tsx`

**Interfaces:**
- Consumes: Next.js App Router, Zod schemas, UI components (`Card`, `Badge`, `Tabs`, `RadarChart`, `BarChart`)
- Produces: Dynamic routes for `/fundos/[id]`, `/etfs/[ticker]`, and standalone `/derivativos`

- [ ] **Step 1: Expand Zod schemas for ETF TER, Options Chain, BTC borrowing and Fund Holdings**
- [ ] **Step 2: Implement `/fundos/[id]` with 10x10 Quant Risk Matrix and CDA portfolio view**
- [ ] **Step 3: Implement `/etfs/[ticker]` with TER breakdown, NAV spread gauge, and flow charts**
- [ ] **Step 4: Implement `/derivativos` with options chain (Black-Scholes Greeks), BTC lending rates, and buybacks**
- [ ] **Step 5: Update `Navbar.tsx` to include Derivativos in primary navigation**
- [ ] **Step 6: Run `pnpm build` in `fin-web` to verify compilation and static generation**
- [ ] **Step 7: Commit changes in `fin-web`**

---

### Task 3: `fin-web` — Interactive Calculators & Sliders

**Files:**
- Modify: `/Users/rafaelaparecido/fin-web/src/app/acoes/[ticker]/StockDetailClient.tsx`
- Modify: `/Users/rafaelaparecido/fin-web/src/app/fiis/[ticker]/FIIDetailClient.tsx`
- Modify: `/Users/rafaelaparecido/fin-web/src/app/comparador/page.tsx`
- Modify: `/Users/rafaelaparecido/fin-web/src/app/screener/page.tsx`

**Interfaces:**
- Consumes: `calculateMagicNumber`, Valuation formulas, real-time client state
- Produces: Reactive sliders, dynamic recalculation, and multi-asset filtering

- [ ] **Step 1: Add interactive valuation sliders to StockDetailClient (Graham margin, Bazin target yield, Gordon growth rate, DCF WACC/growth)**
- [ ] **Step 2: Add interactive Magic Number slider to FIIDetailClient (target income, monthly dividend, required shares)**
- [ ] **Step 3: Enhance multi-asset comparator with interactive asset selector and normalized performance chart**
- [ ] **Step 4: Enhance Screener with multi-criteria filters for Ações, FIIs, Fundos, and ETFs**
- [ ] **Step 5: Run `pnpm build` in `fin-web` to verify everything builds with zero errors**
- [ ] **Step 6: Commit changes in `fin-web`**

---

### Task 4: `fin-ingestion` & Verification Across Ecosystem

**Files:**
- Verify: `/Users/rafaelaparecido/fin-ingestion/fin_ingestion/analytics/valuation.py`
- Verify: `/Users/rafaelaparecido/fin-ingestion/fin_ingestion/analytics/risk_metrics.py`
- Verify: `/Users/rafaelaparecido/fin-ingestion/fin_ingestion/analytics/technical.py`
- Test: Run pytest across `fin-ingestion` tests

- [ ] **Step 1: Run pytest in `fin-ingestion`**
- [ ] **Step 2: Run pytest in `fin-api`**
- [ ] **Step 3: Run `pnpm build` in `fin-web`**
- [ ] **Step 4: Final verification and summary across all repos**
