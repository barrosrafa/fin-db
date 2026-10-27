# `fin-api` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish the complete `fin-api` backend (FastAPI HTTP API + ARQ Async Worker), unified in a single Python codebase, consuming and extending the 303 tables of `fin-db` (PostgreSQL 18 / TimescaleDB on Neon), featuring low-latency cache with Redis, 12 REA collector adapters with circuit breakers, hybrid cold-start, strategy-based auth (Supabase Auth), and strategy-based billing (Asaas PIX/Boleto transparent & Card hosted), pushing to `https://github.com/barrosrafa/fin-api`.

**Architecture:** A dual-entrypoint Python package (`app.cli serve` for FastAPI and `app.cli worker` for ARQ) sharing the same Redis connection pool, asyncpg / SQLAlchemy 2.0 database pool, and domain modules. The HTTP API serves cached data in milliseconds under *stale-while-revalidate*, while the ARQ worker executes background cron and on-demand scraping across the 12 REA sources with rate limits, circuit breakers, and deduplication into `fin-db`.

**Tech Stack:** Python 3.12+, FastAPI 0.115+, ARQ 0.26+, Redis 7+, PostgreSQL 18 / TimescaleDB (`asyncpg` + `SQLAlchemy 2.0`), Pydantic V2, `httpx`, `uv`.

**Spec:** `docs/superpowers/specs/2026-10-26-fin-api-design.md`

## Global Constraints
- Python 3.12+ managed by `uv`.
- All I/O operations must be strictly asynchronous (`async def`, `asyncpg`, `httpx.AsyncClient`).
- HTTP API must NEVER execute external scraping or third-party web requests during a user call.
- The `fin-db` database owns all DDL and migrations; `fin-api` acts as a client without introducing conflicting Alembic migrations.
- Cold-start must use `TickerCatalog` $O(1)$ in Redis: invalid tickers return immediate 404; valid un-cached tickers return 202 Accepted with `sync_id`.
- Billing uses Strategy pattern with `PaymentProvider`: Asaas PIX and Boleto are transparent on Day 1; Card is hosted checkout on MVP.
- Repository target is `/Users/rafaelaparecido/fin-api` linked to `https://github.com/barrosrafa/fin-api.git`.

## Review Focus
1. **Invalid Ticker Cold-Start DoS:** Querying unlisted/nonsense tickers (e.g. `NONEXIST99`) must return 404 in < 5ms without scheduling worker jobs.
2. **Circuit Breaker Trip on Scraper 429:** When a collector receives consecutive HTTP 429s, the Redis circuit breaker opens for 10 minutes, preventing further external requests and gracefully serving stale cache or 422.
3. **Webhook Idempotency in Billing:** Duplicate delivery of Asaas payment webhooks must not create duplicate subscription records or trigger redundant plan upgrades.
4. **JWT JIT User Provisioning:** First-time authentication with a valid Supabase JWT creates `core.usuario` without race conditions and caches permissions in Redis for 1h.
5. **Worker Shutdown Grace Period:** SIGTERM signal to ARQ worker allows currently in-flight ticker ingestion jobs to complete cleanly without partial DB writes.

---

