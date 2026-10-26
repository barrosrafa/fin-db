-- =========================================================
-- BLOCO 3: ANTI-FRAUDE E SEGURANÇA
-- =========================================================

-- 3.1 Device fingerprint (reconhecer dispositivos)
CREATE TABLE system.device_fingerprint (
    id_fingerprint    BIGSERIAL PRIMARY KEY,
    id_usuario        UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    fingerprint_hash  VARCHAR(64) NOT NULL,
    user_agent        TEXT,
    ip_primeiro_uso   INET,
    geo_pais          VARCHAR(3),
    geo_cidade        VARCHAR(100),
    primeiro_uso      TIMESTAMPTZ DEFAULT NOW(),
    ultimo_uso        TIMESTAMPTZ DEFAULT NOW(),
    confiavel         BOOLEAN DEFAULT FALSE,
    UNIQUE (id_usuario, fingerprint_hash)
);
CREATE INDEX idx_device_fp_user ON system.device_fingerprint(id_usuario, confiavel);

-- 3.2 Eventos de segurança (login suspeito, novo device, etc.)
CREATE TABLE system.evento_seguranca (
    id_evento      BIGSERIAL,
    id_usuario     UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    tipo           VARCHAR(40) NOT NULL
        CHECK (tipo IN ('LOGIN_SUSPEITO','NOVO_DISPOSITIVO','MUDANCA_SENHA',
                        'MUDANCA_EMAIL','ACESSO_NEGADO','BLOQUEIO_CONTA',
                        'TENTATIVA_MFA_FALHA','SESSAO_EXPIRADA')),
    severidade     VARCHAR(10) CHECK (severidade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    detalhes_json  JSONB,
    ip             INET,
    user_agent     TEXT,
    data           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolvido      BOOLEAN DEFAULT FALSE,
    data_resolucao TIMESTAMPTZ
);
SELECT create_hypertable('system.evento_seguranca','data', chunk_time_interval => INTERVAL '1 month');
CREATE INDEX idx_evento_seg_user ON system.evento_seguranca(id_usuario, data DESC);
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.evento_seguranca', INTERVAL '730 days');

-- 3.3 IPs bloqueados
CREATE TABLE system.ip_bloqueado (
    id_ip            BIGSERIAL PRIMARY KEY,
    ip               INET NOT NULL,
    motivo           VARCHAR(100),
    data_bloqueio    TIMESTAMPTZ DEFAULT NOW(),
    data_desbloqueio TIMESTAMPTZ,
    permanente       BOOLEAN DEFAULT FALSE,
    UNIQUE (ip)
);
CREATE INDEX idx_ip_bloq_ativo ON system.ip_bloqueado(ip) WHERE data_desbloqueio IS NULL;

-- 3.4 Rate limiting persistente
CREATE TABLE system.rate_limit (
    chave             VARCHAR(150) NOT NULL,
    endpoint          VARCHAR(150) NOT NULL,
    janela_inicio     TIMESTAMPTZ NOT NULL,
    contador          INT NOT NULL DEFAULT 0,
    PRIMARY KEY (chave, endpoint, janela_inicio)
);
SELECT create_hypertable('system.rate_limit','janela_inicio', chunk_time_interval => INTERVAL '1 day');
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.rate_limit', INTERVAL '7 days');
