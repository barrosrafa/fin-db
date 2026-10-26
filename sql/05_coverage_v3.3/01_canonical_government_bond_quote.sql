-- =========================================================
-- M1: canonical.government_bond_quote
-- Cobertura: Status Invest (Cotações e taxas do Tesouro Direto)
-- =========================================================

CREATE TABLE IF NOT EXISTS canonical.government_bond_quote (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    government_bond_id  UUID NOT NULL REFERENCES canonical.government_bond(instrument_id) ON DELETE CASCADE,
    quote_date          DATE NOT NULL,
    buy_rate            NUMERIC(12,6),
    sell_rate           NUMERIC(12,6),
    buy_price           NUMERIC(18,6),
    sell_price          NUMERIC(18,6),
    duration_years      NUMERIC(8,4),
    source              TEXT NOT NULL,
    raw_payload_id      UUID REFERENCES raw.payload(payload_id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (government_bond_id, quote_date, source)
);

CREATE INDEX IF NOT EXISTS ix_gbq_bond_date
    ON canonical.government_bond_quote (government_bond_id, quote_date DESC);
