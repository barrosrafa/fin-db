# Portfolio Graph Reconciliation & Look-Through Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the bitemporal look-through debtor graph, multi-source metric reconciliation engine with divergence taxonomy, and deterministic falsifiable phrase generator across `fin-db`, `fin-ingestion`, `fin-api`, `fin-web`, and `fin-infra`.

**Architecture:** A unified substrate in `fin-db` with bitemporal edges (`valid_range`, `transaction_range`) and MDM canonical entities, fed by `fin-ingestion` (ANBIMA Data + CVM 175 CDA + Legacy Seed), exposed via `fin-api` with look-through traversal and slot-based deterministic phrase generation (<10ms), and visualized in `fin-web` with triple coverage bars, interactive source pills, and divergence explainers.

**Tech Stack:** PostgreSQL 18 / TimescaleDB, Python 3.12 (FastAPI, Pydantic v2, Pytest, Requests/Httpx), Next.js 15 (React 19, TypeScript, Tailwind CSS), Docker Compose / Redis.

**Spec:** `/Users/rafaelaparecido/fin/docs/superpowers/specs/2026-10-26-portfolio-graph-reconciliation-design.md`

## Global Constraints
- Bitemporal edges must use PostgreSQL `tstzrange` with GiST index support.
- Phrase generator must be 100% deterministic in MVP (< 10ms execution, zero LLM network dependencies).
- User overrides must be indexed by `(user_id, source_asset_id, target_entity_id)` with `override_type` to decouple from transient CDA edge IDs.
- Non-decomposable bucket must explicitly differentiate `TEMPORARILY_UNAVAILABLE` from `STRUCTURE_OPAQUE`.
- Discrepancy taxonomy must classify divergences into finite categories (`PRICE_TIMESTAMP_MISMATCH`, `DIVIDEND_WINDOW_MISMATCH`, `TAX_TREATMENT_MISMATCH`, `CAPITAL_BASE_MISMATCH`, `AMORTIZATION_ACCOUNTING`, `SOURCE_STALENESS_OR_ERROR`).
- Zero financial recommendation wording; purely diagnostic/informational copy compliant with CVM guidelines.

## Review Focus
1. Bitemporal query as-of: querying at `as_of_valid_time` and `as_of_transaction_time` returns the historical version known at that instant, not the retified future version.
2. Incomplete ANBIMA coverage: CRIs prior to Dec/2025 fallback to `canonical.cri_legacy_seeds`; if absent in both, mapped to `TEMPORARY_PENDING_CURATION`.
3. Division by zero in mixed portfolios: a portfolio with 0% FIIs/Credit gracefully displays 100% resolved level-0 exposure without NaN in coverage bar.
4. Divergence delta edge case: identical metrics across sources produce zero active divergence rows without phantom alerts.
5. User override persistence: subsequent CDA monthly ingestion preserves user's custom mapping without overwriting or duplicating.

---

### Task 1: `fin-db` — Bitemporal Graph, MDM & Reconciliation Schemas

**Files:**
- Create: `/Users/rafaelaparecido/fin/sql/07_portfolio_graph_reconciliation_v3.5/01_graph_bitemporal_and_mdm.sql`
- Create: `/Users/rafaelaparecido/fin/sql/07_portfolio_graph_reconciliation_v3.5/02_reconciliation_and_taxonomies.sql`
- Create: `/Users/rafaelaparecido/fin/sql/07_portfolio_graph_reconciliation_v3.5/03_seeds_anbima_and_legacy_cris.sql`
- Test: `/Users/rafaelaparecido/fin/scripts/verify_07_migrations.py`

**Interfaces:**
- Consumes: Existing PostgreSQL 18 schemas (`core`, `canonical`, `market`, `wealth`).
- Produces: Tables `graph.entities`, `graph.entity_aliases`, `graph.edges_bitemporal`, `canonical.cri_legacy_seeds`, `wealth.user_graph_overrides`, `audit.inference_logs`, `audit.discrepancies`, `reconciliation.divergence_taxonomies`, `reconciliation.metric_snapshots`, `reconciliation.divergences`, `reconciliation.canonical_metrics`.

