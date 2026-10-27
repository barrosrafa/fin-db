# Design Document: `fin-api` — Backend Unificado de Alta Performance & Worker Assíncrono

**Data:** 2026-10-26  
**Status:** Aguardando Aprovação  
**Repositório Alvo:** `https://github.com/barrosrafa/fin-api`  
**Diretório Local:** `/Users/rafaelaparecido/fin-api`  
**Banco de Dados:** PostgreSQL 18 / TimescaleDB no Neon Serverless (`fin-db`)  
**Cache & Fila:** Redis 7+  

---

## 1. Visão Geral & Intenção ("The Why")

O **`fin-api`** é o backend central para a plataforma de inteligência de investimentos e gestão de patrimônio do ecossistema `fin`. Ele atua como o elo executivo entre a modelagem de dados do **`fin-db`** (303 tabelas em 12 schemas relacionais e 36 hypertables) e as interfaces de usuário (web, mobile, dashboards analíticos).

### O Princípio Sagrado: API "Garçom" vs. Worker "Cozinha"
* **A API HTTP NUNCA faz scraping ou chamadas externas durante requisições de clientes.** Seu papel exclusivo é servir dados pré-processados e cacheados em milissegundos.
* **Leitura com *Stale-While-Revalidate*:** Se o dado estiver no Redis, é entregue instantaneamente. Se estiver ausente ou vencido (*stale*), a API devolve a versão antiga imediatamente (se houver) e dispara um job assíncrono para a fila de tarefas do worker no Redis sem bloquear o usuário.
* **Worker Assíncrono:** É o motor resiliente de coleta, normalização, deduplicação, cálculo analítico e aquecimento de cache (*cache warm-up*), rodando tanto tarefas periódicas (*cron jobs*) quanto sob demanda.
* **Código Unificado:** O mesmo código-fonte em Python roda como servidor HTTP (`uvicorn`) ou como worker de fila (`arq`).

---

## 2. Metas, Não-Metas e Anti-Metas

### Metas (Goals)
1. **Baixíssima Latência:** p95 < 20ms para leituras de cotações, indicadores e carteiras via Redis com fallback ao PostgreSQL/TimescaleDB.
2. **Resiliência a Falhas de Scrapers:** Circuit breaker por fonte (Redis sliding window), rotação de sessões/tokens e backoff exponencial com jitter para mitigar HTTP 429/bloqueios.
3. **Isolamento Modular com Padrão Strategy:**
   - Módulo de `auth` desacoplado de provedor externo via `AuthProvider` (começando com `SupabaseAuthAdapter`).
   - Módulo de `billing` desacoplado de gateway via `PaymentProvider` (começando com `AsaasPaymentProvider` para PIX e Boleto transparentes, e checkout hospedado para cartão no MVP).
   - Módulo de `collectors` com adaptadores isolados para as 12 plataformas de mercado mapeadas no REA.
4. **Execução Dual Simplificada:** Um único pacote Python com CLI unificada (`app.cli`) para iniciar a API HTTP ou o Worker ARQ.
5. **Compatibilidade Estrita com `fin-db`:** Governança centralizada no `fin-db` (sem duplicar migrações no Alembic). O `fin-api` mapeia via SQLAlchemy ORM apenas entidades de domínio transacional (usuários, carteiras, ordens, assinaturas) e usa SQLAlchemy Core para consultas analíticas pesadas.

### Não-Metas (Non-Goals)
1. Scraping síncrono inline em endpoints da API HTTP.
2. Reimplementação de um motor proprietário de identidade/senhas do zero (delegado via interface para provedores gerenciados como Supabase Auth / Cognito).
3. Processamento transparente de cartão de crédito no MVP (evitando escopo complexo de PCI SAQ-A e 3DS antes do momento certo).

### Anti-Metas (Anti-Goals)
1. **Espaguete de Scrapers:** Proibido código de scraping misturado com rotas de API ou regras de negócio do portfólio.
2. **Acoplamento a Gateway Específico:** Nenhuma menção direta a URLs ou estruturas do Asaas ou Stripe nos controllers da API.
3. **Sobrecarga Síncrona:** Proibido uso de Celery com processos síncronos pesados ou bloqueio de threads em chamadas I/O.

---

## 3. Arquitetura do Sistema & Stack Tecnológica

