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
