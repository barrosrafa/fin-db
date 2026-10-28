-- ============================================================================
-- MIGRATION 10: OCEANS14 COVERAGE V3.8
-- Schemas: market, analytics, asset_details
-- Objectives: 
--   1. Historical P/E Corridor of Ibovespa (market.historico_pl_indice)
--   2. B3 Investor Flows (market.fluxo_investidor_b3)
--   3. Earnings and Dividend Calendars (market.agenda_resultados)
--   4. Macroeconomic Credit & Public Accounts (market.contas_publicas_governo, market.credito_sistema_financeiro)
--   5. 10-Year Canonical Matrix Financial Statements (analytics.demonstrativo_padronizado_serie)
--   6. Real Estate FII Vacancy History (asset_details.fii_historico_vacancia)
--   7. Consistency Screener ("Sem Prejuízo") Materialized View (analytics.mv_acoes_consistencia_lucro)
-- ============================================================================

-- 1. IBOVESPA HISTORICAL P/E (VALUATION CORRIDOR)
CREATE TABLE IF NOT EXISTS market.historico_pl_indice (
    id_pl_indice         BIGSERIAL,
    data_referencia      DATE NOT NULL,
    codigo_indice        VARCHAR(10) NOT NULL DEFAULT 'IBOV',
    fechamento_indice    NUMERIC(14,2) NOT NULL,
    pl_ponderado         NUMERIC(8,2) NOT NULL, -- P/L ponderado pelo Market Cap
    pl_mediano           NUMERIC(8,2) NOT NULL,
    pl_medio_aritmetico  NUMERIC(8,2) NOT NULL,
    lucro_projetado_fwd  NUMERIC(8,2),         -- P/L Projetado 12M
    media_historica_5y   NUMERIC(8,2) NOT NULL,
    desvio_padrao_5y     NUMERIC(8,2) NOT NULL,
    banda_superior_1dp   NUMERIC(8,2) NOT NULL,
    banda_inferior_1dp   NUMERIC(8,2) NOT NULL,
    banda_superior_2dp   NUMERIC(8,2) NOT NULL,
    banda_inferior_2dp   NUMERIC(8,2) NOT NULL,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (codigo_indice, data_referencia)
);
DO $$
BEGIN
    PERFORM create_hypertable('market.historico_pl_indice', 'data_referencia', if_not_exists => TRUE);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Hypertable already exists or timescaledb notice: %', SQLERRM;
END $$;
CREATE INDEX IF NOT EXISTS idx_hist_pl_indice_dt ON market.historico_pl_indice (data_referencia DESC);

-- 2. B3 INVESTOR FLOWS (CAPTAÇÃO / PARTICIPAÇÃO DE INVESTIDORES)
CREATE TABLE IF NOT EXISTS market.fluxo_investidor_b3 (
    id_fluxo             BIGSERIAL,
    data_pregao          DATE NOT NULL,
    categoria_investidor VARCHAR(40) NOT NULL CHECK (categoria_investidor IN (
        'ESTRANGEIRO', 
        'INSTITUCIONAL', 
        'PESSOA_FISICA', 
        'INSTITUICAO_FINANCEIRA', 
        'EMPRESAS_PUBLICAS_PRIVADAS', 
        'OUTROS'
    )),
    compras_reais        NUMERIC(18,2) NOT NULL,
    vendas_reais         NUMERIC(18,2) NOT NULL,
    saldo_liquido        NUMERIC(18,2) GENERATED ALWAYS AS (compras_reais - vendas_reais) STORED,
    saldo_acumulado_mes  NUMERIC(18,2),
    saldo_acumulado_ano  NUMERIC(18,2),
    participacao_pct     NUMERIC(6,3),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (data_pregao, categoria_investidor)
);
DO $$
BEGIN
    PERFORM create_hypertable('market.fluxo_investidor_b3', 'data_pregao', if_not_exists => TRUE);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Hypertable already exists or timescaledb notice: %', SQLERRM;
END $$;
CREATE INDEX IF NOT EXISTS idx_fluxo_inv_b3_cat_dt ON market.fluxo_investidor_b3 (categoria_investidor, data_pregao DESC);

