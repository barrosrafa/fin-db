# 📦 DDL v3.2 — Foco em Plataforma de Análise (Não Regulada)

Escopo desta versão: **apenas o que uma plataforma de análise precisa**. Removi todo o bloco regulatório (suitability CVM, PLD/AML, ouvidoria, contratos), PIX/pagamentos e obrigações de fintech.

**Total: ~35 tabelas novas** organizadas em 6 blocos priorizados.

---

## BLOCO 1 — Reconciliação (CRÍTICO)

Necessário para confiabilidade dos dados quando o usuário importa notas, sincroniza Open Finance ou cadastra manualmente.

```sql
-- =========================================================
-- BLOCO 1: RECONCILIAÇÃO
-- =========================================================

-- 1.1 Reconciliação bancária (Open Finance vs. cadastro manual)
CREATE TABLE wealth.reconciliacao_bancaria (
    id_reconciliacao   BIGSERIAL PRIMARY KEY,
    id_usuario         UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_conta           BIGINT REFERENCES wealth.conta_bancaria(id_conta) ON DELETE CASCADE,
    data               DATE NOT NULL,
    saldo_extrato      NUMERIC(18,2),
    saldo_sistema      NUMERIC(18,2),
    divergencia        NUMERIC(18,2) GENERATED ALWAYS AS (saldo_extrato - saldo_sistema) STORED,
    status             VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','OK','AJUSTADA','IGNORADA')),
    observacao         TEXT,
    data_criacao       TIMESTAMPTZ DEFAULT NOW(),
    data_resolucao     TIMESTAMPTZ,
    UNIQUE (id_usuario, id_conta, data)
);
CREATE INDEX idx_recon_banc_status ON wealth.reconciliacao_bancaria(status, data DESC);

-- 1.2 Reconciliação de custódia (B3 vs. sistema)
CREATE TABLE core.reconciliacao_custodia (
    id_reconciliacao   BIGSERIAL PRIMARY KEY,
    id_carteira        UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo           INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    data               DATE NOT NULL,
    quantidade_externa NUMERIC(18,6),
    quantidade_sistema NUMERIC(18,6),
    divergencia        NUMERIC(18,6) GENERATED ALWAYS AS (quantidade_externa - quantidade_sistema) STORED,
    fonte_externa      VARCHAR(30) CHECK (fonte_externa IN ('B3','CORRETORA','OPEN_FINANCE','MANUAL')),
    status             VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','OK','AJUSTADA','IGNORADA')),
    data_criacao       TIMESTAMPTZ DEFAULT NOW(),
    data_resolucao     TIMESTAMPTZ,
    UNIQUE (id_carteira, id_ativo, data, fonte_externa)
);
CREATE INDEX idx_recon_cust_status ON core.reconciliacao_custodia(status, data DESC);

-- 1.3 Ajustes manuais (com auditoria)
CREATE TABLE core.ajuste_manual (
    id_ajuste          BIGSERIAL PRIMARY KEY,
    id_usuario         UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_carteira        UUID REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo           INT REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    entidade           VARCHAR(50) NOT NULL,
    entidade_id        TEXT,
    tipo               VARCHAR(30) CHECK (tipo IN ('QUANTIDADE','PRECO','PROVENTO','DATA','OUTRO')),
    valor_anterior     JSONB,
    valor_novo         JSONB,
    motivo             TEXT NOT NULL,
    data_ajuste        TIMESTAMPTZ DEFAULT NOW(),
    ip                 INET
);
CREATE INDEX idx_ajuste_manual_user ON core.ajuste_manual(id_usuario, data_ajuste DESC);
```

---

## BLOCO 2 — SCD (Histórico de Atributos)

Sem isso, você reescreve história. Consultas de 2020 em 2025 ficam erradas.

