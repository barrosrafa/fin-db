-- =========================================================
-- SCHEMA system
-- =========================================================
CREATE TABLE system.plano (
    id_plano      SERIAL PRIMARY KEY,
    nome          VARCHAR(30) UNIQUE,
    preco         NUMERIC(10,2),
    funcionalidades_json JSONB
);

CREATE TABLE system.assinatura (
    id_assinatura BIGSERIAL PRIMARY KEY,
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_plano      INT NOT NULL REFERENCES system.plano(id_plano),
    status        VARCHAR(20),
    data_renovacao DATE,
    trial_ativo   BOOLEAN DEFAULT FALSE,
    data_criacao  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE system.pagamento (
    id_pagamento  BIGSERIAL PRIMARY KEY,
    id_assinatura BIGINT NOT NULL REFERENCES system.assinatura(id_assinatura) ON DELETE CASCADE,
    gateway       VARCHAR(30),
    transaction_id VARCHAR(80),
    valor         NUMERIC(10,2),
    status        VARCHAR(20),
    data_pagamento TIMESTAMP
);

CREATE TABLE system.fatura (
    id_fatura     BIGSERIAL PRIMARY KEY,
    id_assinatura BIGINT NOT NULL REFERENCES system.assinatura(id_assinatura) ON DELETE CASCADE,
    url_pdf       TEXT,
    cupom_desconto VARCHAR(30),
    data_emissao  DATE,
    data_vencimento DATE,
    valor         NUMERIC(10,2)
);

CREATE TABLE system.feature_flag (
    id_feature    SERIAL PRIMARY KEY,
    nome          VARCHAR(50) UNIQUE,
    descricao     TEXT,
    id_plano_minimo INT REFERENCES system.plano(id_plano),
    ativo         BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.uso_api (
    id_uso        BIGSERIAL,
    id_usuario    UUID,
    endpoint      VARCHAR(150),
    data_hora     TIMESTAMPTZ NOT NULL,
    status_code   INT,
    tempo_resposta_ms INT
);
SELECT create_hypertable('system.uso_api','data_hora', chunk_time_interval => INTERVAL '1 month');

CREATE TABLE system.configuracao_usuario (
    id_usuario    UUID PRIMARY KEY REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tema          VARCHAR(20),
    idioma        VARCHAR(10),
    moeda_preferida VARCHAR(3),
    coluna_personalizada JSONB,
    alertas_ativos BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.alerta (
    id_alerta     BIGSERIAL PRIMARY KEY,
    id_usuario    UUID NOT NULL,
    id_ativo      INT,
    tipo          VARCHAR(30),
    parametro_json JSONB,
    ativo         BOOLEAN DEFAULT TRUE,
    data_criacao  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE system.notificacao (
    id_notificacao BIGSERIAL PRIMARY KEY,
    id_alerta      BIGINT REFERENCES system.alerta(id_alerta) ON DELETE CASCADE,
    id_usuario     UUID NOT NULL,
    canal          VARCHAR(20),
    mensagem       TEXT,
    enviado        BOOLEAN DEFAULT FALSE,
    data_envio     TIMESTAMP
);

CREATE TABLE system.exportacao (
    id_exportacao BIGSERIAL PRIMARY KEY,
    id_usuario    UUID NOT NULL,
    arquivo       TEXT,
    formato       VARCHAR(10) CHECK (formato IN ('CSV','PDF','XLSX')),
    data          TIMESTAMP DEFAULT NOW()
);

CREATE TABLE system.role (
    id_role  SERIAL PRIMARY KEY,
    nome     VARCHAR(30) UNIQUE
);

CREATE TABLE system.permissao (
    id_permissao SERIAL PRIMARY KEY,
    nome         VARCHAR(50) UNIQUE
);

CREATE TABLE system.usuario_role (
    id_usuario UUID NOT NULL,
    id_role    INT NOT NULL,
    PRIMARY KEY (id_usuario, id_role)
);

CREATE TABLE system.sessao (
    id_sessao  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    criada_em  TIMESTAMP DEFAULT NOW(),
    expira_em  TIMESTAMP,
    ip         INET,
    user_agent TEXT
);

CREATE TABLE system.token (
    id_token   BIGSERIAL PRIMARY KEY,
    id_usuario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    hash_token VARCHAR(64) UNIQUE,
    escopos    TEXT,
    expira_em  TIMESTAMP
);

CREATE TABLE system.auditoria_log (
    id_log     BIGSERIAL,
    data_hora  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_usuario UUID,
    operacao   VARCHAR(20),
    tabela     VARCHAR(60),
    registro_id TEXT,
    old_value  JSONB,
    new_value  JSONB
);
SELECT create_hypertable('system.auditoria_log','data_hora', chunk_time_interval => INTERVAL '1 month');

CREATE TABLE system.log_acesso (
    id_log    BIGSERIAL,
    id_usuario UUID,
    data_hora TIMESTAMPTZ NOT NULL,
    ip        INET,
    user_agent TEXT,
    sucesso   BOOLEAN
);
SELECT create_hypertable('system.log_acesso','data_hora', chunk_time_interval => INTERVAL '1 month');

CREATE TABLE system.log_alteracao (
    id_log    BIGSERIAL,
    data_hora TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tabela    VARCHAR(60),
    registro_id TEXT,
    operacao  VARCHAR(10),
    diff      JSONB
);

CREATE TABLE system.finalidade_consentimento (
    id_finalidade SERIAL PRIMARY KEY,
    nome          VARCHAR(80) UNIQUE
);

CREATE TABLE system.consentimento_lgpd (
    id_consentimento BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_finalidade  INT NOT NULL REFERENCES system.finalidade_consentimento(id_finalidade),
    data_concessao TIMESTAMP DEFAULT NOW(),
    status         VARCHAR(20) DEFAULT 'Ativo'
);

CREATE TABLE system.revogacao_consentimento (
    id_revogacao   BIGSERIAL PRIMARY KEY,
    id_consentimento BIGINT NOT NULL REFERENCES system.consentimento_lgpd(id_consentimento) ON DELETE CASCADE,
    data_revogacao TIMESTAMP DEFAULT NOW(),
    motivo         TEXT
);
