# Arquitetura e Deploy Distribuído Gratuito: fin-web, fin-api, fin-ingestion e fin-infra

## 1. Contexto & Intenção (The Why)
O ecossistema **fin** é uma plataforma analítica e transacional de investimentos brasileira e internacional composta por frontend Next.js (`fin-web`), API de alta performance FastAPI/Python (`fin-api`), pipeline de ingestão e analytics com dbt (`fin-ingestion`), banco de dados relacional e analítico (`fin-db`) e configurações de infraestrutura (`fin-infra`).

O objetivo deste projeto é disponibilizar o ecossistema completo para acesso público e irrestrito (desktop, mobile e qualquer dispositivo), operando 24 horas por dia, 7 dias por semana, com **custo zero permanente de infraestrutura** utilizando os melhores serviços gerenciados de camada gratuita (Free Tier).

---

## 2. Metas, Não-Metas e Anti-Metas

### Metas (Goals)
- **Custo Zero ($0/mês)**: Operar 100% dentro dos limites gratuitos definitivos dos provedores.
- **Disponibilidade 24/7 Sem Interrupções**: Interface web e API respondendo sem cold starts ou hibernação por inatividade.
- **Ingestão Incremental & Idempotente**: Rotinas de coleta programadas no GitHub Actions durante e após o pregão para atualizar cotações, proventos e novos tickers sem duplicidade de registros (`ON CONFLICT DO UPDATE` / deduplicação determinística).
- **Deploy Contínuo (CI/CD)**: Cada push nas branches `main` dos repositórios GitHub atualiza automaticamente os serviços em produção.
- **Segurança & SSL/HTTPS**: Certificados TLS gerenciados automaticamente de ponta a ponta.

### Não-Metas (Non-Goals)
- Provisionamento de infraestrutura paga em AWS (RDS Aurora, NAT Gateways, ALB, ECS Fargate), presente nos templates legados do `fin-infra/terraform`.
- Ingestão contínua em streaming tick-by-tick segundo a segundo (inviável em free tiers de banco de dados).

### Anti-Metas (Anti-Goals)
- Depender de máquinas locais ligadas 24h ou de túneis efêmeros (como URLs temporárias do `trycloudflare.com`).
- Aceitar plataformas que hibernem a API após inatividade sem mecanismo de keep-alive.
- Ingestão descontrolada que gere registros duplicados no banco de dados Neon ou esgote a cota mensal de 100 Compute Unit-hours do Neon.

---

## 3. Matriz de Arquitetura e Componentes

| Componente | Repositório | Plataforma de Nuvem | Plano / Custo | Função Principal |
|---|---|---|---|---|
| **fin-web** | `barrosrafa/fin-web` | **Vercel** | Hobby ($0) | Frontend Next.js 16 / React 19, CDN Edge global, HTTPS nativo |
| **fin-api** | `barrosrafa/fin-api` | **Koyeb** | Free Nano ($0) | API FastAPI (Python 3.12), endpoints públicos REST, sem hibernação via ping leve |
| **fin-db** | `barrosrafa/fin-db` | **Neon Serverless** | Free Tier ($0) | PostgreSQL 18 com TimescaleDB, pgvector, conexão via pooler seguro |
| **Redis** | Integrado | **Redis Cloud (ou Upstash)** | Free Tier ($0) | 30MB de memória, comandos ilimitados e SSL nativo (`rediss://` ou `redis://`) |
| **fin-ingestion** | `barrosrafa/fin-ingestion` | **GitHub Actions** | 2.000 min/mês ($0) | Cron workflows agendados para coleta de B3/CVM/StatusInvest e enriquecimento |
| **fin-infra** | `barrosrafa/fin-infra` | **GitHub & Koyeb CLI** | Repositório ($0) | Configurações de deploy (`koyeb.yaml`), variáveis de ambiente e documentação |

---

## 4. Detalhamento Técnico das Decisões (Decisões do Builder)

### 4.1. Frontend (`fin-web`) na Vercel
- **Build & Runtime**: `pnpm run build` (Next.js 16.4.3 Turbopack).
- **Variáveis de Ambiente**:
  - `NEXT_PUBLIC_API_URL`: URL HTTPS pública fornecida pelo Koyeb (ex: `https://fin-api-<username>.koyeb.app/api/v1`).
- **Deploy**: Conexão nativa do GitHub com a Vercel. Cada push dispara preview e production deploys automaticamente.

