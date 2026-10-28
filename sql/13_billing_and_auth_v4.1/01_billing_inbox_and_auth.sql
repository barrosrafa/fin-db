-- =========================================================
-- 13. BILLING INBOX & AUTH CREDENTIALS EXTENSION
-- =========================================================

CREATE SCHEMA IF NOT EXISTS billing;

-- 1. Tabela de Inbox de Webhooks para Idempotência Estrita
CREATE TABLE IF NOT EXISTS billing.webhook_inbox (
    event_id         VARCHAR(120) PRIMARY KEY,
    gateway_provider VARCHAR(50) NOT NULL,
    event_type       VARCHAR(100) NOT NULL,
    payload          JSONB NOT NULL,
    status           VARCHAR(30) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSED', 'FAILED')),
    error_message    TEXT,
    received_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_webhook_inbox_status_recv 
    ON billing.webhook_inbox(status, received_at DESC);

-- 2. Suporte a credenciais de autenticação direta em core.usuario
ALTER TABLE core.usuario ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE core.usuario ADD COLUMN IF NOT EXISTS salt VARCHAR(64);
ALTER TABLE core.usuario ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_usuario_email_lookup ON core.usuario(email);
