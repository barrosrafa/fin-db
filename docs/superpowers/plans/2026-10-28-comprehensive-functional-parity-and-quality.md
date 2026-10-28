# Plano de Implementação: Paridade Funcional, Saneamento de Dados e Entrega Integral (Fases 1 a 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar 100% dos valores mock/demonstrativos, corrigir falhas conceituais e inconsistências de dados, entregar os pilares de dividendos, histórico de preços e comunicados oficiais, implementar backtest e rankings reais, executar testes gerais, documentar no cofre de documentação e realizar push em todos os repositórios alterados.

**Architecture:** 
1. **Backend (`fin-api`)**: Endpoints FastAPI reescritos para consultar tabelas canônicas e séries temporais (`market.cotacao_diaria`, `market.provento`, `canonical.disclosure_document`, `core.ativo`, `asset_details.etf_detalhe`). Eliminação de listas fixas e dicionários de priors.
2. **Frontend (`fin-web`)**: Next.js 16 App Router com Turbopack. Substituição de dados hardcoded em JSX por chamadas de API, tratamento explícito de valores nulos ("N/D"), filtros server-side na busca avançada e gráficos acoplados a séries históricas reais.
3. **Docs & Infra (`fin`, `fin-docs`)**: Atualização dos relatórios de auditoria, especificação arquitetural e sincronização Git em todos os repositórios.

**Tech Stack:**
- Backend: Python 3.12, FastAPI, SQLAlchemy 2.0 (asyncpg), Pydantic v2, TimescaleDB / Neon PostgreSQL 18
- Frontend: Next.js 16.4, React 19, TypeScript 5, Tailwind CSS, SVG Sparklines/Charts
- Docs: Obsidian Vault (`fin-docs`), Markdown

---

## Global Constraints
- Nenhuma tela pode conter valores estáticos ou de demonstração apresentados como dados reais.
- Onde não houver dados comprovados no banco, a interface deve exibir explicitamente "N/D" ou "-", nunca "R$ 0,00" ou "+%".
- Identificadores sintéticos (como `B3-PROV-...`) não podem ser exibidos como "protocolos CVM".
- O simulador de portfólios deve usar cotações históricas reais de `market.cotacao_diaria` e CDI diário.
- Todos os testes automatizados devem passar e `npm run build` deve compilar com 0 erros.

---

## Tarefas de Execução

### Fase 1: Saneamento de Mocks, Valores Demonstrativos & Qualidade dos Dados

- [x] **Task 1.1: Saneamento do Feed de Comunicados e Notícias**
  - **Arquivos:**
    - Modificar: `fin-api/app/market/router.py:106-152`
    - Modificar: `fin-web/src/app/noticias/page.tsx`
    - Modificar: `fin-web/src/lib/api.ts`
    - Testar: `fin-api/tests/test_market_news.py`
  - **Ações:**
    - Reestruturar `get_market_news` para consultar `canonical.disclosure_document` prioritariamente e, em fallback, eventos oficiais sem criar protocolos falsos (`B3-PROV-...`).
    - Remover rótulo arbitrário `"RESULTADO"` e sentimento `"POSITIVO"` forçado em proventos.
    - Atualizar `fin-web/src/app/noticias/page.tsx` para apresentar links reais para a CVM/B3, filtro por tipo correto e paginação.

- [x] **Task 1.2: Drawdown Dinâmico de ETFs**
  - **Arquivos:**
    - Modificar: `fin-api/app/etfs/router.py`
    - Modificar: `fin-api/app/etfs/service.py`
    - Modificar: `fin-api/app/etfs/schemas.py`
    - Modificar: `fin-web/src/app/etfs/[ticker]/ETFDetailClient.tsx:254-277`
    - Modificar: `fin-web/src/lib/api.ts`
    - Testar: `fin-api/tests/test_etf_drawdown.py`
  - **Ações:**
    - Implementar endpoint `/etfs/{ticker}/drawdown` que calcula a série de drawdown subaquático, vale e dias de recuperação a partir de `market.cotacao_diaria`.
    - Atualizar `ETFDetailClient.tsx` para consumir essa API, removendo os arrays e métricas hardcoded do JSX.

- [x] **Task 1.3: Ranking Dinâmico de ETFs**
  - **Arquivos:**
    - Modificar: `fin-api/app/rankings/router.py:20-80`
    - Testar: `fin-api/tests/test_etfs_brasil_api.py`
  - **Ações:**
    - Eliminar o array hardcoded `base_etfs` de 10 posições fixas.
    - Implementar query SQL dinâmica agrupando `core.ativo`, `asset_details.etf_detalhe` e cotações de `market.cotacao_diaria`, ordenando dinamicamente por retorno 30d, 12m, PL, taxa e cotistas.

- [x] **Task 1.4: Conciliação de Valores e Tratamento de N/D em ETFs (IVVB11 e outros)**
  - **Arquivos:**
    - Modificar: `fin-api/app/etfs/service.py:57-80`
    - Modificar: `fin-web/src/app/etfs/[ticker]/ETFDetailClient.tsx`
    - Modificar: `fin/scripts/seed_etf_canonical_data.py`
  - **Ações:**
    - Conciliar taxas de administração primária vs total (padronizar 0.23% ou conforme regulamento do fundo).
    - Assegurar cálculo de `nav_per_share` e `nav_spread_pct` com fallback explícito para `null`.
    - No frontend, formatar campos nulos como `"N/D"` em vez de `R$ 0,00` ou `+%`.

