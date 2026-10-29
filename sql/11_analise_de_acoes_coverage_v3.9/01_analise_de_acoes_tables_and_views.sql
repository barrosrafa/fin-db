-- ============================================================================
-- FIN-DB: MIGRATION 11 - ANÁLISE DE AÇÕES FULL COVERAGE (v3.9)
-- Esquemas: cms, suitability, market, asset_details, analytics, core, system
-- Compatibilidade: PostgreSQL 18 / TimescaleDB (Neon Serverless)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS cms;
CREATE SCHEMA IF NOT EXISTS suitability;

-- ----------------------------------------------------------------------------
-- 1. CÂMBIO PTAX DIÁRIO E DUPLA LISTAGEM INTERNACIONAL (STOCKS / BDRs)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS market.cotacao_cambio_diaria (
    data_cambio         DATE NOT NULL,
    moeda_origem        VARCHAR(3) NOT NULL,
    moeda_destino       VARCHAR(3) NOT NULL DEFAULT 'BRL',
    taxa_compra         NUMERIC(14,6) NOT NULL,
    taxa_venda          NUMERIC(14,6) NOT NULL,
    boletim             VARCHAR(20) DEFAULT 'FECHAMENTO',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (data_cambio, moeda_origem, moeda_destino)
);

CREATE INDEX IF NOT EXISTS idx_cambio_data_moeda
    ON market.cotacao_cambio_diaria(data_cambio DESC, moeda_origem);

CREATE TABLE IF NOT EXISTS core.ativo_dupla_listagem (
    id_dupla_listagem   BIGSERIAL PRIMARY KEY,
    id_ativo_origem     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_ativo_bdr        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    proporcao_bdr       NUMERIC(12,6) NOT NULL, -- Ex: 1 Stock = 10 BDRs
    banco_depositario   VARCHAR(100),
    is_patrocinado      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id_ativo_origem, id_ativo_bdr)
);