### Task 1: Scaffolding, Environment & Core Infrastructure in `/Users/rafaelaparecido/fin-api`

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/pyproject.toml`
- Create: `/Users/rafaelaparecido/fin-api/.env.example`
- Create: `/Users/rafaelaparecido/fin-api/.gitignore`
- Create: `/Users/rafaelaparecido/fin-api/app/config.py`
- Create: `/Users/rafaelaparecido/fin-api/app/core/database.py`
- Create: `/Users/rafaelaparecido/fin-api/app/core/redis.py`
- Create: `/Users/rafaelaparecido/fin-api/app/core/circuit_breaker.py`
- Create: `/Users/rafaelaparecido/fin-api/app/core/catalog.py`
- Create: `/Users/rafaelaparecido/fin-api/app/core/exceptions.py`
- Create: `/Users/rafaelaparecido/fin-api/app/core/logging.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_core_infrastructure.py`

**Interfaces:**
- Produces:
  - `get_settings() -> Settings`
  - `get_async_session() -> AsyncGenerator[AsyncSession, None]`
  - `get_redis_client() -> Redis`
  - `RedisCircuitBreaker(domain: str)`: `async def can_execute() -> bool`, `async def record_failure()`, `async def record_success()`
  - `TickerCatalog`: `async def is_valid(ticker: str) -> bool`, `async def add_tickers(tickers: list[str])`

- [ ] **Step 1: Initialize git repository in `/Users/rafaelaparecido/fin-api` and configure remote `https://github.com/barrosrafa/fin-api.git`**
- [ ] **Step 2: Create `pyproject.toml` with `fastapi`, `uvicorn`, `arq`, `redis`, `asyncpg`, `sqlalchemy`, `pydantic-settings`, `httpx`, `pytest`, `pytest-asyncio`**
- [ ] **Step 3: Write failing unit test in `tests/test_core_infrastructure.py` testing `TickerCatalog`, `Settings`, and `RedisCircuitBreaker`**
- [ ] **Step 4: Implement `app/config.py`, `app/core/database.py`, `app/core/redis.py`, `app/core/circuit_breaker.py`, `app/core/catalog.py`, `app/core/logging.py`, `app/core/exceptions.py`**
- [ ] **Step 5: Run tests using `uv run pytest tests/test_core_infrastructure.py` and verify PASS**
- [ ] **Step 6: Commit: `git add . && git commit -m "feat(core): initialize fin-api repository and core infrastructure"`**

---

### Task 2: Auth Module with Strategy Pattern & Supabase Adapter

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/auth/contracts.py`
- Create: `/Users/rafaelaparecido/fin-api/app/auth/models.py`
- Create: `/Users/rafaelaparecido/fin-api/app/auth/dependencies.py`
- Create: `/Users/rafaelaparecido/fin-api/app/auth/adapters/supabase.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_auth.py`

**Interfaces:**
- Consumes: `Settings`, `get_redis_client`, `get_async_session`
- Produces:
  - `AuthProvider` (ABC)
  - `SupabaseAuthAdapter(AuthProvider)`: `async def validate_token(token: str) -> UserClaims`, `async def get_or_create_user(claims: UserClaims) -> User`
  - `get_current_user(...) -> User`
  - `require_role(role: str)`
  - `require_tier(min_tier: str)`

- [ ] **Step 1: Write failing unit test in `tests/test_auth.py` for JWT validation, JIT user creation, and role/tier checks**
- [ ] **Step 2: Implement domain models in `app/auth/models.py` (`User`, `UserRole`, `SubscriptionTier`) and contract in `app/auth/contracts.py`**
- [ ] **Step 3: Implement `app/auth/adapters/supabase.py` with JWKS / HS256 validation, JIT insertion in `core.usuario`, and 1-hour Redis permission cache**
- [ ] **Step 4: Implement FastAPI dependency `get_current_user` and security decorators in `app/auth/dependencies.py`**
- [ ] **Step 5: Run `uv run pytest tests/test_auth.py` and verify PASS**
- [ ] **Step 6: Commit: `git add app/auth tests/test_auth.py && git commit -m "feat(auth): implement decoupled auth provider and supabase adapter with JIT"`**

---

### Task 3: Ingestion Collectors & 12 REA Adapters with Fallback Routing

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/base.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/normalizer.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/router.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/status_invest.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/investidor10.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/fundamentei.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/fundamentus.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/clube_fii.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/funds_explorer.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/fiis_com_br.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/mais_retorno.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/analise_de_acoes.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/brick360.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/advfn.py`
- Create: `/Users/rafaelaparecido/fin-api/app/collectors/adapters/etfs_brasil.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_collectors.py`

