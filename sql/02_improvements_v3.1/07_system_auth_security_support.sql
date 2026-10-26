-- =========================================================
-- 6. SYSTEM: Novas tabelas (maior bloco)
-- =========================================================

-- 6.1 Autenticação completa
CREATE TABLE system.password_reset (
    id_reset       BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    token_hash     VARCHAR(64) NOT NULL UNIQUE,
    data_criacao   TIMESTAMPTZ DEFAULT NOW(),
    data_expiracao TIMESTAMPTZ NOT NULL,
    usado          BOOLEAN DEFAULT FALSE,
    ip             INET
);
CREATE INDEX idx_pwd_reset_user ON system.password_reset(id_usuario, usado);

CREATE TABLE system.email_verificacao (
    id_verificacao BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    email          VARCHAR(150) NOT NULL,
    token_hash     VARCHAR(64) NOT NULL UNIQUE,
    data_criacao   TIMESTAMPTZ DEFAULT NOW(),
    data_expiracao TIMESTAMPTZ NOT NULL,
    verificado     BOOLEAN DEFAULT FALSE
);

CREATE TABLE system.mfa_backup_code (
    id_code    BIGSERIAL PRIMARY KEY,
    id_usuario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    hash_code  VARCHAR(64) NOT NULL,
    usado      BOOLEAN DEFAULT FALSE,
    data_uso   TIMESTAMPTZ
);
CREATE INDEX idx_mfa_user ON system.mfa_backup_code(id_usuario, usado);

CREATE TABLE system.oauth_provider (
    id_provider   SERIAL PRIMARY KEY,
    nome          VARCHAR(30) UNIQUE NOT NULL,
    client_id     VARCHAR(200),
    client_secret VARCHAR(200),
    ativo         BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.oauth_vinculo (
    id_vinculo       BIGSERIAL PRIMARY KEY,
    id_usuario       UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_provider      INT NOT NULL REFERENCES system.oauth_provider(id_provider),
    provider_user_id VARCHAR(200) NOT NULL,
    data_vinculo     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_provider, provider_user_id)
);

