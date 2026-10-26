-- =========================================================
-- M9: asset_details.detalhe_fii (Adição de taxas e benchmarks)
-- Cobertura: Clube FII
-- =========================================================

ALTER TABLE asset_details.detalhe_fii
    ADD COLUMN IF NOT EXISTS management_fee        NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS performance_fee       NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS performance_benchmark  TEXT,
    ADD COLUMN IF NOT EXISTS taxa_total            NUMERIC(10,6);
