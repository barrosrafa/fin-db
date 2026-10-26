# 📦 DDL v3.1 — Completo e Executável

Este script contém:
1. **Correções** na v3.0 (FKs ausentes, PKs inconsistentes, retenção, compressão)
2. **~60 tabelas novas** organizadas por schema
3. **Triggers, RLS, políticas de retenção e compressão**

Ordem de execução: **as correções primeiro, depois as novas tabelas, por último políticas.**

---

## PARTE 0 — Correções na v3.0 (executar antes das novas tabelas)

```sql
-- =========================================================
-- 0. CORREÇÕES NA v3.0
-- =========================================================

-- 0.1 Adicionar FKs ausentes
ALTER TABLE analytics.historico_indicador_fundamentalista
    ADD CONSTRAINT fk_hist_ind_fund_ativo
    FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.historico_indicador_tecnico
    ADD CONSTRAINT fk_hist_ind_tec_ativo
    FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.historico_risco
    ADD CONSTRAINT fk_hist_risco_ativo
    FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.matriz_correlacao_historico
    ADD CONSTRAINT fk_matriz_ativo1 FOREIGN KEY (id_ativo_1) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ADD CONSTRAINT fk_matriz_ativo2 FOREIGN KEY (id_ativo_2) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.preco_alvo
    ADD CONSTRAINT fk_preco_alvo_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE analytics.score_ativo
    ADD CONSTRAINT fk_score_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE market.calendario_proventos
    ADD CONSTRAINT fk_cal_prov_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE market.previsao_provento
    ADD CONSTRAINT fk_prev_prov_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE market.antecipacao_dividendo
    ADD CONSTRAINT fk_antecip_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_antecip_provento FOREIGN KEY (id_provento) REFERENCES market.provento(id_provento) ON DELETE RESTRICT;

ALTER TABLE wealth.instituicao_conectada
    ADD CONSTRAINT fk_inst_conn_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.conta_bancaria
    ADD CONSTRAINT fk_conta_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_conta_inst FOREIGN KEY (id_instituicao_conectada)
        REFERENCES wealth.instituicao_conectada(id_instituicao_conectada) ON DELETE CASCADE;

ALTER TABLE wealth.transacao_bancaria
    ADD CONSTRAINT fk_trans_banc_conta FOREIGN KEY (id_conta) REFERENCES wealth.conta_bancaria(id_conta) ON DELETE CASCADE;

ALTER TABLE wealth.cartao_credito
    ADD CONSTRAINT fk_cartao_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.emprestimo
    ADD CONSTRAINT fk_emprest_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.financiamento
    ADD CONSTRAINT fk_financ_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.imovel
    ADD CONSTRAINT fk_imovel_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.veiculo
    ADD CONSTRAINT fk_veiculo_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.outros_bens
    ADD CONSTRAINT fk_bens_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.seguro
    ADD CONSTRAINT fk_seguro_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.previdencia_privada
    ADD CONSTRAINT fk_prev_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.consorcio
    ADD CONSTRAINT fk_consorcio_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.investimento_exterior
    ADD CONSTRAINT fk_inv_ext_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_inv_ext_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE SET NULL;

ALTER TABLE wealth.divida_externa
    ADD CONSTRAINT fk_div_ext_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.meta_financeira
    ADD CONSTRAINT fk_meta_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.simulador
    ADD CONSTRAINT fk_simul_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.rebalanceamento
    ADD CONSTRAINT fk_rebal_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.apuracao_ir
    ADD CONSTRAINT fk_ir_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE wealth.planejamento_tributario
    ADD CONSTRAINT fk_plan_trib_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.comparacao_ativo
    ADD CONSTRAINT fk_comp_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE social.assembleia
    ADD CONSTRAINT fk_assembleia_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE social.progresso_aula
    ADD CONSTRAINT fk_prog_aula FOREIGN KEY (id_aula) REFERENCES social.aula(id_aula) ON DELETE CASCADE,
    ADD CONSTRAINT fk_prog_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.certificado
    ADD CONSTRAINT fk_cert_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_cert_curso FOREIGN KEY (id_curso) REFERENCES social.curso(id_curso) ON DELETE CASCADE;

ALTER TABLE social.topico
    ADD CONSTRAINT fk_topico_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.comentario
    ADD CONSTRAINT fk_coment_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.curtida
    ADD CONSTRAINT fk_curtida_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.seguidor
    ADD CONSTRAINT fk_seg_seguidor FOREIGN KEY (id_usuario_seguidor) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_seg_seguido FOREIGN KEY (id_usuario_seguido) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE social.gamificacao
    ADD CONSTRAINT fk_gamif_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.alerta
    ADD CONSTRAINT fk_alerta_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.notificacao
    ADD CONSTRAINT fk_notif_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.exportacao
    ADD CONSTRAINT fk_export_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE;

ALTER TABLE system.usuario_role
    ADD CONSTRAINT fk_ur_usuario FOREIGN KEY (id_usuario) REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    ADD CONSTRAINT fk_ur_role FOREIGN KEY (id_role) REFERENCES system.role(id_role) ON DELETE CASCADE;

ALTER TABLE dw.historico_posicao
    ADD CONSTRAINT fk_hist_pos_carteira FOREIGN KEY (id_carteira) REFERENCES core.carteira(id_carteira) ON DELETE CASCADE;

ALTER TABLE dw.historico_carteira
    ADD CONSTRAINT fk_hist_cart_carteira FOREIGN KEY (id_carteira) REFERENCES core.carteira(id_carteira) ON DELETE CASCADE;

ALTER TABLE dw.historico_rentabilidade
    ADD CONSTRAINT fk_hist_rent_carteira FOREIGN KEY (id_carteira) REFERENCES core.carteira(id_carteira) ON DELETE CASCADE;

ALTER TABLE dw.ranking
    ADD CONSTRAINT fk_ranking_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

ALTER TABLE dw.historico_indicador
    ADD CONSTRAINT fk_hist_ind_ativo FOREIGN KEY (id_ativo) REFERENCES core.ativo(id_ativo) ON DELETE CASCADE;

-- 0.2 Corrigir PKs inconsistentes
ALTER TABLE wealth.patrimonio_global DROP CONSTRAINT patrimonio_global_pkey;
ALTER TABLE wealth.patrimonio_global DROP COLUMN id_patrimonio;
ALTER TABLE wealth.patrimonio_global
    ADD CONSTRAINT patrimonio_global_pkey PRIMARY KEY (id_usuario, data_referencia);

ALTER TABLE market.curva_juros DROP CONSTRAINT curva_juros_pkey;
ALTER TABLE market.curva_juros DROP COLUMN id_curva;
ALTER TABLE market.curva_juros
    ADD CONSTRAINT curva_juros_pkey PRIMARY KEY (data_referencia, tipo, vertice);

ALTER TABLE market.cambio DROP CONSTRAINT cambio_pkey;
ALTER TABLE market.cambio DROP COLUMN id_cambio;
ALTER TABLE market.cambio
    ADD CONSTRAINT cambio_pkey PRIMARY KEY (data_referencia, moeda_origem, moeda_destino, tipo);

ALTER TABLE market.commodity DROP CONSTRAINT commodity_pkey;
ALTER TABLE market.commodity DROP COLUMN id_commodity;
ALTER TABLE market.commodity
    ADD CONSTRAINT commodity_pkey PRIMARY KEY (data_referencia, nome);

ALTER TABLE market.serie_macroeconomica DROP CONSTRAINT serie_macroeconomica_pkey;
ALTER TABLE market.serie_macroeconomica DROP COLUMN id_serie;
ALTER TABLE market.serie_macroeconomica
    ADD CONSTRAINT serie_macroeconomica_pkey PRIMARY KEY (codigo_sgs, data_referencia);

ALTER TABLE market.aluguel_acoes DROP CONSTRAINT aluguel_acoes_pkey;
ALTER TABLE market.aluguel_acoes DROP COLUMN id_aluguel;
ALTER TABLE market.aluguel_acoes
    ADD CONSTRAINT aluguel_acoes_pkey PRIMARY KEY (id_ativo, data);

-- 0.3 Adicionar NOT NULL em colunas críticas
ALTER TABLE social.topico ALTER COLUMN id_forum SET NOT NULL;
ALTER TABLE social.comentario ALTER COLUMN id_topico SET NOT NULL;
ALTER TABLE analytics.item_carteira_recomendada ALTER COLUMN id_carteira_recomendada SET NOT NULL;

-- 0.4 Adicionar colunas de auditoria em tabelas transacionais
ALTER TABLE core.carteira ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE core.carteira ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE core.posicao_custodia ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 0.5 Ajustar exportacao com status
ALTER TABLE system.exportacao
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','PROCESSANDO','CONCLUIDO','ERRO')),
    ADD COLUMN IF NOT EXISTS url_download TEXT,
    ADD COLUMN IF NOT EXISTS tamanho_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS erro_mensagem TEXT,
    ADD COLUMN IF NOT EXISTS data_conclusao TIMESTAMPTZ;

-- 0.6 Políticas de retenção Timescale
SELECT add_retention_policy('market.cotacao_intraday', INTERVAL '90 days');
SELECT add_retention_policy('market.book_ordens',      INTERVAL '30 days');
SELECT add_retention_policy('market.negocio_intraday', INTERVAL '90 days');
SELECT add_retention_policy('market.after_market',     INTERVAL '365 days');
SELECT add_retention_policy('system.uso_api',          INTERVAL '365 days');
SELECT add_retention_policy('system.auditoria_log',    INTERVAL '1825 days');
SELECT add_retention_policy('system.log_acesso',       INTERVAL '365 days');

-- 0.7 Compressão Timescale (executar em produção, não em dev)
-- ALTER TABLE market.cotacao_diaria SET (timescaledb.compress, timescaledb.compress_segmentby = 'id_ativo');
-- SELECT add_compression_policy('market.cotacao_diaria', INTERVAL '90 days');
```

