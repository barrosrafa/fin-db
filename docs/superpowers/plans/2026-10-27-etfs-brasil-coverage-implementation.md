# Plano de Implementação: Cobertura Completa ETFs Brasil (fin-db, fin-ingestion, fin-api, fin-web)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar de ponta a ponta e de forma segura todas as funcionalidades do portal ETFs Brasil (catálogo multiclasse, simulador quantitativo de portfólios, comparador avançado de pares com holdings overlap, rankings Top 20 e páginas canônicas) nos repositórios `fin-db`, `fin-ingestion`, `fin-api` e `fin-web`.

**Architecture:** 
1. **Banco de Dados (`fin-db`):** Migração Stage 12 (`sql/12_etfs_brasil_coverage_v4.0/01_etfs_brasil_tables_and_views.sql`) adicionando tabelas de detalhes de FI-Infras, carteira aberta de ETFs (`etf_composicao_carteira`), métricas diárias de NAV/Spread/Tracking, configuração de simulações e pares canônicos.
2. **Ingestão (`fin-ingestion`):** Pipeline `etfs_brasil_pipeline.py` unificando extração de dados do portal ETFs Brasil, parsing de composição CDA/CVM e cálculo de métricas estatísticas.
3. **Backend (`fin-api`):** Routers e services para `/api/v1/simulate-portfolio`, `/api/v1/comparator/compare`, `/api/v1/rankings`, e enriquecimento de `/api/v1/etfs/{ticker}` com decomposição TER e tracking difference.
4. **Frontend (`fin-web`):** Correção de inconsistências de build/tipagem, implementação da rota `/simulador-de-portfolios`, rota canônica de pares `/comparador/[tickerA]/[tickerB]` (SSG/ISR), rota `/rankings`, páginas institucionais (`/quem-somos`, `/termos-de-uso`, `/politica-de-privacidade`, `/mapa-do-site`) e componentes de visualização (`UnderwaterDrawdownChart`, `HoldingsOverlapTable`, `RelativePerformanceBase100Chart`).

**Tech Stack:** PostgreSQL 18 / TimescaleDB, Python 3.12, FastAPI, SQLAlchemy, Pydantic v2, NumPy, Next.js 16 (Turbopack), React 19, TypeScript 5, Tailwind CSS v4.

---

## Global Constraints
- Todas as alterações em banco devem ser estritamente aditivas e idempotentes (`IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`).
- Nenhum endpoint existente de outras fontes (Status Invest, Oceans14, Fundamentus, Análise de Ações) pode sofrer regressão.
- Preservar padrões de isolamento, resiliência (Circuit Breaker) e normalização canônica.
- O build do frontend (`next build`) e as suítes de testes de backend e ingestão devem passar com 100% de sucesso.

---

## Estrutura de Tarefas

### Fase 1: Banco de Dados (`fin-db`) — Stage 12 Migration
- [ ] **Tarefa 1.1:** Criar o arquivo DDL `sql/12_etfs_brasil_coverage_v4.0/01_etfs_brasil_tables_and_views.sql`.
- [ ] **Tarefa 1.2:** Criar o script de verificação `scripts/verify_12_migration.py`.
- [ ] **Tarefa 1.3:** Atualizar `scripts/migrate.py` registrando o estágio 12.
- [ ] **Tarefa 1.4:** Executar migração no banco Neon e validar tabelas e índices criados.

### Fase 2: Ingestão de Dados (`fin-ingestion`)
- [ ] **Tarefa 2.1:** Aprimorar o coletor `fin_ingestion/collectors/sites/etfs_brasil.py` para capturar rankings, comparador e composições.
- [ ] **Tarefa 2.2:** Criar o pipeline `fin_ingestion/pipelines/etfs_brasil_pipeline.py` orquestrando sincronização de métricas de ETFs e holdings.
- [ ] **Tarefa 2.3:** Escrever testes unitários em `tests/test_etfs_brasil_pipeline.py` e validar execução no pytest.

### Fase 3: Backend & APIs Quantitativas (`fin-api`)
- [ ] **Tarefa 3.1:** Implementar o serviço e router do Simulador de Portfólios `app/simulator/` com rebalanceamento discreto e cálculo de Sharpe/Sortino/Drawdown.
- [ ] **Tarefa 3.2:** Aprimorar o router do Comparador `app/comparator/` suportando até 4 ativos, base 100 normalizada e sobreposição de carteira (*Holdings Overlap*).
- [ ] **Tarefa 3.3:** Implementar o router de Rankings `app/rankings/` com suporte a classes (ETFs, FIIs, Infras, Fundos, Índices) e critérios de ordenação.
- [ ] **Tarefa 3.4:** Enriquecer o router de ETFs `app/etfs/` com tracking error/difference diário e carteira aberta.
- [ ] **Tarefa 3.5:** Registrar os novos routers no `app/main.py`.
- [ ] **Tarefa 3.6:** Escrever testes unitários em `tests/test_etfs_brasil_api.py` e validar suíte completa.

### Fase 4: Frontend, Visualização & SEO (`fin-web`)
- [ ] **Tarefa 4.1:** Corrigir os erros pré-existentes de tipagem (`ButtonProps`, `BadgeProps` com `"indigo" | "outline"` e `api.ts` com `str -> string`).
- [ ] **Tarefa 4.2:** Atualizar `src/schemas/financial.ts` com as novas classes de ativos e interfaces de simulação/comparação.
- [ ] **Tarefa 4.3:** Criar os componentes visuais: `UnderwaterDrawdownChart.tsx`, `HoldingsOverlapTable.tsx` e `RelativePerformanceBase100Chart.tsx`.
- [ ] **Tarefa 4.4:** Implementar a rota `/simulador-de-portfolios` completa com suporte a 3 carteiras, sliders de alocação e métricas de risco.
- [ ] **Tarefa 4.5:** Implementar a rota canônica `/comparador/[tickerA]/[tickerB]` com SSG/ISR, deltas comparativos e tags SEO JSON-LD.
- [ ] **Tarefa 4.6:** Implementar a rota `/rankings` com tabela Top 20 e ordenação dinâmica.
- [ ] **Tarefa 4.7:** Implementar páginas institucionais: `/quem-somos`, `/termos-de-uso`, `/politica-de-privacidade` e `/mapa-do-site`.
- [ ] **Tarefa 4.8:** Integrar métodos em `src/lib/api.ts` e validar compilação sem erros via `pnpm build`.

### Fase 5: Validação Integrada Ponta a Ponta
- [ ] **Tarefa 5.1:** Executar testes de integração entre `fin-api` e `fin-db`.
- [ ] **Tarefa 5.2:** Validar simulações com ativos reais (BOVA11, IVVB11, SMAL11, LFTB11).
- [ ] **Tarefa 5.3:** Validar comparador canônico `/comparador/cdib11/lftb11` e `/comparador/blft11/lfts11`.
- [ ] **Tarefa 5.4:** Concluir com relatório executivo consolidado.
