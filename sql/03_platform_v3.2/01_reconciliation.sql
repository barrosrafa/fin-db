-- =========================================================
-- BLOCO 1: RECONCILIAÇÃO
-- =========================================================

-- 1.1 Reconciliação bancária (Open Finance vs. cadastro manual)
CREATE TABLE wealth.reconciliacao_bancaria (
    id_reconciliacao   BIGSERIAL PRIMARY KEY,
    id_usuario         UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_conta           BIGINT REFERENCES wealth.conta_bancaria(id_conta) ON DELETE CASCADE,
    data               DATE NOT NULL,
    saldo_extrato      NUMERIC(18,2),
    saldo_sistema      NUMERIC(18,2),
    divergencia        NUMERIC(18,2) GENERATED ALWAYS AS (saldo_extrato - saldo_sistema) STORED,
    status             VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','OK','AJUSTADA','IGNORADA')),
    observacao         TEXT,
    data_criacao       TIMESTAMPTZ DEFAULT NOW(),
    data_resolucao     TIMESTAMPTZ,
    UNIQUE (id_usuario, id_conta, data)
);
CREATE INDEX idx_recon_banc_status ON wealth.reconciliacao_bancaria(status, data DESC);

-- 1.2 Reconciliação de custódia (B3 vs. sistema)
CREATE TABLE core.reconciliacao_custodia (
    id_reconciliacao   BIGSERIAL PRIMARY KEY,
    id_carteira        UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo           INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    data               DATE NOT NULL,
    quantidade_externa NUMERIC(18,6),
    quantidade_sistema NUMERIC(18,6),
    divergencia        NUMERIC(18,6) GENERATED ALWAYS AS (quantidade_externa - quantidade_sistema) STORED,
    fonte_externa      VARCHAR(30) CHECK (fonte_externa IN ('B3','CORRETORA','OPEN_FINANCE','MANUAL')),
    status             VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','OK','AJUSTADA','IGNORADA')),
    data_criacao       TIMESTAMPTZ DEFAULT NOW(),
    data_resolucao     TIMESTAMPTZ,
    UNIQUE (id_carteira, id_ativo, data, fonte_externa)
);
CREATE INDEX idx_recon_cust_status ON core.reconciliacao_custodia(status, data DESC);

-- 1.3 Ajustes manuais (com auditoria)
CREATE TABLE core.ajuste_manual (
    id_ajuste          BIGSERIAL PRIMARY KEY,
    id_usuario         UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_carteira        UUID REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo           INT REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    entidade           VARCHAR(50) NOT NULL,
    entidade_id        TEXT,
    tipo               VARCHAR(30) CHECK (tipo IN ('QUANTIDADE','PRECO','PROVENTO','DATA','OUTRO')),
    valor_anterior     JSONB,
    valor_novo         JSONB,
    motivo             TEXT NOT NULL,
    data_ajuste        TIMESTAMPTZ DEFAULT NOW(),
    ip                 INET
);
CREATE INDEX idx_ajuste_manual_user ON core.ajuste_manual(id_usuario, data_ajuste DESC);
