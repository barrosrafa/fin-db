-- =========================================================
-- SCHEMA asset_details
-- =========================================================
CREATE TABLE asset_details.segmento_fii (
    id_segmento SERIAL PRIMARY KEY,
    nome        VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE asset_details.tipo_gestao_fii (
    id_tipo_gestao SERIAL PRIMARY KEY,
    nome           VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE asset_details.detalhe_fii (
    id_detalhe_fii  BIGSERIAL PRIMARY KEY,
    id_ativo        INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_segmento     INT REFERENCES asset_details.segmento_fii(id_segmento),
    id_tipo_gestao  INT REFERENCES asset_details.tipo_gestao_fii(id_tipo_gestao),
    gestor          VARCHAR(150),
    administrador   VARCHAR(150),
    numero_cotistas INT,
    prazo_duracao   VARCHAR(50)
);

CREATE TABLE asset_details.historico_vacancia_fii (
    id_ativo       INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia DATE NOT NULL,
    vacancia_fisica NUMERIC(5,2),
    vacancia_financeira NUMERIC(5,2),
    abl_total      NUMERIC(18,2),
    abl_locada     NUMERIC(18,2),
    PRIMARY KEY (id_ativo, data_referencia)
);
SELECT create_hypertable('asset_details.historico_vacancia_fii','data_referencia', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE asset_details.historico_patrimonio_fii (
    id_ativo        INT NOT NULL,
    data_referencia DATE NOT NULL,
    patrimonio_liquido NUMERIC(18,2),
    quantidade_cotas BIGINT,
    valor_patrimonial_cota NUMERIC(12,4),
    PRIMARY KEY (id_ativo, data_referencia)
);
SELECT create_hypertable('asset_details.historico_patrimonio_fii','data_referencia', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE asset_details.composicao_carteira_fii (
    id_composicao  BIGSERIAL PRIMARY KEY,
    id_ativo       INT NOT NULL,
    data_referencia DATE NOT NULL,
    tipo_ativo     VARCHAR(30),
    nome_ativo     VARCHAR(200),
    percentual     NUMERIC(6,3),
    valor          NUMERIC(18,2),
    endereco       TEXT
);

CREATE TABLE asset_details.rentabilidade_fii (
    id_ativo        INT NOT NULL,
    data_referencia DATE NOT NULL,
    rentabilidade_mes NUMERIC(8,4),
    rentabilidade_ano NUMERIC(8,4),
    rentabilidade_12m NUMERIC(8,4),
    rentabilidade_desde_inicio NUMERIC(10,4),
    benchmark       VARCHAR(20),
    PRIMARY KEY (id_ativo, data_referencia)
);

CREATE TABLE asset_details.etf_detalhe (
    id_etf      BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    indice_referencia VARCHAR(50),
    taxa_administracao NUMERIC(6,4),
    patrimonio  NUMERIC(18,2),
    cotas       BIGINT,
    numero_cotistas INT,
    benchmark   VARCHAR(30),
    composicao_carteira_url TEXT
);

CREATE TABLE asset_details.bdr_detalhe (
    id_bdr      BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    empresa_estrangeira VARCHAR(150),
    pais_origem VARCHAR(50),
    ratio       NUMERIC(10,4),
    moeda_origem VARCHAR(3),
    bolsa_origem VARCHAR(20),
    setor_global VARCHAR(50)
);

CREATE TABLE asset_details.opcao_detalhe (
    id_opcao    BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    serie       VARCHAR(20),
    strike      NUMERIC(12,4),
    vencimento  DATE,
    tipo        CHAR(4) CHECK (tipo IN ('CALL','PUT')),
    id_ativo_objeto INT REFERENCES core.ativo(id_ativo),
    premio      NUMERIC(12,4),
    contratos_abertos BIGINT,
    volatilidade_implicita NUMERIC(8,4),
    delta       NUMERIC(8,4),
    gamma       NUMERIC(8,4),
    theta       NUMERIC(8,4),
    vega        NUMERIC(8,4)
);

CREATE TABLE asset_details.tesouro_direto (
    id_tesouro  BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    tipo_titulo VARCHAR(30),
    indexador   VARCHAR(20),
    taxa_compra NUMERIC(8,4),
    taxa_venda  NUMERIC(8,4),
    vencimento  DATE,
    pu          NUMERIC(12,6),
    quantidade_mercado NUMERIC(18,2),
    rentabilidade NUMERIC(8,4)
);

CREATE TABLE asset_details.renda_fixa_detalhe (
    id_rf       BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    emissor     VARCHAR(150),
    indexador   VARCHAR(20),
    taxa        NUMERIC(8,4),
    vencimento  DATE,
    rating      VARCHAR(10),
    garantia    VARCHAR(30),
    liquidez    VARCHAR(20),
    classe      VARCHAR(30),
    spread      NUMERIC(8,4)
);

CREATE TABLE asset_details.fundo_investimento (
    id_fundo    BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    cnpj        VARCHAR(14) UNIQUE,
    classe      VARCHAR(30),
    segmento    VARCHAR(50),
    taxa_adm    NUMERIC(6,4),
    taxa_performance NUMERIC(6,4),
    benchmark   VARCHAR(30),
    patrimonio  NUMERIC(18,2),
    cota_atual  NUMERIC(18,8),
    performance_12m NUMERIC(8,4),
    numero_cotistas INT,
    classificacao_anbima VARCHAR(50),
    gestor      VARCHAR(150)
);

CREATE TABLE asset_details.fundo_carteira (
    id_carteira_fundo BIGSERIAL PRIMARY KEY,
    id_fundo    BIGINT NOT NULL REFERENCES asset_details.fundo_investimento(id_fundo) ON DELETE CASCADE,
    data_referencia DATE NOT NULL,
    tipo_ativo  VARCHAR(30),
    nome_ativo  VARCHAR(200),
    percentual  NUMERIC(6,3)
);

CREATE TABLE asset_details.fundo_rentabilidade (
    id_fundo    BIGINT NOT NULL,
    data_referencia DATE NOT NULL,
    rentabilidade_mes NUMERIC(8,4),
    rentabilidade_ano NUMERIC(8,4),
    rentabilidade_12m NUMERIC(8,4),
    rentabilidade_desde_inicio NUMERIC(10,4),
    sharpe      NUMERIC(8,4),
    volatilidade NUMERIC(8,4),
    PRIMARY KEY (id_fundo, data_referencia)
);

CREATE TABLE asset_details.criptomoeda_detalhe (
    id_cripto   BIGSERIAL PRIMARY KEY,
    id_ativo    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    exchange    VARCHAR(50),
    wallet      VARCHAR(150),
    staking_yield NUMERIC(6,4),
    tipo_custodia VARCHAR(30),
    algoritmo_consenso VARCHAR(30),
    market_cap  NUMERIC(20,2),
    volume_24h  NUMERIC(20,2),
    dominancia  NUMERIC(6,4),
    fornecimento_maximo NUMERIC(20,8)
);
