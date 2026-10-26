-- =========================================================
-- M8: canonical.fund_profile (Adição de taxas e benchmarks)
-- Cobertura: Status Invest (FI-Infra, FIAGRO, Fundos Mútuos)
-- =========================================================

ALTER TABLE canonical.fund_profile
    ADD COLUMN IF NOT EXISTS benchmark             TEXT,
    ADD COLUMN IF NOT EXISTS management_fee        NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS performance_fee       NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS performance_benchmark  TEXT;
