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
