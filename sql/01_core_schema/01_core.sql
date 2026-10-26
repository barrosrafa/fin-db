-- =========================================================
-- SCHEMA core
-- =========================================================
CREATE TABLE core.usuario (
    id_usuario        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome              VARCHAR(100) NOT NULL,
    email             VARCHAR(150) NOT NULL UNIQUE,
    cpf_cnpj         VARCHAR(14) NOT NULL UNIQUE,
    data_nascimento   DATE,
    telefone          VARCHAR(20),
    endereco          TEXT,
    pais              VARCHAR(50) DEFAULT 'BR',
    perfil_investidor VARCHAR(50) CHECK (perfil_investidor IN ('Conservador','Moderado','Arrojado')),
    status            VARCHAR(20) DEFAULT 'Ativo',
    ultimo_acesso     TIMESTAMP,
    mfa               BOOLEAN DEFAULT FALSE,
    aceite_termos     BOOLEAN DEFAULT FALSE,
    data_aceite       TIMESTAMP,
    data_cadastro     TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_usuario_email_trgm ON core.usuario USING GIN (email gin_trgm_ops);

CREATE TABLE core.instituicao_financeira (
    id_instituicao   SERIAL PRIMARY KEY,
    nome_instituicao VARCHAR(100) NOT NULL,
    cnpj             VARCHAR(14) UNIQUE,
    codigo_sinacor   VARCHAR(10),
    codigo_compe     VARCHAR(3),
    ispb             VARCHAR(8),
    tipo             VARCHAR(50),
    agencias         TEXT,
    telefone         VARCHAR(20),
    site             VARCHAR(150)
);

CREATE TABLE core.emissor_companhia (
    id_emissor       SERIAL PRIMARY KEY,
    cnpj             VARCHAR(14) UNIQUE NOT NULL,
    nome_empresarial VARCHAR(150) NOT NULL,
    codigo_cvm       VARCHAR(10),
    setor            VARCHAR(50),
    subsetor         VARCHAR(50),
    cnae             VARCHAR(20),
    gics             VARCHAR(50),
    free_float       NUMERIC(5,2),
    tag_along        NUMERIC(5,2),
    composicao_acionaria TEXT,
    data_ipo         DATE,
    data_registro_cvm DATE
);
CREATE INDEX idx_emissor_setor ON core.emissor_companhia(setor);

CREATE TABLE core.grupo_acionista (
    id_grupo    BIGSERIAL PRIMARY KEY,
    id_emissor  INT NOT NULL REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    nome_grupo  VARCHAR(150),
    tipo        VARCHAR(30) CHECK (tipo IN ('Controlador','Minoritario','Tesouraria','Insider'))
);

CREATE TABLE core.historico_acionista (
    id_historico         BIGSERIAL PRIMARY KEY,
    id_acionista         BIGINT REFERENCES core.grupo_acionista(id_grupo) ON DELETE CASCADE,
    id_emissor           INT REFERENCES core.emissor_companhia(id_emissor) ON DELETE CASCADE,
    data_posicao         DATE NOT NULL,
    quantidade_ordinarias BIGINT DEFAULT 0,
    quantidade_preferenciais BIGINT DEFAULT 0,
    percentual_total     NUMERIC(7,4),
    UNIQUE (id_acionista, id_emissor, data_posicao)
);

CREATE TABLE core.ativo (
    id_ativo           SERIAL PRIMARY KEY,
    id_emissor         INT REFERENCES core.emissor_companhia(id_emissor) ON DELETE RESTRICT,
    ticker             VARCHAR(12) UNIQUE NOT NULL,
    isin               VARCHAR(12) UNIQUE,
    codigo_cetip       VARCHAR(20) UNIQUE,
    tipo_ativo         core.tipo_ativo_enum NOT NULL,
    tipo_mercado       core.tipo_mercado_enum,
    moeda              VARCHAR(3) DEFAULT 'BRL',
    data_ipo           DATE,
    data_inicio_negociacao DATE,
    data_vencimento    DATE,
    data_emissao       DATE,
    quantidade_emitida BIGINT CHECK (quantidade_emitida >= 0),
    volume_medio       NUMERIC(18,2),
    liquidez           NUMERIC(18,2),
    indexador          VARCHAR(20),
    mercado_balcao     BOOLEAN DEFAULT FALSE,
    segmento_listagem  VARCHAR(50),
    tipo_titulo        VARCHAR(50)
);
CREATE INDEX idx_ativo_tipo ON core.ativo(tipo_ativo);
CREATE INDEX idx_ativo_emissor ON core.ativo(id_emissor);

CREATE TABLE core.carteira (
    id_carteira   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome_carteira VARCHAR(50) NOT NULL,
    tipo          VARCHAR(20) CHECK (tipo IN ('Real','Simulada')),
    benchmark     VARCHAR(20),
    objetivo      VARCHAR(100),
    moeda         VARCHAR(3) DEFAULT 'BRL',
    status        VARCHAR(20) DEFAULT 'Ativa',
    data_criacao  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_carteira_usuario ON core.carteira(id_usuario);

CREATE TABLE core.posicao_custodia (
    id_posicao              BIGSERIAL PRIMARY KEY,
    id_carteira             UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo                INT  NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    quantidade_total        NUMERIC(18,6) DEFAULT 0 CHECK (quantidade_total >= 0),
    quantidade_disponivel   NUMERIC(18,6) DEFAULT 0 CHECK (quantidade_disponivel >= 0),
    quantidade_bloqueada    NUMERIC(18,6) DEFAULT 0 CHECK (quantidade_bloqueada >= 0),
    preco_medio_ponderado   NUMERIC(12,4) DEFAULT 0,
    preco_atual             NUMERIC(12,4),
    valor_mercado           NUMERIC(18,2),
    rentabilidade           NUMERIC(10,4),
    data_aquisicao          DATE,
    data_ultima_atualizacao TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_carteira, id_ativo)
);

CREATE TABLE core.nota_corretagem (
    id_nota               BIGSERIAL PRIMARY KEY,
    id_usuario            UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_instituicao        INT  NOT NULL REFERENCES core.instituicao_financeira(id_instituicao) ON DELETE RESTRICT,
    numero_nota           VARCHAR(20) NOT NULL,
    numero_ordem          VARCHAR(50),
    canal                 VARCHAR(50),
    data_pregao           DATE NOT NULL,
    data_liquidacao       DATE,
    data_vencimento       DATE,
    operacao_normal       NUMERIC(14,2) DEFAULT 0,
    day_trade             NUMERIC(14,2) DEFAULT 0,
    taxa_liquidacao       NUMERIC(10,2) DEFAULT 0,
    emolumentos           NUMERIC(10,2) DEFAULT 0,
    corretagem            NUMERIC(10,2) DEFAULT 0,
    irrf                  NUMERIC(10,2) DEFAULT 0,
    valor_liquido_operacoes NUMERIC(14,2),
    observacao            TEXT,
    UNIQUE (id_instituicao, numero_nota)
);
CREATE INDEX idx_nota_usuario_data ON core.nota_corretagem(id_usuario, data_pregao DESC);

CREATE TABLE core.transacao_operacao (
    id_transacao          BIGSERIAL PRIMARY KEY,
    id_nota               BIGINT NOT NULL REFERENCES core.nota_corretagem(id_nota) ON DELETE CASCADE,
    id_carteira           UUID REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo              INT  NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE RESTRICT,
    numero_ordem          VARCHAR(50),
    horario               TIME,
    tipo_operacao         core.tipo_operacao_enum NOT NULL,
    quantidade            NUMERIC(18,6) NOT NULL CHECK (quantidade >= 0),
    preco_unitario        NUMERIC(12,4) NOT NULL CHECK (preco_unitario >= 0),
    valor_total           NUMERIC(14,2) NOT NULL CHECK (valor_total >= 0),
    corretagem_rateada    NUMERIC(10,4) DEFAULT 0,
    emolumentos_rateados  NUMERIC(10,4) DEFAULT 0,
    irrf_rateado          NUMERIC(10,4) DEFAULT 0,
    liquidacao            BOOLEAN DEFAULT FALSE,
    UNIQUE (id_nota, numero_ordem)
);

CREATE TABLE core.historico_ticker (
    id_historico BIGSERIAL PRIMARY KEY,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ticker_antigo VARCHAR(12),
    ticker_novo   VARCHAR(12),
    isin_antigo   VARCHAR(12),
    data_mudanca  DATE NOT NULL
);
