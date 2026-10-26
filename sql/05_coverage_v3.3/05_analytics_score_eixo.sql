-- =========================================================
-- M5: analytics.score_eixo
-- Cobertura: brick360.com.br (Decomposição do score em eixos qualitativos/quantitativos)
-- =========================================================

CREATE TABLE IF NOT EXISTS analytics.score_eixo (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    score_ativo_id BIGINT NOT NULL REFERENCES analytics.score_ativo(id_score) ON DELETE CASCADE,
    eixo           TEXT NOT NULL CHECK (eixo IN (
                      'financeiro','imoveis','inquilinos','gestores','riscos','projecoes','outro')),
    pontuacao      NUMERIC(10,4) NOT NULL,
    peso           NUMERIC(6,4),
    detalhes       JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (score_ativo_id, eixo)
);

CREATE INDEX IF NOT EXISTS ix_score_eixo_ativo ON analytics.score_eixo (score_ativo_id);