-- 3. AGENDA DE DIVULGAÇÃO DE RESULTADOS (CVM DFP / ITR)
CREATE TABLE IF NOT EXISTS market.agenda_resultados (
    id_agenda            BIGSERIAL PRIMARY KEY,
    id_emissor           INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    ticker_referencia    VARCHAR(12) NOT NULL,
    periodo_referencia   VARCHAR(10) NOT NULL, -- Ex: '4T2025', '1T2026'
    tipo_documento       VARCHAR(10) NOT NULL CHECK (tipo_documento IN ('ITR', 'DFP')),
    data_prevista        DATE NOT NULL,
    horario_previsto     VARCHAR(20) CHECK (horario_previsto IN ('ANTES_ABERTURA', 'APOS_FECHAMENTO', 'DURANTE_PREGAO', 'INDEFINIDO')),
    data_efetiva         DATE,
    status               VARCHAR(20) DEFAULT 'CONFIRMADO' CHECK (status IN ('PREVISTO', 'CONFIRMADO', 'POSTERGADO', 'REALIZADO')),
    link_webcast         TEXT,
    link_documento_cvm   TEXT,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_emissor, periodo_referencia)
);
CREATE INDEX IF NOT EXISTS idx_agenda_res_dt ON market.agenda_resultados (data_prevista ASC, status);

-- 4. CONTAS PÚBLICAS DO GOVERNO (TESOURO NACIONAL / BACEN)
CREATE TABLE IF NOT EXISTS market.contas_publicas_governo (
    id_registro          BIGSERIAL,
    data_referencia      DATE NOT NULL, -- Mensal
    receita_total_bruta  NUMERIC(18,2),
    transferencias_estados_mun NUMERIC(18,2),
    receita_liquida      NUMERIC(18,2) NOT NULL,
    despesa_previdencia  NUMERIC(18,2),
    despesa_pessoal      NUMERIC(18,2),
    despesas_outras_custeio NUMERIC(18,2),
    despesa_total        NUMERIC(18,2) NOT NULL,
    resultado_primario   NUMERIC(18,2) GENERATED ALWAYS AS (receita_liquida - despesa_total) STORED,
    resultado_nominal    NUMERIC(18,2),
    divida_bruta_pib_pct NUMERIC(6,2),
    divida_liquida_pib_pct NUMERIC(6,2),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (data_referencia)
);

-- 5. CRÉDITO DO SISTEMA FINANCEIRO, POUPANÇA E TAXA DE CÂMBIO REAL (BACEN SGS)
CREATE TABLE IF NOT EXISTS market.credito_sistema_financeiro (
    id_registro          BIGSERIAL,
    data_referencia      DATE NOT NULL, -- Mensal
    poupanca_captacao_liquida NUMERIC(18,2),
    poupanca_saldo_total      NUMERIC(18,2),
    inadimplencia_pf_pct      NUMERIC(6,2),
    inadimplencia_pj_pct      NUMERIC(6,2),
    inadimplencia_total_pct   NUMERIC(6,2),
    estoque_credito_pj        NUMERIC(18,2),
    estoque_credito_pf        NUMERIC(18,2),
    concessao_imobiliario_pf  NUMERIC(18,2),
    tcr_efetiva_indice        NUMERIC(10,4),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (data_referencia)
);

-- 6. MATRIZ CONTÁBIL PADRONIZADA DE 10+ ANOS (DRE / BP / DFC NORMALIZADOS)
CREATE TABLE IF NOT EXISTS analytics.demonstrativo_padronizado_serie (
    id_serie_contabil    BIGSERIAL PRIMARY KEY,
    id_emissor           INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    ano_exercicio        INT NOT NULL,
    trimestre            SMALLINT NOT NULL CHECK (trimestre BETWEEN 0 AND 4), -- 0 = Consolidado Anual
    tipo_demonstracao    VARCHAR(20) NOT NULL CHECK (tipo_demonstracao IN ('ANUAL_CONSOL', 'TRIMESTRAL_CONSOL', 'TRIMESTRAL_INDIV')),
    data_fim_periodo     DATE NOT NULL,
    moeda                VARCHAR(3) DEFAULT 'BRL',
    fator_escala         NUMERIC(12,2) DEFAULT 1.0,
    -- DRE
    receita_liquida      NUMERIC(18,2),
    custos_bens_servicos NUMERIC(18,2),
    lucro_bruto          NUMERIC(18,2),
    despesas_operacionais NUMERIC(18,2),
    ebitda               NUMERIC(18,2),
    depreciacao_amortizacao NUMERIC(18,2),
    ebit                 NUMERIC(18,2),
    resultado_financeiro NUMERIC(18,2),
    receitas_financeiras NUMERIC(18,2),
    despesas_financeiras NUMERIC(18,2),
    lucro_antes_ir       NUMERIC(18,2),
    ir_csll              NUMERIC(18,2),
    lucro_liquido        NUMERIC(18,2),
    -- Balanço Patrimonial
    ativo_total          NUMERIC(18,2),
    ativo_circulante     NUMERIC(18,2),
    disponibilidades     NUMERIC(18,2),
    contas_a_receber     NUMERIC(18,2),
    estoques             NUMERIC(18,2),
    passivo_circulante   NUMERIC(18,2),
    divida_bruta_curto_prazo NUMERIC(18,2),
    divida_bruta_longo_prazo NUMERIC(18,2),
    divida_bruta_total   NUMERIC(18,2),
    divida_liquida       NUMERIC(18,2),
    patrimonio_liquido   NUMERIC(18,2),
    -- Fluxo de Caixa (DFC)
    fco_operacional      NUMERIC(18,2),
    fci_investimentos    NUMERIC(18,2),
    fcf_financiamentos   NUMERIC(18,2),
    fluxo_caixa_livre    NUMERIC(18,2),
    -- Métricas Per Share Ajustadas por Splits Retroativos
    numero_acoes_ajustado BIGINT,
    lpa_ajustado         NUMERIC(12,4),
    vpa_ajustado         NUMERIC(12,4),
    payout_exercicio_pct NUMERIC(6,2),
    proventos_declarados_ano NUMERIC(18,2),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_emissor, ano_exercicio, trimestre, tipo_demonstracao)
);
CREATE INDEX IF NOT EXISTS idx_dem_serie_emissor_ano ON analytics.demonstrativo_padronizado_serie (id_emissor, ano_exercicio DESC, trimestre DESC);

