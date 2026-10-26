-- =========================================================
-- M11: canonical.fund_holding (Suporte ETF) & asset_details.etf_composicao
-- Cobertura: etfsbrasil.com.br (Composição de carteiras de ETFs sem duplicação)
-- =========================================================

-- Suporte a referência explícita de ETF em fund_holding
ALTER TABLE canonical.fund_holding
    ADD COLUMN IF NOT EXISTS etf_instrument_id UUID REFERENCES canonical.instrument(instrument_id);

CREATE INDEX IF NOT EXISTS ix_fund_holding_etf
    ON canonical.fund_holding (etf_instrument_id, reference_date DESC);

-- View analítica para comparadores e consultas de carteira de ETFs
CREATE OR REPLACE VIEW asset_details.etf_composicao AS
SELECT
    fh.etf_instrument_id      AS instrument_id,
    fh.reference_date         AS data_referencia,
    fh.holding_instrument_id  AS ativo_id,
    fh.holding_name           AS ativo_descricao,
    fh.weight                 AS percentual,
    fh.quantity               AS quantidade
FROM canonical.fund_holding fh
WHERE fh.etf_instrument_id IS NOT NULL;