```
                              ┌─────────────────────────────────────────────────────────┐
                              │                        CLIENTES                         │
                              │                 (Web, Mobile, BI, APIs)                 │
                              └────────────────────────────┬────────────────────────────┘
                                                           │ HTTPS (Bearer JWT)
                                                           ▼
                              ┌─────────────────────────────────────────────────────────┐
                              │                      API HTTP                           │
                              │             FastAPI (Asynchronous, Uvicorn)             │
                              │      [auth]  [market]  [portfolio]  [billing]  [system] │
                              └─────────────┬─────────────────────────────┬─────────────┘
                                            │                             │
                     Cache Hit / Fast Reads │                             │ Enqueue Job
                                            ▼                             ▼
                              ┌─────────────────────────────────────────────────────────┐
                              │                         REDIS                           │
                              │       • Cache de Dados (TTLs por volatilidade)          │
                              │       • TickerCatalog O(1) (B3/CVM Valid Tickers)       │
                              │       • Filas de Tarefas ARQ (high, default, batch)     │
                              │       • Circuit Breakers & Rate Limiters (Tokens)       │
                              │       • Sessões e Tokens de Scrapers (ex: JWT Clube FII)│
                              └─────────────▲─────────────────────────────┬─────────────┘
                                            │                             │
                              Cache Warm-up │                             │ Dequeue Task
                                            │                             ▼
                              ┌─────────────┴───────────────────────────────────────────┐
                              │                    WORKER ASSÍNCRONO                    │
                              │                ARQ (Native asyncio loop)                │
                              │     • Cron Jobs periódicos                              │
                              │     • Coletas sob demanda (Stale-while-revalidate)      │
                              │     • Circuit Breakers & Health Monitors                │
                              │     • Normalização & Deduplicação                       │
                              └────────────────────────────┬────────────────────────────┘
                                                           │
                                                           ▼
                             ┌───────────────────────────────────────────┐
                             │           CAMADA DE INGESTÃO              │
                             │       12 Adaptadores REA Isolados         │
                             │  (StatusInvest, Investidor10, ClubeFII..) │
                             └─────────────────────┬─────────────────────┘
                                                   │
                                                   ▼
                             ┌───────────────────────────────────────────┐
                             │              BANCO DE DADOS               │
                             │      PostgreSQL 18 + TimescaleDB (Neon)   │
                             │        (12 Schemas, 303 Tabelas)          │
                             └───────────────────────────────────────────┘
```

### Tecnologias Escolhidas
| Componente | Tecnologia | Justificativa |
|---|---|---|
| **Linguagem & Runtime** | Python 3.12+ / asyncio | Alta produtividade, ecossistema financeiro rico, concorrência async eficiente |
| **Framework HTTP** | FastAPI 0.115+ | Async nativo, validação Pydantic V2, OpenAPI/Swagger automático, injeção de dependências |
| **Worker Assíncrono** | ARQ 0.26+ | Async nativo (`async def`), agendamento `arq.cron` integrado, filas prioritárias sobre Redis, pegada de memória levíssima (~30MB) |
| **Cache & Fila** | Redis 7+ | Broker unificado para ARQ, cache chave-valor com TTL, locks distribuídos e contadores atômicos |
| **Cliente HTTP para Coleta** | `httpx.AsyncClient` | Async, HTTP/2, pooling de conexões, timeouts granulares e suporte a proxies |
| **Banco de Dados** | Neon PostgreSQL 18 / TimescaleDB | Hypertables nativas para séries temporais (`market.cotacao_diaria`, `asset_details`), pgvector para busca semântica |
| **Driver de Banco** | `asyncpg` + `SQLAlchemy 2.0` (async) | Conexões pooled de máxima velocidade para PostgreSQL |
| **Validação & Config** | Pydantic V2 / `pydantic-settings` | Validação estrita tipada e leitura de variáveis de ambiente (`.env`) |
| **Gerenciador de Pacotes** | `uv` | Resolução e instalação ultrarrápida de dependências Python |

---

## 4. Decomposição Modular da Aplicação

