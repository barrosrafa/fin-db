-- =========================================================
-- 4. SOCIAL: Novas tabelas
-- =========================================================

-- 4.1 Watchlists Múltiplas
CREATE TABLE social.watchlist (
    id_watchlist BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome         VARCHAR(80) NOT NULL,
    cor          VARCHAR(10) DEFAULT '#3B82F6',
    icone        VARCHAR(30),
    ordem        INT DEFAULT 0,
    publica      BOOLEAN DEFAULT FALSE,
    data_criacao TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_usuario, nome)
);
CREATE INDEX idx_watchlist_usuario ON social.watchlist(id_usuario, ordem);

CREATE TABLE social.watchlist_item (
    id_item      BIGSERIAL PRIMARY KEY,
    id_watchlist BIGINT NOT NULL REFERENCES social.watchlist(id_watchlist) ON DELETE CASCADE,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    ordem        INT DEFAULT 0,
    nota         TEXT,
    preco_alerta NUMERIC(12,4),
    data_adicao  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_watchlist, id_ativo)
);

-- 4.2 Anotações / Diário do Investidor
CREATE TABLE social.anotacao_ativo (
    id_anotacao   BIGSERIAL PRIMARY KEY,
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo      INT REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_carteira   UUID REFERENCES core.carteira(id_carteira) ON DELETE SET NULL,
    titulo        VARCHAR(150),
    conteudo      TEXT,
    tags          TEXT[],
    publica       BOOLEAN DEFAULT FALSE,
    data_criacao  TIMESTAMPTZ DEFAULT NOW(),
    data_atualizacao TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_anotacao_usuario ON social.anotacao_ativo(id_usuario, data_criacao DESC);
CREATE INDEX idx_anotacao_ativo   ON social.anotacao_ativo(id_ativo);
CREATE INDEX idx_anotacao_tags    ON social.anotacao_ativo USING GIN (tags);
