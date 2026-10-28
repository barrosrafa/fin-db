# Plano Abrangente de Remediação QA — Ecossistema Fin

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir com segurança todos os 10 defeitos (FIN-QA-01 a FIN-QA-10), inconsistências de dados no Neon DB, problemas de carregamento/skeletons, acessibilidade e alinhamento de tokens identificados na Auditoria QA do Fin.

**Architecture:** Abordagem full-stack coordenada: (1) Saneamento e inserção de dados canônicos nas tabelas do Neon PostgreSQL (ETFs, FIIs e oscilações históricas); (2) Correção de rotas, queries e validação de domínio financeiro na FastAPI (`fin-api`); (3) Sincronização de estado analítico via URL `searchParams`, formatação uniforme pt-BR, suporte a 4 ativos no comparador com regras de elegibilidade, acessibilidade WAI-ARIA e eliminação de valores provisórios com skeletons na Next.js (`fin-web`).

**Tech Stack:** Next.js 16 (App Router, Turbopack, React 19, TypeScript, Tailwind CSS v4, Zod), FastAPI (Python 3.12, SQLAlchemy async, asyncpg, Pydantic v2), Neon PostgreSQL 18 (TimescaleDB).

**Spec:** Auditoria QA — Fin (28/10/2026), referências D1 (Next.js & Tokens), D2 (Catálogo de Telas), D3 (Eliminação de Mocks & Data Binding) e D4 (Design System Dark Obsidian).

## Global Constraints

- Preservar integridade documental e comentários existentes nos repositórios.
- Nenhum retorno simples de ativo à vista (`tipo_ativo = 'ACAO'`) pode ser inferior a -100,00%.
- Acesso e migrações no Neon DB devem ser idempotentes e aditivas.
- Formatação numérica obrigatória em pt-BR (vírgula decimal para moedas, múltiplos e percentuais; 4 casas decimais para proventos unitários fracionados).
- URLs de páginas analíticas (`/acoes/[ticker]`, `/fiis/[ticker]`, `/etfs/[ticker]`, `/screener`, `/comparador`) devem ser totalmente compartilháveis e reprodutíveis no recarregamento (F5).
- Abas e seletores de filtros devem implementar WAI-ARIA semântico (`role="tablist"`, `role="tab"`, `aria-selected`, `role="tabpanel"` e navegação por teclado).

## Review Focus

1. `IVVB11` no catálogo `/etfs` e no detalhe `/etfs/IVVB11` deve exibir benchmark S&P 500 e holdings norte-americanas (IVV / Big Techs), nunca IBOVESPA ou ações brasileiras genéricas.
2. `RENT3` em `/acoes` e nos screeners deve exibir variação de 12 meses matematicamente coerente (estritamente >= -100%), eliminando a fórmula fictícia `var24h * 3.5 + dy * 0.8`.
3. Fundos imobiliários (`FTCE11B` e `SHOP11`) não podem exibir os 5 galpões logísticos da `HGLG11`; fundos sem imóveis físicos diretos devem declarar ausência de imóveis ou foco em papel/CRI sem exibir selos falsos de auditoria.
4. O comparador `/comparador` deve renderizar "Não comparável" / "—" em indicadores não aplicáveis (ex: P/L para ETFs/FIIs) e nunca declarar vencedor com base em valores nulos/indefinidos.
5. Recarregar páginas com abas (`/acoes/PETR4?tab=DRE`, `/fiis/FTCE11B?tab=BRICK_SCORE`) e telas de busca (`/screener?q=PETR4`, `/comparador?tickers=IVVB11,VALE3`) deve restaurar 100% do estado semântico.

---

### Task 1: Correção de Identidade, Benchmark e Carteira de IVVB11 (FIN-QA-01 & Neon DB)

**Files:**
- Modify: `fin-api/app/etfs/service.py:15-115`
- Modify: `fin-api/app/market/service.py:133-145`
- Modify: `fin-web/src/app/etfs/page.tsx:70-130`
- Modify: `fin-web/src/app/etfs/[ticker]/ETFDetailClient.tsx:40-100`
- Script: `fin/scripts/seed_etf_canonical_data.py`

