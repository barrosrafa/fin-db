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
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.envio_campanha', INTERVAL '730 days');
