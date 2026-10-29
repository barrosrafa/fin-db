-- =============================================================================
-- MIGRATION: 12_etfs_brasil_coverage_v4.0
-- ETFS BRASIL: SCREENER MULTICLASSE, HOLDINGS CDA, SPREAD NAV, TRACKING,
-- SIMULADOR DE PORTFÓLIOS & COMPARADOR CANÔNICO
-- Repositório: fin-db (Aditivo e Idempotente)
-- =============================================================================

-- 1. Ampliação do Enum de Classes de Ativos
DO $$
BEGIN
    ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'ETF_EUA';
    ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'STOCK_EUA';
    ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'FI_INFRA';
    ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'BDR_ETF';
    ALTER TYPE core.tipo_ativo_enum ADD VALUE IF NOT EXISTS 'INDICE';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Tabela de Detalhes Específicos de FI-Infras (Lei 12.431/2011)
CREATE TABLE IF NOT EXISTS asset_details.fi_infra_detalhe (
    id_fi_infra                 BIGSERIAL PRIMARY KEY,
    id_ativo                    INT UNIQUE NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    benchmark_referencia        VARCHAR(50) DEFAULT 'NTN-B',
    spread_indicativo_ntnb      NUMERIC(8,4),       -- Spread médio da carteira sobre NTN-B equivalente
    duration_media_carteira     NUMERIC(8,4),       -- Em anos
    isencao_ir_pf               BOOLEAN DEFAULT TRUE,
    taxa_administracao_total    NUMERIC(8,4) NOT NULL,
    taxa_performance            NUMERIC(8,4) DEFAULT 0.00,
    segmento_infra              VARCHAR(60),        -- Energia, Saneamento, Transporte, Telecom
    gestor                      VARCHAR(150),
    administrador               VARCHAR(150),
    data_inicio_fundo           DATE,
    created_at                  TIMESTAMPTZ DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fi_infra_gestor ON asset_details.fi_infra_detalhe(gestor);

-- 3. Tabela Canônica de Composição Aberta da Carteira de ETFs e Fundos (Holdings)
CREATE TABLE IF NOT EXISTS market.etf_composicao_carteira (
    id_composicao               BIGSERIAL PRIMARY KEY,
    id_ativo_fundo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia             DATE NOT NULL,
    id_ativo_subjacente         INT REFERENCES core.ativo(id_ativo) ON DELETE SET NULL,
    codigo_ativo                VARCHAR(30) NOT NULL,    -- Ex: VALE3, PETR4, NVDA, LFT-2029
    descricao_ativo             VARCHAR(200),
    setor_economico             VARCHAR(100),
    pais_origem                 VARCHAR(50) DEFAULT 'Brasil',
    peso_percentual             NUMERIC(8,4) NOT NULL CHECK (peso_percentual >= 0.0000 AND peso_percentual <= 100.0000),
    quantidade_cotas            NUMERIC(22,6),
    valor_mercado_posicao       NUMERIC(22,2),
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_etf_comp_fundo_data
    ON market.etf_composicao_carteira(id_ativo_fundo, data_referencia DESC);
CREATE INDEX IF NOT EXISTS idx_etf_comp_subjacente
    ON market.etf_composicao_carteira(codigo_ativo, data_referencia);

-- 4. Séries Históricas de NAV, Spread de Arbitragem e Tracking Difference Diário
CREATE TABLE IF NOT EXISTS market.etf_metricas_diarias (
    id_ativo                    INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_pregao                 DATE NOT NULL,
    preco_fechamento_mercado    NUMERIC(14,4) NOT NULL,
    nav_cota_patrimonial        NUMERIC(14,4) NOT NULL,
    spread_nav_pct              NUMERIC(8,4) GENERATED ALWAYS AS (
                                    CASE WHEN nav_cota_patrimonial > 0
                                         THEN ((preco_fechamento_mercado - nav_cota_patrimonial) / nav_cota_patrimonial) * 100.0
                                         ELSE 0.0 END
                                ) STORED,
    patrimonio_liquido_diario   NUMERIC(22,2),
    cotas_emitidas_total        BIGINT,
    fluxo_criacao_resgate_cotas BIGINT DEFAULT 0,
    numero_cotistas             INT,
    aluguel_acoes_pl_pct        NUMERIC(6,2),
    tracking_difference_diario  NUMERIC(8,4),
    tracking_difference_acum_ano NUMERIC(8,4),
    PRIMARY KEY (id_ativo, data_pregao)
);
CREATE INDEX IF NOT EXISTS idx_etf_metricas_data
    ON market.etf_metricas_diarias(data_pregao DESC);

-- 5. Tabelas para o Motor de Simulação de Portfólios
CREATE TABLE IF NOT EXISTS analytics.simulador_portfolio_config (
    id_simulacao                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario                  UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    nome_simulacao              VARCHAR(120),
    data_inicio                 DATE NOT NULL,
    data_fim                    DATE NOT NULL,
    aporte_inicial              NUMERIC(18,2) NOT NULL DEFAULT 50000.00,
    aporte_mensal               NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    rebalanceamento_frequencia  VARCHAR(20) NOT NULL CHECK (rebalanceamento_frequencia IN ('NENHUM','MENSAL','TRIMESTRAL','SEMESTRAL','ANUAL')),
    taxa_consultoria_anual      NUMERIC(6,4) DEFAULT 0.00,
    benchmark_comparacao        VARCHAR(30) DEFAULT 'CDI',
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS analytics.simulador_portfolio_carteira (
    id_carteira_simulada        BIGSERIAL PRIMARY KEY,
    id_simulacao                UUID NOT NULL REFERENCES analytics.simulador_portfolio_config(id_simulacao) ON DELETE CASCADE,
    nome_carteira               VARCHAR(80) NOT NULL,
    ordem_apresentacao          INT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS analytics.simulador_portfolio_ativo (
    id_carteira_simulada        BIGINT NOT NULL REFERENCES analytics.simulador_portfolio_carteira(id_carteira_simulada) ON DELETE CASCADE,
    id_ativo                    INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    peso_percentual             NUMERIC(6,4) NOT NULL CHECK (peso_percentual > 0.0000 AND peso_percentual <= 1.0000),
    PRIMARY KEY (id_carteira_simulada, id_ativo)
);

CREATE TABLE IF NOT EXISTS analytics.simulador_portfolio_resultado (
    id_resultado                BIGSERIAL PRIMARY KEY,
    id_carteira_simulada        BIGINT UNIQUE NOT NULL REFERENCES analytics.simulador_portfolio_carteira(id_carteira_simulada) ON DELETE CASCADE,
    valor_final_acumulado       NUMERIC(18,2) NOT NULL,
    retorno_total_pct           NUMERIC(10,4) NOT NULL,
    retorno_anualizado_cagr     NUMERIC(8,4) NOT NULL,
    volatilidade_anualizada     NUMERIC(8,4) NOT NULL,
    sharpe_ratio                NUMERIC(8,4),
    sortino_ratio               NUMERIC(8,4),
    max_drawdown_pct            NUMERIC(8,4) NOT NULL,
    data_max_drawdown           DATE,
    dias_recuperacao_drawdown   INT,
    taxa_administracao_media    NUMERIC(6,4) NOT NULL,
    curva_evolucao_json         JSONB NOT NULL,
    curva_drawdown_json         JSONB NOT NULL,
    metricas_periodos_json      JSONB NOT NULL
);

-- 6. Tabela de Pares Canônicos de Comparação Pré-Computados (Cache de Comparador para SEO)
CREATE TABLE IF NOT EXISTS market.comparador_par_canonico (
    ticker_a                    VARCHAR(12) NOT NULL,
    ticker_b                    VARCHAR(12) NOT NULL,
    data_calculo                DATE NOT NULL,
    overlap_holdings_pct        NUMERIC(6,2),
    delta_taxa_adm              NUMERIC(6,4),
    tracking_error_a            NUMERIC(6,4),
    tracking_error_b            NUMERIC(6,4),
    correlacao_historica_12m    NUMERIC(6,4),
    dados_comparacao_json       JSONB NOT NULL,
    PRIMARY KEY (ticker_a, ticker_b)
);
CREATE INDEX IF NOT EXISTS idx_comp_par_b ON market.comparador_par_canonico(ticker_b, ticker_a);

-- 7. Estruturas para composição de carteira e comparação de ETFs





















































      ;
