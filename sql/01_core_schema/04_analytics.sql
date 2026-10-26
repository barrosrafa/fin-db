-- =========================================================
-- SCHEMA analytics
-- =========================================================
CREATE TABLE analytics.demonstrativo_financeiro (
    id_demonstrativo BIGSERIAL PRIMARY KEY,
    id_emissor       INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_referencia  DATE NOT NULL,
    data_publicacao  DATE,
    tipo_documento   VARCHAR(10) CHECK (tipo_documento IN ('DFP','ITR','Release')),
    versao           INT DEFAULT 1,
    contas_detalhadas JSONB,
    numero_acoes     BIGINT,
    receita_liquida  NUMERIC(18,2),
    ebitda           NUMERIC(18,2),
    lucro_liquido    NUMERIC(18,2),
    patrimonio_liquido NUMERIC(18,2),
    divida_bruta     NUMERIC(18,2),
    divida_liquida   NUMERIC(18,2),
    UNIQUE (id_emissor, data_referencia, tipo_documento, versao)
);
CREATE INDEX idx_dem_fin_contas_gin ON analytics.demonstrativo_financeiro USING GIN (contas_detalhadas);
CREATE INDEX idx_dem_fin_emissor ON analytics.demonstrativo_financeiro(id_emissor, data_referencia DESC);

CREATE TABLE analytics.indicador_fundamentalista (
    id_indicador    BIGSERIAL PRIMARY KEY,
    id_ativo        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia DATE NOT NULL,
    pl              NUMERIC(12,4),
    pvp             NUMERIC(12,4),
    psr             NUMERIC(12,4),
    dividend_yield  NUMERIC(8,4),
    payout          NUMERIC(8,4),
    roe             NUMERIC(8,4),
    roic            NUMERIC(8,4),
    ebitda_margem   NUMERIC(8,4),
    margem_liquida  NUMERIC(8,4),
    divida_liquida_ebitda NUMERIC(10,4),
    lpa             NUMERIC(12,4),
    vpa             NUMERIC(12,4),
    ev_ebitda       NUMERIC(12,4),
    ev_ebit         NUMERIC(12,4),
    liquidez_corrente NUMERIC(8,4),
    giro_ativo      NUMERIC(8,4),
    UNIQUE (id_ativo, data_referencia)
);

