-- ==============================================================================
-- Migration: 01_fundamentus_market_and_indicators.sql
-- Ecossistema: fin-db (PostgreSQL 18 / TimescaleDB no Neon Serverless)
-- Versão: 3.7 (Cobertura Completa Fundamentus, Séries Temporais e Bancos)
-- Idempotente: Execução segura com IF NOT EXISTS e ADD COLUMN IF NOT EXISTS
-- ==============================================================================

-- 1. Extensões no Cadastro de Ativos (core.ativo)
ALTER TABLE core.ativo
    ADD COLUMN IF NOT EXISTS classe_acao VARCHAR(10),
    ADD COLUMN IF NOT EXISTS min_52_semanas NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS max_52_semanas NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS volume_medio_2m NUMERIC(18, 2);

COMMENT ON COLUMN core.ativo.classe_acao IS 'Classe específica da ação B3 (ON, PN, PNA, PNB, UNT)';
COMMENT ON COLUMN core.ativo.min_52_semanas IS 'Menor cotação registrada nas últimas 52 semanas de negociação (252 pregões)';
COMMENT ON COLUMN core.ativo.max_52_semanas IS 'Maior cotação registrada nas últimas 52 semanas de negociação (252 pregões)';
COMMENT ON COLUMN core.ativo.volume_medio_2m IS 'Volume financeiro médio diário nos últimos 2 meses (~42 pregões úteis)';

-- 2. Tabela de Oscilações Históricas por Janela (market.oscilacao_ativo)
CREATE TABLE IF NOT EXISTS market.oscilacao_ativo (
    id_ativo                INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia         DATE NOT NULL,
    variacao_dia            NUMERIC(8, 4),
    variacao_mes            NUMERIC(8, 4),
    variacao_30_dias        NUMERIC(8, 4),
    variacao_12_meses       NUMERIC(8, 4),
    variacao_ano_atual      NUMERIC(8, 4),
    historico_anos_json     JSONB, -- Ex.: {"2025": 0.6240, "2024": -0.0380, "2023": 0.4106}
    atualizado_em           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_ativo, data_referencia)
);

CREATE INDEX IF NOT EXISTS idx_oscilacao_ativo_ref
    ON market.oscilacao_ativo(id_ativo, data_referencia DESC);

-- 3. Snapshot de Demonstrativo Financeiro LTM (12m) vs. 3M (analytics.demonstrativo_snapshot_fundamentus)
CREATE TABLE IF NOT EXISTS analytics.demonstrativo_snapshot_fundamentus (
    id_snapshot             BIGSERIAL PRIMARY KEY,
    id_emissor              INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_balanco_processado DATE NOT NULL,
    is_instituicao_financeira BOOLEAN DEFAULT FALSE,

    -- Dados de Balanço Patrimonial (Snapshot mais recente)
    ativo_total             NUMERIC(20, 2),
    disponibilidades        NUMERIC(20, 2),
    ativo_circulante        NUMERIC(20, 2),
    divida_bruta            NUMERIC(20, 2),
    divida_liquida          NUMERIC(20, 2),
    patrimonio_liquido      NUMERIC(20, 2),
    carteira_credito        NUMERIC(20, 2), -- Exclusivo para Instituições Financeiras
    depositos_totais        NUMERIC(20, 2), -- Exclusivo para Instituições Financeiras

    -- DRE: Últimos 12 Meses (LTM / TTM)
    receita_liquida_12m     NUMERIC(20, 2),
    ebit_12m                NUMERIC(20, 2),
    lucro_liquido_12m       NUMERIC(20, 2),
    resultado_intermediacao_12m NUMERIC(20, 2), -- Exclusivo para Instituições Financeiras
    receita_servicos_12m    NUMERIC(20, 2), -- Exclusivo para Instituições Financeiras

    -- DRE: Últimos 3 Meses (Trimestre Isolado)
    receita_liquida_3m      NUMERIC(20, 2),
    ebit_3m                 NUMERIC(20, 2),
    lucro_liquido_3m        NUMERIC(20, 2),
    resultado_intermediacao_3m  NUMERIC(20, 2), -- Exclusivo para Instituições Financeiras
    receita_servicos_3m     NUMERIC(20, 2), -- Exclusivo para Instituições Financeiras

    capturado_em            TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_emissor, data_balanco_processado)
);

CREATE INDEX IF NOT EXISTS idx_dem_snap_emissor
    ON analytics.demonstrativo_snapshot_fundamentus(id_emissor, data_balanco_processado DESC);

-- 4. Índice Trigram para Busca Fuzzy Instantânea no Screener
CREATE INDEX IF NOT EXISTS idx_ativo_ticker_trgm
    ON core.ativo USING GIN (ticker gin_trgm_ops);

-- 5. Registro Canônico de Novas Métricas de Intermediação Financeira












                                      ;
