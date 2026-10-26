-- =========================================================
-- M4: analytics.valuation
-- Cobertura: analisedeacoes.com (Preço justo por metodologia e margem de segurança)
-- =========================================================

CREATE TABLE IF NOT EXISTS analytics.valuation (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id    UUID NOT NULL REFERENCES canonical.instrument(instrument_id) ON DELETE CASCADE,
    data_referencia  DATE NOT NULL,
    metodologia      TEXT NOT NULL,
    parametros       JSONB NOT NULL DEFAULT '{}'::jsonb,
    preco_justo      NUMERIC(18,6) NOT NULL,
    preco_mercado    NUMERIC(18,6),
    margem_seguranca NUMERIC(10,6),
    source           TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (instrument_id, data_referencia, metodologia, source)
);

CREATE INDEX IF NOT EXISTS ix_valuation_instrument_data
    ON analytics.valuation (instrument_id, data_referencia DESC);