CREATE TABLE system.tentativa_login (
    id_tentativa  BIGSERIAL,
    email         VARCHAR(150),
    ip            INET,
    user_agent    TEXT,
    sucesso       BOOLEAN NOT NULL,
    motivo_falha  VARCHAR(60),
    data_hora     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT create_hypertable('system.tentativa_login','data_hora', chunk_time_interval => INTERVAL '1 month');
CREATE INDEX idx_tent_login_email ON system.tentativa_login(email, data_hora DESC);

INSERT INTO system.oauth_provider (nome, ativo) VALUES
    ('GOOGLE', FALSE),('APPLE', FALSE),('FACEBOOK', FALSE),('GITHUB', FALSE);

-- 6.2 Termos, Consentimentos e LGPD
CREATE TABLE system.versao_termo (
    id_versao    SERIAL PRIMARY KEY,
    tipo         VARCHAR(30) NOT NULL CHECK (tipo IN ('TERMOS_USO','PRIVACIDADE','COOKIES','COMUNICACAO')),
    versao       VARCHAR(20) NOT NULL,
    conteudo     TEXT,
    data_vigencia DATE NOT NULL,
    obrigatorio_reaceite BOOLEAN DEFAULT FALSE,
    UNIQUE (tipo, versao)
);

CREATE TABLE system.aceite_termo (
    id_aceite  BIGSERIAL PRIMARY KEY,
    id_usuario UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_versao  INT NOT NULL REFERENCES system.versao_termo(id_versao) ON DELETE RESTRICT,
    data_aceite TIMESTAMPTZ DEFAULT NOW(),
    ip         INET,
    user_agent TEXT,
    UNIQUE (id_usuario, id_versao)
);

CREATE TABLE system.consentimento_cookie (
    id_consentimento BIGSERIAL PRIMARY KEY,
    id_usuario       UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    session_id       UUID,
    categorias       JSONB NOT NULL,
    data             TIMESTAMPTZ DEFAULT NOW(),
    ip               INET
);

CREATE TABLE system.solicitacao_lgpd (
    id_solicitacao BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo           VARCHAR(30) NOT NULL
        CHECK (tipo IN ('ACESSO','CORRECAO','EXCLUSAO','PORTABILIDADE','REVOGACAO','OPOSICAO')),
    status         VARCHAR(20) DEFAULT 'ABERTA'
        CHECK (status IN ('ABERTA','EM_ANALISE','CONCLUIDA','NEGADA')),
    data_abertura  TIMESTAMPTZ DEFAULT NOW(),
    data_conclusao TIMESTAMPTZ,
    resposta       TEXT,
    url_arquivo    TEXT
);
CREATE INDEX idx_dsar_status ON system.solicitacao_lgpd(status, data_abertura DESC);

CREATE TABLE system.ropa (
    id_ropa             SERIAL PRIMARY KEY,
    nome_atividade      VARCHAR(150) NOT NULL,
    finalidade          TEXT,
    base_legal          VARCHAR(50),
    categorias_dados    TEXT,
    categorias_titulares TEXT,
    compartilhamentos   TEXT,
    retencao            VARCHAR(100),
    medidas_seguranca   TEXT,
    data_atualizacao    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.incidente_seguranca (
    id_incidente        BIGSERIAL PRIMARY KEY,
    titulo              VARCHAR(200) NOT NULL,
    descricao           TEXT,
    severidade          VARCHAR(20) CHECK (severidade IN ('BAIXA','MEDIA','ALTA','CRITICA')),
    data_deteccao       TIMESTAMPTZ NOT NULL,
    data_resolucao      TIMESTAMPTZ,
    dados_afetados      TEXT,
    notificado_anpd     BOOLEAN DEFAULT FALSE,
    notificado_titulares BOOLEAN DEFAULT FALSE,
    data_notificacao_anpd TIMESTAMPTZ
);

CREATE TABLE system.politica_retencao (
    id_politica  SERIAL PRIMARY KEY,
    tabela       VARCHAR(100) NOT NULL,
    campo_data   VARCHAR(50),
    dias_retencao INT NOT NULL,
    acao         VARCHAR(20) CHECK (acao IN ('DELETAR','ANONIMIZAR','ARQUIVAR')),
    base_legal   VARCHAR(100),
    ativa        BOOLEAN DEFAULT TRUE,
    UNIQUE (tabela, campo_data)
);

-- 6.3 API Keys e Webhooks
CREATE TABLE system.api_key (
    id_api_key      BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    nome            VARCHAR(80) NOT NULL,
    hash_key        VARCHAR(64) NOT NULL UNIQUE,
    prefixo         VARCHAR(12) NOT NULL,
    escopos         TEXT[],
    quota_diaria    INT DEFAULT 1000,
    quota_usada     INT DEFAULT 0,
    data_criacao    TIMESTAMPTZ DEFAULT NOW(),
    data_expiracao  TIMESTAMPTZ,
    ultimo_uso      TIMESTAMPTZ,
    ativo           BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_api_key_prefixo ON system.api_key(prefixo);

CREATE TABLE system.api_key_uso (
    id_uso            BIGSERIAL,
    id_api_key        BIGINT NOT NULL REFERENCES system.api_key(id_api_key) ON DELETE CASCADE,
    endpoint          VARCHAR(200),
    metodo_http       VARCHAR(10),
    data_hora         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status_code       INT,
    tempo_resposta_ms INT,
    ip                INET
);
SELECT create_hypertable('system.api_key_uso','data_hora', chunk_time_interval => INTERVAL '1 month');
-- [Timescale Cloud Only]: SELECT add_retention_policy('system.api_key_uso', INTERVAL '365 days');

CREATE TABLE system.webhook (
    id_webhook   BIGSERIAL PRIMARY KEY,
    id_usuario   UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    url          TEXT NOT NULL,
    eventos      TEXT[] NOT NULL,
    secret       VARCHAR(64),
    ativo        BOOLEAN DEFAULT TRUE,
    data_criacao TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.webhook_entrega (
    id_entrega       BIGSERIAL PRIMARY KEY,
    id_webhook       BIGINT NOT NULL REFERENCES system.webhook(id_webhook) ON DELETE CASCADE,
    evento           VARCHAR(60) NOT NULL,
    payload          JSONB,
    status_code      INT,
    resposta         TEXT,
    tentativas       INT DEFAULT 0,
    data_envio       TIMESTAMPTZ DEFAULT NOW(),
    proxima_tentativa TIMESTAMPTZ,
    sucesso          BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_webhook_entrega_status ON system.webhook_entrega(id_webhook, sucesso, proxima_tentativa);

-- 6.4 Fontes de Dados e ETL
CREATE TABLE system.fonte_dados (
    id_fonte        SERIAL PRIMARY KEY,
    nome            VARCHAR(100) UNIQUE NOT NULL,
    tipo            VARCHAR(20) CHECK (tipo IN ('API','SCRAPING','ARQUIVO','BANCO')),
    url_base        TEXT,
    frequencia      VARCHAR(30),
    ativo           BOOLEAN DEFAULT TRUE,
    ultima_execucao TIMESTAMPTZ,
    status          VARCHAR(20)
);

CREATE TABLE system.fonte_credencial (
    id_credencial     BIGSERIAL PRIMARY KEY,
    id_fonte          INT NOT NULL REFERENCES system.fonte_dados(id_fonte) ON DELETE CASCADE,
    chave             VARCHAR(80) NOT NULL,
    valor_criptografado TEXT NOT NULL,
    data_expiracao    TIMESTAMPTZ,
    data_criacao      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_fonte, chave)
);

CREATE TABLE system.etl_execucao (
    id_execucao          BIGSERIAL PRIMARY KEY,
    pipeline             VARCHAR(100) NOT NULL,
    data_inicio          TIMESTAMPTZ NOT NULL,
    data_fim             TIMESTAMPTZ,
    status               VARCHAR(20) CHECK (status IN ('EXECUTANDO','SUCESSO','ERRO','PARCIAL')),
    registros_processados INT DEFAULT 0,
    registros_erro       INT DEFAULT 0,
    mensagem_erro        TEXT
);
CREATE INDEX idx_etl_pipeline_data ON system.etl_execucao(pipeline, data_inicio DESC);

CREATE TABLE system.etl_erro (
    id_erro      BIGSERIAL PRIMARY KEY,
    id_execucao  BIGINT NOT NULL REFERENCES system.etl_execucao(id_execucao) ON DELETE CASCADE,
    tabela       VARCHAR(100),
    registro     TEXT,
    mensagem     TEXT,
    data         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.cache_metadata (
    chave               VARCHAR(150) PRIMARY KEY,
    ultima_atualizacao  TIMESTAMPTZ NOT NULL,
    ttl_segundos        INT,
    fonte               VARCHAR(100),
    versao              INT DEFAULT 1
);

-- 6.5 Feature Flags e Experimentos
CREATE TABLE system.feature_flag_usuario (
    id_feature  INT NOT NULL REFERENCES system.feature_flag(id_feature) ON DELETE CASCADE,
    id_usuario  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    habilitado  BOOLEAN NOT NULL,
    data_override TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_feature, id_usuario)
);

CREATE TABLE system.experimento (
    id_experimento SERIAL PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    descricao      TEXT,
    status         VARCHAR(20) DEFAULT 'RASCUNHO'
        CHECK (status IN ('RASCUNHO','ATIVO','PAUSADO','ENCERRADO')),
    data_inicio    DATE,
    data_fim       DATE
);

CREATE TABLE system.experimento_variante (
    id_variante    SERIAL PRIMARY KEY,
    id_experimento INT NOT NULL REFERENCES system.experimento(id_experimento) ON DELETE CASCADE,
    nome           VARCHAR(50) NOT NULL,
    peso           NUMERIC(5,2) NOT NULL,
    config_json    JSONB,
    UNIQUE (id_experimento, nome)
);

CREATE TABLE system.experimento_usuario (
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_experimento INT NOT NULL REFERENCES system.experimento(id_experimento) ON DELETE CASCADE,
    id_variante    INT NOT NULL REFERENCES system.experimento_variante(id_variante) ON DELETE CASCADE,
    data_atribuicao TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id_usuario, id_experimento)
);

-- 6.6 Monetização
CREATE TABLE system.cupom (
    id_cupom           SERIAL PRIMARY KEY,
    codigo             VARCHAR(30) UNIQUE NOT NULL,
    tipo               VARCHAR(20) CHECK (tipo IN ('PERCENTUAL','FIXO','TRIAL')),
    valor              NUMERIC(10,2),
    validade_inicio    TIMESTAMPTZ,
    validade_fim       TIMESTAMPTZ,
    usos_maximos       INT,
    usos_atuais        INT DEFAULT 0,
    id_plano_aplicavel INT REFERENCES system.plano(id_plano),
    ativo              BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.cupom_uso (
    id_uso        BIGSERIAL PRIMARY KEY,
    id_cupom      INT NOT NULL REFERENCES system.cupom(id_cupom) ON DELETE RESTRICT,
    id_usuario    UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_assinatura BIGINT REFERENCES system.assinatura(id_assinatura) ON DELETE SET NULL,
    data_uso      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_cupom, id_usuario)
);

CREATE TABLE system.programa_indicacao (
    id_programa          SERIAL PRIMARY KEY,
    nome                 VARCHAR(100) NOT NULL,
    tipo                 VARCHAR(20) CHECK (tipo IN ('INDICACAO','AFILIADO')),
    comissao_percentual  NUMERIC(5,2),
    ativo                BOOLEAN DEFAULT TRUE
);

CREATE TABLE system.indicacao (
    id_indicacao         BIGSERIAL PRIMARY KEY,
    id_programa          INT NOT NULL REFERENCES system.programa_indicacao(id_programa) ON DELETE CASCADE,
    id_usuario_indicador UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_usuario_indicado  UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    data                 TIMESTAMPTZ DEFAULT NOW(),
    status               VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','CONVERTIDA','EXPIRADA','CANCELADA')),
    recompensa_paga      BOOLEAN DEFAULT FALSE,
    UNIQUE (id_usuario_indicado)
);

CREATE TABLE system.comissao (
    id_comissao   BIGSERIAL PRIMARY KEY,
    id_indicacao  BIGINT NOT NULL REFERENCES system.indicacao(id_indicacao) ON DELETE CASCADE,
    valor         NUMERIC(10,2) NOT NULL,
    status        VARCHAR(20) DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE','APROVADA','PAGA','CANCELADA')),
    data_pagamento DATE
);

CREATE TABLE system.dunning_evento (
    id_evento        BIGSERIAL PRIMARY KEY,
    id_assinatura    BIGINT NOT NULL REFERENCES system.assinatura(id_assinatura) ON DELETE CASCADE,
    tipo             VARCHAR(30) CHECK (tipo IN ('FALHA_PAGAMENTO','RETENTATIVA','CANCELAMENTO','REATIVACAO')),
    tentativa        INT DEFAULT 1,
    data             TIMESTAMPTZ DEFAULT NOW(),
    status           VARCHAR(20),
    proxima_tentativa TIMESTAMPTZ
);

CREATE TABLE system.reembolso (
    id_reembolso    BIGSERIAL PRIMARY KEY,
    id_pagamento    BIGINT NOT NULL REFERENCES system.pagamento(id_pagamento) ON DELETE RESTRICT,
    valor           NUMERIC(10,2) NOT NULL,
    motivo          VARCHAR(100),
    status          VARCHAR(20) DEFAULT 'SOLICITADO'
        CHECK (status IN ('SOLICITADO','APROVADO','PROCESSANDO','CONCLUIDO','NEGADO')),
    data_solicitacao TIMESTAMPTZ DEFAULT NOW(),
    data_processamento TIMESTAMPTZ,
    gateway_id      VARCHAR(100)
);

-- 6.7 Alertas e Notificações (granular)
CREATE TABLE system.alerta_disparo (
    id_disparo       BIGSERIAL,
    id_alerta        BIGINT NOT NULL REFERENCES system.alerta(id_alerta) ON DELETE CASCADE,
    data_disparo     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valor_no_disparo NUMERIC(18,6),
    canal_envio      VARCHAR(20),
    lido             BOOLEAN DEFAULT FALSE
);
SELECT create_hypertable('system.alerta_disparo','data_disparo', chunk_time_interval => INTERVAL '3 months');

CREATE TABLE system.preferencia_notificacao (
    id_preferencia SERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    tipo_evento    VARCHAR(50) NOT NULL,
    canal          VARCHAR(20) NOT NULL CHECK (canal IN ('EMAIL','PUSH','SMS','WHATSAPP','IN_APP')),
    frequencia     VARCHAR(20) DEFAULT 'IMEDIATO'
        CHECK (frequencia IN ('IMEDIATO','DIARIO','SEMANAL','DESATIVADO')),
    ativo          BOOLEAN DEFAULT TRUE,
    UNIQUE (id_usuario, tipo_evento, canal)
);

CREATE TABLE system.dispositivo (
    id_dispositivo BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    token_push     VARCHAR(300) NOT NULL UNIQUE,
    plataforma     VARCHAR(20) CHECK (plataforma IN ('IOS','ANDROID','WEB')),
    modelo         VARCHAR(80),
    versao_app     VARCHAR(20),
    ultimo_uso     TIMESTAMPTZ DEFAULT NOW(),
    ativo          BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_dispositivo_user ON system.dispositivo(id_usuario, ativo);

-- 6.8 Suporte e Feedback
CREATE TABLE system.ticket (
    id_ticket      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    assunto        VARCHAR(200) NOT NULL,
    categoria      VARCHAR(50),
    prioridade     VARCHAR(20) DEFAULT 'NORMAL'
        CHECK (prioridade IN ('BAIXA','NORMAL','ALTA','URGENTE')),
    status         VARCHAR(20) DEFAULT 'ABERTO'
        CHECK (status IN ('ABERTO','EM_ANDAMENTO','AGUARDANDO_USUARIO','RESOLVIDO','FECHADO')),
    atribuido_a    UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    data_abertura  TIMESTAMPTZ DEFAULT NOW(),
    data_fechamento TIMESTAMPTZ
);
CREATE INDEX idx_ticket_usuario ON system.ticket(id_usuario, status);
CREATE INDEX idx_ticket_status  ON system.ticket(status, prioridade);

CREATE TABLE system.ticket_mensagem (
    id_mensagem BIGSERIAL PRIMARY KEY,
    id_ticket   BIGINT NOT NULL REFERENCES system.ticket(id_ticket) ON DELETE CASCADE,
    id_usuario  UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    is_agente   BOOLEAN DEFAULT FALSE,
    conteudo    TEXT,
    anexos      JSONB,
    data        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE system.feedback (
    id_feedback BIGSERIAL PRIMARY KEY,
    id_usuario  UUID REFERENCES core.usuario(id_usuario) ON DELETE SET NULL,
    tipo        VARCHAR(20) CHECK (tipo IN ('NPS','CSAT','SUGESTAO','BUG','ELOGIO')),
    nota        INT CHECK (nota BETWEEN 0 AND 10),
    comentario  TEXT,
    contexto    VARCHAR(100),
    data        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_feedback_tipo_data ON system.feedback(tipo, data DESC);