```sql
-- =========================================================
-- BLOCO 2: SLOWLY CHANGING DIMENSIONS (SCD Tipo 2)
-- =========================================================

-- 2.1 Histórico do emissor (setor, nome, GICS mudam ao longo do tempo)
CREATE TABLE core.emissor_historico (
    id_historico          BIGSERIAL PRIMARY KEY,
    id_emissor            INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_vigencia_inicio  DATE NOT NULL,
    data_vigencia_fim     DATE,
    nome_empresarial      VARCHAR(150),
    setor                 VARCHAR(50),
    subsetor              VARCHAR(50),
    gics                  VARCHAR(50),
    cnae                  VARCHAR(20),
    codigo_cvm            VARCHAR(10),
    versao                INT NOT NULL DEFAULT 1,
    motivo_mudanca        VARCHAR(100),
    UNIQUE (id_emissor, data_vigencia_inicio)
);
CREATE INDEX idx_emissor_hist_vigencia ON core.emissor_historico(id_emissor, data_vigencia_inicio DESC);
CREATE INDEX idx_emissor_hist_atual    ON core.emissor_historico(id_emissor) WHERE data_vigencia_fim IS NULL;

-- 2.2 Histórico do ativo (ticker, ISIN, tipo, segmento mudam)
CREATE TABLE core.ativo_historico (
    id_historico          BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_vigencia_inicio  DATE NOT NULL,
    data_vigencia_fim     DATE,
    ticker                VARCHAR(12),
    isin                  VARCHAR(12),
    codigo_cetip          VARCHAR(20),
    tipo_ativo            core.tipo_ativo_enum,
    segmento_listagem     VARCHAR(50),
    versao                INT NOT NULL DEFAULT 1,
    motivo_mudanca        VARCHAR(100),
    UNIQUE (id_ativo, data_vigencia_inicio)
);
CREATE INDEX idx_ativo_hist_vigencia ON core.ativo_historico(id_ativo, data_vigencia_inicio DESC);

-- 2.3 Histórico de composição de índices (rebalanceamentos)
CREATE TABLE market.composicao_indice_historico (
    id_historico          BIGSERIAL PRIMARY KEY,
    id_indice             INT NOT NULL REFERENCES market.indice(id_indice) ON DELETE CASCADE,
    data_rebalanceamento  DATE NOT NULL,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    peso_anterior         NUMERIC(7,4),
    peso_novo             NUMERIC(7,4),
    tipo_mudanca          VARCHAR(20) CHECK (tipo_mudanca IN ('ENTRADA','SAIDA','PESO')),
    UNIQUE (id_indice, data_rebalanceamento, id_ativo)
);
```

---

## BLOCO 3 — Anti-fraude e Segurança

Essencial mesmo para plataforma não regulada.

```sql
-- =========================================================
-- BLOCO 3: ANTI-FRAUDE E SEGURANÇA
-- =========================================================

-- 3.1 Device fingerprint (reconhecer dispositivos)
CREATE TABLE system.device_fingerprint (
    id_fingerprint    BIGSERIAL PRIMARY KEY,
    id_usuario        UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    fingerprint_hash  VARCHAR(64) NOT NULL,
    user_agent        TEXT,
    ip_primeiro_uso   INET,
    geo_pais          VARCHAR(3),
    geo_cidade        VARCHAR(100),
    primeiro_uso      TIMESTAMPTZ DEFAULT NOW(),
    ultimo_uso        TIMESTAMPTZ DEFAULT NOW(),
    confiavel         BOOLEAN DEFAULT FALSE,
    UNIQUE (id_usuario, fingerprint_hash)
);
CREATE INDEX idx_device_fp_user ON system.device_fingerprint(id_usuario, confiavel);

-- 3.2 Eventos de segurança (login suspeito, novo device, etc.)
CREATE TABLE system.evento_seguranca (
    id_evento      BIGSERIAL,
    id_usuario     UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    tipo           VARCHAR(40) NOT NULL
        CHECK (tipo IN ('LOGIN_SUSPEITO','NOVO_DISPOSITIVO','MUDANCA_SENHA',
                        'MUDANCA_EMAIL','ACESSO_NEGADO','BLOQUEIO_CONTA',
                        'TENTATIVA_MFA_FALHA','SESSAO_EXPIRADA')),
    severidade     VARCHAR(10) CHECK (severidade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    detalhes_json  JSONB,
    ip             INET,
    user_agent     TEXT,
    data           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolvido      BOOLEAN DEFAULT FALSE,
    data_resolucao TIMESTAMPTZ
);
SELECT create_hypertable('system.evento_seguranca','data', chunk_time_interval => INTERVAL '1 month');
CREATE INDEX idx_evento_seg_user ON system.evento_seguranca(id_usuario, data DESC);
SELECT add_retention_policy('system.evento_seguranca', INTERVAL '730 days');

-- 3.3 IPs bloqueados
CREATE TABLE system.ip_bloqueado (
    id_ip            BIGSERIAL PRIMARY KEY,
    ip               INET NOT NULL,
    motivo           VARCHAR(100),
    data_bloqueio    TIMESTAMPTZ DEFAULT NOW(),
    data_desbloqueio TIMESTAMPTZ,
    permanente       BOOLEAN DEFAULT FALSE,
    UNIQUE (ip)
);
CREATE INDEX idx_ip_bloq_ativo ON system.ip_bloqueado(ip) WHERE data_desbloqueio IS NULL;

-- 3.4 Rate limiting persistente
CREATE TABLE system.rate_limit (
    chave             VARCHAR(150) NOT NULL,
    endpoint          VARCHAR(150) NOT NULL,
    janela_inicio     TIMESTAMPTZ NOT NULL,
    contador          INT NOT NULL DEFAULT 0,
    PRIMARY KEY (chave, endpoint, janela_inicio)
);
SELECT create_hypertable('system.rate_limit','janela_inicio', chunk_time_interval => INTERVAL '1 day');
SELECT add_retention_policy('system.rate_limit', INTERVAL '7 days');
```