---

## PARTE 1 — Schema `core`: Tax Lot, Ordens, Bolsas, Moedas

```sql
-- =========================================================
-- 1. CORE: Novas tabelas
-- =========================================================

-- 1.1 Tax Lot Tracking (CRÍTICO para IR)
CREATE TABLE core.lote_ativo (
    id_lote              BIGSERIAL PRIMARY KEY,
    id_carteira          UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo             INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    id_transacao_origem  BIGINT REFERENCES core.transacao_operacao(id_transacao) ON DELETE SET NULL,
    data_aquisicao       DATE NOT NULL,
    quantidade_original  NUMERIC(18,6) NOT NULL CHECK (quantidade_original > 0),
    quantidade_restante  NUMERIC(18,6) NOT NULL CHECK (quantidade_restante >= 0),
    preco_unitario       NUMERIC(12,4) NOT NULL,
    custos_rateados      NUMERIC(12,4) DEFAULT 0,
    tipo_operacao        VARCHAR(20) CHECK (tipo_operacao IN ('DAY_TRADE','SWING_TRADE')),
    isento               BOOLEAN DEFAULT FALSE,
    data_esgotamento     DATE,
    created_at           TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_lote_carteira_ativo ON core.lote_ativo(id_carteira, id_ativo);
CREATE INDEX idx_lote_restante       ON core.lote_ativo(id_carteira, id_ativo)
    WHERE quantidade_restante > 0;

-- 1.2 Consumo de Lote (rastreio de qual lote originou qual venda)
CREATE TABLE core.lote_consumo (
    id_consumo      BIGSERIAL PRIMARY KEY,
    id_lote         BIGINT NOT NULL REFERENCES core.lote_ativo(id_lote) ON DELETE CASCADE,
    id_transacao    BIGINT NOT NULL REFERENCES core.transacao_operacao(id_transacao) ON DELETE CASCADE,
    quantidade      NUMERIC(18,6) NOT NULL CHECK (quantidade > 0),
    preco_venda     NUMERIC(12,4),
    ganho_liquido   NUMERIC(14,2),
    data_venda      DATE,
    UNIQUE (id_lote, id_transacao)
);

-- 1.3 Ordens (ciclo de vida completo)
CREATE TABLE core.ordem (
    id_ordem              BIGSERIAL PRIMARY KEY,
    id_carteira           UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    id_instituicao        INT REFERENCES core.instituicao_financeira(id_instituicao),
    tipo                  core.tipo_operacao_enum NOT NULL,
    tipo_ordem            VARCHAR(20) CHECK (tipo_ordem IN ('LIMIT','MARKET','STOP','STOP_LIMIT','OCO')),
    preco                 NUMERIC(12,4),
    preco_stop            NUMERIC(12,4),
    quantidade            NUMERIC(18,6) NOT NULL CHECK (quantidade > 0),
    quantidade_executada  NUMERIC(18,6) DEFAULT 0,
    preco_medio_execucao  NUMERIC(12,4),
    status                VARCHAR(20) DEFAULT 'ABERTA'
        CHECK (status IN ('ABERTA','PARCIAL','EXECUTADA','CANCELADA','EXPIRADA','REJEITADA')),
    validade              VARCHAR(20) DEFAULT 'DIA' CHECK (validade IN ('DIA','IOC','FOK','GTC','DATA')),
    data_validade         DATE,
    canal                 VARCHAR(50),
    numero_ordem_externo   VARCHAR(50),
    data_criacao          TIMESTAMPTZ DEFAULT NOW(),
    data_atualizacao      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ordem_carteira_status ON core.ordem(id_carteira, status);
CREATE INDEX idx_ordem_data            ON core.ordem(data_criacao DESC);

-- 1.4 Bolsas Internacionais
CREATE TABLE core.bolsa (
    id_bolsa           SERIAL PRIMARY KEY,
    codigo             VARCHAR(20) UNIQUE NOT NULL,
    nome               VARCHAR(150) NOT NULL,
    pais               VARCHAR(50),
    id_moeda           INT,
    fuso_horario       VARCHAR(50),
    horario_abertura   TIME,
    horario_fechamento TIME,
    ativo              BOOLEAN DEFAULT TRUE
);

-- 1.5 Fuso Horário
CREATE TABLE core.fuso_horario (
    id_fuso   SERIAL PRIMARY KEY,
    nome      VARCHAR(60) UNIQUE NOT NULL,
    offset_utc INT NOT NULL,
    dst       BOOLEAN DEFAULT FALSE
);

-- 1.6 Moedas
CREATE TABLE core.moeda (
    id_moeda  SERIAL PRIMARY KEY,
    codigo    VARCHAR(3) UNIQUE NOT NULL,
    nome      VARCHAR(60),
    simbolo   VARCHAR(5),
    pais      VARCHAR(50),
    ativo     BOOLEAN DEFAULT TRUE
);

-- 1.7 Par de Moedas (para câmbio)
CREATE TABLE core.par_moeda (
    id_par          SERIAL PRIMARY KEY,
    id_moeda_origem INT NOT NULL REFERENCES core.moeda(id_moeda),
    id_moeda_destino INT NOT NULL REFERENCES core.moeda(id_moeda),
    codigo           VARCHAR(7) UNIQUE NOT NULL,
    ativo            BOOLEAN DEFAULT TRUE,
    UNIQUE (id_moeda_origem, id_moeda_destino)
);

-- 1.8 Popular moedas básicas
INSERT INTO core.moeda (codigo, nome, simbolo, pais) VALUES
    ('BRL','Real Brasileiro','R$','Brasil'),
    ('USD','Dólar Americano','$','EUA'),
    ('EUR','Euro','€','União Europeia'),
    ('GBP','Libra Esterlina','£','Reino Unido'),
    ('JPY','Iene Japonês','¥','Japão'),
    ('ARS','Peso Argentino','$','Argentina'),
    ('CAD','Dólar Canadense','$','Canadá'),
    ('AUD','Dólar Australiano','$','Austrália'),
    ('CHF','Franco Suíço','Fr','Suíça'),
    ('CNY','Yuan Chinês','¥','China');

-- 1.9 Popular fusos básicos
INSERT INTO core.fuso_horario (nome, offset_utc, dst) VALUES
    ('America/Sao_Paulo', -3, FALSE),
    ('America/New_York', -5, TRUE),
    ('Europe/London', 0, TRUE),
    ('Asia/Tokyo', 9, FALSE),
    ('UTC', 0, FALSE);

-- 1.10 Popular bolsas
INSERT INTO core.bolsa (codigo, nome, pais, fuso_horario, horario_abertura, horario_fechamento) VALUES
    ('B3','B3 - Brasil Bolsa Balcão','Brasil','America/Sao_Paulo','10:00','17:00'),
    ('NYSE','New York Stock Exchange','EUA','America/New_York','09:30','16:00'),
    ('NASDAQ','NASDAQ','EUA','America/New_York','09:30','16:00'),
    ('LSE','London Stock Exchange','Reino Unido','Europe/London','08:00','16:30'),
    ('TSE','Tokyo Stock Exchange','Japão','Asia/Tokyo','09:00','15:00');
```