-- ----------------------------------------------------------------------------
-- 2. MÉTRICAS ESPECIALIZADAS DE REITS & DEMONSTRATIVOS US GAAP (NAREIT)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS asset_details.detalhe_reit (
    id_ativo                INT PRIMARY KEY REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    subtipo_reit            VARCHAR(50) NOT NULL, -- Industrial, Healthcare, Retail, Data Center, etc.
    ffo_12m                 NUMERIC(18,4),       -- Funds From Operations 12 meses (USD)
    affo_12m                NUMERIC(18,4),      -- Adjusted Funds From Operations 12 meses (USD)
    ffo_por_acao            NUMERIC(12,4),
    affo_por_acao           NUMERIC(12,4),
    p_ffo                   NUMERIC(10,2),
    p_affo                  NUMERIC(10,2),
    ffo_payout_ratio        NUMERIC(6,2),       -- % proventos sobre FFO
    taxa_ocupacao_pct       NUMERIC(5,2),
    total_propriedades      INT,
    alavancagem_divida_ev   NUMERIC(6,2),
    withholding_tax_pct     NUMERIC(5,2) DEFAULT 30.00,
    data_atualizacao        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. PROVENTOS DETALHADOS & TRIBUTAÇÃO NA FONTE UNIFICADA
-- ----------------------------------------------------------------------------

DO $$ BEGIN
    ALTER TYPE market.tipo_provento_enum ADD VALUE IF NOT EXISTS 'ORDINARY_DIVIDEND_US';
    ALTER TYPE market.tipo_provento_enum ADD VALUE IF NOT EXISTS 'RETURN_OF_CAPITAL_US';
    ALTER TYPE market.tipo_provento_enum ADD VALUE IF NOT EXISTS 'CAPITAL_GAIN_DIST_US';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE market.provento
    ADD COLUMN IF NOT EXISTS valor_bruto_usd         NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS aliquota_retencao_fonte NUMERIC(5,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS valor_liquido_moeda     NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS taxa_cambio_ptax        NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS valor_liquido_brl       NUMERIC(14,6),
    ADD COLUMN IF NOT EXISTS status_aprovacao        VARCHAR(30) DEFAULT 'CONFIRMADO',
    ADD COLUMN IF NOT EXISTS data_limite_alteracao   DATE;

CREATE INDEX IF NOT EXISTS idx_provento_data_pagamento
    ON market.provento(data_pagamento DESC, id_ativo);

-- ----------------------------------------------------------------------------
-- 4. MATRIZ DE SAZONALIDADE E MAPA DE DIVIDENDOS (PRÉ-AGREGADA)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.mapa_sazonalidade_dividendo (
    id_ativo                INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    mes_calendario          SMALLINT NOT NULL CHECK (mes_calendario BETWEEN 1 AND 12),
    tipo_evento             VARCHAR(20) NOT NULL CHECK (tipo_evento IN ('DATA_COM', 'PAGAMENTO')),
    ocorrencias_historicas  INT NOT NULL DEFAULT 0,
    anos_analisados         INT NOT NULL DEFAULT 1,
    probabilidade_pct       NUMERIC(5,2) GENERATED ALWAYS AS (
        LEAST(100.00, ROUND((ocorrencias_historicas::numeric / GREATEST(anos_analisados, 1)) * 100, 2))
    ) STORED,
    valor_medio_provento    NUMERIC(12,6) DEFAULT 0.00,
    yield_medio_mensal      NUMERIC(6,4) DEFAULT 0.00,
    ultimo_ano_pago         INT,
    data_atualizacao        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id_ativo, mes_calendario, tipo_evento)
);

CREATE INDEX IF NOT EXISTS idx_mapa_sazonal_prob
    ON analytics.mapa_sazonalidade_dividendo(mes_calendario, probabilidade_pct DESC);

-- ----------------------------------------------------------------------------
-- 5. CMS COMPLETO: GLOSSÁRIO (DICIONÁRIO), LIVROS, ARTIGOS E SUPORTE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cms.termo_glossario (
    id_termo            SERIAL PRIMARY KEY,
    slug                VARCHAR(120) NOT NULL UNIQUE,
    termo               VARCHAR(150) NOT NULL,
    letra_inicial       CHAR(1) GENERATED ALWAYS AS (UPPER(SUBSTRING(termo FROM 1 FOR 1))) STORED,
    categoria           VARCHAR(60) NOT NULL, -- Valuation, Renda Fixa, Contabilidade, etc.
    definicao_curta     VARCHAR(300) NOT NULL,
    conteudo_markdown   TEXT NOT NULL,
    formula_latex       TEXT,
    meta_title          VARCHAR(100),
    meta_description    VARCHAR(200),
    total_visualizacoes BIGINT DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_glossario_letra ON cms.termo_glossario(letra_inicial, termo);

CREATE TABLE IF NOT EXISTS cms.livro_investimento (
    id_livro            SERIAL PRIMARY KEY,
    slug                VARCHAR(150) NOT NULL UNIQUE,
    titulo              VARCHAR(200) NOT NULL,
    subtitulo           VARCHAR(250),
    autor               VARCHAR(150) NOT NULL,
    editora             VARCHAR(100),
    ano_publicacao      INT,
    isbn                VARCHAR(20),
    nivel_dificuldade   VARCHAR(30) CHECK (nivel_dificuldade IN ('INICIANTE', 'INTERMEDIARIO', 'AVANCADO')),
    categoria           VARCHAR(60) NOT NULL,
    capa_url            TEXT,
    resenha_markdown    TEXT NOT NULL,
    principais_licoes   JSONB DEFAULT '[]'::jsonb,
    avaliacao_media     NUMERIC(3,2) DEFAULT 5.00,
    link_afiliado       TEXT,
    ativo               BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cms.artigo_blog (
    id_artigo           BIGSERIAL PRIMARY KEY,
    slug                VARCHAR(200) NOT NULL UNIQUE,
    titulo              VARCHAR(250) NOT NULL,
    subtitulo           TEXT,
    autor_id            UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    autor_nome          VARCHAR(120) NOT NULL,
    categoria           VARCHAR(60) NOT NULL,
    tags                TEXT[] DEFAULT ARRAY[]::TEXT[],
    conteudo_markdown   TEXT NOT NULL,
    tempo_leitura_min   SMALLINT DEFAULT 5,
    is_premium          BOOLEAN NOT NULL DEFAULT FALSE,
    banner_url          TEXT,
    publicado_em        TIMESTAMPTZ,
    status              VARCHAR(20) DEFAULT 'RASCUNHO' CHECK (status IN ('RASCUNHO', 'PUBLICADO', 'ARQUIVADO')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_artigo_publicado ON cms.artigo_blog(publicado_em DESC) WHERE status = 'PUBLICADO';

CREATE TABLE IF NOT EXISTS cms.ticket_suporte (
    id_ticket           BIGSERIAL PRIMARY KEY,
    id_usuario          UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    nome_contato        VARCHAR(120) NOT NULL,
    email_contato       VARCHAR(150) NOT NULL,
    assunto             VARCHAR(60) NOT NULL, -- ASSINATURA, ERRO_DADOS, SUGESTAO, OUTROS
    mensagem            TEXT NOT NULL,
    status              VARCHAR(20) DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'EM_ANALISE', 'RESOLVIDO', 'FECHADO')),
    ip_origem           INET,
    resposta_admin      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- 6. SUITABILITY: MOTOR DE QUESTIONÁRIO, SCORING E ALOCAÇÃO RECOMENDADA
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS suitability.pergunta (
    id_pergunta         SERIAL PRIMARY KEY,
    ordem               INT NOT NULL UNIQUE,
    titulo              VARCHAR(250) NOT NULL,
    descricao           TEXT,
    eixo_analise        VARCHAR(40) NOT NULL, -- HORIZONTE, TOLERANCIA_RISCO, CONHECIMENTO, LIQUIDEZ
    ativo               BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS suitability.opcao_resposta (
    id_opcao            SERIAL PRIMARY KEY,
    id_pergunta         INT NOT NULL REFERENCES suitability.pergunta(id_pergunta) ON DELETE CASCADE,
    ordem               INT NOT NULL,
    texto_resposta      TEXT NOT NULL,
    pontuacao_peso      INT NOT NULL, -- Pontos atribuídos (ex: 1 a 10)
    UNIQUE (id_pergunta, ordem)
);

CREATE TABLE IF NOT EXISTS suitability.categoria_risco (
    id_categoria        SERIAL PRIMARY KEY,
    codigo              VARCHAR(30) NOT NULL UNIQUE, -- CONSERVADOR, MODERADO, ARROJADO
    nome                VARCHAR(60) NOT NULL,
    score_min           INT NOT NULL,
    score_max           INT NOT NULL,
    descricao           TEXT NOT NULL,
    alocacao_alvo_json  JSONB NOT NULL -- { "renda_fixa": 45, "fiis": 30, "acoes": 20, "internacional": 5 }
);

CREATE TABLE IF NOT EXISTS suitability.historico_respostas_usuario (
    id_avaliacao        BIGSERIAL PRIMARY KEY,
    id_usuario          UUID REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    score_total         INT NOT NULL,
    id_categoria        INT NOT NULL REFERENCES suitability.categoria_risco(id_categoria),
    respostas_json      JSONB NOT NULL,
    data_avaliacao      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. TARIFAS DE CORRETORAS E PLATAFORMAS (EXPANSÃO core.instituicao_financeira)
-- ----------------------------------------------------------------------------

ALTER TABLE core.instituicao_financeira
    ADD COLUMN IF NOT EXISTS taxa_corretagem_acoes     NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS taxa_corretagem_fiis      NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS taxa_corretagem_opcoes    NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS custodia_mensal           NUMERIC(8,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS spread_cambial_ptax_pct   NUMERIC(5,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS plataformas_suportadas    TEXT[] DEFAULT ARRAY['Home Broker']::TEXT[],
    ADD COLUMN IF NOT EXISTS is_internacional          BOOLEAN DEFAULT FALSE;

-- ----------------------------------------------------------------------------
-- 8. ASSINATURAS, ENTITLEMENTS E WEBHOOKS IDEMPOTENTES
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS system.plano_entitlement (
    id_entitlement      SERIAL PRIMARY KEY,
    id_plano            INT NOT NULL REFERENCES system.plano(id_plano) ON DELETE CASCADE,
    recurso_chave       VARCHAR(60) NOT NULL, -- VALUATION_GRAHAM, MAPA_DIVIDENDOS, ALERTAS_TELEGRAM, EXPORT_EXCEL
    permitido           BOOLEAN NOT NULL DEFAULT TRUE,
    limite_mensal       INT, -- NULL = Ilimitado
    UNIQUE (id_plano, recurso_chave)
);

CREATE TABLE IF NOT EXISTS system.webhook_evento_processado (
    id_evento_gateway   VARCHAR(120) PRIMARY KEY, -- ID enviado pelo Asaas / Stripe
    gateway             VARCHAR(30) NOT NULL,
    tipo_evento         VARCHAR(80) NOT NULL,
    payload_json        JSONB NOT NULL,
    processado_com_sucesso BOOLEAN NOT NULL DEFAULT FALSE,
    mensagem_erro       TEXT,
    recebido_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processado_em       TIMESTAMPTZ
);

-- ============================================================================
-- OBJETOS DE CONTEÚDO E SUITABILITY (SEM DADOS INICIAIS)
-- ============================================================================

-- A. GLOSSÁRIO TÉCNICO






                                                       ;







                                                       ;







                                                       ;







                                                       ;







                                                       ;

-- B. LIVROS DE INVESTIMENTO RECOMENDADOS





                                                         ;






                                                         ;






                                                         ;





                                                         ;

-- C. SUITABILITY: CATEGORIAS DE RISCO & PERGUNTAS PONDERADAS (CVM 30)











                                                                 ;











                                                          ;

-- Opções da Pergunta 1



                                                                                       ;




                                                                                       ;




                                                                                       ;

-- Opções da Pergunta 2



                                                                                       ;




                                                                                       ;




                                                                                       ;

-- Opções da Pergunta 3



                                                                                       ;




                                                                                       ;




                                                                                       ;

-- Opções da Pergunta 4



                                                                                       ;




                                                                                       ;




                                                                                       ;

-- D. CORRETORAS COM TARIFAS E SPREADS



                                                                                                                                                   ;




                                                                                                                                                   ;




                                                                                                                                                   ;




                                                                                                                                                   ;

-- E. ATIVOS INTERNACIONAIS (STOCKS EUA & REITS) EM core.ativo






                                                         ;

-- Detalhes dos REITs



                                                           ;




                                                           ;

-- F. CÂMBIO PTAX DE REFERÊNCIA




                                                                 ;

-- G. ESTRUTURA DO MAPA DE SAZONALIDADE


                                                                                                                          ;



                                                                                                                          ;



                                                                                                                          ;



                                                                                                                          ;



                                                                                                                          ;

-- FIIs com distribuição em todos os meses































      ;