---

## BLOCO 4 — Produto e UX

```sql
-- =========================================================
-- BLOCO 4: PRODUTO E UX
-- =========================================================

-- 4.1 Inbox centralizado (unifica alertas, notificações, comunicados)
CREATE TABLE system.inbox (
    id_inbox    BIGSERIAL,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo        VARCHAR(30) NOT NULL
        CHECK (tipo IN ('ALERTA','NOTIFICACAO','COMUNICADO','PROVENTO',
                        'EVENTO_CORPORATIVO','NEWSLETTER','SISTEMA')),
    titulo      VARCHAR(200),
    mensagem    TEXT,
    link        TEXT,
    icone       VARCHAR(30),
    prioridade  VARCHAR(10) DEFAULT 'NORMAL' CHECK (prioridade IN ('BAIXA','NORMAL','ALTA')),
    lida        BOOLEAN DEFAULT FALSE,
    arquivada   BOOLEAN DEFAULT FALSE,
    data_criacao TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_leitura TIMESTAMPTZ
);
SELECT create_hypertable('system.inbox','data_criacao', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_inbox_user_unread ON system.inbox(id_usuario, lida, data_criacao DESC);
SELECT add_retention_policy('system.inbox', INTERVAL '365 days');

-- 4.2 Grupos e comunidades
CREATE TABLE social.grupo (
    id_grupo     BIGSERIAL PRIMARY KEY,
    nome         VARCHAR(100) NOT NULL,
    slug         VARCHAR(100) UNIQUE,
    descricao    TEXT,
    tipo         VARCHAR(20) DEFAULT 'PUBLICO' CHECK (tipo IN ('PUBLICO','PRIVADO','PAGO')),
    id_criador   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    avatar_url   TEXT,
    membros_count INT DEFAULT 0,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE social.grupo_membro (
    id_grupo    BIGINT NOT NULL REFERENCES social.grupo(id_grupo) ON DELETE CASCADE,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    papel       VARCHAR(20) DEFAULT 'MEMBRO' CHECK (papel IN ('ADMIN','MODERADOR','MEMBRO')),
    data_entrada TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_grupo, id_usuario)
);
CREATE INDEX idx_grupo_membro_user ON social.grupo_membro(id_usuario);

-- 4.3 Mensagens diretas
CREATE TABLE social.mensagem_direta (
    id_mensagem    BIGSERIAL,
    id_remetente   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_destinatario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    conteudo       TEXT NOT NULL,
    lida           BOOLEAN DEFAULT FALSE,
    data_envio     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_leitura   TIMESTAMPTZ
);
SELECT create_hypertable('social.mensagem_direta','data_envio', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_msg_direta_rem ON social.mensagem_direta(id_remetente, data_envio DESC);
CREATE INDEX idx_msg_direta_dest ON social.mensagem_direta(id_destinatario, lida, data_envio DESC);

-- 4.4 Bloqueio de usuário
CREATE TABLE social.bloqueio_usuario (
    id_usuario          UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_usuario_bloqueado UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    data_bloqueio       TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_usuario, id_usuario_bloqueado)
);

-- 4.5 Dashboards customizados
CREATE TABLE social.dashboard (
    id_dashboard BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome         VARCHAR(80) NOT NULL,
    publico      BOOLEAN DEFAULT FALSE,
    slug         VARCHAR(100) UNIQUE,
    data_criacao TIMESTAMPTZ DEFAULT NOW(),
    data_atualizacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE social.dashboard_widget (
    id_widget      BIGSERIAL PRIMARY KEY,
    id_dashboard   BIGINT NOT NULL REFERENCES social.dashboard(id_dashboard) ON DELETE CASCADE,
    tipo           VARCHAR(40) NOT NULL
        CHECK (tipo IN ('GRAFICO_COTACAO','RANKING','TABELA_ATIVOS','CARD_PROVENTO',
                        'CARD_PATRIMONIO','NOTICIAS','WATCHLIST','CALENDARIO')),
    config_json    JSONB NOT NULL,
    posicao_x      INT DEFAULT 0,
    posicao_y      INT DEFAULT 0,
    largura        INT DEFAULT 4,
    altura         INT DEFAULT 3,
    ordem          INT DEFAULT 0
);

-- 4.6 Pipeline de Teses (Kanban do investidor)
CREATE TABLE social.tese_pipeline (
    id_tese            BIGSERIAL PRIMARY KEY,
    id_usuario         UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo           INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    estagio            VARCHAR(20) NOT NULL DEFAULT 'DESCOBERTA'
        CHECK (estagio IN ('DESCOBERTA','ANALISE','COMPRAR','MONITORANDO','DESCARTADA')),
    tese               TEXT,
    preco_entrada_alvo NUMERIC(12,4),
    preco_saida_alvo   NUMERIC(12,4),
    data_movimentacao  TIMESTAMPTZ DEFAULT NOW(),
    data_criacao       TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_usuario, id_ativo)
);
CREATE INDEX idx_tese_user_estagio ON social.tese_pipeline(id_usuario, estagio);
```