**Interfaces:**
- Consumes: Neon DB `asset_details.etf_detalhe`, `market.etf_composicao_carteira`
- Produces: `ETFDetailResponse` com `benchmark_index="S&P 500"`, `provider="BlackRock Brasil"`, holdings dos componentes do S&P 500 / IVV

- [ ] **Step 1: Escrever script de migração e semente para IVVB11 no Neon DB**

Criar `fin/scripts/seed_etf_canonical_data.py` para atualizar `asset_details.etf_detalhe` para IVVB11 (`indice_referencia = 'S&P 500'`, `benchmark = 'S&P 500'`), SMAL11 (`indice_referencia = 'SMLL'`), HASH11 (`indice_referencia = 'Nasdaq Crypto Index'`) e inserir as 10 principais posições em `market.etf_composicao_carteira` para IVVB11 (MSFT 6.8%, AAPL 6.5%, NVDA 6.2%, AMZN 3.6%, GOOGL 2.3%, META 2.2%, GOOG 2.0%, BRK.B 1.7%, AVGO 1.6%, LLY 1.5% com país 'Estados Unidos').

- [ ] **Step 2: Executar semente e validar no banco**

Executar: `/Users/rafaelaparecido/fin-api/.venv/bin/python /Users/rafaelaparecido/fin/scripts/seed_etf_canonical_data.py`
Esperado: 10 posições inseridas para IVVB11 e `etf_detalhe` atualizado com sucesso.

- [ ] **Step 3: Ajustar `fin-api/app/etfs/service.py` e `market/service.py`**

Remover fallback estático de IBOVESPA para ETFs internacionais em `app/etfs/service.py`. Em `app/market/service.py` linha 139, alterar a query para ler `COALESCE(ed.indice_referencia, 'Índice Global')` para ETFs em vez do literal `'Índice B3'`.

- [ ] **Step 4: Executar testes da API de ETFs**

Executar: `cd /Users/rafaelaparecido/fin-api && .venv/bin/pytest tests/test_etfs_brasil_api.py -v`
Esperado: PASS.

- [ ] **Step 5: Ajustar e testar `fin-web/src/app/etfs/page.tsx` e `[ticker]/ETFDetailClient.tsx`**

Garantir exibição de S&P 500 na coluna "Índice Subjacente" de IVVB11 e indicação de fonte/data-base na tabela de composição.

---

### Task 2: Correção de Retorno Financeiro e Validação de Domínio (FIN-QA-02)

**Files:**
- Modify: `fin-api/app/market/service.py:200-215`
- Modify: `fin-api/app/comparator/router.py:90-110`
- Modify: `fin-web/src/lib/formatters.ts:40-60`
- Test: `fin-api/tests/test_financial_domain_rules.py`

**Interfaces:**
- Consumes: `market.cotacao_diaria` e cotações de fechamento
- Produces: `change12m` validado matematicamente com piso de -100% para ações ordinárias/preferenciais

- [ ] **Step 1: Escrever teste automatizado para validação de retorno de ações**

Criar `fin-api/tests/test_financial_domain_rules.py` testando que ativos do tipo `ACAO` nunca retornam `change12m < -100.0%` mesmo em pregões com forte variação diária negativa (`var24h = -39.58%`).

- [ ] **Step 2: Executar teste para verificar falha inicial**

Executar: `cd /Users/rafaelaparecido/fin-api && .venv/bin/pytest tests/test_financial_domain_rules.py -v`
Esperado: FAIL com retorno fictício de -133.21%.

- [ ] **Step 3: Implementar cálculo real e sanitização de domínio em `fin-api`**

Em `app/market/service.py` e `app/comparator/router.py`, calcular a variação de 12 meses através da consulta lateral à cotação histórica de 1 ano atrás em `market.cotacao_diaria`. Se a série for curta ou ausente, usar a variação disponível ou `None`. Aplicar validação estrita de domínio financeiro:
`if asset_type == 'ACAO' and change12m is not None: change12m = max(-100.0, change12m)`.

- [ ] **Step 4: Executar teste para verificar aprovação**

Executar: `cd /Users/rafaelaparecido/fin-api && .venv/bin/pytest tests/test_financial_domain_rules.py -v`
Esperado: PASS.

---

### Task 5: Isolamento de Portfólio de FIIs e Tratamento de Fundo de Papel/CRI (FIN-QA-03)