CREATE TABLE analytics.historico_indicador_fundamentalista (
    id_ativo        INT NOT NULL,
    data_referencia DATE NOT NULL,
    pl              NUMERIC(12,4),
    pvp             NUMERIC(12,4),
    roe             NUMERIC(8,4),
    roic            NUMERIC(8,4),
    dividend_yield  NUMERIC(8,4),
    ev_ebitda       NUMERIC(12,4),
    margem_liquida  NUMERIC(8,4),
    divida_liquida_ebitda NUMERIC(10,4),
    PRIMARY KEY (id_ativo, data_referencia)
);
SELECT create_hypertable('analytics.historico_indicador_fundamentalista','data_referencia', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE analytics.indicador_tecnico (
    id_indicador    BIGSERIAL PRIMARY KEY,
    id_ativo        INT NOT NULL,
    data_pregao     DATE NOT NULL,
    media_movel_20  NUMERIC(12,4),
    media_movel_50  NUMERIC(12,4),
    media_movel_200 NUMERIC(12,4),
    ifr_14          NUMERIC(8,4),
    macd            NUMERIC(12,6),
    banda_boll_sup  NUMERIC(12,4),
    banda_boll_inf  NUMERIC(12,4),
    suporte         NUMERIC(12,4),
    resistencia     NUMERIC(12,4),
    UNIQUE (id_ativo, data_pregao)
);

CREATE TABLE analytics.historico_indicador_tecnico (
    id_ativo       INT NOT NULL,
    data_pregao    DATE NOT NULL,
    media_movel_20 NUMERIC(12,4),
    media_movel_50 NUMERIC(12,4),
    media_movel_200 NUMERIC(12,4),
    ifr_14         NUMERIC(8,4),
    macd           NUMERIC(12,6),
    banda_boll_sup NUMERIC(12,4),
    banda_boll_inf NUMERIC(12,4),
    PRIMARY KEY (id_ativo, data_pregao)
);
SELECT create_hypertable('analytics.historico_indicador_tecnico','data_pregao', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE analytics.historico_risco (
    id_ativo       INT NOT NULL,
    data_calculo   DATE NOT NULL,
    beta           NUMERIC(8,4),
    volatilidade_anualizada NUMERIC(8,4),
    sharpe         NUMERIC(8,4),
    treynor        NUMERIC(8,4),
    sortino        NUMERIC(8,4),
    drawdown_maximo NUMERIC(8,4),
    var            NUMERIC(8,4),
    PRIMARY KEY (id_ativo, data_calculo)
);
SELECT create_hypertable('analytics.historico_risco','data_calculo', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE analytics.matriz_correlacao_historico (
    id_matriz      BIGSERIAL,
    data_calculo   DATE NOT NULL,
    janela_tempo   VARCHAR(10),
    id_ativo_1     INT NOT NULL,
    id_ativo_2     INT NOT NULL,
    coeficiente_pearson NUMERIC(6,4),
    PRIMARY KEY (id_matriz, data_calculo)
);

CREATE TABLE analytics.backtest_resultado (
    id_backtest    BIGSERIAL PRIMARY KEY,
    id_usuario     UUID REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    estrategia     VARCHAR(100),
    data_inicio    DATE,
    data_fim       DATE,
    rentabilidade_total NUMERIC(10,4),
    sharpe         NUMERIC(8,4),
    drawdown_maximo NUMERIC(8,4),
    trades_json    JSONB
);

CREATE TABLE analytics.filtro_salvo (
    id_filtro     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome_filtro   VARCHAR(80),
    tipo_ativo    core.tipo_ativo_enum,
    criterios_json JSONB NOT NULL,
    data_criacao  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_filtro_criterios_gin ON analytics.filtro_salvo USING GIN (criterios_json);

CREATE TABLE analytics.ranking_configuracao (
    id_config      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo_ranking   VARCHAR(30),
    tipo_ativo     core.tipo_ativo_enum,
    ativo_ordenacao VARCHAR(20) DEFAULT 'DESC',
    limite         INT DEFAULT 10,
    data_criacao   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE analytics.carteira_recomendada (
    id_carteira_recomendada BIGSERIAL PRIMARY KEY,
    nome           VARCHAR(100),
    tipo           VARCHAR(20),
    perfil         VARCHAR(20),
    benchmark      VARCHAR(20),
    data_criacao   DATE,
    data_ultima_atualizacao DATE,
    justificativa  TEXT
);

CREATE TABLE analytics.item_carteira_recomendada (
    id_item        BIGSERIAL PRIMARY KEY,
    id_carteira_recomendada BIGINT NOT NULL REFERENCES analytics.carteira_recomendada(id_carteira_recomendada) ON DELETE CASCADE,
    id_ativo       INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    peso_percentual NUMERIC(6,3),
    tese_investimento TEXT,
    data_entrada   DATE,
    data_saida     DATE
);

CREATE TABLE analytics.relatorio_analise (
    id_relatorio   BIGSERIAL PRIMARY KEY,
    id_emissor     INT REFERENCES core.emissor_companhia(id_emissor) ON DELETE SET NULL,
    id_ativo       INT REFERENCES core.ativo(id_ativo) ON DELETE SET NULL,
    tipo           VARCHAR(30),
    titulo         VARCHAR(200),
    resumo         TEXT,
    url_pdf        TEXT,
    analista       VARCHAR(100),
    data_publicacao DATE,
    nota_analista  VARCHAR(20)
);

CREATE TABLE analytics.score_ativo (
    id_score       BIGSERIAL PRIMARY KEY,
    id_ativo       INT NOT NULL,
    data_calculo   DATE NOT NULL,
    metodologia    VARCHAR(50),
    pontuacao      NUMERIC(6,2),
    classificacao  VARCHAR(30),
    detalhes_json  JSONB,
    UNIQUE (id_ativo, data_calculo, metodologia)
);

CREATE TABLE analytics.preco_alvo (
    id_preco_alvo  BIGSERIAL PRIMARY KEY,
    id_ativo       INT NOT NULL,
    data_referencia DATE NOT NULL,
    preco_alvo_medio NUMERIC(12,4),
    preco_alvo_maximo NUMERIC(12,4),
    preco_alvo_minimo NUMERIC(12,4),
    numero_analistas INT,
    recomendacao   VARCHAR(20),
    UNIQUE (id_ativo, data_referencia)
);

CREATE TABLE analytics.casa_analise (
    id_casa        SERIAL PRIMARY KEY,
    nome           VARCHAR(150) UNIQUE,
    tipo           VARCHAR(30)
);

CREATE TABLE analytics.analista (
    id_analista    SERIAL PRIMARY KEY,
    nome           VARCHAR(150),
    id_casa        INT REFERENCES analytics.casa_analise(id_casa)
);

CREATE TABLE analytics.insider_transaction (
    id_transacao   BIGSERIAL PRIMARY KEY,
    id_emissor     INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    id_insider     VARCHAR(100),
    cargo          VARCHAR(60),
    tipo_operacao  CHAR(1) CHECK (tipo_operacao IN ('C','V')),
    quantidade     BIGINT,
    preco_unitario NUMERIC(12,4),
    data_operacao  DATE NOT NULL
);
