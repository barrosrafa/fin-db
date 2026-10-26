-- =========================================================
-- SCHEMA dw
-- =========================================================
CREATE TABLE dw.historico_posicao (
    id_carteira   UUID NOT NULL,
    data_snapshot DATE NOT NULL,
    id_ativo      INT NOT NULL,
    quantidade    NUMERIC(18,6),
    preco_medio   NUMERIC(12,4),
    preco_fechamento NUMERIC(12,4),
    valor_mercado NUMERIC(18,2),
    PRIMARY KEY (id_carteira, data_snapshot, id_ativo)
);
SELECT create_hypertable('dw.historico_posicao','data_snapshot', chunk_time_interval => INTERVAL '1 year');

CREATE TABLE dw.historico_carteira (
    id_carteira   UUID NOT NULL,
    data_snapshot DATE NOT NULL,
    valor_total   NUMERIC(18,2),
    rentabilidade_dia NUMERIC(8,4),
    rentabilidade_mes NUMERIC(8,4),
    rentabilidade_ano NUMERIC(8,4),
    PRIMARY KEY (id_carteira, data_snapshot)
);
SELECT create_hypertable('dw.historico_carteira','data_snapshot', chunk_time_interval => INTERVAL '1 year');

CREATE TABLE dw.historico_patrimonio (
    id_usuario    UUID NOT NULL,
    data_snapshot DATE NOT NULL,
    total_ativos  NUMERIC(18,2),
    total_passivos NUMERIC(18,2),
    patrimonio_liquido NUMERIC(18,2),
    PRIMARY KEY (id_usuario, data_snapshot)
);
SELECT create_hypertable('dw.historico_patrimonio','data_snapshot', chunk_time_interval => INTERVAL '1 year');

CREATE TABLE dw.historico_rentabilidade (
    id_carteira   UUID NOT NULL,
    data_snapshot DATE NOT NULL,
    twr           NUMERIC(10,6),
    cotizacao     NUMERIC(18,8),
    benchmark     VARCHAR(20),
    excesso       NUMERIC(10,6),
    PRIMARY KEY (id_carteira, data_snapshot)
);
SELECT create_hypertable('dw.historico_rentabilidade','data_snapshot', chunk_time_interval => INTERVAL '1 year');

CREATE TABLE dw.historico_provento (
    id_usuario    UUID NOT NULL,
    mes_referencia DATE NOT NULL,
    id_ativo      INT NOT NULL,
    valor_total   NUMERIC(14,2),
    PRIMARY KEY (id_usuario, mes_referencia, id_ativo)
);

CREATE TABLE dw.historico_ir (
    id_usuario    UUID NOT NULL,
    ano_referencia INT NOT NULL,
    imposto_pago  NUMERIC(14,2),
    prejuizo_compensado NUMERIC(14,2),
    PRIMARY KEY (id_usuario, ano_referencia)
);

CREATE TABLE dw.ranking (
    data_referencia DATE NOT NULL,
    tipo_ranking    VARCHAR(30) NOT NULL,
    id_ativo        INT NOT NULL,
    valor           NUMERIC(18,6),
    posicao         INT,
    PRIMARY KEY (data_referencia, tipo_ranking, id_ativo)
);
SELECT create_hypertable('dw.ranking','data_referencia', chunk_time_interval => INTERVAL '1 year');

CREATE TABLE dw.historico_indicador (
    id_ativo        INT NOT NULL,
    data_referencia DATE NOT NULL,
    tipo_indicador  VARCHAR(30) NOT NULL,
    valor           NUMERIC(18,6),
    PRIMARY KEY (id_ativo, data_referencia, tipo_indicador)
);
SELECT create_hypertable('dw.historico_indicador','data_referencia', chunk_time_interval => INTERVAL '2 years');
