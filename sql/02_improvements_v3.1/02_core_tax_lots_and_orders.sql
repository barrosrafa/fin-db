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
