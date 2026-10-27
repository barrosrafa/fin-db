-- =========================================================
-- ESTÁGIO 06 (v3.4) - PARTE 4: FUNDOS CVM 175, CARTEIRA CDA, ETFs, TÍTULOS PÚBLICOS ANBIMA E CRIPTO
-- Cobertura REA: Mais Retorno, ETFs Brasil, Status Invest, Investidor10
-- Estritamente aditivo e idempotente (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- =========================================================

-- 1. Hierarquia CVM 175 (Fundo / Classe / Subclasse) e Regras Operacionais completas de Fundos (Mais Retorno, Status Invest, ETFs Brasil)
ALTER TABLE asset_details.fundo_investimento
    ADD COLUMN IF NOT EXISTS cvm_175_tipo_entidade       VARCHAR(20) CHECK (cvm_175_tipo_entidade IN ('FUNDO','CLASSE','SUBCLASSE','TRADICIONAL')),
    ADD COLUMN IF NOT EXISTS id_fundo_pai                BIGINT REFERENCES asset_details.fundo_investimento(id_fundo) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS id_classe_pai               BIGINT REFERENCES asset_details.fundo_investimento(id_fundo) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS codigo_cvm_classe           VARCHAR(30),
    ADD COLUMN IF NOT EXISTS codigo_cvm_subclasse        VARCHAR(30),
    ADD COLUMN IF NOT EXISTS codigo_anbima               VARCHAR(30),
    ADD COLUMN IF NOT EXISTS classe_cvm                  VARCHAR(80),
    ADD COLUMN IF NOT EXISTS subclasse_cvm               VARCHAR(100),
    ADD COLUMN IF NOT EXISTS publico_alvo                VARCHAR(40) CHECK (publico_alvo IN ('GERAL','QUALIFICADO','PROFISSIONAL')),
    ADD COLUMN IF NOT EXISTS tipo_cota                   VARCHAR(20) CHECK (tipo_cota IN ('ABERTURA','FECHAMENTO')),
    ADD COLUMN IF NOT EXISTS tributacao_alerta           VARCHAR(60),
    ADD COLUMN IF NOT EXISTS tributacao_perseguida       VARCHAR(40),
    ADD COLUMN IF NOT EXISTS condominio                  VARCHAR(20) CHECK (condominio IN ('ABERTO','FECHADO')),
    ADD COLUMN IF NOT EXISTS exclusivo                   BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS previdenciario              BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS fundo_cotas                 BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS responsabilidade_limitada   BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS investimento_exterior_max_pct NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS credito_privado_max_pct     NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS taxa_adm_maxima             NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_entrada                NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_saida                  NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS aplicacao_inicial_minima    NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS aplicacao_adicional_minima  NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS resgate_minimo              NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS saldo_minimo_permanencia    NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS prazo_cotizacao_aplicacao_dias INT,
    ADD COLUMN IF NOT EXISTS prazo_liquidacao_aplicacao_dias INT,
    ADD COLUMN IF NOT EXISTS prazo_cotizacao_resgate_dias INT,
    ADD COLUMN IF NOT EXISTS prazo_liquidacao_resgate_dias INT,
    ADD COLUMN IF NOT EXISTS tipo_prazo_resgate          VARCHAR(20) CHECK (tipo_prazo_resgate IN ('DIAS_UTEIS','DIAS_CORRIDOS')),
    ADD COLUMN IF NOT EXISTS carencia_dias               INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS horario_limite_movimentacao TIME,
    ADD COLUMN IF NOT EXISTS auditor_nome                VARCHAR(150),
    ADD COLUMN IF NOT EXISTS auditor_cnpj                VARCHAR(18),
    ADD COLUMN IF NOT EXISTS custodiante_cnpj            VARCHAR(18),
    ADD COLUMN IF NOT EXISTS controlador_nome            VARCHAR(150),
    ADD COLUMN IF NOT EXISTS data_inicio_fundo           DATE,
    ADD COLUMN IF NOT EXISTS data_encerramento_fundo     DATE;

ALTER TABLE canonical.fund_profile
    ADD COLUMN IF NOT EXISTS cvm_175_entity_type         TEXT,
    ADD COLUMN IF NOT EXISTS parent_fund_instrument_id   UUID REFERENCES canonical.instrument(instrument_id),
    ADD COLUMN IF NOT EXISTS anbima_code                 TEXT,
    ADD COLUMN IF NOT EXISTS target_audience             TEXT,
    ADD COLUMN IF NOT EXISTS quota_type                  TEXT,
    ADD COLUMN IF NOT EXISTS tax_regime                  TEXT,
    ADD COLUMN IF NOT EXISTS max_management_fee          NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS entry_fee                   NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS exit_fee                    NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS min_initial_investment      NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS min_additional_investment   NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS min_redemption              NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS min_balance                 NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS subscription_cotization_days INT,
    ADD COLUMN IF NOT EXISTS subscription_settlement_days INT,
    ADD COLUMN IF NOT EXISTS redemption_cotization_days  INT,
    ADD COLUMN IF NOT EXISTS redemption_settlement_days  INT,
    ADD COLUMN IF NOT EXISTS lockup_days                 INT;

-- 2. Movimentação Mensal de Carteira CDA CVM: Compras, Vendas e Posição Confidencial (Mais Retorno, Status Invest)
ALTER TABLE asset_details.fundo_carteira
    ADD COLUMN IF NOT EXISTS tipo_ativo_cda              VARCHAR(60),
    ADD COLUMN IF NOT EXISTS codigo_ativo_cda            VARCHAR(40),
    ADD COLUMN IF NOT EXISTS isin_ativo_cda              VARCHAR(12),
    ADD COLUMN IF NOT EXISTS quantidade_comprada_mes     NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS valor_comprado_mes          NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS quantidade_vendida_mes      NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS valor_vendido_mes           NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS posicao_confidencial        BOOLEAN DEFAULT FALSE;

ALTER TABLE canonical.fund_holding
    ADD COLUMN IF NOT EXISTS asset_category_cda          TEXT,
    ADD COLUMN IF NOT EXISTS bought_quantity_month       NUMERIC(20,6),
    ADD COLUMN IF NOT EXISTS bought_value_month          NUMERIC(20,2),
    ADD COLUMN IF NOT EXISTS sold_quantity_month         NUMERIC(20,6),
    ADD COLUMN IF NOT EXISTS sold_value_month            NUMERIC(20,2),
    ADD COLUMN IF NOT EXISTS is_confidential             BOOLEAN DEFAULT FALSE;

-- 3. ETFs B3, Internacionais e UCITS: Taxa Primária vs. Secundária/Total, Empréstimo % PL e Dividendos (ETFs Brasil, Mais Retorno, Investidor10)
ALTER TABLE asset_details.etf_detalhe
    ADD COLUMN IF NOT EXISTS taxa_administracao_primaria NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_administracao_secundaria NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_administracao_total    NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_administracao_anualizada NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS limite_aluguel_pl_pct       NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS frequencia_distribuicao_dividendos VARCHAR(40),
    ADD COLUMN IF NOT EXISTS politica_dividendos         VARCHAR(30) CHECK (politica_dividendos IN ('ACUMULACAO','DISTRIBUICAO','AMBOS')),
    ADD COLUMN IF NOT EXISTS metodo_replicacao           VARCHAR(40) CHECK (metodo_replicacao IN ('FISICA_TOTAL','FISICA_AMOSTRAGEM','SINTETICA_SWAP','FUNDO_DE_FUNDO','ATIVA')),
    ADD COLUMN IF NOT EXISTS domicilio_fiscal            VARCHAR(40),
    ADD COLUMN IF NOT EXISTS regiao_exposicao            VARCHAR(60),
    ADD COLUMN IF NOT EXISTS categoria_etf               VARCHAR(60),
    ADD COLUMN IF NOT EXISTS subcategoria_etf            VARCHAR(80),
    ADD COLUMN IF NOT EXISTS provedor_indice             VARCHAR(80),
    ADD COLUMN IF NOT EXISTS gestor                      VARCHAR(120),
    ADD COLUMN IF NOT EXISTS administrador               VARCHAR(120),
    ADD COLUMN IF NOT EXISTS controlador                 VARCHAR(120),
    ADD COLUMN IF NOT EXISTS tracking_error              NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS fluxo_liquido_30d           NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS p_vp                        NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS dy_12m                      NUMERIC(8,4);

-- 4. Títulos Públicos: Taxas Indicativas ANBIMA Mercado Secundário, PU e VNA (Mais Retorno /titulos-publicos, Status Invest)
ALTER TABLE canonical.government_bond_quote
    ADD COLUMN IF NOT EXISTS anbima_indicative_rate      NUMERIC(12,6),
    ADD COLUMN IF NOT EXISTS anbima_min_rate             NUMERIC(12,6),
    ADD COLUMN IF NOT EXISTS anbima_max_rate             NUMERIC(12,6),
    ADD COLUMN IF NOT EXISTS anbima_pu                   NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS clean_price                 NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS vna                         NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS selic_code                  VARCHAR(20);

ALTER TABLE asset_details.tesouro_direto
    ADD COLUMN IF NOT EXISTS codigo_selic                VARCHAR(20),
    ADD COLUMN IF NOT EXISTS isin                        VARCHAR(12),
    ADD COLUMN IF NOT EXISTS taxa_indicativa_anbima      NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_min_anbima             NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_max_anbima             NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS pu_anbima                   NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS vna_atual                   NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS duration_anos               NUMERIC(8,4);

-- 5. Criptomoedas: Supply Circulante/Total, FDV e TVL DeFi (Investidor10, Status Invest)
ALTER TABLE asset_details.criptomoeda_detalhe
    ADD COLUMN IF NOT EXISTS fornecimento_circulante     NUMERIC(28,8),
    ADD COLUMN IF NOT EXISTS fornecimento_total          NUMERIC(28,8),
    ADD COLUMN IF NOT EXISTS fdv                         NUMERIC(22,2),
    ADD COLUMN IF NOT EXISTS tvl                         NUMERIC(22,2),
    ADD COLUMN IF NOT EXISTS tvl_market_cap_ratio        NUMERIC(10,4);
