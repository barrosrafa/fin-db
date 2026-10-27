-- =========================================================
-- ESTÁGIO 06 (v3.4) - PARTE 2: RECOMPRAS, ALUGUEL BTC, PROVENTOS, SUBSCRIÇÕES, TERMO E OPÇÕES
-- Cobertura REA: Status Invest, Fundamentus, Clube FII, Funds Explorer, FIIs.com.br, ADVFN, ETFs Brasil
-- Estritamente aditivo e idempotente (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
-- =========================================================

-- 1. Programas de Recompra de Ações (Status Invest Buybacks, Fundamentei, Fundamentus recompras.php)
CREATE TABLE IF NOT EXISTS market.programa_recompra (
    id_recompra           BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_emissor            INT REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    tipo_acao             VARCHAR(10),
    data_aprovacao        DATE NOT NULL,
    data_inicio           DATE,
    data_fim              DATE,
    status                VARCHAR(30) CHECK (status IN ('APROVADO','EM_ANDAMENTO','ENCERRADO','CANCELADO')),
    quantidade_autorizada BIGINT,
    quantidade_recomprada BIGINT DEFAULT 0,
    quantidade_cancelada  BIGINT DEFAULT 0,
    percentual_executado  NUMERIC(6,2),
    preco_medio_recompra  NUMERIC(12,4),
    volume_financeiro_recomprado NUMERIC(18,2),
    objetivo              TEXT,
    protocolo_cvm         VARCHAR(40),
    fonte                 VARCHAR(40) DEFAULT 'CVM',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_recompra_ativo_data_tipo
    ON market.programa_recompra(id_ativo, data_aprovacao, COALESCE(tipo_acao, ''));
CREATE INDEX IF NOT EXISTS idx_recompra_ativo_data ON market.programa_recompra(id_ativo, data_aprovacao DESC);

-- 2. Aluguel de Ações BTC: Taxas Tomador vs. Doador e Fluxo Diário vs. Estoque Aberto (Status Invest /category/borrowhistory)
ALTER TABLE market.aluguel_acoes
    ADD COLUMN IF NOT EXISTS taxa_tomador_media          NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_tomador_min            NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_tomador_max            NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_doador_media           NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_doador_min             NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS taxa_doador_max             NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS quantidade_alugada_dia      BIGINT,
    ADD COLUMN IF NOT EXISTS volume_alugado_dia          NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS quantidade_aberta_total     BIGINT;

-- 3. Proventos: Competência Mensal, ISIN, Cotação Base, DY no Anúncio e Grupamento (Clube FII, FIIs.com.br, Fundamentus)
ALTER TABLE market.provento
    ADD COLUMN IF NOT EXISTS mes_referencia              VARCHAR(7),
    ADD COLUMN IF NOT EXISTS isin_codigo                 VARCHAR(12),
    ADD COLUMN IF NOT EXISTS cotacao_base                NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS dy_mensal_pct               NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS fator_grupamento_acoes      INT DEFAULT 1,
    ADD COLUMN IF NOT EXISTS data_ex_especial            BOOLEAN DEFAULT FALSE;

-- 4. Subscrições e Ofertas Públicas (CVM 160 / 400 / 476): Ciclo Completo com Sobras, Período Público e Custos (Clube FII, Funds Explorer)
ALTER TABLE market.subscricao_acao
    ADD COLUMN IF NOT EXISTS numero_emissao              INT,
    ADD COLUMN IF NOT EXISTS norma_cvm                   VARCHAR(30),
    ADD COLUMN IF NOT EXISTS coordenador_lider           VARCHAR(150),
    ADD COLUMN IF NOT EXISTS custo_unitario_distribuicao NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS custo_distribuicao_pct      NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS preco_total_subscricao      NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS cotacao_data_divulgacao     NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS vpa_data_emissao            NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS desconto_agio_mercado_pct   NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS desconto_agio_vpa_pct       NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS proporcao_sobras_pct        NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS inicio_sobras               DATE,
    ADD COLUMN IF NOT EXISTS fim_sobras                  DATE,
    ADD COLUMN IF NOT EXISTS data_liquidacao_sobras      DATE,
    ADD COLUMN IF NOT EXISTS inicio_periodo_publico      DATE,
    ADD COLUMN IF NOT EXISTS fim_periodo_publico         DATE,
    ADD COLUMN IF NOT EXISTS data_liquidacao_publico     DATE,
    ADD COLUMN IF NOT EXISTS data_liquidacao_preferencia DATE,
    ADD COLUMN IF NOT EXISTS data_conversao_recibos      DATE,
    ADD COLUMN IF NOT EXISTS inicio_negociacao_direito   DATE,
    ADD COLUMN IF NOT EXISTS fim_negociacao_direito      DATE,
    ADD COLUMN IF NOT EXISTS ticker_direito              VARCHAR(15),
    ADD COLUMN IF NOT EXISTS ticker_recibo               VARCHAR(15),
    ADD COLUMN IF NOT EXISTS montante_inicial            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS montante_minimo             NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS montante_maximo             NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS montante_captado            NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS lote_adicional              NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS investimento_minimo         NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS metodo_rateio               VARCHAR(60),
    ADD COLUMN IF NOT EXISTS oferta_modificada           BOOLEAN DEFAULT FALSE;

ALTER TABLE canonical.offering
    ADD COLUMN IF NOT EXISTS issue_number                INT,
    ADD COLUMN IF NOT EXISTS cvm_rule                    TEXT,
    ADD COLUMN IF NOT EXISTS lead_coordinator            TEXT,
    ADD COLUMN IF NOT EXISTS distribution_cost_per_unit  NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS distribution_cost_pct       NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS total_subscription_price    NUMERIC(18,6),
    ADD COLUMN IF NOT EXISTS preference_ratio_pct        NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS leftovers_ratio_pct         NUMERIC(10,6),
    ADD COLUMN IF NOT EXISTS leftovers_start_date        DATE,
    ADD COLUMN IF NOT EXISTS leftovers_end_date          DATE,
    ADD COLUMN IF NOT EXISTS leftovers_settlement_date   DATE,
    ADD COLUMN IF NOT EXISTS public_period_start_date    DATE,
    ADD COLUMN IF NOT EXISTS public_period_end_date      DATE,
    ADD COLUMN IF NOT EXISTS public_settlement_date      DATE,
    ADD COLUMN IF NOT EXISTS receipt_conversion_date     DATE,
    ADD COLUMN IF NOT EXISTS right_ticker                TEXT,
    ADD COLUMN IF NOT EXISTS receipt_ticker              TEXT,
    ADD COLUMN IF NOT EXISTS initial_amount              NUMERIC(20,2),
    ADD COLUMN IF NOT EXISTS min_amount                  NUMERIC(20,2),
    ADD COLUMN IF NOT EXISTS raised_amount               NUMERIC(20,2),
    ADD COLUMN IF NOT EXISTS allocation_method           TEXT;

-- 5. Cotações Diárias, Negócios Intraday e Negociação Mensal por Modalidade / Termo (ADVFN, Status Invest, Funds Explorer, ETFs Brasil)
ALTER TABLE market.cotacao_diaria
    ADD COLUMN IF NOT EXISTS vwap_diario                 NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS spread_intraday_pct         NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS patrimonio_liquido_fundo    NUMERIC(18,2),
    ADD COLUMN IF NOT EXISTS numero_cotistas_fundo       INT,
    ADD COLUMN IF NOT EXISTS is_backtest_simulado        BOOLEAN DEFAULT FALSE;

ALTER TABLE market.negocio_intraday
    ADD COLUMN IF NOT EXISTS bid_no_momento              NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS ask_no_momento              NUMERIC(12,4);

CREATE TABLE IF NOT EXISTS market.negociacao_mensal_modalidade (
    id_negociacao_mensal  BIGSERIAL PRIMARY KEY,
    id_ativo              INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_referencia       DATE NOT NULL,
    negocios_vista        BIGINT,
    volume_vista          NUMERIC(18,2),
    quantidade_vista      BIGINT,
    participacao_vista_pct NUMERIC(6,2),
    volume_termo          NUMERIC(18,2),
    prazo_medio_termo_dias INT,
    volume_opcoes         NUMERIC(18,2),
    volume_exercicio_opcoes NUMERIC(18,2),
    volume_leilao         NUMERIC(18,2),
    volume_fracionario    NUMERIC(18,2),
    volume_balcao_otc     NUMERIC(18,2),
    volume_total          NUMERIC(18,2),
    presenca_pregoes_pct  NUMERIC(6,2),
    turnover_pct          NUMERIC(8,4),
    fonte                 VARCHAR(30) DEFAULT 'B3',
    UNIQUE (id_ativo, data_referencia)
);
CREATE INDEX IF NOT EXISTS idx_neg_mensal_mod_ativo ON market.negociacao_mensal_modalidade(id_ativo, data_referencia DESC);

-- 6. Opções: Grega Rho, Posições Coberto/Trava/Descoberto e Fluxo de Opções (Status Invest, ADVFN /opcoes e /ferramentas/fluxo-de-opcoes)
ALTER TABLE asset_details.opcao_detalhe
    ADD COLUMN IF NOT EXISTS rho                         NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS preco_teorico_bs            NUMERIC(12,4),
    ADD COLUMN IF NOT EXISTS distancia_strike_pct        NUMERIC(8,4),
    ADD COLUMN IF NOT EXISTS qtd_coberto                 BIGINT,
    ADD COLUMN IF NOT EXISTS qtd_trava                   BIGINT,
    ADD COLUMN IF NOT EXISTS qtd_descoberto              BIGINT,
    ADD COLUMN IF NOT EXISTS qtd_titular                 INT,
    ADD COLUMN IF NOT EXISTS qtd_lancador                INT,
    ADD COLUMN IF NOT EXISTS estilo_exercicio            VARCHAR(20) CHECK (estilo_exercicio IN ('AMERICANA','EUROPEIA'));

CREATE TABLE IF NOT EXISTS market.fluxo_opcoes (
    id_fluxo_opcao        BIGSERIAL PRIMARY KEY,
    id_ativo_objeto       INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_ativo_opcao        INT REFERENCES core.ativo(id_ativo) ON DELETE SET NULL,
    data_hora             TIMESTAMPTZ NOT NULL,
    tipo_opcao            VARCHAR(10) CHECK (tipo_opcao IN ('CALL','PUT')),
    strike                NUMERIC(12,4),
    vencimento            DATE,
    quantidade            BIGINT,
    preco_premio          NUMERIC(12,4),
    volume_premio         NUMERIC(18,2),
    volatilidade_implicita NUMERIC(8,4),
    agressor              VARCHAR(20) CHECK (agressor IN ('COMPRADOR','VENDEDOR','LEILAO','DESCONHECIDO')),
    sentimento            VARCHAR(20) CHECK (sentimento IN ('BULLISH','BEARISH','NEUTRO')),
    call_put_ratio_dia    NUMERIC(8,4),
    fonte                 VARCHAR(30) DEFAULT 'B3'
);
CREATE INDEX IF NOT EXISTS idx_fluxo_opcoes_objeto ON market.fluxo_opcoes(id_ativo_objeto, data_hora DESC);

-- 7. Calendário de Resultados: Links Diretos DF/Release e Status de Processamento CVM (Fundamentus ultimos-resultados.php, Status Invest)
ALTER TABLE market.calendario_resultados
    ADD COLUMN IF NOT EXISTS documento_df_url            TEXT,
    ADD COLUMN IF NOT EXISTS release_resultados_url      TEXT,
    ADD COLUMN IF NOT EXISTS data_entrega_cvm            TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS processado                  BOOLEAN DEFAULT FALSE;
