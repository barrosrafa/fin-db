-- =========================================================
-- BLOCO 4: PRODUTO E UX
-- =========================================================

-- 4.1 Inbox centralizado (unifica alertas, notificações, comunicados)
CREATE TABLE system.inbox (
    id_inbox    BIGSERIAL,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo        VARCHAR(30) NOT NULL
        CHECK (tipo IN ('ALERTA','NOTIFICACAO','COMUNICADO','PROVENTO',
                        'EVENTO_CORPORATIVO','NEWSLETTER','SISTEMA')),
    titulo      VARCHAR(200),
    mensagem    TEXT,
    link        TEXT,
    icone       VARCHAR(30),
    prioridade  VARCHAR(10) DEFAULT 'NORMAL' CHECK (prioridade IN ('BAIXA','NORMAL','ALTA')),
    lida        BOOLEAN DEFAULT FALSE,
    arquivada   BOOLEAN DEFAULT FALSE,
    data_criacao TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_leitura TIMESTAMPTZ
);
SELECT create_hypertable('system.inbox','data_criacao', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_inbox_user_unread ON system.inbox(id_usuario, lida, data_criacao DESC);
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.inbox', INTERVAL '365 days');

-- 4.2 Grupos e comunidades
CREATE TABLE social.grupo (
    id_grupo     BIGSERIAL PRIMARY KEY,
    nome         VARCHAR(100) NOT NULL,
    slug         VARCHAR(100) UNIQUE,
    descricao    TEXT,
    tipo         VARCHAR(20) DEFAULT 'PUBLICO' CHECK (tipo IN ('PUBLICO','PRIVADO','PAGO')),
    id_criador   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    avatar_url   TEXT,
    membros_count INT DEFAULT 0,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE social.grupo_membro (
    id_grupo    BIGINT NOT NULL REFERENCES social.grupo(id_grupo) ON DELETE CASCADE,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    papel       VARCHAR(20) DEFAULT 'MEMBRO' CHECK (papel IN ('ADMIN','MODERADOR','MEMBRO')),
    data_entrada TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_grupo, id_usuario)
);
CREATE INDEX idx_grupo_membro_user ON social.grupo_membro(id_usuario);

-- 4.3 Mensagens diretas
CREATE TABLE social.mensagem_direta (
    id_mensagem    BIGSERIAL,
    id_remetente   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_destinatario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    conteudo       TEXT NOT NULL,
    lida           BOOLEAN DEFAULT FALSE,
    data_envio     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_leitura   TIMESTAMPTZ
);
SELECT create_hypertable('social.mensagem_direta','data_envio', chunk_time_interval => INTERVAL '3 months');
CREATE INDEX idx_msg_direta_rem ON social.mensagem_direta(id_remetente, data_envio DESC);
CREATE INDEX idx_msg_direta_dest ON social.mensagem_direta(id_destinatario, lida, data_envio DESC);

-- 4.4 Bloqueio de usuário
CREATE TABLE social.bloqueio_usuario (
    id_usuario          UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_usuario_bloqueado UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    data_bloqueio       TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_usuario, id_usuario_bloqueado)
);

-- 4.5 Dashboards customizados
CREATE TABLE social.dashboard (
    id_dashboard BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome         VARCHAR(80) NOT NULL,
    publico      BOOLEAN DEFAULT FALSE,
    slug         VARCHAR(100) UNIQUE,
    data_criacao TIMESTAMPTZ DEFAULT NOW(),
    data_atualizacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE social.dashboard_widget (
    id_widget      BIGSERIAL PRIMARY KEY,
    id_dashboard   BIGINT NOT NULL REFERENCES social.dashboard(id_dashboard) ON DELETE CASCADE,
    tipo           VARCHAR(40) NOT NULL
        CHECK (tipo IN ('GRAFICO_COTACAO','RANKING','TABELA_ATIVOS','CARD_PROVENTO',
                        'CARD_PATRIMONIO','NOTICIAS','WATCHLIST','CALENDARIO')),
    config_json    JSONB NOT NULL,
    posicao_x      INT DEFAULT 0,
    posicao_y      INT DEFAULT 0,
    largura        INT DEFAULT 4,
    altura         INT DEFAULT 3,
    ordem          INT DEFAULT 0
);

-- 4.6 Pipeline de Teses (Kanban do investidor)
CREATE TABLE social.tese_pipeline (
    id_tese            BIGSERIAL PRIMARY KEY,
    id_usuario         UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo           INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    estagio            VARCHAR(20) NOT NULL DEFAULT 'DESCOBERTA'
        CHECK (estagio IN ('DESCOBERTA','ANALISE','COMPRAR','MONITORANDO','DESCARTADA')),
    tese               TEXT,
    preco_entrada_alvo NUMERIC(12,4),
    preco_saida_alvo   NUMERIC(12,4),
    data_movimentacao  TIMESTAMPTZ DEFAULT NOW(),
    data_criacao       TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_usuario, id_ativo)
);
CREATE INDEX idx_tese_user_estagio ON social.tese_pipeline(id_usuario, estagio);