**Interfaces:**
- Consumes: `RedisCircuitBreaker`, `httpx.AsyncClient`
- Produces:
  - `BaseCollector`: `async def collect_ticker(ticker: str) -> dict`
  - `DataNormalizer`: `def normalize_quote(raw: dict) -> CanonicalQuote`, `def normalize_fundamentals(raw: dict) -> CanonicalFundamentals`
  - `CollectorRouter`: `async def collect_asset(ticker: str, asset_class: str) -> CanonicalAssetData`

- [ ] **Step 1: Write failing test in `tests/test_collectors.py` testing `CollectorRouter` fallback chains and circuit breaker integration**
- [ ] **Step 2: Implement `app/collectors/base.py` with `httpx.AsyncClient` session reuse, random user-agent rotation, rate limits, and circuit breaker**
- [ ] **Step 3: Implement `app/collectors/normalizer.py` mapping raw dictionaries into standardized `fin-db` data dictionaries**
- [ ] **Step 4: Implement the 12 REA adapters with domain-specific extraction logic:**
  - Status Invest (XHR DRE, BTC aluguel, cotações)
  - Investidor10 (REST histórico e checklist)
  - Fundamentei (Apollo GraphQL state)
  - Fundamentus (HTML tabular parser)
  - Clube FII (JWT GraphQL 12h + SiiLA transações)
  - Funds Explorer (Ranking e proventos)
  - FIIs.com.br (Agenda proventos)
  - Mais Retorno (CVM 175, CDA carteiras)
  - Análise de Ações (Checklist 5 pilares)
  - Brick360 (REST v2 6 eixos de score)
  - ADVFN (Suportes/resistências e indicadores técnicos)
  - ETFs Brasil (ETFs B3/US e benchmarks Teva)
- [ ] **Step 5: Implement `CollectorRouter` with priority lists and fallback logic**
- [ ] **Step 6: Run `uv run pytest tests/test_collectors.py` and verify PASS**
- [ ] **Step 7: Commit: `git add app/collectors tests/test_collectors.py && git commit -m "feat(collectors): implement 12 REA adapters, normalizer and collector router"`**

---

### Task 4: Worker Engine (ARQ Tasks, Priority Queues & Schedulers)

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/worker/settings.py`
- Create: `/Users/rafaelaparecido/fin-api/app/worker/tasks/ingestion.py`
- Create: `/Users/rafaelaparecido/fin-api/app/worker/tasks/calculation.py`
- Create: `/Users/rafaelaparecido/fin-api/app/worker/tasks/cache.py`
- Create: `/Users/rafaelaparecido/fin-api/app/worker/tasks/housekeeping.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_worker.py`

**Interfaces:**
- Consumes: `CollectorRouter`, `get_redis_client`, `get_async_session`, `TickerCatalog`
- Produces:
  - `WorkerSettings`: ARQ configuration with queues `high_priority`, `default`, `batch`
  - Ingestion tasks: `refresh_ticker_data_task(ctx, ticker, asset_class)`, `sync_market_quotes_task(ctx)`
  - Calculation tasks: `calculate_sector_averages_task(ctx)`, `recalculate_rankings_task(ctx)`
  - Cache tasks: `warm_cache_top_tickers_task(ctx)`, `sync_ticker_catalog_task(ctx)`
  - Housekeeping tasks: `refresh_clube_fii_token_task(ctx)`, `purge_stale_cache_task(ctx)`

- [ ] **Step 1: Write failing test in `tests/test_worker.py` testing task dispatching, context injection, and queue configuration**
- [ ] **Step 2: Implement `app/worker/settings.py` defining queues, `cron_jobs`, `on_startup`, and `on_shutdown` hooks**
- [ ] **Step 3: Implement ingestion tasks in `app/worker/tasks/ingestion.py` that invoke `CollectorRouter`, upsert to `fin-db` and update Redis cache**
- [ ] **Step 4: Implement calculation and cache warm-up tasks in `app/worker/tasks/calculation.py` and `cache.py`**
- [ ] **Step 5: Implement housekeeping in `app/worker/tasks/housekeeping.py`**
- [ ] **Step 6: Run `uv run pytest tests/test_worker.py` and verify PASS**
- [ ] **Step 7: Commit: `git add app/worker tests/test_worker.py && git commit -m "feat(worker): implement ARQ worker settings, cron schedules, and async tasks"`**

---

### Task 5: Market Module (Quotes, Indicators, Screener & Hybrid Cold-Start)

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/market/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/market/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/market/router.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_market.py`

