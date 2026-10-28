# Distributed 100% Free Cloud Deployment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar o ecossistema financeiro distribuído (fin-web, fin-api, fin-ingestion, fin-infra) em plataformas de nuvem 100% gratuitas (Vercel, Koyeb, Neon, Upstash/Redis Cloud, GitHub Actions) e entregar a URL pública acessível de qualquer dispositivo.

**Architecture:** Frontend Next.js 16 hospedado na Vercel com CDN global e SSL automático, consumindo API FastAPI em Python 3.12 no Koyeb (instância Nano sem hibernação via ping leve), persistência analítica no Neon Serverless PostgreSQL 18, mensageria no Redis gerenciado e pipelines agendados de ingestão idempotente no GitHub Actions.

**Tech Stack:** Next.js 16, React 19, FastAPI, Python 3.12, Uvicorn, Docker, PostgreSQL 18 (Neon), Redis, GitHub Actions, Vercel CLI, Koyeb.

**Spec:** [docs/superpowers/specs/2026-10-28-cloud-free-deployment-design.md](file:///Users/rafaelaparecido/fin/docs/superpowers/specs/2026-10-28-cloud-free-deployment-design.md)

## Global Constraints
- Custo zero absoluto ($0/mês) em todos os componentes.
- Sem perda de dados ou registros duplicados no PostgreSQL (idempotência com `ON CONFLICT DO UPDATE`).
- Prevenção de cold start sem exaurir a cota de 100 CU-horas mensais do Neon (health check isolado em memória).
- Todos os repositórios versionados e com commits atômicos em `main`.

## Review Focus
- **CORS Failure**: Requisições do frontend da Vercel para o Koyeb bloqueadas por política de mesma origem. (Tratado na Task 1).
- **Port Binding Failure**: Koyeb atribui porta dinâmica via `$PORT` que não é respeitada pelo entrypoint do container. (Tratado na Task 1).
- **Ingestion Duplicate Data**: Execuções agendadas criam linhas duplicadas ou quebram constraints únicas. (Tratado na Task 3).
- **Neon Quota Burn**: Monitor de keep-alive chama rota de banco a cada 10 min e suspende o Neon por estourar horas de computação. (Tratado na Task 1).
- **API URL Missing in Build**: `NEXT_PUBLIC_API_URL` não propagada durante a compilação do Next.js gerando chamadas para localhost em produção. (Tratado na Task 4).

---

### Task 1: `fin-api` - CORS, Porta Dinâmica e Healthcheck Otimizado para Nuvem

**Files:**
- Modify: `/Users/rafaelaparecido/fin-api/app/main.py`
- Modify: `/Users/rafaelaparecido/fin-api/app/api/routes/health.py`
- Modify: `/Users/rafaelaparecido/fin-api/Dockerfile`
- Test: `/Users/rafaelaparecido/fin-api/tests/test_cloud_readiness.py`

**Interfaces:**
- Consumes: Configurações de ambiente (`PORT`, `ENVIRONMENT`)
- Produces: API HTTP pronta para deploy em container gerenciado com CORS aberto para Vercel e health check leve.

- [ ] **Step 1: Escrever teste de prontidão para nuvem (CORS e healthcheck leve)**
- [ ] **Step 2: Executar teste e validar falha inicial ou gaps**
- [ ] **Step 3: Implementar suporte a `$PORT`, CORS para `*.vercel.app` e rota `/health` em memória**
- [ ] **Step 4: Executar suite de testes e validar 100% de sucesso**
- [ ] **Step 5: Fazer commit no repositório `fin-api`**

---

### Task 2: `fin-infra` - Manifesto de Deploy Declarativo Koyeb & Scripts de Verificação

**Files:**
- Create: `/Users/rafaelaparecido/fin-infra/koyeb.yaml`
- Create: `/Users/rafaelaparecido/fin-infra/scripts/verify_cloud_deploy.py`
- Modify: `/Users/rafaelaparecido/fin-infra/README.md`

**Interfaces:**
- Consumes: Especificação de serviço Koyeb Nano e endpoints da API
- Produces: Infraestrutura como código para o ecossistema distribuído gratuito

- [ ] **Step 1: Criar manifesto `koyeb.yaml` configurado com tipo de instância nano, variáveis de ambiente e rota de health**
- [ ] **Step 2: Criar script `scripts/verify_cloud_deploy.py` para testar a saúde de todos os serviços remotos**
- [ ] **Step 3: Atualizar documentação operacional no `fin-infra/README.md`**
- [ ] **Step 4: Fazer commit no repositório `fin-infra`**

---

### Task 3: `fin-ingestion` - Automação de Ingestão Idempotente via GitHub Actions

**Files:**
- Create: `/Users/rafaelaparecido/fin-ingestion/.github/workflows/scheduled-ingestion.yml`
- Modify: `/Users/rafaelaparecido/fin-ingestion/README.md`

**Interfaces:**
- Consumes: Repositório `barrosrafa/fin-ingestion`, secrets `DATABASE_URL` e `REDIS_URL`
- Produces: Workflows automáticos no GitHub Actions para coletas sem duplicidade

- [ ] **Step 1: Criar workflow `.github/workflows/scheduled-ingestion.yml` com agendamento nos horários de pregão da B3, fechamento diário e enriquecimento dominical**
- [ ] **Step 2: Adicionar suporte ao gatilho `workflow_dispatch` com parâmetros de execução**
- [ ] **Step 3: Documentar no README a lista exata de GitHub Secrets necessários**
- [ ] **Step 4: Fazer commit no repositório `fin-ingestion`**

---

### Task 4: `fin-web` - Configuração de Variáveis de Produção e Deploy na Vercel

**Files:**
- Modify: `/Users/rafaelaparecido/fin-web/src/lib/api.ts`
- Create: `/Users/rafaelaparecido/fin-web/.vercelignore`
- Deploy: Deploy do frontend via Vercel CLI / Git Integration

**Interfaces:**
- Consumes: URL pública da API via `NEXT_PUBLIC_API_URL`
- Produces: Aplicação web em produção com URL pública global

- [ ] **Step 1: Ajustar `fin-web/src/lib/api.ts` para consumo determinístico de `NEXT_PUBLIC_API_URL`**
- [ ] **Step 2: Executar build de produção local (`pnpm run build`) para assegurar integridade**
- [ ] **Step 3: Efetuar deploy de produção na Vercel**
- [ ] **Step 4: Fazer commit no repositório `fin-web`**

---

### Task 5: Validação Integrada Ponta a Ponta e Entrega da URL Pública

**Files:**
- Verify: URL pública da Vercel
- Verify: Conectividade entre Frontend e API remota
- Output: Resumo executivo com todas as URLs, credenciais necessárias e link direto para teste imediato.

- [ ] **Step 1: Validar carregamento das páginas principais no navegador / HTTP test**
- [ ] **Step 2: Validar consulta de cotações, FIIs, ações e rankings**
- [ ] **Step 3: Entregar ao usuário a URL final e o guia de acesso**