### 4.2. Backend (`fin-api`) no Koyeb & Política de Zero Cold-Start
- **Build**: Imagem Docker gerada a partir do `Dockerfile` oficial do repositório `fin-api`.
- **Configuração de Execução**:
  - A API responde na porta definida dinamicamente pela variável `$PORT` (default 8000).
  - Health check HTTP configurado no endpoint `/health`.
- **Prevenção de Cold-Start Sem Exaurir o Neon**:
  - O endpoint `/health` retorna status 200 OK em memória pura, sem disparar queries SQL no Neon.
  - Um monitor de uptime gratuito (ex: UptimeRobot ou Cron-job.org) executa um `GET /health` a cada 40 minutos. Isso mantém a instância do Koyeb aquecida sem consumir a cota de 100 CU-horas do banco Neon.
- **CORS**:
  - Adição de `https://*.vercel.app` e dos domínios do frontend no middleware CORS do FastAPI.
- **Variáveis de Ambiente**:
  - `ENVIRONMENT=production`
  - `DEBUG=false`
  - `PORT=8000`
  - `HOST=0.0.0.0`
  - `DATABASE_URL`: String pooler do Neon (`postgresql+asyncpg://...`)
  - `REDIS_URL`: String de conexão Redis gerenciado com SSL.

### 4.3. Cache e Fila de Workers (Redis Cloud / Upstash)
- **Decisão de Arquitetura**: Usar **Redis Cloud (30MB Free Forever)** ou **Upstash com ARQ desacoplado**:
  - Como o Upstash impõe teto de 10.000 comandos/dia no plano gratuito e um worker ARQ ocioso em loop 24/7 consome >80.000 comandos/dia de polling, adotamos o **Redis Cloud** (que possui comandos diários ilimitados no free tier) para o broker e cache.
  - Alternativamente, as tarefas pesadas de reconciliação e sincronização rodam em modo `--burst` dentro dos runners do GitHub Actions, poupando a memória de 512MB do container da API.

### 4.4. Ingestão Automatizada (`fin-ingestion`) via GitHub Actions
- Workflow `.github/workflows/scheduled-ingestion.yml` configurado no repositório `fin-ingestion`.
- **Gatilhos Programados**:
  - Durante o pregão (Segunda a Sexta, 11:00 às 17:00 BRT, de 2 em 2 horas): atualização rápida de cotações e novos tickers.
  - Fechamento de mercado (Segunda a Sexta às 18:30 BRT): pipeline diário completo de fechamento e proventos.
  - Fim de semana (Domingo às 20:00 BRT): enriquecimento cadastral profundo (`enrich-metadata`).
  - Gatilho manual `workflow_dispatch` para disparar coletas sob demanda via interface web do GitHub.
- **Consumo de Minutos**: ~250 a 350 minutos/mês dos 2.000 minutos gratuitos mensais do GitHub Actions.
- **Idempotência**: Garantida pela chave composta primária e regras `ON CONFLICT DO UPDATE` do modelo Neon, evitando duplicidade de ativos e cotações históricas.

### 4.5. Banco de Dados (`fin-db`) e Migrações
- O banco PostgreSQL 18 no Neon já está provisionado e com todos os 12 schemas aplicados.
- Futuras migrações DDL são executadas via script de migração controlado, sem necessidade de deploy contínuo destrutivo.

### 4.6. Orquestração e Repositório de Infraestrutura (`fin-infra`)
- O repositório `fin-infra` centraliza a documentação operacional, o manifesto declarativo do Koyeb (`koyeb.yaml`) e os guias de configuração de segredos.
- O deploy do Koyeb é conectado via GitHub App oficial diretamente ao repositório `barrosrafa/fin-api`.

---

## 5. Plano de Implementação (Passos Executáveis)
1. **fin-api**:
   - Ajustar CORS no FastAPI para permitir domínios Vercel.
   - Ajustar `Dockerfile` para garantir suporte à variável `$PORT` do Koyeb.
   - Provisionar o serviço no Koyeb conectado a `barrosrafa/fin-api`.
2. **fin-web**:
   - Configurar o projeto na Vercel conectado a `barrosrafa/fin-web`.
   - Injetar `NEXT_PUBLIC_API_URL` com o endpoint HTTPS do Koyeb.
3. **fin-ingestion**:
   - Criar `.github/workflows/scheduled-ingestion.yml` com as rotinas idempotentes.
   - Configurar os GitHub Secrets (`DATABASE_URL`, `REDIS_URL`).
4. **fin-infra**:
   - Adicionar `koyeb.yaml` e documentação de manutenção no `fin-infra`.
   - Adicionar script de health check e verificação de conectividade.