**Interfaces:**
- Consumes: `TickerCatalog`, `get_redis_client`, `get_async_session`
- Produces:
  - `MarketService`:
    - `async def get_quote(ticker: str) -> MarketResponse`: implements 3-tier cold-start (Catalog $O(1)$ $\rightarrow$ Redis Cache $\rightarrow$ DB $\rightarrow$ 202 Accepted + ARQ job)
    - `async def get_sync_status(ticker: str) -> SyncStatusResponse`
    - `async def get_indicators(ticker: str) -> IndicatorsResponse`
    - `async def get_screener(asset_class: str, filters: dict) -> list[ScreenerItem]`
  - Endpoints:
    - `GET /api/v1/market/{ticker}`
    - `GET /api/v1/market/{ticker}/sync-status`
    - `GET /api/v1/market/{ticker}/stream` (SSE)
    - `GET /api/v1/market/{ticker}/indicators`
    - `GET /api/v1/market/screeners/{asset_class}`

- [ ] **Step 1: Write failing test in `tests/test_market.py` testing: 200 fresh, 200 stale + enqueue, 202 accepted for un-cached valid ticker, and 404 for invalid ticker**
- [ ] **Step 2: Define Pydantic request/response schemas in `app/market/schemas.py`**
- [ ] **Step 3: Implement `MarketService` in `app/market/service.py` with strict cold-start gating and stale-while-revalidate**
- [ ] **Step 4: Implement FastAPI routes in `app/market/router.py` including SSE streaming endpoint**
- [ ] **Step 5: Run `uv run pytest tests/test_market.py` and verify PASS**
- [ ] **Step 6: Commit: `git add app/market tests/test_market.py && git commit -m "feat(market): implement market quotes, indicators, screeners, and hybrid cold-start"`**

---