---

## BLOCO 5 — Marketing e LGPD

```sql
-- =========================================================
-- BLOCO 5: MARKETING E LGPD
-- =========================================================

-- 5.1 Opt-out granular (LGPD)
CREATE TABLE system.opt_out (
    id_opt_out       BIGSERIAL PRIMARY KEY,
    id_usuario       UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    canal            VARCHAR(20) NOT NULL CHECK (canal IN ('EMAIL','PUSH','SMS','WHATSAPP')),
    tipo_comunicacao VARCHAR(40) NOT NULL,
    data_opt_out     TIMESTAMPTZ DEFAULT NOW(),
    motivo           VARCHAR(100),
    UNIQUE (id_usuario, canal, tipo_comunicacao)
);

-- 5.2 Templates de mensagem
CREATE TABLE system.template_mensagem (
    id_template    SERIAL PRIMARY KEY,
    nome           VARCHAR(80) UNIQUE NOT NULL,
    canal          VARCHAR(20) CHECK (canal IN ('EMAIL','PUSH','SMS','WHATSAPP','IN_APP')),
    assunto        VARCHAR(200),
    corpo_html     TEXT,
    corpo_texto    TEXT,
    variaveis_json JSONB,
    data_criacao   TIMESTAMPTZ DEFAULT NOW()
);

-- 5.3 Segmentos de usuário (para campanhas)
CREATE TABLE system.segmento_usuario (
    id_segmento  SERIAL PRIMARY KEY,
    nome         VARCHAR(80) UNIQUE NOT NULL,
    descricao    TEXT,
    criterios_json JSONB NOT NULL,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

-- 5.4 Campanhas
CREATE TABLE system.campanha (
    id_campanha  BIGSERIAL PRIMARY KEY,
    nome         VARCHAR(100) NOT NULL,
    tipo         VARCHAR(20) CHECK (tipo IN ('EMAIL','PUSH','IN_APP','SMS')),
    id_template  INT REFERENCES system.template_mensagem(id_template),
    id_segmento  INT REFERENCES system.segmento_usuario(id_segmento),
    data_inicio  TIMESTAMPTZ,
    data_fim     TIMESTAMPTZ,
    status       VARCHAR(20) DEFAULT 'RASCUNHO'
        CHECK (status IN ('RASCUNHO','AGENDADA','ATIVA','PAUSADA','CONCLUIDA','CANCELADA')),
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

-- 5.5 Envios de campanha (tracking)
CREATE TABLE system.envio_campanha (
    id_envio    BIGSERIAL,
    id_campanha BIGINT NOT NULL REFERENCES system.campanha(id_campanha) ON DELETE CASCADE,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    data_envio  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    aberto      BOOLEAN DEFAULT FALSE,
    data_abertura TIMESTAMPTZ,
    clicado     BOOLEAN DEFAULT FALSE,
    data_clique TIMESTAMPTZ,
    convertido  BOOLEAN DEFAULT FALSE
);
SELECT create_hypertable('system.envio_campanha','data_envio', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_envio_camp_user ON system.envio_campanha(id_usuario, data_envio DESC);
SELECT add_retention_policy('system.envio_campanha', INTERVAL '730 days');
```

