-- =========================================================
-- M2: asset_details.mercado_imobiliario_indicador
-- Cobertura: Clube FII (Indicadores imobiliários por praça/região)
-- =========================================================

CREATE TABLE IF NOT EXISTS asset_details.mercado_imobiliario_indicador (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uf              CHAR(2) NOT NULL,
    cidade          TEXT NOT NULL,
    regiao          TEXT,
    tipo_imovel     TEXT NOT NULL CHECK (tipo_imovel IN ('residencial','comercial','logistico','rural','outro')),
    data_referencia DATE NOT NULL,
    preco_m2        NUMERIC(18,2),
    variacao_12m    NUMERIC(10,6),
    transacoes      INTEGER,
    source          TEXT NOT NULL,
    raw_payload_id  UUID REFERENCES raw.payload(payload_id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice único tratando valores nulos de região com COALESCE (compatível PostgreSQL)
CREATE UNIQUE INDEX IF NOT EXISTS ix_mii_unique
    ON asset_details.mercado_imobiliario_indicador (uf, cidade, COALESCE(regiao, ''), tipo_imovel, data_referencia, source);

CREATE INDEX IF NOT EXISTS ix_mii_uf_cidade_tipo
    ON asset_details.mercado_imobiliario_indicador (uf, cidade, tipo_imovel, data_referencia DESC);