-- 7. VACÂNCIA HISTÓRICA DE FIIS (TRIMESTRAL / MENSAL)
CREATE TABLE IF NOT EXISTS asset_details.fii_historico_vacancia (
    id_vacancia          BIGSERIAL,
    id_ativo             INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia      DATE NOT NULL,
    vacancia_fisica_pct  NUMERIC(6,2) NOT NULL,
    vacancia_financeira_pct NUMERIC(6,2) NOT NULL,
    abl_propria_m2       NUMERIC(12,2),
    area_ocupada_m2      NUMERIC(12,2),
    inadimplencia_repasse_pct NUMERIC(6,2),
    PRIMARY KEY (id_ativo, data_referencia)
);
CREATE INDEX IF NOT EXISTS idx_fii_vacancia_dt ON asset_details.fii_historico_vacancia (id_ativo, data_referencia DESC);

-- 8. VIEW MATERIALIZADA: FILTRO DE CONSISTÊNCIA ("SEM PREJUÍZO" OCEANS14)
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_acoes_consistencia_lucro AS
SELECT 
    a.id_ativo,
    a.ticker,
    ec.nome_empresarial,
    ec.setor,
    ec.subsetor,
    ec.segmento_listagem,
    COUNT(dps.ano_exercicio) AS anos_historico_cobertura,
    MIN(dps.lucro_liquido) AS menor_lucro_historico,
    BOOL_AND(dps.lucro_liquido > 0) AS nunca_deu_prejuizo,
    BOOL_AND(CASE WHEN dps.ano_exercicio >= EXTRACT(YEAR FROM CURRENT_DATE) - 5 THEN dps.lucro_liquido > 0 ELSE TRUE END) AS sem_prejuizo_ultimos_5a,
    BOOL_AND(CASE WHEN dps.ano_exercicio >= EXTRACT(YEAR FROM CURRENT_DATE) - 10 THEN dps.lucro_liquido > 0 ELSE TRUE END) AS sem_prejuizo_ultimos_10a,
    ROUND(
        COALESCE(
            (POWER(
                NULLIF(MAX(CASE WHEN dps.ano_exercicio = EXTRACT(YEAR FROM CURRENT_DATE) - 1 THEN dps.lucro_liquido END), 0) /
                NULLIF(MAX(CASE WHEN dps.ano_exercicio = EXTRACT(YEAR FROM CURRENT_DATE) - 6 THEN dps.lucro_liquido END), 0),
                1.0 / 5.0
            ) - 1.0) * 100,
            0.0
        ), 2
    ) AS cagr_lucro_5a
FROM core.ativo a
JOIN core.emissor_companhia ec ON ec.id_emissor = a.id_emissor
JOIN analytics.demonstrativo_padronizado_serie dps ON dps.id_emissor = a.id_emissor
WHERE dps.tipo_demonstracao = 'ANUAL_CONSOL' AND dps.ano_exercicio >= EXTRACT(YEAR FROM CURRENT_DATE) - 15
GROUP BY a.id_ativo, a.ticker, ec.nome_empresarial, ec.setor, ec.subsetor, ec.segmento_listagem;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_consist_ticker ON analytics.mv_acoes_consistencia_lucro (ticker);