---

## BLOCO 6 — Notícias e Métricas Avançadas

```sql
-- =========================================================
-- BLOCO 6: NOTÍCIAS E MÉTRICAS
-- =========================================================

-- 6.1 Fontes de notícia (agregador)
CREATE TABLE social.fonte_noticia (
    id_fonte       SERIAL PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    url_base       TEXT,
    tipo           VARCHAR(20) CHECK (tipo IN ('RSS','API','SCRAPING')),
    categoria      VARCHAR(40),
    confiabilidade INT DEFAULT 3 CHECK (confiabilidade BETWEEN 1 AND 5),
    ativo          BOOLEAN DEFAULT TRUE,
    ultima_coleta  TIMESTAMPTZ
);

-- 6.2 Detecção de duplicatas
CREATE TABLE social.noticia_duplicada (
    id_noticia_origem   BIGINT NOT NULL REFERENCES social.noticia_ativo(id_noticia) ON DELETE CASCADE,
    id_noticia_duplicata BIGINT NOT NULL REFERENCES social.noticia_ativo(id_noticia) ON DELETE CASCADE,
    similaridade        NUMERIC(5,4),
    PRIMARY KEY (id_noticia_origem, id_noticia_duplicata)
);

-- 6.3 Entidades mencionadas em notícias
CREATE TABLE social.noticia_entidade (
    id_noticia  BIGINT NOT NULL REFERENCES social.noticia_ativo(id_noticia) ON DELETE CASCADE,
    id_ativo    INT REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_emissor  INT REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    relevancia  NUMERIC(5,4),
    PRIMARY KEY (id_noticia, id_ativo, id_emissor)
);

-- 6.4 Modelos de precificação (DCF, Gordon, etc.)
CREATE TABLE analytics.modelo_precificacao (
    id_modelo      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo       INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    tipo           VARCHAR(30) CHECK (tipo IN ('DCF','GORDON','COMPARAVEIS','RNAV','DDM','OUTRO')),
    parametros_json JSONB NOT NULL,
    resultado      NUMERIC(12,4),
    data_calculo   TIMESTAMPTZ DEFAULT NOW(),
    publico        BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_modelo_prec_ativo ON analytics.modelo_precificacao(id_ativo, data_calculo DESC);

-- 6.5 Métricas extras de rentabilidade
ALTER TABLE dw.historico_rentabilidade
    ADD COLUMN IF NOT EXISTS mwr NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS cagr NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS rentabilidade_real NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS cash_drag NUMERIC(10,6);

-- 6.6 ETF NAV e fluxo de cotas
CREATE TABLE asset_details.etf_nav (
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    nav                   NUMERIC(12,6),
    preco_mercado         NUMERIC(12,4),
    premio_desconto_pct   NUMERIC(8,4),
    PRIMARY KEY (id_ativo, data_referencia)
);
SELECT create_hypertable('asset_details.etf_nav','data_referencia', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE asset_details.etf_fluxo_cotas (
    id_ativo         INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data             DATE NOT NULL,
    cotas_criadas    BIGINT DEFAULT 0,
    cotas_resgatadas BIGINT DEFAULT 0,
    fluxo_liquido    BIGINT GENERATED ALWAYS AS (cotas_criadas - cotas_resgatadas) STORED,
    PRIMARY KEY (id_ativo, data)
);
SELECT create_hypertable('asset_details.etf_fluxo_cotas','data', chunk_time_interval => INTERVAL '2 years');
```

---

## BLOCO 7 — IA (Fase Futura, mas já estrutura)

Deixei apenas a fundação. Se não pretende usar IA agora, pode pular.

