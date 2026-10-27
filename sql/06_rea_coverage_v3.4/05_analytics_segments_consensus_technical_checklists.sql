-- =========================================================
-- ESTÁGIO 06 (v3.4) - PARTE 5: SEGMENTOS DE RECEITA, KPIS, CONSENSO, TÉCNICO AVANÇADO E CHECKLISTS
-- Cobertura REA: Investidor10, Fundamentei, Status Invest, Fundamentus, Análise de Ações, ADVFN, Brick360, Mais Retorno, ETFs Brasil
-- Estritamente aditivo e idempotente (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- =========================================================

-- 1. Receita por Segmento de Negócio e por Geografia (Investidor10 companyBussinesRevenues/companyRevenues, Fundamentei financialBusinessSegments/financialGeographicSegments)
CREATE TABLE IF NOT EXISTS analytics.receita_segmento_negocio (
    id_receita_segmento   BIGSERIAL PRIMARY KEY,
    id_emissor            INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    tipo_periodo          VARCHAR(10) NOT NULL CHECK (tipo_periodo IN ('ANUAL','TRIMESTRAL','LTM')),
    nome_segmento         VARCHAR(150) NOT NULL,
    receita_liquida       NUMERIC(18,2),
    ebitda_segmento       NUMERIC(18,2),
    lucro_segmento        NUMERIC(18,2),
    participacao_pct      NUMERIC(8,4),
    moeda                 CHAR(3) DEFAULT 'BRL',
    fonte                 VARCHAR(40),
    UNIQUE (id_emissor, data_referencia, tipo_periodo, nome_segmento)
);
CREATE INDEX IF NOT EXISTS idx_rec_seg_neg_emissor ON analytics.receita_segmento_negocio(id_emissor, data_referencia DESC);

CREATE TABLE IF NOT EXISTS analytics.receita_geografia (
    id_receita_geografia  BIGSERIAL PRIMARY KEY,
    id_emissor            INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    tipo_periodo          VARCHAR(10) NOT NULL CHECK (tipo_periodo IN ('ANUAL','TRIMESTRAL','LTM')),
    regiao_pais           VARCHAR(120) NOT NULL,
    codigo_pais_iso       CHAR(2),
    is_mercado_interno    BOOLEAN,
    receita_liquida       NUMERIC(18,2),
    participacao_pct      NUMERIC(8,4),
    moeda                 CHAR(3) DEFAULT 'BRL',
    fonte                 VARCHAR(40),
    UNIQUE (id_emissor, data_referencia, tipo_periodo, regiao_pais)
);
CREATE INDEX IF NOT EXISTS idx_rec_geo_emissor ON analytics.receita_geografia(id_emissor, data_referencia DESC);

-- 2. KPIs Operacionais Específicos por Emissor/Setor (Investidor10 companyCustomChartsConfig, Fundamentei kpis)
CREATE TABLE IF NOT EXISTS analytics.kpi_operacional_emissor (
    id_kpi_operacional    BIGSERIAL PRIMARY KEY,
    id_emissor            INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    tipo_periodo          VARCHAR(10) NOT NULL CHECK (tipo_periodo IN ('ANUAL','TRIMESTRAL','MENSAL')),
    codigo_kpi            VARCHAR(60) NOT NULL,
    nome_kpi              VARCHAR(150) NOT NULL,
    categoria_setor       VARCHAR(80),
    valor                 NUMERIC(20,4) NOT NULL,
    unidade               VARCHAR(30),
    variacao_yoy_pct      NUMERIC(8,4),
    variacao_qoq_pct      NUMERIC(8,4),
    fonte                 VARCHAR(40),
    UNIQUE (id_emissor, data_referencia, tipo_periodo, codigo_kpi)
);
CREATE INDEX IF NOT EXISTS idx_kpi_op_emissor ON analytics.kpi_operacional_emissor(id_emissor, codigo_kpi, data_referencia DESC);

-- 3. Expansão de Demonstrativo Financeiro e Indicadores Fundamentalistas (Fundamentus, Status Invest, Investidor10, Fundamentei, Análise de Ações, ADVFN)
ALTER TABLE analytics.demonstrativo_financeiro
    ADD COLUMN IF NOT EXISTS ebit                        NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS ativo_total                 NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS ativo_circulante            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS disponibilidades            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS fluxo_caixa_operacional     NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS fluxo_caixa_investimento    NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS fluxo_caixa_financiamento   NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS fluxo_caixa_livre           NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS capex                       NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS depreciacao_amortizacao     NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS carteira_credito            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS depositos                   NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS resultado_intermediacao_financeira NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS receita_servicos            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS pdd                         NUMERIC(18,2);

ALTER TABLE analytics.indicador_fundamentalista
    ADD COLUMN IF NOT EXISTS peg_ratio                   NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_ebitda                    NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_ebit                      NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_ativo                     NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_cap_giro                  NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_ativo_circ_liq            NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_fco                       NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS p_fcl                       NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS ev_receita                  NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS divida_liquida_pl           NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS divida_bruta_pl             NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS divida_liquida_ebit         NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS patrimonio_ativos           NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS passivos_ativos             NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS margem_bruta                NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS margem_ebit                 NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS roa                         NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS ebit_ativo                  NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS liquidez_seca               NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS liquidez_imediata           NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS cobertura_juros             NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS cagr_receita_5a             NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS cagr_lucro_5a               NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS buyback_yield               NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS total_yield                 NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS payout_total                NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS fco_por_acao                NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS fcl_por_acao                NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS vpta                        NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS valor_mercado               NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS enterprise_value            NUMERIC(18,2);

-- 4. Estatísticas Avançadas de Risco, Consistência e Janelas Móveis (Mais Retorno /ms/v2, ETFs Brasil)
ALTER TABLE analytics.historico_risco
    ADD COLUMN IF NOT EXISTS janela                      VARCHAR(15) DEFAULT '12M',
    ADD COLUMN IF NOT EXISTS alfa_jensen                 NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS tracking_error              NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS information_ratio           NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS cagr                        NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS meses_positivos             INT,
    ADD COLUMN IF NOT EXISTS meses_negativos             INT,
    ADD COLUMN IF NOT EXISTS meses_acima_benchmark       INT,
    ADD COLUMN IF NOT EXISTS meses_abaixo_benchmark      INT,
    ADD COLUMN IF NOT EXISTS maior_retorno_mensal        NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS menor_retorno_mensal        NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS data_max_drawdown           DATE,
    ADD COLUMN IF NOT EXISTS tempo_recuperacao_dias      INT,
    ADD COLUMN IF NOT EXISTS taxa_sucesso_janelas_moveis_pct NUMERIC(6,2);

-- 5. Análise Técnica Multi-Timeframe, 4 Suportes / 3 Resistências e Padrões de Candlestick (ADVFN Brasil)
ALTER TABLE analytics.indicador_tecnico
    ADD COLUMN IF NOT EXISTS timeframe                   VARCHAR(10) DEFAULT '1D',
    ADD COLUMN IF NOT EXISTS mms_5                       NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS mms_21                      NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS parabolico_sar              NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS hilo_activator              NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS obv                          NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS estocastico_rapido          NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS momento                     NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS trix                        NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS cci                         NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS adx_dmi                     NUMERIC(10,4),
    ADD COLUMN IF NOT EXISTS suporte_2                   NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS suporte_3                   NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS suporte_4                   NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS resistencia_2               NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS resistencia_3               NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS potencial_altista_pct       NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS qtd_sinais_alta             INT,
    ADD COLUMN IF NOT EXISTS qtd_sinais_baixa            INT,
    ADD COLUMN IF NOT EXISTS qtd_sinais_neutro           INT;

CREATE TABLE IF NOT EXISTS analytics.padrao_candlestick (
    id_padrao             BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia       TIMESTAMPTZ NOT NULL,
    timeframe             VARCHAR(10) NOT NULL DEFAULT '1D',
    nome_padrao           VARCHAR(80) NOT NULL,
    direcao               VARCHAR(20) CHECK (direcao IN ('ALTA','BAIXA','NEUTRO')),
    tipo_sinal            VARCHAR(30) CHECK (tipo_sinal IN ('REVERSAO','CONTINUIDADE','INDECISAO')),
    confiabilidade        INT CHECK (confiabilidade BETWEEN 1 AND 5),
    fonte                 VARCHAR(30) DEFAULT 'ADVFN',
    UNIQUE (id_ativo, data_referencia, timeframe, nome_padrao)
);
CREATE INDEX IF NOT EXISTS idx_padrao_candle_ativo ON analytics.padrao_candlestick(id_ativo, data_referencia DESC);

-- 6. Previsões e Consenso de Analistas por Exercício Futuros (ADVFN /previsoes)
ALTER TABLE analytics.preco_alvo
    ADD COLUMN IF NOT EXISTS qtd_strong_buy              INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS qtd_buy                     INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS qtd_hold                    INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS qtd_sell                    INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS qtd_strong_sell             INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS upside_pct                  NUMERIC(8,4);

CREATE TABLE IF NOT EXISTS analytics.previsao_consenso_analistas (
    id_previsao           BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_coleta           DATE NOT NULL,
    periodo_projetado     VARCHAR(20) NOT NULL,
    tipo_periodo          VARCHAR(15) NOT NULL CHECK (tipo_periodo IN ('ANUAL','TRIMESTRAL')),
    metrica               VARCHAR(40) NOT NULL CHECK (metrica IN (
                              'RECEITA','LPA','EBITDA','EBIT','LUCRO_LIQUIDO','DIVIDENDO','P_L_PROJETADO','PEG_PROJETADO','CRESCIMENTO_LPA'
                          )),
    estimativa_media      NUMERIC(18,4),
    estimativa_alta       NUMERIC(18,4),
    estimativa_baixa      NUMERIC(18,4),
    ano_anterior_real     NUMERIC(18,4),
    numero_analistas      INT,
    moeda                 CHAR(3) DEFAULT 'BRL',
    fonte                 VARCHAR(40) DEFAULT 'ADVFN',
    UNIQUE (id_ativo, data_coleta, periodo_projetado, tipo_periodo, metrica)
);
CREATE INDEX IF NOT EXISTS idx_prev_consenso_ativo ON analytics.previsao_consenso_analistas(id_ativo, periodo_projetado);

-- 7. Checklists Qualitativos Buy & Hold, Pilares de Score e Médias Setoriais (Investidor10, Análise de Ações, Brick360)
ALTER TABLE analytics.score_eixo DROP CONSTRAINT IF EXISTS score_eixo_eixo_check;
ALTER TABLE analytics.score_eixo ADD CONSTRAINT score_eixo_eixo_check CHECK (
    eixo IN (
        'financeiro','imoveis','inquilinos','gestores','riscos','projecoes',
        'governanca','rentabilidade','crescimento','endividamento','dividendos','comunidade','outro'
    )
);

CREATE TABLE IF NOT EXISTS analytics.checklist_avaliacao_ativo (
    id_checklist          BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    fonte_plataforma      VARCHAR(50) NOT NULL,
    data_referencia       DATE NOT NULL,
    nota_geral            NUMERIC(6,2),
    nota_comunidade       NUMERIC(6,2),
    total_votos           INT,
    criterios_json        JSONB NOT NULL DEFAULT '[]'::jsonb,
    pontos_positivos      JSONB DEFAULT '[]'::jsonb,
    pontos_atencao        JSONB DEFAULT '[]'::jsonb,
    resumo_ia             TEXT,
    UNIQUE (id_ativo, fonte_plataforma, data_referencia)
);
CREATE INDEX IF NOT EXISTS idx_checklist_aval_ativo ON analytics.checklist_avaliacao_ativo(id_ativo, data_referencia DESC);

CREATE TABLE IF NOT EXISTS analytics.indicador_media_setorial (
    id_media_setorial     BIGSERIAL PRIMARY KEY,
    nivel_agregacao       VARCHAR(20) NOT NULL CHECK (nivel_agregacao IN ('SETOR','SUBSETOR','SEGMENTO','SEGMENTO_FII')),
    nome_agregacao        VARCHAR(120) NOT NULL,
    data_referencia       DATE NOT NULL,
    codigo_indicador      VARCHAR(50) NOT NULL,
    valor_medio           NUMERIC(18,4),
    valor_mediano         NUMERIC(18,4),
    quantidade_ativos     INT,
    fonte                 VARCHAR(40),
    UNIQUE (nivel_agregacao, nome_agregacao, data_referencia, codigo_indicador)
);
CREATE INDEX IF NOT EXISTS idx_ind_media_setorial ON analytics.indicador_media_setorial(nivel_agregacao, nome_agregacao, data_referencia DESC);

-- 8. Complemento de Insiders, Posição Institucional e Resumo IA em Documentos CVM (Fundamentus insiders.php, ADVFN /propriedade, Brick360 /documents)
ALTER TABLE canonical.insider_transaction
    ADD COLUMN IF NOT EXISTS orgao_administracao         TEXT,
    ADD COLUMN IF NOT EXISTS volume_financeiro           NUMERIC(20,2),
    ADD COLUMN IF NOT EXISTS saldo_final_acoes           NUMERIC(20,4),
    ADD COLUMN IF NOT EXISTS participacao_pct_variacao   NUMERIC(10,6);

ALTER TABLE canonical.institutional_holding
    ADD COLUMN IF NOT EXISTS categoria_investidor        TEXT,
    ADD COLUMN IF NOT EXISTS variacao_quantidade         NUMERIC(20,4),
    ADD COLUMN IF NOT EXISTS valor_mercado_posicao       NUMERIC(20,2);

ALTER TABLE canonical.disclosure_document
    ADD COLUMN IF NOT EXISTS ai_summary                  TEXT,
    ADD COLUMN IF NOT EXISTS ai_sentiment                VARCHAR(20),
    ADD COLUMN IF NOT EXISTS key_highlights              JSONB DEFAULT '[]'::jsonb;

ALTER TABLE canonical.news_article
    ADD COLUMN IF NOT EXISTS ai_summary                  TEXT,
    ADD COLUMN IF NOT EXISTS category_type               VARCHAR(40);