---

## PARTE 2 — Schema `market`: Benchmarks, Calendário

```sql
-- =========================================================
-- 2. MARKET: Novas tabelas
-- =========================================================

-- 2.1 Benchmarks (CDI, IPCA, IBOV, etc.)
CREATE TABLE market.benchmark (
    id_benchmark SERIAL PRIMARY KEY,
    codigo       VARCHAR(20) UNIQUE NOT NULL,
    nome         VARCHAR(100) NOT NULL,
    tipo         VARCHAR(30) CHECK (tipo IN ('INDICE','TAXA','MOEDA','INFLACAO','COMMODITY')),
    moeda        VARCHAR(3) DEFAULT 'BRL',
    frequencia   VARCHAR(20) CHECK (frequencia IN ('DIARIA','MENSAL','ANUAL')),
    fonte        VARCHAR(50),
    ativo        BOOLEAN DEFAULT TRUE
);

CREATE TABLE market.benchmark_serie (
    id_benchmark     INT NOT NULL REFERENCES market.benchmark(id_benchmark) ON DELETE CASCADE,
    data_referencia  DATE NOT NULL,
    valor            NUMERIC(18,8) NOT NULL,
    valor_normalizado NUMERIC(18,8),
    PRIMARY KEY (id_benchmark, data_referencia)
);
SELECT create_hypertable('market.benchmark_serie','data_referencia', chunk_time_interval => INTERVAL '5 years');
CREATE INDEX idx_bench_serie ON market.benchmark_serie(id_benchmark, data_referencia DESC);

INSERT INTO market.benchmark (codigo, nome, tipo, frequencia, fonte) VALUES
    ('CDI','CDI acumulado','TAXA','DIARIA','BCB'),
    ('SELIC','Taxa Selic','TAXA','DIARIA','BCB'),
    ('IPCA','IPCA','INFLACAO','MENSAL','IBGE'),
    ('IGPM','IGP-M','INFLACAO','MENSAL','FGV'),
    ('IBOV','Ibovespa','INDICE','DIARIA','B3'),
    ('IFIX','IFIX','INDICE','DIARIA','B3'),
    ('IBRX','IBRX-100','INDICE','DIARIA','B3'),
    ('SMLL','Small Caps','INDICE','DIARIA','B3'),
    ('IDIV','IDIV','INDICE','DIARIA','B3'),
    ('SP500','S&P 500','INDICE','DIARIA','Yahoo'),
    ('NASDAQ','NASDAQ Composite','INDICE','DIARIA','Yahoo'),
    ('DXY','Dollar Index','INDICE','DIARIA','Yahoo'),
    ('BTC','Bitcoin','COMMODITY','DIARIA','CoinGecko'),
    ('GOLD','Ouro','COMMODITY','DIARIA','Yahoo'),
    ('BRENT','Petróleo Brent','COMMODITY','DIARIA','Yahoo');

-- 2.2 Calendário de Negociação (feriados B3)
CREATE TABLE market.calendario_negociacao (
    data        DATE NOT NULL,
    id_bolsa    INT NOT NULL REFERENCES core.bolsa(id_bolsa) ON DELETE CASCADE,
    tipo        VARCHAR(30) NOT NULL
        CHECK (tipo IN ('PREGAO_NORMAL','FERIADO','MEIO_EXPEDIENTE','SEM_NEGOCIACAO','PONTO_FACULTATIVO')),
    descricao   VARCHAR(150),
    PRIMARY KEY (data, id_bolsa)
);

-- Popular feriados B3 2024-2026 (exemplo, completar via ETL)
INSERT INTO market.calendario_negociacao (data, id_bolsa, tipo, descricao)
SELECT d::date, 1,
    CASE
        WHEN EXTRACT(dow FROM d) IN (0,6) THEN 'SEM_NEGOCIACAO'
        ELSE 'PREGAO_NORMAL'
    END,
    NULL
FROM generate_series('2024-01-01'::date,'2026-12-31'::date, '1 day') d;
```

---

## PARTE 3 — Schema `analytics`: Internacional, Tags, Coleções, Eventos, Feature Store

