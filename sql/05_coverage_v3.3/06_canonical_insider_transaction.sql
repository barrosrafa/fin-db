-- =========================================================
-- M6: canonical.insider_transaction
-- Cobertura: br.advfn.com (Transações de diretores/controladores no modelo canônico)
-- =========================================================

CREATE TABLE IF NOT EXISTS canonical.insider_transaction (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id   UUID NOT NULL REFERENCES canonical.instrument(instrument_id) ON DELETE CASCADE,
    pessoa_nome     TEXT NOT NULL,
    cargo           TEXT,
    tipo            TEXT NOT NULL CHECK (tipo IN ('compra','venda','opcao','doacao','outro')),
    quantidade      NUMERIC(20,4) NOT NULL,
    preco_unitario  NUMERIC(18,6),
    data_negocio    DATE NOT NULL,
    fonte_documento TEXT,
    source          TEXT NOT NULL,
    raw_payload_id  UUID REFERENCES raw.payload(payload_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (instrument_id, pessoa_nome, data_negocio, tipo, quantidade, source)
);

CREATE INDEX IF NOT EXISTS ix_insider_instrument_data
    ON canonical.insider_transaction (instrument_id, data_negocio DESC);
