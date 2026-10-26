-- =========================================================
-- M7: canonical.institutional_holding
-- Cobertura: br.advfn.com (Posição de investidores institucionais por ativo)
-- =========================================================

CREATE TABLE IF NOT EXISTS canonical.institutional_holding (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id    UUID NOT NULL REFERENCES canonical.instrument(instrument_id) ON DELETE CASCADE,
    instituicao_id   UUID REFERENCES canonical.legal_entity(legal_entity_id),
    instituicao_nome TEXT NOT NULL,
    data_referencia  DATE NOT NULL,
    quantidade       NUMERIC(20,4) NOT NULL,
    participacao_pct NUMERIC(10,6),
    variacao_pct     NUMERIC(10,6),
    source           TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (instrument_id, instituicao_nome, data_referencia, source)
);

CREATE INDEX IF NOT EXISTS ix_inst_holding_inst_data
    ON canonical.institutional_holding (instrument_id, data_referencia DESC);