- [x] **Task 1.5: Correção do Mapa de Sazonalidade de Dividendos**
  - **Arquivos:**
    - Modificar: `fin-api/app/analytics/service.py:110-156`
    - Modificar: `fin-api/app/analytics/router.py`
    - Testar: `fin-api/tests/test_analytics_api.py`
  - **Ações:**
    - Separar o cálculo de `DATA_COM` do cálculo de `DATA_PAGAMENTO`.
    - Eliminar a duplicação de `prob` de data-com para probabilidade de pagamento.

- [x] **Task 1.6: Busca Avançada com Filtragem Server-Side**
  - **Arquivos:**
    - Modificar: `fin-api/app/stocks/router.py`
    - Modificar: `fin-api/app/stocks/service.py`
    - Modificar: `fin-web/src/app/acoes/busca-avancada/page.tsx:24-48`
    - Modificar: `fin-web/src/lib/api.ts`
  - **Ações:**
    - Implementar endpoint `/stocks/screener` com parâmetros query (`min_dy`, `max_pl`, `max_pvp`, `min_roe`, `min_roic`, `min_margem`, `setor`, `limit`, `offset`).
    - Atualizar a tela `busca-avancada/page.tsx` para disparar busca server-side, garantindo que nenhum ativo seja omitido por corte preliminar em DY.

---

### Fase 2: Conclusão dos Pilares Centrais

- [x] **Task 2.1: Histórico Integral e Agenda Paginada de Dividendos**
  - **Arquivos:**
    - Modificar: `fin-api/app/market/router.py`
    - Modificar: `fin-web/src/app/agenda-dividendos/page.tsx`
    - Modificar: `fin-web/src/app/acoes/[ticker]/StockDetailClient.tsx`
    - Modificar: `fin-web/src/lib/api.ts`
  - **Ações:**
    - Endpoint `/market/dividends` com histórico paginado, suporte a data-com, data-ex calculada, data-pagamento, tipo (DIVIDENDO, JCP, RENDIMENTO), e status (FUTURO vs PAGO).
    - Botão de exportação CSV de proventos.

- [x] **Task 2.2: Gráfico e Histórico Completo de Preços**
  - **Arquivos:**
    - Modificar: `fin-api/app/market/router.py`
    - Modificar: `fin-web/src/app/acoes/[ticker]/StockDetailClient.tsx`
    - Modificar: `fin-web/src/app/etfs/[ticker]/ETFDetailClient.tsx`
    - Criar/Modificar: componente de histórico de cotações com tabela diária e exportação CSV.
  - **Ações:**
    - Endpoint `/market/quotes/{ticker}/history` retornando séries diárias completas com OHLCV e volume.
    - Adicionar visualização de tabela diária paginada e exportação CSV na página de detalhes do ativo.

- [x] **Task 2.3: Biblioteca Oficial de Documentos CVM/B3**
  - **Arquivos:**
    - Modificar: `fin-api/app/market/router.py`
    - Modificar: `fin-web/src/app/noticias/page.tsx`
    - Modificar: `fin/scripts/ingest_real_market_data.py` (ou script canônico de documentos)
  - **Ações:**
    - Seed/ingestão de documentos canônicos para ativos principais (Fatos Relevantes, ITR, DFP, Comunicados).
    - Exibição de biblioteca documental organizada por categorias, ticker e data com link direto para o documento oficial.

---

### Fase 3: Motores Analíticos & Ferramental

- [x] **Task 3.1: Backtest Histórico Real do Simulador de Portfólios**
  - **Arquivos:**
    - Modificar: `fin-api/app/simulator/service.py`
    - Modificar: `fin-web/src/app/simulador-de-portfolios/page.tsx`
    - Testar: `fin-api/tests/test_etfs_brasil_api.py`
  - **Ações:**
    - Substituir `asset_priors` e CDI constante de 10.75% por consulta real a `market.cotacao_diaria` para os tickers selecionados no período escolhido.
    - Calcular curva patrimonial histórica real, volatilidade real, drawdown e Sharpe ratio contra o CDI diário real.

- [x] **Task 3.2: Rankings Consolidados Multi-Classe**
  - **Arquivos:**
    - Modificar: `fin-api/app/rankings/router.py`
    - Modificar: `fin-web/src/app/rankings/page.tsx`
  - **Ações:**
    - Suporte dinâmico para múltiplos tipos de ativos (Ações, FIIs, ETFs) no ranking universal.

---

### Fase 4: Expansão de Recursos, Testes Gerais, Documentação e Push

- [x] **Task 4.1: Governança, Acionistas e Remuneração**
  - **Arquivos:**
    - Modificar: `fin-api/app/stocks/router.py`
    - Modificar: `fin-web/src/app/acoes/[ticker]/StockDetailClient.tsx`
  - **Ações:**
    - Exibir composição acionária e dados de administração quando disponíveis em `core.historico_acionista` e `core.administrador_companhia`.

- [x] **Task 4.2: Testes Gerais e Homologação**
  - **Ações:**
    - Executar suíte completa de testes no `fin-api` via `pytest`.
    - Executar `npm run build` no `fin-web` garantindo 0 erros e 100% de páginas geradas.
    - Executar scripts de verificação no `fin`.

- [x] **Task 4.3: Documentação Completa**
  - **Ações:**
    - Registrar o relatório de conformidade, histórico de alterações e cobertura em `fin/docs/` e `fin-docs/08_AUDITORIAS_TESTES_E_PENTEST/` e `00_CENTRAL_MOC.md`.

- [x] **Task 4.4: Git Commit e Push**
  - **Ações:**
    - Comitar e fazer push nos repositórios alterados (`fin`, `fin-api`, `fin-web`, `fin-docs`).