```sql
-- =========================================================
-- 3. ANALYTICS: Novas tabelas
-- =========================================================

-- 3.1 Demonstrativos Internacionais (SEC filings)
CREATE TABLE analytics.demonstrativo_internacional (
    id_demonstrativo   BIGSERIAL PRIMARY KEY,
    ticker_internacional VARCHAR(20) NOT NULL,
    pais               VARCHAR(50),
    id_bolsa           INT REFERENCES core.bolsa(id_bolsa),
    tipo               VARCHAR(20) CHECK (tipo IN ('10-K','10-Q','20-F','8-K','EARNINGS','ANNUAL')),
    periodo            VARCHAR(10),
    data_publicacao    DATE,
    contas_json        JSONB,
    moeda              VARCHAR(3),
    fonte              VARCHAR(30),
    UNIQUE (ticker_internacional, tipo, periodo)
);
CREATE INDEX idx_dem_int_contas_gin ON analytics.demonstrativo_internacional USING GIN (contas_json);

-- 3.2 Tags de Ativos
CREATE TABLE analytics.tag (
    id_tag   SERIAL PRIMARY KEY,
    nome     VARCHAR(50) UNIQUE NOT NULL,
    tipo     VARCHAR(30) CHECK (tipo IN ('ESTRATEGIA','TEMA','SETOR','PERFIL')),
    cor      VARCHAR(10)
);

CREATE TABLE analytics.ativo_tag (
    id_ativo INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_tag   INT NOT NULL REFERENCES analytics.tag(id_tag) ON DELETE CASCADE,
    peso     NUMERIC(5,2),
    PRIMARY KEY (id_ativo, id_tag)
);

INSERT INTO analytics.tag (nome, tipo) VALUES
    ('Dividendos','ESTRATEGIA'),
    ('Value','ESTRATEGIA'),
    ('Growth','ESTRATEGIA'),
    ('Small Caps','PERFIL'),
    ('Blue Chips','PERFIL'),
    ('ESG','TEMA'),
    ('Turnaround','TEMA'),
    ('Papel','SETOR'),
    ('Logística','SETOR'),
    ('Shopping','SETOR'),
    ('Híbrido','SETOR'),
    ('Fiagro','SETOR');

-- 3.3 Coleções Curadas
CREATE TABLE analytics.colecao (
    id_colecao   BIGSERIAL PRIMARY KEY,
    nome         VARCHAR(150) NOT NULL,
    descricao    TEXT,
    id_curador   UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    publica      BOOLEAN DEFAULT TRUE,
    slug         VARCHAR(150) UNIQUE,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE analytics.colecao_item (
    id_colecao   BIGINT NOT NULL REFERENCES analytics.colecao(id_colecao) ON DELETE CASCADE,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ordem        INT DEFAULT 0,
    comentario   TEXT,
    PRIMARY KEY (id_colecao, id_ativo)
);

-- 3.4 Eventos de Uso (Product Analytics)
CREATE TABLE analytics.evento_usuario (
    id_evento    BIGSERIAL,
    id_usuario   UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    session_id   UUID,
    evento       VARCHAR(60) NOT NULL,
    propriedades JSONB,
    data_hora    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip           INET,
    user_agent   TEXT,
    plataforma   VARCHAR(20)
);
SELECT create_hypertable('analytics.evento_usuario','data_hora', chunk_time_interval => INTERVAL '7 days');
CREATE INDEX idx_evento_usuario_user_data ON analytics.evento_usuario(id_usuario, data_hora DESC);
CREATE INDEX idx_evento_usuario_evento   ON analytics.evento_usuario(evento, data_hora DESC);
SELECT add_retention_policy('analytics.evento_usuario', INTERVAL '730 days');

-- 3.5 Funis de Conversão
CREATE TABLE analytics.funil (
    id_funil    SERIAL PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    descricao   TEXT,
    etapas      JSONB NOT NULL,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

-- 3.6 Feature Store (IA)
CREATE TABLE analytics.feature_store (
    id_feature       SERIAL PRIMARY KEY,
    nome             VARCHAR(100) UNIQUE NOT NULL,
    tipo             VARCHAR(30) CHECK (tipo IN ('NUMERICO','CATEGORICO','EMBEDDING','BOOLEANO')),
    entidade         VARCHAR(30) CHECK (entidade IN ('ATIVO','USUARIO','CARTEIRA','EMISSOR')),
    fonte_tabela     VARCHAR(100),
    fonte_query      TEXT,
    descricao        TEXT,
    data_atualizacao TIMESTAMPTZ DEFAULT NOW()
);

-- 3.7 Busca Full-Text (View Materializada)
CREATE MATERIALIZED VIEW analytics.busca_ativo AS
SELECT
    a.id_ativo,
    a.ticker,
    e.nome_empresarial AS nome,
    e.setor,
    e.subsetor,
    a.tipo_ativo::text AS tipo,
    setweight(to_tsvector('portuguese', coalesce(a.ticker,'')), 'A') ||
    setweight(to_tsvector('portuguese', coalesce(e.nome_empresarial,'')), 'B') ||
    setweight(to_tsvector('portuguese', coalesce(e.setor,'')), 'C') ||
    setweight(to_tsvector('portuguese', coalesce(e.subsetor,'')), 'C') AS tsv
FROM core.ativo a
LEFT JOIN core.emissor_companhia e ON e.id_emissor = a.id_emissor;

CREATE UNIQUE INDEX idx_busca_ativo_id ON analytics.busca_ativo(id_ativo);
CREATE INDEX idx_busca_ativo_tsv    ON analytics.busca_ativo USING GIN (tsv);
```

---

## PARTE 4 — Schema `social`: Watchlists Múltiplas, Anotações

```sql
-- =========================================================
-- 4. SOCIAL: Novas tabelas
-- =========================================================

-- 4.1 Watchlists Múltiplas
CREATE TABLE social.watchlist (
    id_watchlist BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome         VARCHAR(80) NOT NULL,
    cor          VARCHAR(10) DEFAULT '#3B82F6',
    icone        VARCHAR(30),
    ordem        INT DEFAULT 0,
    publica      BOOLEAN DEFAULT FALSE,
    data_criacao TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_usuario, nome)
);
CREATE INDEX idx_watchlist_usuario ON social.watchlist(id_usuario, ordem);

CREATE TABLE social.watchlist_item (
    id_item      BIGSERIAL PRIMARY KEY,
    id_watchlist BIGINT NOT NULL REFERENCES social.watchlist(id_watchlist) ON DELETE CASCADE,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ordem        INT DEFAULT 0,
    nota         TEXT,
    preco_alerta NUMERIC(12,4),
    data_adicao  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_watchlist, id_ativo)
);

-- 4.2 Anotações / Diário do Investidor
CREATE TABLE social.anotacao_ativo (
    id_anotacao   BIGSERIAL PRIMARY KEY,
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo      INT REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_carteira   UUID REFERENCES core.carteira(id_carteira) ON DELETE SET NULL,
    titulo        VARCHAR(150),
    conteudo      TEXT,
    tags          TEXT[],
    publica       BOOLEAN DEFAULT FALSE,
    data_criacao  TIMESTAMPTZ DEFAULT NOW(),
    data_atualizacao TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_anotacao_usuario ON social.anotacao_ativo(id_usuario, data_criacao DESC);
CREATE INDEX idx_anotacao_ativo   ON social.anotacao_ativo(id_ativo);
CREATE INDEX idx_anotacao_tags    ON social.anotacao_ativo USING GIN (tags);
```

---

## PARTE 5 — Schema `wealth`: Aportes Programados