```sql
-- =========================================================
-- BLOCO 7: IA / ML (Fase Futura)
-- =========================================================

-- 7.1 Recomendações personalizadas
CREATE TABLE analytics.recomendacao (
    id_recomendacao BIGSERIAL,
    id_usuario      UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    score           NUMERIC(6,4),
    motivo          VARCHAR(30) CHECK (motivo IN ('COLLABORATIVE','CONTENT_BASED','HYBRID','TRENDING')),
    data_geracao    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    clique          BOOLEAN DEFAULT FALSE,
    feedback        INT CHECK (feedback BETWEEN -1 AND 1)
);
SELECT create_hypertable('analytics.recomendacao','data_geracao', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_recomend_user ON analytics.recomendacao(id_usuario, data_geracao DESC);

-- 7.2 Modelos ML registrados
CREATE TABLE analytics.modelo_ml (
    id_modelo      SERIAL PRIMARY KEY,
    nome           VARCHAR(80) NOT NULL,
    versao         VARCHAR(20) NOT NULL,
    tipo           VARCHAR(30),
    data_treino    TIMESTAMPTZ,
    metricas_json  JSONB,
    ativo          BOOLEAN DEFAULT FALSE,
    UNIQUE (nome, versao)
);

-- 7.3 Embeddings (requer extensão pgvector)
-- CREATE EXTENSION IF NOT EXISTS vector;
-- CREATE TABLE analytics.embedding_ativo (
--     id_ativo    INT PRIMARY KEY REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
--     modelo      VARCHAR(50) NOT NULL,
--     vetor       vector(768),
--     data_geracao TIMESTAMPTZ DEFAULT NOW()
-- );
-- CREATE INDEX idx_emb_ativo ON analytics.embedding_ativo USING ivfflat (vetor vector_cosine_ops);
```

---

## 📊 Resumo v3.2

| Bloco | Tabelas | Prioridade |
|---|---|---|
| 1. Reconciliação | 3 | 🔴 Crítica |
| 2. SCD Histórico | 3 | 🔴 Crítica |
| 3. Anti-fraude | 4 | 🔴 Crítica |
| 4. Produto/UX | 8 | 🟠 Alta |
| 5. Marketing/LGPD | 5 | 🟠 Alta |
| 6. Notícias/Métricas | 6 | 🟡 Média |
| 7. IA/ML | 3 (opcional) | 🟢 Baixa |
| **Total** | **~32 tabelas** | |

### O que foi **deliberadamente omitido** (por ser plataforma não regulada)

❌ Suitability / Questionário de perfil
❌ PLD/AML / PEP / Sanções
❌ Ouvidoria / Reclamações CVM
❌ Contratos regulatórios / Assinatura eletrônica
❌ Regime tributário tabelado (você pode calcular, mas não é obrigado)
❌ PIX / Pagamentos / Boletos
❌ Transações de cartão de crédito detalhadas
❌ SLO/SLI operacionais (fica em Grafana/Prometheus, não no DB)

### O que foi **incluído porque é essencial mesmo sem regulação**

✅ Reconciliação → confiabilidade dos dados
✅ SCD → histórico correto
✅ Anti-fraude → proteção do usuário
✅ Inbox → UX unificada
✅ Grupos/mensagens → engajamento
✅ Opt-out → LGPD
✅ Métricas extras → análise profissional
✅ NAV/Fluxo ETF → granularidade
✅ Fundação IA → sem custo agora, pronta para depois

---

## ✅ Conclusão

Com a v3.2, o banco está **completo para uma plataforma de análise não regulada** no nível Status Invest + Investidor10 + Fundamentei + Clube FII.

**Total consolidado: ~200 tabelas** distribuídas em 8 schemas, cobrindo:
- Cadastro, custódia, transações
- Mercado, proventos, eventos
- Fundamentos, técnico, risco
- FIIs, ETFs, fundos, renda fixa
- Wealth, IR, patrimônio
- Social, educação, gamificação
- DW, rankings, histórico
- Sistema, segurança, LGPD

**Próximos passos práticos:**
1. Aplicar DDL v3.2 no ambiente dev
2. Validar com `EXPLAIN ANALYZE` as queries críticas
3. Rodar carga de teste (10M cotações, 100k usuários)
4. Ajustar índices conforme `pg_stat_statements`
5. Partir para os DAGs Airflow

Quer que eu gere agora os **DAGs Airflow** para popular as tabelas prioritárias (cotações B3, proventos, fundamentos CVM, macro BCB)?