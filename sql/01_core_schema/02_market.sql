-- =========================================================
-- SCHEMA market
-- =========================================================
CREATE TABLE market.cotacao_diaria (
    data_pregao        DATE NOT NULL,
    id_ativo           INT  NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    preco_abertura     NUMERIC(10,2),
    preco_maximo       NUMERIC(10,2),
    preco_minimo       NUMERIC(10,2),
    preco_fechamento   NUMERIC(10,2),
    preco_medio        NUMERIC(10,2),
    volume_total       NUMERIC(18,2),
    quantidade_negocios INT,
    preco_ajustado     NUMERIC(10,2),
    variacao_percentual NUMERIC(8,4),
    preco_ajuste_anterior NUMERIC(10,2),
    preco_fechamento_anterior NUMERIC(10,2),
    quantidade_teorica BIGINT,
    ajuste             NUMERIC(10,2),
    PRIMARY KEY (id_ativo, data_pregao)
);
SELECT create_hypertable('market.cotacao_diaria','data_pregao', chunk_time_interval => INTERVAL '1 year');
CREATE INDEX idx_cot_diaria_ativo_data ON market.cotacao_diaria(id_ativo, data_pregao DESC);

CREATE TABLE market.cotacao_intraday (
    id_tick      BIGSERIAL,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    timestamp    TIMESTAMPTZ NOT NULL,
    preco_atual  NUMERIC(12,4),
    variacao     NUMERIC(8,4),
    volume       NUMERIC(18,2)
);
SELECT create_hypertable('market.cotacao_intraday','timestamp', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX idx_cot_intraday ON market.cotacao_intraday(id_ativo, timestamp DESC);

CREATE TABLE market.book_ordens (
    id_book    BIGSERIAL,
    id_ativo   INT NOT NULL,
    tipo_oferta CHAR(1) CHECK (tipo_oferta IN ('C','V')),
    preco      NUMERIC(12,4),
    quantidade NUMERIC(18,6),
    corretora  INT,
    timestamp  TIMESTAMPTZ NOT NULL
);
SELECT create_hypertable('market.book_ordens','timestamp', chunk_time_interval => INTERVAL '1 day');

CREATE TABLE market.negocio_intraday (
    id_negocio BIGSERIAL,
    id_ativo   INT NOT NULL,
    timestamp  TIMESTAMPTZ NOT NULL,
    preco      NUMERIC(12,4),
    quantidade NUMERIC(18,6),
    comprador  INT,
    vendedor   INT,
    agressor   CHAR(1) CHECK (agressor IN ('C','V'))
);
SELECT create_hypertable('market.negocio_intraday','timestamp', chunk_time_interval => INTERVAL '1 day');

CREATE TABLE market.leilao (
    id_leilao  BIGSERIAL PRIMARY KEY,
    id_ativo   INT NOT NULL,
    data       DATE NOT NULL,
    tipo       VARCHAR(20) CHECK (tipo IN ('PRE_ABERTURA','FECHAMENTO')),
    preco_teorico NUMERIC(12,4),
    quantidade_teorica NUMERIC(18,6)
);

CREATE TABLE market.after_market (
    id_after   BIGSERIAL,
    id_ativo   INT NOT NULL,
    timestamp  TIMESTAMPTZ NOT NULL,
    preco      NUMERIC(12,4),
    volume     NUMERIC(18,2)
);
SELECT create_hypertable('market.after_market','timestamp', chunk_time_interval => INTERVAL '1 day');

CREATE TABLE market.ajuste_intraday (
    id_ajuste  BIGSERIAL,
    id_ativo   INT NOT NULL,
    data       DATE NOT NULL,
    valor_ajuste NUMERIC(12,4)
);
SELECT create_hypertable('market.ajuste_intraday','data', chunk_time_interval => INTERVAL '1 year');

-- Eventos societários
CREATE TABLE market.evento_corporativo (
    id_evento      BIGSERIAL PRIMARY KEY,
    id_ativo       INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    tipo_evento    VARCHAR(50),
    data_aprovacao DATE,
    data_ex        DATE,
    fator_proporcao NUMERIC(10,6),
    observacao     TEXT
);

CREATE TABLE market.desdobramento_split (
    id_desdobramento BIGSERIAL PRIMARY KEY,
    id_ativo         INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    tipo             VARCHAR(20) CHECK (tipo IN ('SPLIT','INPLIT','BONIFICACAO')),
    data_ex          DATE NOT NULL,
    quantidade_antes INT,
    quantidade_depois INT,
    fator            NUMERIC(10,6)
);

CREATE TABLE market.subscricao_acao (
    id_subscricao      BIGSERIAL PRIMARY KEY,
    id_ativo           INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    tipo               VARCHAR(20) CHECK (tipo IN ('PRIMARIA','SECUNDARIA')),
    data_aprovacao     DATE,
    data_inicio        DATE,
    data_fim           DATE,
    preco_emissao      NUMERIC(12,4),
    quantidade_ofertada BIGINT,
    fator_proporcao    NUMERIC(10,6)
);

-- Proventos
CREATE TABLE market.provento (
    id_provento     BIGSERIAL PRIMARY KEY,
    id_ativo        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    tipo_provento   market.tipo_provento_enum NOT NULL,
    data_anuncio    DATE,
    data_com        DATE,
    data_ex         DATE,
    data_registro   DATE,
    data_pagamento  DATE,
    valor_por_acao  NUMERIC(12,6),
    moeda           VARCHAR(3) DEFAULT 'BRL',
    tipo_pagamento  VARCHAR(20),
    imposto         NUMERIC(5,2),
    observacao      TEXT,
    UNIQUE (id_ativo, tipo_provento, data_com, data_pagamento)
);
CREATE INDEX idx_provento_ativo_data ON market.provento(id_ativo, data_com);

CREATE TABLE market.calendario_proventos (
    id_calendario  BIGSERIAL PRIMARY KEY,
    id_ativo       INT NOT NULL,
    id_provento    BIGINT REFERENCES market.provento(id_provento) ON DELETE CASCADE,
    data_com       DATE,
    data_ex        DATE,
    data_pagamento DATE,
    valor_estimado NUMERIC(12,6),
    valor_confirmado NUMERIC(12,6),
    status         VARCHAR(20) CHECK (status IN ('Confirmado','Projetado','Pago'))
);

CREATE TABLE market.previsao_provento (
    id_previsao    BIGSERIAL PRIMARY KEY,
    id_ativo       INT NOT NULL,
    data_referencia DATE NOT NULL,
    valor_estimado_por_acao NUMERIC(12,6),
    metodo_projecao VARCHAR(30) CHECK (metodo_projecao IN ('Historico','Payout','Consenso')),
    confianca      VARCHAR(10) CHECK (confianca IN ('Alta','Media','Baixa'))
);

CREATE TABLE market.historico_provento_recebido (
    id_recebimento BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_provento    BIGINT NOT NULL REFERENCES market.provento(id_provento) ON DELETE RESTRICT,
    id_carteira    UUID REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    quantidade     NUMERIC(18,6),
    valor_bruto    NUMERIC(14,2),
    imposto        NUMERIC(10,2),
    valor_liquido  NUMERIC(14,2),
    data_credito   DATE,
    status         VARCHAR(20) CHECK (status IN ('PROVISIONADO','PAGO','RECEBIDO')),
    UNIQUE (id_usuario, id_provento, id_carteira)
);

CREATE TABLE market.antecipacao_dividendo (
    id_antecipacao  BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL,
    id_provento     BIGINT NOT NULL,
    valor_antecipado NUMERIC(14,2),
    taxa_desconto   NUMERIC(6,4),
    data_antecipacao DATE,
    data_recebimento_original DATE
);

-- Índices
CREATE TABLE market.indice (
    id_indice    SERIAL PRIMARY KEY,
    ticker_indice VARCHAR(12) UNIQUE,
    nome         VARCHAR(100),
    tipo         VARCHAR(50)
);

CREATE TABLE market.composicao_indice (
    id_composicao BIGSERIAL PRIMARY KEY,
    id_indice     INT NOT NULL REFERENCES market.indice(id_indice) ON DELETE CASCADE,
    id_ativo      INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    peso          NUMERIC(7,4),
    qtde_teorica  BIGINT,
    data_vigencia_inicio DATE,
    data_vigencia_fim    DATE
);

-- Macro e mercado
CREATE TABLE market.serie_macroeconomica (
    id_serie       BIGSERIAL,
    codigo_sgs     INT NOT NULL,
    nome           VARCHAR(150),
    fonte          VARCHAR(20) CHECK (fonte IN ('BCB','IBGE','IPEA','Outros')),
    periodicidade  VARCHAR(20),
    data_referencia DATE NOT NULL,
    valor          NUMERIC(18,6),
    unidade        VARCHAR(20),
    PRIMARY KEY (id_serie, data_referencia)
);
SELECT create_hypertable('market.serie_macroeconomica','data_referencia', chunk_time_interval => INTERVAL '5 years');

CREATE TABLE market.curva_juros (
    id_curva       BIGSERIAL,
    data_referencia DATE NOT NULL,
    tipo           VARCHAR(10) CHECK (tipo IN ('PRE','IPCA','DI')),
    vertice        INT,
    taxa           NUMERIC(10,6),
    PRIMARY KEY (id_curva, data_referencia)
);

CREATE TABLE market.cambio (
    id_cambio     BIGSERIAL,
    data_referencia DATE NOT NULL,
    moeda_origem  VARCHAR(3),
    moeda_destino VARCHAR(3),
    taxa_compra   NUMERIC(12,6),
    taxa_venda    NUMERIC(12,6),
    tipo          VARCHAR(15) CHECK (tipo IN ('PTAX','Fechamento','Intraday')),
    PRIMARY KEY (id_cambio, data_referencia)
);

CREATE TABLE market.commodity (
    id_commodity BIGSERIAL,
    data_referencia DATE NOT NULL,
    nome         VARCHAR(50),
    preco_spot   NUMERIC(18,6),
    preco_futuro NUMERIC(18,6),
    vencimento_futuro DATE,
    PRIMARY KEY (id_commodity, data_referencia)
);

CREATE TABLE market.estatistica_mercado (
    id_estatistica BIGSERIAL PRIMARY KEY,
    data_referencia DATE NOT NULL,
    tipo           VARCHAR(30),
    id_ativo       INT,
    valor          NUMERIC(18,6),
    posicao        INT
);

CREATE TABLE market.aluguel_acoes (
    id_aluguel      BIGSERIAL,
    id_ativo        INT NOT NULL,
    data            DATE NOT NULL,
    taxa_aluguel_media NUMERIC(8,4),
    contratos_abertos BIGINT,
    volume_alugado  NUMERIC(18,2),
    short_interest  NUMERIC(8,4),
    PRIMARY KEY (id_aluguel, data)
);
SELECT create_hypertable('market.aluguel_acoes','data', chunk_time_interval => INTERVAL '2 years');

CREATE TABLE market.calendario_economico (
    id_evento       BIGSERIAL PRIMARY KEY,
    data_hora       TIMESTAMPTZ NOT NULL,
    pais            VARCHAR(3),
    titulo          VARCHAR(150),
    importancia     VARCHAR(10) CHECK (importancia IN ('Alta','Media','Baixa')),
    valor_esperado  VARCHAR(50),
    valor_anterior  VARCHAR(50),
    valor_real      VARCHAR(50)
);

CREATE TABLE market.calendario_resultados (
    id_calendario  BIGSERIAL PRIMARY KEY,
    id_emissor     INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_prevista  DATE,
    data_confirmada DATE,
    periodo_referencia VARCHAR(10),
    tipo           VARCHAR(10) CHECK (tipo IN ('DFP','ITR','Release'))
);