- [ ] **Step 1: Write verification test script**

Create `/Users/rafaelaparecido/fin/scripts/verify_07_migrations.py` verifying SQL syntax and schema structure declarations against the spec.

- [ ] **Step 2: Run verification script to confirm tables are missing**

Run: `python3 /Users/rafaelaparecido/fin/scripts/verify_07_migrations.py`
Expected: FAIL indicating SQL migration files or tables not yet present.

- [ ] **Step 3: Create migration `01_graph_bitemporal_and_mdm.sql`**

Define `graph` schema, `graph.entities`, `graph.entity_aliases`, `graph.edges_bitemporal` (with `tstzrange`, `coverage_category` enum), `canonical.cri_legacy_seeds`, `wealth.user_graph_overrides`, `audit.inference_logs`, and `audit.discrepancies`.

- [ ] **Step 4: Create migration `02_reconciliation_and_taxonomies.sql`**

Define `reconciliation` schema, `reconciliation.divergence_taxonomies` (with 6 finite taxonomy codes), `reconciliation.metric_snapshots`, `reconciliation.divergences`, and `reconciliation.canonical_metrics`.

- [ ] **Step 5: Create migration `03_seeds_anbima_and_legacy_cris.sql`**

Seed default divergence taxonomies and top legacy CRIs for major paper FIIs (KNIP11, KNCR11, CPTS11, KNSC11) mapping to canonical groups (JHSF, MRV, etc.).

- [ ] **Step 6: Run verification script to verify syntax and schema completeness**

Run: `python3 /Users/rafaelaparecido/fin/scripts/verify_07_migrations.py`
Expected: PASS.

- [ ] **Step 7: Commit in `fin` repo**

```bash
git add sql/07_portfolio_graph_reconciliation_v3.5/ scripts/verify_07_migrations.py
git commit -m "feat(fin-db): add bitemporal graph, MDM and reconciliation migrations v3.5"
```

---

### Task 2: `fin-ingestion` — ANBIMA Data Collector, CDA Parser & Reconciler

**Files:**
- Create: `/Users/rafaelaparecido/fin-ingestion/fin_ingestion/collectors/anbima_cri_data.py`
- Create: `/Users/rafaelaparecido/fin-ingestion/fin_ingestion/pipelines/cvm_cda_parser.py`
- Create: `/Users/rafaelaparecido/fin-ingestion/fin_ingestion/pipelines/reconciliation_pipeline.py`
- Test: `/Users/rafaelaparecido/fin-ingestion/tests/test_anbima_cri_data.py`
- Test: `/Users/rafaelaparecido/fin-ingestion/tests/test_cvm_cda_parser.py`
- Test: `/Users/rafaelaparecido/fin-ingestion/tests/test_reconciliation_pipeline.py`

**Interfaces:**
- Consumes: ANBIMA public data, CVM CDA datasets, Status Invest and Funds Explorer metrics.
- Produces: Normalized data structures for `graph.edges_bitemporal`, `graph.entities`, `reconciliation.metric_snapshots`, `reconciliation.divergences`.

- [ ] **Step 1: Write failing unit test for `anbima_cri_data.py`**

Test parsing ANBIMA public data records extracting `isin`, `cnpj_devedor`, `razao_social`, `nome_fantasia`, `data_encerramento`.

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest /Users/rafaelaparecido/fin-ingestion/tests/test_anbima_cri_data.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement `AnbimaCriCollector` in `anbima_cri_data.py`**

Class `AnbimaCriCollector` with methods `fetch_public_dataset()` and `normalize_records()`.

- [ ] **Step 4: Write failing unit test for `cvm_cda_parser.py`**

Test parsing CVM 175 CDA FII holdings isolating CRI receivables and linking ISIN to fund ticker.

- [ ] **Step 5: Implement `CvmCdaParser` in `cvm_cda_parser.py`**

Extract assets, weights (% PL), ISINs, and categorize between resolved, legacy, or opaque.

- [ ] **Step 6: Write failing unit test for `reconciliation_pipeline.py`**