**Files:**
- Modify: `fin-api/app/fiis/service.py:60-120`
- Modify: `fin-web/src/app/fiis/[ticker]/FIIDetailClient.tsx:180-260`
- Script: `fin/scripts/seed_shop11_properties.py`

**Interfaces:**
- Consumes: `asset_details.fii_imovel_participacao` filtrado por `id_ativo`
- Produces: `properties: List[FIIPropertyItem]` isoladas por fundo; lista vazia com declaração explícita para fundos de papel

- [ ] **Step 1: Filtrar `asset_details.fii_imovel_participacao` estritamente por `id_ativo` na API**

Em `fin-api/app/fiis/service.py`, corrigir a query `prop_stmt` para incluir `JOIN asset_details.fii_imovel_participacao fip ON fip.id_imovel = fi.id_imovel WHERE fip.id_ativo = :id_ativo`.
Se o fundo não possuir imóveis físicos associados, retornar `[]` e não usar valores fictícios de vacância.

- [ ] **Step 2: Inserir imóveis reais para SHOP11 no Neon DB**

Criar e executar `fin/scripts/seed_shop11_properties.py` para cadastrar os shoppings de SHOP11 em `asset_details.fii_imovel` e vincular à sua participação (`id_ativo = 1253`).

- [ ] **Step 3: Ajustar `FIIDetailClient.tsx` para fundos sem imóveis físicos (ex: FTCE11B)**

Em `fin-web/src/app/fiis/[ticker]/FIIDetailClient.tsx`, quando `properties.length === 0`:
Renderizar card explicativo "Fundo de Recebíveis Imobiliários (CRI / Papel) — Ativo sem imóveis físicos diretos", omitindo o selo indevido "5 Empreendimentos Auditados".

- [ ] **Step 4: Validar endpoints de FTCE11B, SHOP11 e HGLG11**

Testar via script de checagem que `HGLG11` retorna galpões logísticos, `SHOP11` retorna shopping centers, e `FTCE11B` retorna 0 imóveis físicos com mensagem contextual.

---

### Task 4: Regras de Elegibilidade e Resolução de Vencedor no Comparador (FIN-QA-04)

**Files:**
- Modify: `fin-web/src/app/comparador/page.tsx:160-240`
- Test: `fin-web/src/app/comparador/__tests__/eligibility.test.ts` (ou teste unitário equivalente)

**Interfaces:**
- Consumes: Ativos selecionados, tipos de ativos (`ACAO`, `FII`, `ETF`) e seus múltiplos
- Produces: Identificação de vencedor somente para métricas elegíveis e mutuamente aplicáveis; caso contrário renderiza "Não comparável" ou "—"

- [ ] **Step 1: Definir matriz de elegibilidade por classe de ativo**

Em `src/app/comparador/page.tsx` (ou helper dedicado):
- P/L: aplicável somente para Ações com lucro positivo. Para ETFs e FIIs: inelegível.
- P/VP: aplicável para Ações e FIIs.
- DY e Retorno 12M: aplicáveis para todas as classes.

- [ ] **Step 2: Implementar função segura de decisão de vencedor**

Substituir as comparações que assumem fallback `(asset.pl ?? 99)` por função `getMetricWinner(indicator, assets)` que retorna `null` se qualquer ativo não possuir valor válido ou pertencer a classe não elegível.

- [ ] **Step 3: Renderizar badge "Não comparável" / "—"**

Garantir que a coluna "Vencedor Relativo" exiba "—" quando não houver comparabilidade válida.

---

### Task 5: Persistência de Abas na URL (`searchParams`) em Cockpits de Ativos (FIN-QA-05)

**Files:**
- Modify: `fin-web/src/app/acoes/[ticker]/AcaoDetailClient.tsx:30-50, 200-230`
- Modify: `fin-web/src/app/fiis/[ticker]/FIIDetailClient.tsx:20-40, 180-210`
- Modify: `fin-web/src/app/etfs/[ticker]/ETFDetailClient.tsx:10-30, 120-140`

**Interfaces:**
- Consumes: Next.js `useSearchParams()`, `useRouter()`, `usePathname()`
- Produces: Sincronização bidirecional entre aba ativa e URL query parameter `?tab=VALUATION` ou `?tab=BRICK_SCORE` com `replace` (sem poluir histórico nem rolar a página)