```sql
-- =========================================================
-- 5. WEALTH: Novas tabelas
-- =========================================================

-- 5.1 Aportes Programados (Recurring Investments)
CREATE TABLE wealth.aporte_programado (
    id_aporte       BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_carteira     UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    valor           NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    frequencia      VARCHAR(20) CHECK (frequencia IN ('SEMANAL','QUINZENAL','MENSAL','BIMESTRAL','TRIMESTRAL')),
    dia_execucao    INT,
    data_inicio     DATE NOT NULL,
    data_fim        DATE,
    status          VARCHAR(20) DEFAULT 'ATIVO' CHECK (status IN ('ATIVO','PAUSADO','ENCERRADO')),
    ultima_execucao DATE,
    proxima_execucao DATE,
    data_criacao    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_aporte_usuario ON wealth.aporte_programado(id_usuario, status);

CREATE TABLE wealth.aporte_execucao (
    id_execucao    BIGSERIAL PRIMARY KEY,
    id_aporte      BIGINT NOT NULL REFERENCES wealth.aporte_programado(id_aporte) ON DELETE CASCADE,
    data           DATE NOT NULL,
    valor_executado NUMERIC(14,2),
    cotacao        NUMERIC(12,4),
    quantidade_comprada NUMERIC(18,6),
    id_transacao   BIGINT REFERENCES core.transacao_operacao(id_transacao) ON DELETE SET NULL,
    status         VARCHAR(20) CHECK (status IN ('EXECUTADO','FALHOU','CANCELADO','PENDENTE')),
    erro_mensagem  TEXT
);
CREATE INDEX idx_aporte_exec_aporte ON wealth.aporte_execucao(id_aporte, data DESC);
```

---

## PARTE 6 — Schema `system`: Autenticação, LGPD, API, Negócio, Suporte

