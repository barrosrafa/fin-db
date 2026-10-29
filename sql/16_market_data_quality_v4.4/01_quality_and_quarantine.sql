-- Estrutura aditiva para futura classificação de qualidade; não altera linhas existentes.
ALTER TABLE market.cotacao_diaria
    ADD COLUMN IF NOT EXISTS source_id TEXT,
    ADD COLUMN IF NOT EXISTS price_kind TEXT NOT NULL DEFAULT 'unverified',
    ADD COLUMN IF NOT EXISTS quality_status TEXT NOT NULL DEFAULT 'unverified',
    ADD COLUMN IF NOT EXISTS collected_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS calendar_version TEXT;

ALTER TABLE market.cotacao_intraday
    ADD COLUMN IF NOT EXISTS source_id TEXT,
    ADD COLUMN IF NOT EXISTS price_kind TEXT NOT NULL DEFAULT 'intraday_snapshot';

CREATE TABLE IF NOT EXISTS market.quote_quality_evidence (
    id_ativo INT NOT NULL REFERENCES core.ativo(id_ativo),
    data_pregao DATE NOT NULL,
    reason TEXT NOT NULL,
    original_row JSONB NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_ativo, data_pregao, reason)
);