- [ ] **Step 1: Conectar `AcaoDetailClient` aos searchParams**

Inicializar `activeTab` a partir de `searchParams.get("tab") || "VALUATION"`. No `onChange`, chamar `router.replace(`${pathname}?${newParams}`, { scroll: false })` e atualizar estado.

- [ ] **Step 2: Conectar `FIIDetailClient` aos searchParams**

Inicializar `activeTab` a partir de `searchParams.get("tab") || "IMOVEIS"`. Preservar abas "BRICK_SCORE", "MAGIC_NUMBER", "DRE" após recarregar.

- [ ] **Step 3: Conectar `ETFDetailClient` aos searchParams**

Inicializar `activeTab` a partir de `searchParams.get("tab") || "VISAO_GERAL"`. Preservar abas "NAV_ARBITRAGEM", "ALUGUEL", "DRAWDOWN" após recarregar.

- [ ] **Step 4: Validar build e navegação**

Executar `pnpm build` no `fin-web` para assegurar conformidade com componentes Client e Suspense boundary existente.

---

### Task 6: Sincronização de Estado de Busca e Comparação na URL (FIN-QA-06)

**Files:**
- Modify: `fin-web/src/app/screener/page.tsx:10-80`
- Modify: `fin-web/src/app/comparador/page.tsx:15-80`

**Interfaces:**
- Consumes: `useSearchParams()`
- Produces: URL reproduzível `/screener?q=PETR4&tipo=ACAO&min_dy=0&max_pvp=5` e `/comparador?tickers=IVVB11,VALE3`

- [ ] **Step 1: Sincronizar filtros do Screener com a URL**

Ler `q`, `tipo`, `min_dy`, `max_pvp`, `sort`, `asc` do `searchParams` na montagem. Atualizar a URL via `router.replace` mantendo compartilhabilidade do filtro.

- [ ] **Step 2: Sincronizar seleção de ativos do Comparador com a URL**

Ler lista de tickers da URL (`?tickers=PETR4,VALE3` ou `?a=PETR4&b=VALE3`). Preservar a seleção ao recarregar a tela.

---

### Task 7: Correção do Destino de "Ver Todos" da Agenda de Dividendos (FIN-QA-07)

**Files:**
- Modify: `fin-web/src/app/page.tsx:368-375`

**Interfaces:**
- Consumes: Card de Agenda de Proventos na Home
- Produces: Navegação para `/agenda-dividendos`

- [ ] **Step 1: Atualizar link para `/agenda-dividendos`**

Alterar linha 369 de `fin-web/src/app/page.tsx` de `href="/carteira"` para `href="/agenda-dividendos"`.

- [ ] **Step 2: Verificar comportamento no navegador e nos testes**

Confirmar redirecionamento para a agenda pública e não para o cockpit de custódia privada.

---

### Task 8: Ampliação do Comparador (Até 4 Ativos, ROE e Endividamento) (FIN-QA-08)

**Files:**
- Modify: `fin-web/src/app/comparador/page.tsx:1-350`
- Modify: `fin-api/app/comparator/router.py:40-120`

**Interfaces:**
- Consumes: Seleção de 2 a 4 tickers
- Produces: Tabela comparativa e gráficos com até 4 colunas de ativos, incluindo linhas para ROE (%) e Dívida Líquida / PL (ou Dívida Líquida / EBITDA)

- [ ] **Step 1: Atualizar schema e router de comparação na API**

Garantir que `app/comparator/router.py` inclua `roe_pct` e `divida_liquida_pl` em `AssetComparisonMetrics` para cada ticker requisitado (até 4 ativos).

- [ ] **Step 2: Adicionar controles de adicionar/remover ativos no frontend**

No `ComparadorPage`, permitir incluir 3º e 4º ativos dinamicamente através de chips ou seletores com botão de remoção (`X`).

- [ ] **Step 3: Incluir linhas de ROE e Dívida Líquida / PL na tabela**

Adicionar linhas de ROE e Dívida com formatação padronizada e regras de elegibilidade por classe.

---

### Task 9: Unificação de Formatação Numérica em pt-BR (FIN-QA-09)