```sql
-- =========================================================
-- 6. SYSTEM: Novas tabelas (maior bloco)
-- =========================================================

-- 6.1 Autenticação completa
CREATE TABLE system.password_reset (
    id_reset       BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    token_hash     VARCHAR(64) NOT NULL UNIQUE,
    data_criacao   TIMESTAMPTZ DEFAULT NOW(),
    data_expiracao TIMESTAMPTZ NOT NULL,
    usado          BOOLEAN DEFAULT FALSE,
    ip             INET
);
CREATE INDEX idx_pwd_reset_user ON system.password_reset(id_usuario, usado);

CREATE TABLE system.email_verificacao (
    id_verificacao BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    email          VARCHAR(150) NOT NULL,
    token_hash     VARCHAR(64) NOT NULL UNIQUE,
    data_criacao   TIMESTAMPTZ DEFAULT NOW(),
    data_expiracao TIMESTAMPTZ NOT NULL,
    verificado     BOOLEAN DEFAULT FALSE
);

CREATE TABLE system.mfa_backup_code (
    id_code    BIGSERIAL PRIMARY KEY,
    id_usuario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    hash_code  VARCHAR(64) NOT NULL,
    usado      BOOLEAN DEFAULT FALSE,
    data_uso   TIMESTAMPTZ
);
CREATE INDEX idx_mfa_user ON system.mfa_backup_code(id_usuario, usado);

CREATE TABLE system.oauth_provider (
    id_provider   SERIAL PRIMARY KEY,
    nome          VARCHAR(30) UNIQUE NOT NULL,
    client_id     VARCHAR(200),
    client_secret VARCHAR(200),
    ativo         BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.oauth_vinculo (
    id_vinculo       BIGSERIAL PRIMARY KEY,
    id_usuario       UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_provider      INT NOT NULL REFERENCES system.oauth_provider(id_provider),
    provider_user_id VARCHAR(200) NOT NULL,
    data_vinculo     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_provider, provider_user_id)
);

CREATE TABLE system.tentativa_login (
    id_tentativa  BIGSERIAL,
    email         VARCHAR(150),
    ip            INET,
    user_agent    TEXT,
    sucesso       BOOLEAN NOT NULL,
    motivo_falha  VARCHAR(60),
    data_hora     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_hypertable('system.tentativa_login','data_hora', chunk_time_interval => INTERVAL '1 month');
CREATE INDEX idx_tent_login_email ON system.tentativa_login(email, data_hora DESC);

INSERT INTO system.oauth_provider (nome, ativo) VALUES
    ('GOOGLE', FALSE),('APPLE', FALSE),('FACEBOOK', FALSE),('GITHUB', FALSE);

-- 6.2 Termos, Consentimentos e LGPD
CREATE TABLE system.versao_termo (
    id_versao    SERIAL PRIMARY KEY,
    tipo         VARCHAR(30) NOT NULL CHECK (tipo IN ('TERMOS_USO','PRIVACIDADE','COOKIES','COMUNICACAO')),
    versao       VARCHAR(20) NOT NULL,
    conteudo     TEXT,
    data_vigencia DATE NOT NULL,
    obrigatorio_reaceite BOOLEAN DEFAULT FALSE,
    UNIQUE (tipo, versao)
);

CREATE TABLE system.aceite_termo (
    id_aceite  BIGSERIAL PRIMARY KEY,
    id_usuario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_versao  INT NOT NULL REFERENCES system.versao_termo(id_versao) ON DELETE RESTRICT,
    data_aceite TIMESTAMPTZ DEFAULT NOW(),
    ip         INET,
    user_agent TEXT,
    UNIQUE (id_usuario, id_versao)
);

CREATE TABLE system.consentimento_cookie (
    id_consentimento BIGSERIAL PRIMARY KEY,
    id_usuario       UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    session_id       UUID,
    categorias       JSONB NOT NULL,
    data             TIMESTAMPTZ DEFAULT NOW(),
    ip               INET
);

CREATE TABLE system.solicitacao_lgpd (
    id_solicitacao BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo           VARCHAR(30) NOT NULL
        CHECK (tipo IN ('ACESSO','CORRECAO','EXCLUSAO','PORTABILIDADE','REVOGACAO','OPOSICAO')),
    status         VARCHAR(20) DEFAULT 'ABERTA'
        CHECK (status IN ('ABERTA','EM_ANALISE','CONCLUIDA','NEGADA')),
    data_abertura  TIMESTAMPTZ DEFAULT NOW(),
    data_conclusao TIMESTAMPTZ,
    resposta       TEXT,
    url_arquivo    TEXT
);
CREATE INDEX idx_dsar_status ON system.solicitacao_lgpd(status, data_abertura DESC);

CREATE TABLE system.ropa (
    id_ropa             SERIAL PRIMARY KEY,
    nome_atividade      VARCHAR(150) NOT NULL,
    finalidade          TEXT,
    base_legal          VARCHAR(50),
    categorias_dados    TEXT,
    categorias_titulares TEXT,
    compartilhamentos   TEXT,
    retencao            VARCHAR(100),
    medidas_seguranca   TEXT,
    data_atualizacao    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.incidente_seguranca (
    id_incidente        BIGSERIAL PRIMARY KEY,
    titulo              VARCHAR(200) NOT NULL,
    descricao           TEXT,
    severidade          VARCHAR(20) CHECK (severidade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    data_deteccao       TIMESTAMPTZ NOT NULL,
    data_resolucao      TIMESTAMPTZ,
    dados_afetados      TEXT,
    notificado_anpd     BOOLEAN DEFAULT FALSE,
    notificado_titulares BOOLEAN DEFAULT FALSE,
    data_notificacao_anpd TIMESTAMPTZ
);

CREATE TABLE system.politica_retencao (
    id_politica  SERIAL PRIMARY KEY,
    tabela       VARCHAR(100) NOT NULL,
    campo_data   VARCHAR(50),
    dias_retencao INT NOT NULL,
    acao         VARCHAR(20) CHECK (acao IN ('DELETAR','ANONIMIZAR','ARQUIVAR')),
    base_legal   VARCHAR(100),
    ativa        BOOLEAN DEFAULT TRUE,
    UNIQUE (tabela, campo_data)
);

-- 6.3 API Keys e Webhooks
CREATE TABLE system.api_key (
    id_api_key      BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome            VARCHAR(80) NOT NULL,
    hash_key        VARCHAR(64) NOT NULL UNIQUE,
    prefixo         VARCHAR(12) NOT NULL,
    escopos         TEXT[],
    quota_diaria    INT DEFAULT 1000,
    quota_usada     INT DEFAULT 0,
    data_criacao    TIMESTAMPTZ DEFAULT NOW(),
    data_expiracao  TIMESTAMPTZ,
    ultimo_uso      TIMESTAMPTZ,
    ativo           BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_api_key_prefixo ON system.api_key(prefixo);

CREATE TABLE system.api_key_uso (
    id_uso            BIGSERIAL,
    id_api_key        BIGINT NOT NULL REFERENCES system.api_key(id_api_key) ON DELETE CASCADE,
    endpoint          VARCHAR(200),
    metodo_http       VARCHAR(10),
    data_hora         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status_code       INT,
    tempo_resposta_ms INT,
    ip                INET
);
SELECT create_hypertable('system.api_key_uso','data_hora', chunk_time_interval => INTERVAL '1 month');
SELECT add_retention_policy('system.api_key_uso', INTERVAL '365 days');

CREATE TABLE system.webhook (
    id_webhook   BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    url          TEXT NOT NULL,
    eventos      TEXT[] NOT NULL,
    secret       VARCHAR(64),
    ativo        BOOLEAN DEFAULT TRUE,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.webhook_entrega (
    id_entrega       BIGSERIAL PRIMARY KEY,
    id_webhook       BIGINT NOT NULL REFERENCES system.webhook(id_webhook) ON DELETE CASCADE,
    evento           VARCHAR(60) NOT NULL,
    payload          JSONB,
    status_code      INT,
    resposta         TEXT,
    tentativas       INT DEFAULT 0,
    data_envio       TIMESTAMPTZ DEFAULT NOW(),
    proxima_tentativa TIMESTAMPTZ,
    sucesso          BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_webhook_entrega_status ON system.webhook_entrega(id_webhook, sucesso, proxima_tentativa);

-- 6.4 Fontes de Dados e ETL
CREATE TABLE system.fonte_dados (
    id_fonte        SERIAL PRIMARY KEY,
    nome            VARCHAR(100) UNIQUE NOT NULL,
    tipo            VARCHAR(20) CHECK (tipo IN ('API','SCRAPING','ARQUIVO','BANCO')),
    url_base        TEXT,
    frequencia      VARCHAR(30),
    ativo           BOOLEAN DEFAULT TRUE,
    ultima_execucao TIMESTAMPTZ,
    status          VARCHAR(20)
);

CREATE TABLE system.fonte_credencial (
    id_credencial     BIGSERIAL PRIMARY KEY,
    id_fonte          INT NOT NULL REFERENCES system.fonte_dados(id_fonte) ON DELETE CASCADE,
    chave             VARCHAR(80) NOT NULL,
    valor_criptografado TEXT NOT NULL,
    data_expiracao    TIMESTAMPTZ,
    data_criacao      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_fonte, chave)
);

CREATE TABLE system.etl_execucao (
    id_execucao          BIGSERIAL PRIMARY KEY,
    pipeline             VARCHAR(100) NOT NULL,
    data_inicio          TIMESTAMPTZ NOT NULL,
    data_fim             TIMESTAMPTZ,
    status               VARCHAR(20) CHECK (status IN ('EXECUTANDO','SUCESSO','ERRO','PARCIAL')),
    registros_processados INT DEFAULT 0,
    registros_erro       INT DEFAULT 0,
    mensagem_erro        TEXT
);
CREATE INDEX idx_etl_pipeline_data ON system.etl_execucao(pipeline, data_inicio DESC);

CREATE TABLE system.etl_erro (
    id_erro      BIGSERIAL PRIMARY KEY,
    id_execucao  BIGINT NOT NULL REFERENCES system.etl_execucao(id_execucao) ON DELETE CASCADE,
    tabela       VARCHAR(100),
    registro     TEXT,
    mensagem     TEXT,
    data         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.cache_metadata (
    chave               VARCHAR(150) PRIMARY KEY,
    ultima_atualizacao  TIMESTAMPTZ NOT NULL,
    ttl_segundos        INT,
    fonte               VARCHAR(100),
    versao              INT DEFAULT 1
);

-- 6.5 Feature Flags e Experimentos
CREATE TABLE system.feature_flag_usuario (
    id_feature  INT NOT NULL REFERENCES system.feature_flag(id_feature) ON DELETE CASCADE,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    habilitado  BOOLEAN NOT NULL,
    data_override TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_feature, id_usuario)
);

CREATE TABLE system.experimento (
    id_experimento SERIAL PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    descricao      TEXT,
    status         VARCHAR(20) DEFAULT 'RASCUNHO'
        CHECK (status IN ('RASCUNHO','ATIVO','PAUSADO','ENCERRADO')),
    data_inicio    DATE,
    data_fim       DATE
);

CREATE TABLE system.experimento_variante (
    id_variante    SERIAL PRIMARY KEY,
    id_experimento INT NOT NULL REFERENCES system.experimento(id_experimento) ON DELETE CASCADE,
    nome           VARCHAR(50) NOT NULL,
    peso           NUMERIC(5,2) NOT NULL,
    config_json    JSONB,
    UNIQUE (id_experimento, nome)
);

CREATE TABLE system.experimento_usuario (
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_experimento INT NOT NULL REFERENCES system.experimento(id_experimento) ON DELETE CASCADE,
    id_variante    INT NOT NULL REFERENCES system.experimento_variante(id_variante) ON DELETE CASCADE,
    data_atribuicao TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_usuario, id_experimento)
);

-- 6.6 Monetização
CREATE TABLE system.cupom (
    id_cupom           SERIAL PRIMARY KEY,
    codigo             VARCHAR(30) UNIQUE NOT NULL,
    tipo               VARCHAR(20) CHECK (tipo IN ('PERCENTUAL','FIXO','TRIAL')),
    valor              NUMERIC(10,2),
    validade_inicio    TIMESTAMPTZ,
    validade_fim       TIMESTAMPTZ,
    usos_maximos       INT,
    usos_atuais        INT DEFAULT 0,
    id_plano_aplicavel INT REFERENCES system.plano(id_plano),
    ativo              BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.cupom_uso (
    id_uso        BIGSERIAL PRIMARY KEY,
    id_cupom      INT NOT NULL REFERENCES system.cupom(id_cupom) ON DELETE RESTRICT,
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_assinatura BIGINT REFERENCES system.assinatura(id_assinatura) ON DELETE SET NULL,
    data_uso      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_cupom, id_usuario)
);

CREATE TABLE system.programa_indicacao (
    id_programa          SERIAL PRIMARY KEY,
    nome                 VARCHAR(100) NOT NULL,
    tipo                 VARCHAR(20) CHECK (tipo IN ('INDICACAO','AFILIADO')),
    comissao_percentual  NUMERIC(5,2),
    ativo                BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.indicacao (
    id_indicacao         BIGSERIAL PRIMARY KEY,
    id_programa          INT NOT NULL REFERENCES system.programa_indicacao(id_programa) ON DELETE CASCADE,
    id_usuario_indicador UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_usuario_indicado  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    data                 TIMESTAMPTZ DEFAULT NOW(),
    status               VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','CONVERTIDA','EXPIRADA','CANCELADA')),
    recompensa_paga      BOOLEAN DEFAULT FALSE,
    UNIQUE (id_usuario_indicado)
);

CREATE TABLE system.comissao (
    id_comissao   BIGSERIAL PRIMARY KEY,
    id_indicacao  BIGINT NOT NULL REFERENCES system.indicacao(id_indicacao) ON DELETE CASCADE,
    valor         NUMERIC(10,2) NOT NULL,
    status        VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','APROVADA','PAGA','CANCELADA')),
    data_pagamento DATE
);

CREATE TABLE system.dunning_evento (
    id_evento        BIGSERIAL PRIMARY KEY,
    id_assinatura    BIGINT NOT NULL REFERENCES system.assinatura(id_assinatura) ON DELETE CASCADE,
    tipo             VARCHAR(30) CHECK (tipo IN ('FALHA_PAGAMENTO','RETENTATIVA','CANCELAMENTO','REATIVACAO')),
    tentativa        INT DEFAULT 1,
    data             TIMESTAMPTZ DEFAULT NOW(),
    status           VARCHAR(20),
    proxima_tentativa TIMESTAMPTZ
);

CREATE TABLE system.reembolso (
    id_reembolso    BIGSERIAL PRIMARY KEY,
    id_pagamento    BIGINT NOT NULL REFERENCES system.pagamento(id_pagamento) ON DELETE RESTRICT,
    valor           NUMERIC(10,2) NOT NULL,
    motivo          VARCHAR(100),
    status          VARCHAR(20) DEFAULT 'SOLICITADO'
        CHECK (status IN ('SOLICITADO','APROVADO','PROCESSANDO','CONCLUIDO','NEGADO')),
    data_solicitacao TIMESTAMPTZ DEFAULT NOW(),
    data_processamento TIMESTAMPTZ,
    gateway_id      VARCHAR(100)
);

-- 6.7 Alertas e Notificações (granular)
CREATE TABLE system.alerta_disparo (
    id_disparo       BIGSERIAL,
    id_alerta        BIGINT NOT NULL REFERENCES system.alerta(id_alerta) ON DELETE CASCADE,
    data_disparo     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valor_no_disparo NUMERIC(18,6),
    canal_envio      VARCHAR(20),
    lido             BOOLEAN DEFAULT FALSE
);
SELECT create_hypertable('system.alerta_disparo','data_disparo', chunk_time_interval => INTERVAL '3 months');

CREATE TABLE system.preferencia_notificacao (
    id_preferencia SERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo_evento    VARCHAR(50) NOT NULL,
    canal          VARCHAR(20) NOT NULL CHECK (canal IN ('EMAIL','PUSH','SMS','WHATSAPP','IN_APP')),
    frequencia     VARCHAR(20) DEFAULT 'IMEDIATO'
        CHECK (frequencia IN ('IMEDIATO','DIARIO','SEMANAL','DESATIVADO')),
    ativo          BOOLEAN DEFAULT TRUE,
    UNIQUE (id_usuario, tipo_evento, canal)
);

CREATE TABLE system.dispositivo (
    id_dispositivo BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    token_push     VARCHAR(300) NOT NULL UNIQUE,
    plataforma     VARCHAR(20) CHECK (plataforma IN ('IOS','ANDROID','WEB')),
    modelo         VARCHAR(80),
    versao_app     VARCHAR(20),
    ultimo_uso     TIMESTAMPTZ DEFAULT NOW(),
    ativo          BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_dispositivo_user ON system.dispositivo(id_usuario, ativo);

-- 6.8 Suporte e Feedback
CREATE TABLE system.ticket (
    id_ticket      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    assunto        VARCHAR(200) NOT NULL,
    categoria      VARCHAR(50),
    prioridade     VARCHAR(20) DEFAULT 'NORMAL'
        CHECK (prioridade IN ('BAIXA','NORMAL','ALTA','URGENTE')),
    status         VARCHAR(20) DEFAULT 'ABERTO'
        CHECK (status IN ('ABERTO','EM_ANDAMENTO','AGUARDANDO_USUARIO','RESOLVIDO','FECHADO')),
    atribuido_a    UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    data_abertura  TIMESTAMPTZ DEFAULT NOW(),
    data_fechamento TIMESTAMPTZ
);
CREATE INDEX idx_ticket_usuario ON system.ticket(id_usuario, status);
CREATE INDEX idx_ticket_status  ON system.ticket(status, prioridade);

CREATE TABLE system.ticket_mensagem (
    id_mensagem BIGSERIAL PRIMARY KEY,
    id_ticket   BIGINT NOT NULL REFERENCES system.ticket(id_ticket) ON DELETE CASCADE,
    id_usuario  UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    is_agente   BOOLEAN DEFAULT FALSE,
    conteudo    TEXT,
    anexos      JSONB,
    data        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.feedback (
    id_feedback BIGSERIAL PRIMARY KEY,
    id_usuario  UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    tipo        VARCHAR(20) CHECK (tipo IN ('NPS','CSAT','SUGESTAO','BUG','ELOGIO')),
    nota        INT CHECK (nota BETWEEN 0 AND 10),
    comentario  TEXT,
    contexto    VARCHAR(100),
    data        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_feedback_tipo_data ON system.feedback(tipo, data DESC);
```