```
fin-api/
├── pyproject.toml              # Dependências e metadados gerenciados por uv
├── .env.example                # Template de configuração de ambiente
├── README.md                   # Instruções de setup, execução e deploy
├── app/
│   ├── __init__.py
│   ├── main.py                 # Ponto de entrada FastAPI (rotas, middlewares, lifespan)
│   ├── cli.py                  # CLI unificada (comandos: serve, worker)
│   ├── config.py               # Settings centralizadas via Pydantic
│   ├── core/                   # Infraestrutura compartilhada
│   │   ├── database.py         # Engine e SessionMaker assíncronos (SQLAlchemy + asyncpg)
│   │   ├── redis.py            # Pool de conexões Redis e utilitários de cache
│   │   ├── catalog.py          # TickerCatalog O(1) em Redis sincronizado com B3/CVM
│   │   ├── logging.py          # Logs estruturados JSON com correlação de request ID
│   │   ├── circuit_breaker.py  # Circuit breaker em Redis com sliding window e TTL
│   │   └── exceptions.py       # Exceções de domínio e handlers HTTP
│   ├── auth/                   # Módulo de Usuários e Autenticação
│   │   ├── contracts.py        # Interface abstrata AuthProvider
│   │   ├── models.py           # Domain model User, Roles e Scopes
│   │   ├── dependencies.py     # get_current_user, require_role, require_tier
│   │   └── adapters/           # SupabaseAuthAdapter, LocalJWTAdapter, CognitoAdapter
│   ├── market/                 # Módulo de Mercado & Dados Financeiros
│   │   ├── router.py           # Rotas: /market/quotes, /market/indicators, /market/screeners, /market/{ticker}/sync-status
│   │   ├── service.py          # Lógica de cache-aside, TickerCatalog e stale-while-revalidate
│   │   └── schemas.py          # Schemas Pydantic de entrada e saída
│   ├── portfolio/              # Módulo de Carteiras e Investimentos Pessoais
│   │   ├── router.py           # Rotas: /portfolio/wallets, /portfolio/positions, /portfolio/performance
│   │   ├── service.py          # Cálculos de rentabilidade, consolidação de lotes e proventos
│   │   └── schemas.py          # Schemas Pydantic
│   ├── billing/                # Módulo de Assinaturas e Pagamentos
│   │   ├── contracts.py        # Interface abstrata PaymentProvider
│   │   ├── router.py           # Rotas: /billing/subscriptions, /billing/plans, /billing/webhooks/{provider}
│   │   ├── service.py          # Gestão de planos, liberação de tiers e conciliação
│   │   └── adapters/           # AsaasPaymentProvider, StripePaymentProvider
│   ├── collectors/             # Camada de Ingestão & Adaptadores REA
│   │   ├── base.py             # Classe base BaseCollector com rate limit e headers
│   │   ├── router.py           # CollectorRouter com prioridades e cadeias de fallback
│   │   ├── normalizer.py       # Normalização de payloads brutos para o schema canônico do fin-db
│   │   └── adapters/           # 12 Adaptadores REA:
│   │       ├── status_invest.py
│   │       ├── investidor10.py
│   │       ├── fundamentei.py
│   │       ├── fundamentus.py
│   │       ├── clube_fii.py    # Gestão de JWT GraphQL 12h
│   │       ├── funds_explorer.py
│   │       ├── fiis_com_br.py
│   │       ├── mais_retorno.py # CVM 175, CDA carteiras
│   │       ├── analise_de_acoes.py
│   │       ├── brick360.py
│   │       ├── advfn.py
│   │       └── etfs_brasil.py
│   └── worker/                 # Motor de Tarefas ARQ
│       ├── settings.py         # WorkerSettings, filas, cron_jobs, startup/shutdown
│       └── tasks/              # Tarefas assíncronas:
│           ├── ingestion.py    # Jobs de coleta periódica e sob demanda
│           ├── calculation.py  # Agregações de ranking, métricas setoriais e rentabilidade
│           ├── cache.py        # Cache warm-up para top tickers e TickerCatalog
│           └── housekeeping.py # Expiração de logs e compactação de tabelas
└── tests/                      # Testes automatizados (pytest-asyncio)
```

---

## 5. Especificação dos Fluxos Críticos

### 5.1 Cold-Start Híbrido de Ativos (Cache Miss Total)
O acesso a ativos segue um modelo em 3 camadas:

```
[Requisição Cliente: GET /market/{ticker}]
                 │
                 ▼
       [1. TickerCatalog no Redis?]
          │                │
         NÃO              SIM
          │                │
          ▼                ▼
     [Retorna 404]   [2. Dado no Redis Cache?]
    ("Ticker inválido      │                │
       ou não listado")   NÃO              SIM
                           │                │
                           ▼                ▼
                    [3. Dado no DB?]   [Retorna 200 Fresh]
                      │          │        (p95 < 15ms)
                     NÃO        SIM
                      │          │
                      │          ▼
                      │     [Retorna 200 Stale]
                      │     + Enfileira refresh no ARQ
                      ▼
               [Retorna 202 Accepted]
            {
              "status": "syncing",
              "sync_id": "job_12345",
              "message": "Ativo válido em processo de coleta inicial",
              "check_url": "/api/v1/market/PETR4/sync-status"
            }
            + Enfileira coleta em 'high_priority'
```

* **Rate Limit de Cold-Start:** 20 chamadas 202/hora no plano Free, 200 no plano Pro para evitar DoS contra o worker.
* **Cache Negativo:** Se 3 tentativas consecutivas falharem em todas as fontes para um ticker válido, a chave `failed_ticker:{ticker}` é cacheada por 10 minutos, retornando HTTP 422 ("Dados temporariamente indisponíveis nas fontes externas").

