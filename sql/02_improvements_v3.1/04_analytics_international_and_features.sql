-- =========================================================
-- 3. ANALYTICS: Novas tabelas
-- =========================================================

-- 3.1 Demonstrativos Internacionais (SEC filings)
CREATE TABLE analytics.demonstrativo_internacional (
    id_demonstrativo   BIGSERIAL PRIMARY KEY,
    ticker_internacional VARCHAR(20) NOT NULL,
    pais               VARCHAR(50),
    id_bolsa           INT REFERENCES core.bolsa(id_bolsa),
    tipo               VARCHAR(20) CHECK (tipo IN ('10-K','10-Q','20-F','8-K','EARNINGS','ANNUAL')),
    periodo            VARCHAR(10),
    data_publicacao    DATE,
    contas_json        JSONB,
    moeda              VARCHAR(3),
    fonte              VARCHAR(30),
    UNIQUE (ticker_internacional, tipo, periodo)
);
CREATE INDEX idx_dem_int_contas_gin ON analytics.demonstrativo_internacional USING GIN (contas_json);

-- 3.2 Tags de Ativos
CREATE TABLE analytics.tag (
    id_tag   SERIAL PRIMARY KEY,
    nome     VARCHAR(50) UNIQUE NOT NULL,
    tipo     VARCHAR(30) CHECK (tipo IN ('ESTRATEGIA','TEMA','SETOR','PERFIL')),
    cor      VARCHAR(10)
);

CREATE TABLE analytics.ativo_tag (
    id_ativo INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_tag   INT NOT NULL REFERENCES analytics.tag(id_tag) ON DELETE CASCADE,
    peso     NUMERIC(5,2),
    PRIMARY KEY (id_ativo, id_tag)
);

INSERT INTO analytics.tag (nome, tipo) VALUES
    ('Dividendos','ESTRATEGIA'),
    ('Value','ESTRATEGIA'),
    ('Growth','ESTRATEGIA'),
    ('Small Caps','PERFIL'),
    ('Blue Chips','PERFIL'),
    ('ESG','TEMA'),
    ('Turnaround','TEMA'),
    ('Papel','SETOR'),
    ('Logística','SETOR'),
    ('Shopping','SETOR'),
    ('Híbrido','SETOR'),
    ('Fiagro','SETOR');

-- 3.3 Coleções Curadas
CREATE TABLE analytics.colecao (
    id_colecao   BIGSERIAL PRIMARY KEY,
    nome         VARCHAR(150) NOT NULL,
    descricao    TEXT,
    id_curador   UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    publica      BOOLEAN DEFAULT TRUE,
    slug         VARCHAR(150) UNIQUE,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE analytics.colecao_item (
    id_colecao   BIGINT NOT NULL REFERENCES analytics.colecao(id_colecao) ON DELETE CASCADE,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ordem        INT DEFAULT 0,
    comentario   TEXT,
    PRIMARY KEY (id_colecao, id_ativo)
);

-- 3.4 Eventos de Uso (Product Analytics)
CREATE TABLE analytics.evento_usuario (
    id_evento    BIGSERIAL,
    id_usuario   UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    session_id   UUID,
    evento       VARCHAR(60) NOT NULL,
    propriedades JSONB,
    data_hora    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip           INET,
    user_agent   TEXT,
    plataforma   VARCHAR(20)
);
SELECT create_hypertable('analytics.evento_usuario','data_hora', chunk_time_interval => INTERVAL '7 days');
CREATE INDEX idx_evento_usuario_user_data ON analytics.evento_usuario(id_usuario, data_hora DESC);
CREATE INDEX idx_evento_usuario_evento   ON analytics.evento_usuario(evento, data_hora DESC);
-- [Timescale Cloud Only]: SELECT add_retention_policy('analytics.evento_usuario', INTERVAL '730 days');

-- 3.5 Funis de Conversão
CREATE TABLE analytics.funil (
    id_funil    SERIAL PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    descricao   TEXT,
    etapas      JSONB NOT NULL,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

-- 3.6 Feature Store (IA)
CREATE TABLE analytics.feature_store (
    id_feature       SERIAL PRIMARY KEY,
    nome             VARCHAR(100) UNIQUE NOT NULL,
    tipo             VARCHAR(30) CHECK (tipo IN ('NUMERICO','CATEGORICO','EMBEDDING','BOOLEANO')),
    entidade         VARCHAR(30) CHECK (entidade IN ('ATIVO','USUARIO','CARTEIRA','EMISSOR')),
    fonte_tabela     VARCHAR(100),
    fonte_query      TEXT,
    descricao        TEXT,
    data_atualizacao TIMESTAMPTZ DEFAULT NOW()
);

-- 3.7 Busca Full-Text (View Materializada)
CREATE MATERIALIZED VIEW analytics.busca_ativo AS
SELECT
    a.id_ativo,
    a.ticker,
    e.nome_empresarial AS nome,
    e.setor,
    e.subsetor,
    a.tipo_ativo::text AS tipo,
    setweight(to_tsvector('portuguese', coalesce(a.ticker,'')), 'A') ||
    setweight(to_tsvector('portuguese', coalesce(e.nome_empresarial,'')), 'B') ||
    setweight(to_tsvector('portuguese', coalesce(e.setor,'')), 'C') ||
    setweight(to_tsvector('portuguese', coalesce(e.subsetor,'')), 'C') AS tsv
FROM core.ativo a
LEFT JOIN core.emissor_companhia e ON e.id_emissor = a.id_emissor;

CREATE UNIQUE INDEX idx_busca_ativo_id ON analytics.busca_ativo(id_ativo);
CREATE INDEX idx_busca_ativo_tsv    ON analytics.busca_ativo USING GIN (tsv);