---

## PARTE 7 — Triggers, Funções e RLS

```sql
-- =========================================================
-- 7. TRIGGERS, FUNÇÕES E RLS
-- =========================================================

-- 7.1 Função genérica de auditoria
CREATE OR REPLACE FUNCTION system.fn_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO system.auditoria_log (operacao, tabela, registro_id, old_value)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.id::text, to_jsonb(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO system.auditoria_log (operacao, tabela, registro_id, old_value, new_value)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id::text, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO system.auditoria_log (operacao, tabela, registro_id, new_value)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id::text, to_jsonb(NEW));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 7.2 Aplicar em tabelas críticas (exemplos)
CREATE TRIGGER trg_audit_posicao
    AFTER INSERT OR UPDATE OR DELETE ON core.posicao_custodia
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

CREATE TRIGGER trg_audit_carteira
    AFTER INSERT OR UPDATE OR DELETE ON core.carteira
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

CREATE TRIGGER trg_audit_ordem
    AFTER INSERT OR UPDATE OR DELETE ON core.ordem
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

CREATE TRIGGER trg_audit_apuracao_ir
    AFTER INSERT OR UPDATE OR DELETE ON wealth.apuracao_ir
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

-- 7.3 Trigger de updated_at automático
CREATE OR REPLACE FUNCTION system.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_carteira_updated
    BEFORE UPDATE ON core.carteira
    FOR EACH ROW EXECUTE FUNCTION system.fn_set_updated_at();

CREATE TRIGGER trg_ordem_updated
    BEFORE UPDATE ON core.ordem
    FOR EACH ROW EXECUTE FUNCTION system.fn_set_updated_at();

-- 7.4 RLS — Row Level Security
ALTER TABLE core.carteira            ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.posicao_custodia    ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.nota_corretagem     ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.transacao_operacao  ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.ordem               ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.lote_ativo          ENABLE ROW LEVEL SECURITY;
ALTER TABLE wealth.apuracao_ir       ENABLE ROW LEVEL SECURITY;
ALTER TABLE wealth.meta_financeira   ENABLE ROW LEVEL SECURITY;
ALTER TABLE social.watchlist         ENABLE ROW LEVEL SECURITY;
ALTER TABLE social.anotacao_ativo    ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.api_key           ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.dispositivo       ENABLE ROW LEVEL SECURITY;

-- Políticas de exemplo (usuário só vê suas carteiras)
CREATE POLICY p_carteira_owner ON core.carteira
    USING (id_usuario = current_setting('app.current_user_id', TRUE)::uuid);

CREATE POLICY p_posicao_owner ON core.posicao_custodia
    USING (id_carteira IN (
        SELECT id_carteira FROM core.carteira
        WHERE id_usuario = current_setting('app.current_user_id', TRUE)::uuid
    ));

CREATE POLICY p_ordem_owner ON core.ordem
    USING (id_carteira IN (
        SELECT id_carteira FROM core.carteira
        WHERE id_usuario = current_setting('app.current_user_id', TRUE)::uuid
    ));

CREATE POLICY p_lote_owner ON core.lote_ativo
    USING (id_carteira IN (
        SELECT id_carteira FROM core.carteira
        WHERE id_usuario = current_setting('app.current_user_id', TRUE)::uuid
    ));

CREATE POLICY p_ir_owner ON wealth.apuracao_ir
    USING (id_usuario = current_setting('app.current_user_id', TRUE)::uuid);

CREATE POLICY p_watchlist_owner ON social.watchlist
    USING (id_usuario = current_setting('app.current_user_id', TRUE)::uuid);

CREATE POLICY p_anotacao_owner ON social.anotacao_ativo
    USING (id_usuario = current_setting('app.current_user_id', TRUE)::uuid);

CREATE POLICY p_apikey_owner ON system.api_key
    USING (id_usuario = current_setting('app.current_user_id', TRUE)::uuid);

CREATE POLICY p_dispositivo_owner ON system.dispositivo
    USING (id_usuario = current_setting('app.current_user_id', TRUE)::uuid);

-- 7.5 Views úteis para o app
CREATE OR REPLACE VIEW core.v_posicao_atual AS
SELECT
    pc.id_posicao,
    pc.id_carteira,
    pc.id_ativo,
    a.ticker,
    a.tipo_ativo,
    pc.quantidade_total,
    pc.quantidade_disponivel,
    pc.quantidade_bloqueada,
    pc.preco_medio_ponderado,
    pc.preco_atual,
    pc.valor_mercado,
    pc.rentabilidade,
    pc.data_ultima_atualizacao
FROM core.posicao_custodia pc
JOIN core.ativo a ON a.id_ativo = pc.id_ativo
WHERE pc.quantidade_total > 0;

CREATE OR REPLACE VIEW wealth.v_patrimonio_resumo AS
SELECT
    id_usuario,
    data_referencia,
    total_ativos,
    total_passivos,
    patrimonio_liquido,
    total_ativos - LAG(total_ativos) OVER (PARTITION BY id_usuario ORDER BY data_referencia) AS variacao
FROM wealth.patrimonio_global
ORDER BY id_usuario, data_referencia DESC;

-- 7.6 Continuous Aggregates adicionais
CREATE MATERIALIZED VIEW analytics.cagg_provento_mensal
WITH (timescaledb.continuous) AS
SELECT
    id_ativo,
    time_bucket('1 month', data_pagamento) AS mes,
    sum(valor_por_acao) AS total_pago,
    count(*) AS num_eventos
FROM market.provento
WHERE data_pagamento IS NOT NULL
GROUP BY id_ativo, mes;

SELECT add_continuous_aggregate_policy('analytics.cagg_provento_mensal',
    start_offset => INTERVAL '10 years',
    end_offset   => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');
```