### Task 6: Portfolio Module (Wallets, Positions, Transactions & Performance)

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/portfolio/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/portfolio/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/portfolio/router.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_portfolio.py`

**Interfaces:**
- Consumes: `get_current_user`, `get_async_session`, `MarketService`
- Produces:
  - `PortfolioService`:
    - `async def list_wallets(user_id: str) -> list[Wallet]`
    - `async def create_wallet(user_id: str, data: WalletCreate) -> Wallet`
    - `async def get_positions(wallet_id: str, user_id: str) -> list[Position]`
    - `async def add_transaction(wallet_id: str, user_id: str, data: TransactionCreate) -> Transaction`
    - `async def calculate_performance(wallet_id: str, user_id: str, benchmark: str) -> PerformanceResult`
  - Endpoints:
    - `GET /api/v1/portfolio/wallets`
    - `POST /api/v1/portfolio/wallets`
    - `GET /api/v1/portfolio/wallets/{wallet_id}/positions`
    - `POST /api/v1/portfolio/wallets/{wallet_id}/transactions`
    - `GET /api/v1/portfolio/wallets/{wallet_id}/performance`

- [ ] **Step 1: Write failing test in `tests/test_portfolio.py` for wallet creation, position calculation, and average price consolidation**
- [ ] **Step 2: Implement schemas in `app/portfolio/schemas.py`**
- [ ] **Step 3: Implement `PortfolioService` in `app/portfolio/service.py` querying `core.carteira`, `core.posicao_custodia`, and calculating equity with cached prices**
- [ ] **Step 4: Implement routes in `app/portfolio/router.py` secured with `get_current_user`**
- [ ] **Step 5: Run `uv run pytest tests/test_portfolio.py` and verify PASS**
- [ ] **Step 6: Commit: `git add app/portfolio tests/test_portfolio.py && git commit -m "feat(portfolio): implement portfolio wallets, positions, and performance calculation"`**

---

### Task 7: Billing Module (Strategy Pattern with Asaas PIX/Boleto/Card & Webhooks)

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/billing/contracts.py`
- Create: `/Users/rafaelaparecido/fin-api/app/billing/schemas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/billing/service.py`
- Create: `/Users/rafaelaparecido/fin-api/app/billing/adapters/asaas.py`
- Create: `/Users/rafaelaparecido/fin-api/app/billing/adapters/stripe.py`
- Create: `/Users/rafaelaparecido/fin-api/app/billing/router.py`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_billing.py`

**Interfaces:**
- Consumes: `Settings`, `get_current_user`, `get_async_session`, `get_redis_client`
- Produces:
  - `PaymentProvider` interface
  - `AsaasPaymentProvider`: `create_pix_subscription`, `create_boleto_subscription`, `create_card_hosted_checkout`, `parse_webhook`
  - `BillingService`: subscription lifecycle, plan upgrades, idempotent webhook handling
  - Endpoints:
    - `GET /api/v1/billing/plans`
    - `POST /api/v1/billing/subscribe`
    - `POST /api/v1/billing/webhooks/asaas`
    - `POST /api/v1/billing/webhooks/stripe`

- [ ] **Step 1: Write failing test in `tests/test_billing.py` verifying transparent PIX/Boleto generation, card checkout URL generation, and webhook idempotency**
- [ ] **Step 2: Implement `PaymentProvider` contract in `app/billing/contracts.py` and Pydantic schemas in `schemas.py`**
- [ ] **Step 3: Implement `AsaasPaymentProvider` in `app/billing/adapters/asaas.py` calling Asaas v3 API via `httpx.AsyncClient`**
- [ ] **Step 4: Implement `StripePaymentProvider` skeleton in `app/billing/adapters/stripe.py`**
- [ ] **Step 5: Implement `BillingService` and FastAPI routes in `app/billing/router.py` with signature verification and asynchronous reconciliation**
- [ ] **Step 6: Run `uv run pytest tests/test_billing.py` and verify PASS**
- [ ] **Step 7: Commit: `git add app/billing tests/test_billing.py && git commit -m "feat(billing): implement strategy-based billing with Asaas transparent PIX/Boleto and webhooks"`**

---

### Task 8: Main App Factory, CLI Tooling, Neon `fin-db` Integration & GitHub Push

**Files:**
- Create: `/Users/rafaelaparecido/fin-api/app/main.py`
- Create: `/Users/rafaelaparecido/fin-api/app/cli.py`
- Create: `/Users/rafaelaparecido/fin-api/Dockerfile`
- Create: `/Users/rafaelaparecido/fin-api/docker-compose.yml`
- Create: `/Users/rafaelaparecido/fin-api/README.md`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_e2e_app.py`

**Interfaces:**
- Produces:
  - `app`: FastAPI ASGI application instance
  - CLI commands: `python -m app.cli serve`, `python -m app.cli worker`, `python -m app.cli catalog-sync`, `python -m app.cli check`
  - Health check: `GET /health` verifying Neon PostgreSQL 18 and Redis connectivity

- [ ] **Step 1: Write integration test in `tests/test_e2e_app.py` verifying OpenAPI docs `/docs`, healthcheck `/health`, and CORS middlewares**
- [ ] **Step 2: Implement `app/main.py` configuring lifespan (initializing database pools and Redis), registering routers, and exception handlers**
- [ ] **Step 3: Implement `app/cli.py` with Typer commands (`serve`, `worker`, `catalog-sync`, `check`)**
- [ ] **Step 4: Create production `Dockerfile`, `docker-compose.yml`, and comprehensive `README.md`**
- [ ] **Step 5: Run full test suite with `uv run pytest tests/ -v` and verify 100% PASS**
- [ ] **Step 6: Run `python -m app.cli check` validating live connectivity to Neon `fin-db` and Redis**
- [ ] **Step 7: Push the complete codebase to `https://github.com/barrosrafa/fin-api.git` (main branch)**
