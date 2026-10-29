-- Additive, idempotent migration. Does not remove or replace original price rows.
BEGIN;
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
-- Keep evidence before changing only its quality classification. No guessed source or price.
INSERT INTO market.quote_quality_evidence (id_ativo, data_pregao, reason, original_row)
SELECT cd.id_ativo, cd.data_pregao, 'B3_WEEKEND_REQUIRES_OFFICIAL_CALENDAR', to_jsonb(cd)
FROM market.cotacao_diaria cd JOIN core.ativo a USING (id_ativo)
WHERE a.tipo_ativo IN ('ACAO', 'FII', 'ETF', 'BDR', 'FI_INFRA')
  AND EXTRACT(ISODOW FROM cd.data_pregao) IN (6, 7)
ON CONFLICT DO NOTHING;
UPDATE market.cotacao_diaria cd SET quality_status = 'quarantined'
WHERE EXISTS (
    SELECT 1 FROM market.quote_quality_evidence e
    WHERE e.id_ativo = cd.id_ativo AND e.data_pregao = cd.data_pregao
      AND e.reason = 'B3_WEEKEND_REQUIRES_OFFICIAL_CALENDAR'
) AND cd.quality_status = 'unverified';
COMMIT;
-- Rollback: retain the additive columns/evidence, revert the reader separately.
-- Do not promote unverified records to official closing prices without primary evidence.
