-- =========================================================
-- SCHEMA social
-- =========================================================
CREATE TABLE social.favorito (
    id_favorito  BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo     INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    data_adicao  TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_usuario, id_ativo)
);

CREATE TABLE social.comparacao_ativo (
    id_comparacao BIGSERIAL PRIMARY KEY,
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_ativo      INT NOT NULL,
    ordem_tela    INT,
    data_criacao  TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_usuario, id_ativo)
);

CREATE TABLE social.categoria_noticia (
    id_categoria SERIAL PRIMARY KEY,
    nome         VARCHAR(50) UNIQUE
);

CREATE TABLE social.noticia_ativo (
    id_noticia    BIGSERIAL PRIMARY KEY,
    id_ativo      INT REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    id_categoria  INT REFERENCES social.categoria_noticia(id_categoria),
    titulo        VARCHAR(200),
    resumo        TEXT,
    fonte         VARCHAR(80),
    url           TEXT,
    data_publicacao TIMESTAMPTZ,
    tipo          VARCHAR(20),
    sentimento    VARCHAR(10) CHECK (sentimento IN ('Positivo','Neutro','Negativo'))
);
CREATE INDEX idx_noticia_ativo_data ON social.noticia_ativo(id_ativo, data_publicacao DESC);

CREATE TABLE social.assembleia (
    id_assembleia BIGSERIAL PRIMARY KEY,
    id_ativo      INT NOT NULL,
    data          TIMESTAMPTZ,
    pauta         TEXT,
    atas          TEXT,
    editais       TEXT,
    deliberacoes  TEXT
);

CREATE TABLE social.curso (
    id_curso    SERIAL PRIMARY KEY,
    nome        VARCHAR(150),
    descricao   TEXT,
    nivel       VARCHAR(20)
);

CREATE TABLE social.trilha (
    id_trilha   SERIAL PRIMARY KEY,
    nome        VARCHAR(150),
    descricao   TEXT
);

CREATE TABLE social.aula (
    id_aula     BIGSERIAL PRIMARY KEY,
    id_curso    INT REFERENCES social.curso(id_curso) ON DELETE CASCADE,
    id_trilha   INT REFERENCES social.trilha(id_trilha) ON DELETE SET NULL,
    titulo      VARCHAR(150),
    url_video   TEXT,
    duracao_min INT,
    ordem       INT
);

CREATE TABLE social.progresso_aula (
    id_progresso BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL,
    id_aula      BIGINT NOT NULL,
    status       VARCHAR(20),
    data_conclusao TIMESTAMP,
    UNIQUE (id_usuario, id_aula)
);

CREATE TABLE social.certificado (
    id_certificado BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    id_curso       INT NOT NULL,
    data_conclusao TIMESTAMP,
    url_certificado TEXT,
    hash_validacao VARCHAR(64) UNIQUE
);

CREATE TABLE social.forum (
    id_forum    SERIAL PRIMARY KEY,
    nome        VARCHAR(100),
    descricao   TEXT
);

CREATE TABLE social.topico (
    id_topico   BIGSERIAL PRIMARY KEY,
    id_forum    INT REFERENCES social.forum(id_forum) ON DELETE CASCADE,
    id_usuario  UUID NOT NULL,
    titulo      VARCHAR(200),
    data_criacao TIMESTAMP DEFAULT NOW()
);

CREATE TABLE social.comentario (
    id_comentario BIGSERIAL PRIMARY KEY,
    id_topico     BIGINT REFERENCES social.topico(id_topico) ON DELETE CASCADE,
    id_usuario    UUID NOT NULL,
    id_comentario_pai BIGINT REFERENCES social.comentario(id_comentario) ON DELETE CASCADE,
    conteudo      TEXT,
    data_criacao  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE social.curtida (
    id_curtida  BIGSERIAL PRIMARY KEY,
    id_usuario  UUID NOT NULL,
    id_comentario BIGINT REFERENCES social.comentario(id_comentario) ON DELETE CASCADE,
    UNIQUE (id_usuario, id_comentario)
);

CREATE TABLE social.seguidor (
    id_seguidor BIGSERIAL PRIMARY KEY,
    id_usuario_seguidor UUID NOT NULL,
    id_usuario_seguido  UUID NOT NULL,
    data_inicio TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_usuario_seguidor, id_usuario_seguido)
);

CREATE TABLE social.perfil_publico (
    id_usuario      UUID PRIMARY KEY REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    biografia       TEXT,
    carteira_publica BOOLEAN DEFAULT FALSE,
    data_criacao    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE social.gamificacao (
    id_gamificacao BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL UNIQUE,
    pontos         INT DEFAULT 0,
    nivel          INT DEFAULT 1
);

CREATE TABLE social.conquista (
    id_conquista SERIAL PRIMARY KEY,
    nome         VARCHAR(100),
    descricao    TEXT,
    pontos       INT
);

CREATE TABLE social.badge (
    id_badge    SERIAL PRIMARY KEY,
    nome        VARCHAR(100),
    url_imagem  TEXT
);