### 5.2 Checkout Híbrido no Módulo de Billing (Asaas)
* **Padrão Strategy com Interface Especializada:**
  ```python
  class PaymentProvider(ABC):
      @abstractmethod
      async def create_customer(self, user: User) -> str: ...
      @abstractmethod
      async def create_pix_subscription(self, customer_id: str, plan_id: str) -> PixPaymentData: ...
      @abstractmethod
      async def create_boleto_subscription(self, customer_id: str, plan_id: str) -> BoletoPaymentData: ...
      @abstractmethod
      async def create_card_hosted_checkout(self, customer_id: str, plan_id: str) -> HostedCheckoutData: ...
      @abstractmethod
      async def cancel_subscription(self, subscription_id: str) -> bool: ...
      @abstractmethod
      async def parse_webhook(self, payload: bytes, headers: dict) -> WebhookEvent: ...
  ```
* **Comportamento por Meio de Pagamento:**
  - **PIX (Transparente - Dia 1):** Retorna `encodedImage` (QR Code base64) e `payload` (chave copia-e-cola). O frontend renderiza o QR Code nativamente.
  - **Boleto (Transparente - Dia 1):** Retorna `identificationField` (linha digitável) e `bankSlipUrl` (PDF oficial).
  - **Cartão de Crédito (Hospedado no MVP):** Retorna link de checkout seguro do Asaas com redirect. Na Fase 2, migra para transparente com tokenização Asaas.js.

### 5.3 Orquestração e Roteamento dos 12 Scrapers (`CollectorRouter`)
Para evitar redundância cega e contenção no banco, cada classe de ativo possui uma cadeia de prioridade configurada:

| Classe de Ativo | Coletor Primário | Fallbacks / Enriquecimento | Dados Coletados |
|---|---|---|---|
| **Ações B3** | Status Invest | 1º Fundamentus (cotações e múltiplos leves)<br>2º Investidor10 (checklist B&H)<br>3º Fundamentei (segmentos e governança) | Cotações, DRE, Balanços, Dividendos, Recompras, Aluguel BTC |
| **FIIs** | Clube FII | 1º Funds Explorer (ranking 30 colunas, proventos)<br>2º FIIs.com.br (agenda dividendos)<br>3º Brick360 (score 6 eixos, DRE CVM) | Imóveis físicos, contratos, vacância, transações SiiLA, CRIs |
| **Fundos de Investimento** | Mais Retorno | Status Invest | CVM 175 (Fundo/Classe/Subclasse), carteira CDA, métricas de risco |
| **ETFs & Índices** | ETFs Brasil | Status Invest | Taxas primária/secundária, spread NAV, 68 índices Teva/B3 |
| **Análise Técnica & Derivativos** | ADVFN Brasil | Status Invest | Suportes/resistências, candlesticks, gregas/fluxo de opções |

* **Resolução de Conflitos:** Atualizações canônicas utilizam upsert com base no carimbo de data/hora (`atualizado_em`), priorizando sempre a fonte com maior granularidade e menor latência.

### 5.4 Autenticação JIT e Cache de Sessão
* O middleware `get_current_user` valida o token JWT do Supabase via JWKS com cache em memória (LRU).
* Se o usuário não existir na tabela `core.usuario`, o adaptador realiza o provisionamento automático *Just-In-Time* (JIT).
* O perfil e o plano/tier (`free`, `pro`, `enterprise`) são armazenados em `user:{user_id}:profile` no Redis (TTL: 1h), sendo invalidados imediatamente após o recebimento de webhooks de pagamento.

---

## 6. Configuração e Execução Dual

O backend é executado a partir do mesmo pacote via `app.cli`:

* **Modo API HTTP (Web):**
  ```bash
  python -m app.cli serve --host 0.0.0.0 --port 8000 --workers 4
  ```
* **Modo Worker de Fila & Agendador (Cron):**
  ```bash
  python -m app.cli worker --burst false
  ```
* **Modo Desenvolvimento Local:**
  ```bash
  uv run app/cli.py serve --reload
  uv run app/cli.py worker
  ```

---

## 7. Decisões do Desenvolvedor Incorporadas
1. **Governança do Banco:** O `fin-db` é tratado como schema externo soberano. O `fin-api` mapeia modelos ORM estritamente necessários para regras de negócio transacionais e usa consultas SQL Core para séries temporais e analytics.
2. **Sincronização de Tickers:** Um job diário do ARQ consome listagens de instrumentos da B3/CVM e atualiza o `TickerCatalog` no Redis.
3. **Circuit Breakers Granulares:** Configurados por host com janela de 5 falhas consecutivas e tempo de resfriamento (*cooldown*) de 10 minutos.