Test comparing Status Invest vs Funds Explorer DY/P_VP with divergence classification (`DIVIDEND_WINDOW_MISMATCH`, etc.).

- [ ] **Step 7: Implement `ReconciliationEngine` in `reconciliation_pipeline.py`**

Compute deltas, match against known taxonomy rules, generate consensus interval and confidence score.

- [ ] **Step 8: Run all ingestion tests**

Run: `pytest /Users/rafaelaparecido/fin-ingestion/tests/ -v`
Expected: All tests PASS.

- [ ] **Step 9: Commit in `fin-ingestion` repo**

```bash
git add fin_ingestion/collectors/anbima_cri_data.py fin_ingestion/pipelines/cvm_cda_parser.py fin_ingestion/pipelines/reconciliation_pipeline.py tests/
git commit -m "feat(fin-ingestion): add ANBIMA CRI collector, CVM CDA parser and reconciliation pipeline"
```

---

### Task 3: `fin-api` — Debtor Graph Look-Through, Deterministic Phrase Generator & API Endpoints

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/portfolio/debtor_graph.py`
- Create: `/Users/rafaelaparecido/fin-api/app/intelligence/falsifiable_phrase.py`
- Create: `/Users/rafaelaparecido/fin-api/app/comparator/arbitration.py`
- Create: `/Users/rafaelaparecido/fin-api/app/portfolio/overrides.py`
- Modify: `/Users/rafaelaparecido/fin-api/app/main.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_debtor_graph.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_falsifiable_phrase.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_arbitration.py`

**Interfaces:**
- Consumes: User portfolio positions (`core.holdings`), bitemporal edges (`graph.edges_bitemporal`), overrides (`wealth.user_graph_overrides`).
- Produces:
  - `GET /api/v1/portfolio/{user_id}/debtor-concentration`: aggregated exposure by canonical group + triple coverage metrics.
  - `GET /api/v1/portfolio/{user_id}/falsifiable-phrase`: deterministic template statement with interactive pill slots and inference logging.
  - `GET /api/v1/reconciliation/{ticker}`: divergence explainer with source comparison and taxonomy badges.
  - `POST /api/v1/portfolio/{user_id}/overrides`: apply user-level graph override.

- [ ] **Step 1: Write failing unit test for `debtor_graph.py`**

Test traversal of portfolio FII holdings into underlying debtors, applying `wealth.user_graph_overrides` and computing triple coverage.

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest /Users/rafaelaparecido/fin-api/tests/test_debtor_graph.py -v`
Expected: FAIL.

- [ ] **Step 3: Implement `DebtorGraphService` in `app/portfolio/debtor_graph.py`**

Implement `calculate_debtor_exposure(portfolio_positions, overrides=None)` returning resolved debtor weights, opaque bucket, and temporary pending bucket.

- [ ] **Step 4: Write failing unit test for `falsifiable_phrase.py`**

Test generating slot-filled deterministic phrase, verifying `<10ms` execution and correct pill slot data.

- [ ] **Step 5: Implement `FalsifiablePhraseEngine` in `app/intelligence/falsifiable_phrase.py`**

Slot-based templating: macro class, total pct, decomposed asset pills, rating change event, threshold alert, inference logging data.

- [ ] **Step 6: Write failing unit test for `arbitration.py`**

Test consensus range $[min, max]$, IQR, and algorithmic canonical anchor selection.

- [ ] **Step 7: Implement `ArbitrationEngine` in `app/comparator/arbitration.py`**

Consensus calculation, anchor scoring rule ($w_1 Freshness + w_2 Doc + w_3 Stability$), audit record creation.

- [ ] **Step 8: Mount routers in `app/main.py`**

Register routes for debtor concentration, falsifiable phrases, reconciliation, and overrides.

- [ ] **Step 9: Run all API tests**

Run: `pytest /Users/rafaelaparecido/fin-api/tests/ -v`
Expected: All tests PASS.

- [ ] **Step 10: Commit in `fin-api` repo**

```bash
git add app/portfolio/debtor_graph.py app/intelligence/falsifiable_phrase.py app/comparator/arbitration.py app/portfolio/overrides.py app/main.py tests/
git commit -m "feat(fin-api): implement debtor graph look-through, deterministic phrase engine and arbitration"
```