**Files:**
- Modify: `fin-web/src/lib/formatters.ts:1-90`
- Modify: Tabelas e cards em `src/app/etfs/page.tsx`, `src/app/comparador/page.tsx`, `src/app/screener/page.tsx`, `src/app/page.tsx`

**Interfaces:**
- Consumes: Números em ponto flutuante
- Produces: `formatMultiple` (`12,90x`), `formatDividendUnit` (`R$ 0,4460`), `formatPercent` consistente com vírgula pt-BR

- [ ] **Step 1: Criar formatadores canônicos em `formatters.ts`**

Adicionar:
- `formatMultiple(value?: number | null, decimals = 2): string` -> `1,32x` (vírgula)
- `formatDividendUnit(value: number): string` -> preserva 4 casas decimais para proventos unitários fracionados (`R$ 0,4460`)
- `formatPercentPtBr(value: number, includeSign?: boolean, decimals?: number): string` -> vírgula obrigatória

- [ ] **Step 2: Substituir chamadas diretas de `.toFixed()` em componentes**

Substituir interpolações `${val.toFixed(2)}x` e `${val.toFixed(1)}%` pelos formatadores centralizados.

---

### Task 10: Acessibilidade Semântica de Abas e Controles (FIN-QA-10)

**Files:**
- Modify: `fin-web/src/components/ui/Tabs.tsx:1-60`
- Modify: `AcaoDetailClient.tsx`, `FIIDetailClient.tsx`, `ETFDetailClient.tsx`

**Interfaces:**
- Consumes: Componente `Tabs`
- Produces: Estrutura WAI-ARIA `role="tablist"`, `role="tab"`, `aria-selected`, `aria-controls`, `tabIndex`, navegação por setas de teclado e painéis com `role="tabpanel"`

- [ ] **Step 1: Implementar ARIA e teclado em `Tabs.tsx`**

Adicionar `role="tablist"`, `role="tab"`, `aria-selected={isActive}`, `id={`tab-${tab.id}`}`, `aria-controls={`panel-${tab.id}`}` e manipulador `onKeyDown` para teclas ArrowLeft, ArrowRight, Home e End.

- [ ] **Step 2: Vincular painéis nas páginas analíticas**

Envolver as seções de conteúdo correspondentes em `<div role="tabpanel" id={`panel-${id}`} aria-labelledby={`tab-${id}`}>`.

---

### Task 11: Estabilização de Skeletons e Alinhamento de Tokens Dark Obsidian (Seções 5 e 6)

**Files:**
- Modify: `fin-web/src/app/page.tsx:310-350`
- Modify: `fin-web/src/app/globals.css:1-50`

**Interfaces:**
- Consumes: Estados de carregamento de valuation
- Produces: Skeletons geométricos estáveis sem substituição de números financeiros falsos provisórios; confirmação dos tokens Dark Obsidian

- [ ] **Step 1: Substituir números provisórios na Home por Skeleton Loader**

Em `src/app/page.tsx` linhas 325 e 336, remover os fallbacks numéricos `?? 56.80` e `?? 64.10`. Enquanto `loadingValuation` for verdadeiro ou o objeto for nulo, renderizar bloco com skeleton animado (`h-6 w-24 bg-white/10 rounded animate-pulse`).

- [ ] **Step 2: Confirmar contenção de layout e rolagem horizontal em tabelas**

Garantir `overflow-x-auto` e largura mínima em tabelas densas para evitar compressão em viewports reduzidos.

---

### Task 12: Validação E2E, Testes Integrados e Homologação Final

**Files:**
- Execute: Testes do `fin-api`
- Execute: Build e lint do `fin-web`
- Execute: Script de auditoria de conformidade pós-reparação

- [ ] **Step 1: Rodar suíte completa de testes no `fin-api`**

Executar: `cd /Users/rafaelaparecido/fin-api && .venv/bin/pytest -v`
Esperado: 100% de testes passando.

- [ ] **Step 2: Rodar build de produção do `fin-web`**

Executar: `cd /Users/rafaelaparecido/fin-web && pnpm build`
Esperado: Compilação de 83+ rotas com sucesso.

- [ ] **Step 3: Validar os 10 itens da auditoria com script automatizado**

Criar e executar script de verificação de sanidade cobrindo os 10 defeitos relatados.

---