---

## PARTE 8 — Resumo do que foi adicionado

| Schema | Tabelas novas | Total v3.1 |
|---|---|---|
| `core` | 9 (lote_ativo, lote_consumo, ordem, bolsa, fuso_horario, moeda, par_moeda) | ~25 |
| `market` | 3 (benchmark, benchmark_serie, calendario_negociacao) | ~22 |
| `analytics` | 8 (demonstrativo_internacional, tag, ativo_tag, colecao, colecao_item, evento_usuario, funil, feature_store) + 1 M-View | ~22 |
| `social` | 3 (watchlist, watchlist_item, anotacao_ativo) | ~17 |
| `wealth` | 2 (aporte_programado, aporte_execucao) | ~22 |
| `system` | 38 (auth, LGPD, API, ETL, monetização, suporte) | ~55 |
| `dw` | — | 9 |
| **Total** | **~63 tabelas novas** | **~170 tabelas** |

### O que ainda foi adicionado além das tabelas:

- ✅ **FKs faltantes** (~45 correções)
- ✅ **PKs corrigidas** (6 tabelas)
- ✅ **Retenção Timescale** (8 políticas)
- ✅ **Compressão Timescale** (comentada, para produção)
- ✅ **Triggers de auditoria** (4 exemplos + função genérica)
- ✅ **RLS** (12 tabelas + 10 políticas)
- ✅ **Views** (2 views para app)
- ✅ **Continuous Aggregate** adicional (provento mensal)
- ✅ **Seed data** (moedas, fusos, bolsas, benchmarks, tags, OAuth providers)

---

## Próximos passos recomendados

1. **Executar em ambiente dev** — validar sintaxe e conflitos
2. **Popular seeds** — completar feriados B3, benchmarks históricos
3. **Configurar `app.current_user_id`** — no middleware do backend antes de cada query RLS
4. **Testar RLS** — garantir que usuário A não vê dados de B
5. **Configurar monitoramento** — `pg_stat_statements`, `pg_stat_user_indexes`
6. **Documentar políticas de retenção** — vincular com `system.politica_retencao`
7. **Gerar OpenAPI** — próximo artefato natural após o DDL

Quer que eu gere agora o **OpenAPI 3.1 completo** com os ~80 endpoints que conversam com esse banco? Ou prefere os **DAGs Airflow** para popular as tabelas?