---

### Task 4: `fin-web` — Cockpit UI Components (Debtor Card, Coverage Bar, Pills & Divergence Modal)

**Files:**
- Create: `/Users/rafaelaparecido/fin-web/src/components/portfolio/DebtorConcentrationCard.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/components/portfolio/TripleCoverageBar.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/components/intelligence/FalsifiablePhraseCard.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/components/reconciliation/DivergenceExplainerModal.tsx`
- Create: `/Users/rafaelaparecido/fin-web/src/app/cockpit/debtor-analysis/page.tsx`
- Test: `/Users/rafaelaparecido/fin-web/src/components/portfolio/__tests__/DebtorConcentrationCard.test.tsx`

**Interfaces:**
- Consumes: REST endpoints from `fin-api` (`/api/v1/portfolio/...`, `/api/v1/reconciliation/...`).
- Produces: Interactive Next.js React components rendering the portfolio-level look-through cockpit.

- [ ] **Step 1: Create `TripleCoverageBar.tsx`**

Render tripartite segmented progress bar: `[ % Desdobrado | % Temporariamente Indisponível (Legado/ANBIMA) | % Estruturalmente Opaco ]` with tooltip explanations.

- [ ] **Step 2: Create `DebtorConcentrationCard.tsx`**

Render debtor rankings (e.g., Grupo JHSF 34%, MRV 12%), underlying tickers contributing, rating badges, and view toggle (Total Portfolio vs Credit/FIIs slice).

- [ ] **Step 3: Create `FalsifiablePhraseCard.tsx`**

Render AI Committee statement with interactive clickable pills for percentages and sources, launching calculation tree and audit proof modals.

- [ ] **Step 4: Create `DivergenceExplainerModal.tsx`**

Display side-by-side metric comparison between Status Invest, Funds Explorer, and canonical anchor with taxonomy reason badge.

- [ ] **Step 5: Create Cockpit page `/app/cockpit/debtor-analysis/page.tsx`**

Compose components with responsive design, state management, and user override action.

- [ ] **Step 6: Build and typecheck in `fin-web`**

Run: `pnpm --prefix /Users/rafaelaparecido/fin-web build` (or `pnpm exec tsc --noEmit`)
Expected: PASS with 0 TypeScript/build errors.

- [ ] **Step 7: Commit in `fin-web` repo**

```bash
git add src/components/ src/app/
git commit -m "feat(fin-web): add debtor concentration card, triple coverage bar and falsifiable phrase components"
```

---

### Task 5: `fin-infra` & End-to-End System Verification

**Files:**
- Create: `/Users/rafaelaparecido/fin-infra/scripts/verify_ecosystem_e2e.py`
- Modify: `/Users/rafaelaparecido/fin-infra/docker-compose.yml` (service definitions / environment alignment)

**Interfaces:**
- Consumes: Running services or mocks across `fin-db`, `fin-ingestion`, `fin-api`, `fin-web`.
- Produces: Verified end-to-end flow from CDA/ANBIMA data -> graph look-through -> falsifiable phrase with clickable provenance.

- [ ] **Step 1: Write E2E verification test `verify_ecosystem_e2e.py`**

Simulate:
1. Ingesting FII portfolio containing KNIP11 and KNCR11 holding CRIs.
2. Resolving ISINs via ANBIMA Data and Legacy Seed to Grupo JHSF.
3. Calculating debtor exposure (aggregating direct CRI + FII look-through).
4. Emitting deterministic falsifiable phrase and validating all audit slots.
5. Emitting multi-source divergence report for DY with taxonomy badge.

- [ ] **Step 2: Run E2E verification test**

Run: `python3 /Users/rafaelaparecido/fin-infra/scripts/verify_ecosystem_e2e.py`
Expected: PASS with exit code 0.

- [ ] **Step 3: Commit in `fin-infra` repo**

```bash
git add scripts/verify_ecosystem_e2e.py docker-compose.yml
git commit -m "feat(fin-infra): add end-to-end ecosystem verification suite for portfolio graph"
```
