-- =========================================================
-- SCHEMA wealth
-- =========================================================
CREATE TABLE wealth.consentimento (
    id_consentimento BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    status         VARCHAR(20),
    validade       TIMESTAMPTZ,
    scopes         TEXT,
    data_criacao   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE wealth.instituicao_conectada (
    id_instituicao_conectada BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    id_instituicao INT NOT NULL,
    id_consentimento BIGINT REFERENCES wealth.consentimento(id_consentimento) ON DELETE CASCADE,
    data_conexao   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE wealth.conta_bancaria (
    id_conta       BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    id_instituicao_conectada BIGINT NOT NULL,
    agencia        VARCHAR(10),
    conta          VARCHAR(20),
    tipo           VARCHAR(30),
    saldo_disponivel NUMERIC(18,2),
    moeda          VARCHAR(3) DEFAULT 'BRL'
);

CREATE TABLE wealth.transacao_bancaria (
    id_transacao   BIGSERIAL,
    id_conta       BIGINT NOT NULL,
    data           TIMESTAMPTZ NOT NULL,
    valor          NUMERIC(18,2),
    debito_credito CHAR(1) CHECK (debito_credito IN ('D','C')),
    nomenclatura   VARCHAR(200),
    tipo           VARCHAR(20) CHECK (tipo IN ('PIX','TED','DOC','BOLETO','CARTAO'))
);
SELECT create_hypertable('wealth.transacao_bancaria','data', chunk_time_interval => INTERVAL '6 months');

CREATE TABLE wealth.cartao_credito (
    id_cartao      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    id_instituicao_conectada BIGINT NOT NULL,
    bandeira       VARCHAR(20),
    limite         NUMERIC(18,2),
    fatura_atual   NUMERIC(18,2),
    vencimento     DATE
);

CREATE TABLE wealth.emprestimo (
    id_emprestimo  BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    credor         VARCHAR(100),
    valor_original NUMERIC(18,2),
    saldo_devedor  NUMERIC(18,2),
    taxa_juros     NUMERIC(6,4),
    parcelas       INT,
    data_contratacao DATE,
    data_vencimento DATE
);

CREATE TABLE wealth.financiamento (
    id_financiamento BIGSERIAL PRIMARY KEY,
    id_usuario       UUID NOT NULL,
    credor           VARCHAR(100),
    tipo             VARCHAR(30),
    valor_original   NUMERIC(18,2),
    saldo_devedor    NUMERIC(18,2),
    taxa_juros       NUMERIC(6,4),
    prazo            INT,
    parcelas         INT
);

CREATE TABLE wealth.imovel (
    id_imovel      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    descricao      VARCHAR(200),
    endereco       TEXT,
    valor_mercado  NUMERIC(18,2),
    data_aquisicao DATE,
    tipo           VARCHAR(30)
);

CREATE TABLE wealth.veiculo (
    id_veiculo     BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    descricao      VARCHAR(200),
    valor_mercado  NUMERIC(18,2),
    ano            INT,
    placa          VARCHAR(10)
);

CREATE TABLE wealth.outros_bens (
    id_bem         BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    descricao      VARCHAR(200),
    valor_mercado  NUMERIC(18,2)
);

CREATE TABLE wealth.seguro (
    id_seguro      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    tipo           VARCHAR(30),
    seguradora     VARCHAR(100),
    cobertura      NUMERIC(18,2),
    premio_mensal  NUMERIC(18,2),
    vigencia_inicio DATE,
    vigencia_fim   DATE
);

CREATE TABLE wealth.previdencia_privada (
    id_previdencia BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    tipo           VARCHAR(10) CHECK (tipo IN ('PGBL','VGBL')),
    seguradora     VARCHAR(100),
    saldo          NUMERIC(18,2),
    aporte_mensal  NUMERIC(18,2),
    taxa_carregamento NUMERIC(6,4)
);

CREATE TABLE wealth.consorcio (
    id_consorcio   BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    tipo           VARCHAR(30),
    valor_carta    NUMERIC(18,2),
    parcela        NUMERIC(18,2),
    parcelas_pagas INT,
    parcelas_total INT
);

CREATE TABLE wealth.planejamento_sucessorio (
    id_planejamento BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL,
    tipo            VARCHAR(30),
    descricao       TEXT,
    data_atualizacao DATE
);

CREATE TABLE wealth.patrimonio_global (
    id_patrimonio  BIGSERIAL,
    id_usuario     UUID NOT NULL,
    data_referencia DATE NOT NULL,
    total_ativos   NUMERIC(18,2),
    total_passivos NUMERIC(18,2),
    patrimonio_liquido NUMERIC(18,2),
    PRIMARY KEY (id_patrimonio, data_referencia)
);

CREATE TABLE wealth.investimento_exterior (
    id_investimento BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL,
    pais            VARCHAR(3),
    tipo            VARCHAR(30),
    id_ativo        INT,
    ticker          VARCHAR(20),
    quantidade      NUMERIC(18,6),
    preco_medio     NUMERIC(12,4),
    moeda           VARCHAR(3),
    corretora_exterior VARCHAR(100),
    data_aquisicao  DATE
);

CREATE TABLE wealth.divida_externa (
    id_divida      BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    credor         VARCHAR(100),
    moeda          VARCHAR(3),
    saldo_devedor  NUMERIC(18,2),
    taxa_juros     NUMERIC(6,4),
    data_vencimento DATE,
    parcela_mensal NUMERIC(18,2)
);

CREATE TABLE wealth.meta_financeira (
    id_meta        BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    nome           VARCHAR(100),
    valor_alvo     NUMERIC(18,2),
    prazo          DATE,
    valor_acumulado NUMERIC(18,2) DEFAULT 0,
    progresso_percentual NUMERIC(6,2) GENERATED ALWAYS AS
        (CASE WHEN valor_alvo > 0 THEN (valor_acumulado/valor_alvo)*100 ELSE 0 END) STORED
);

CREATE TABLE wealth.simulador (
    id_simulacao   BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    nome           VARCHAR(100),
    parametros_json JSONB,
    data_criacao   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE wealth.rebalanceamento (
    id_rebalanceamento BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    id_carteira    UUID,
    regras_json    JSONB,
    data_criacao   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE wealth.apuracao_ir (
    id_apuracao    BIGSERIAL PRIMARY KEY,
    id_usuario     UUID NOT NULL,
    mes_referencia DATE NOT NULL,
    tipo_operacao  wealth.tipo_ir_enum NOT NULL,
    ganho_liquido  NUMERIC(14,2),
    imposto_devido NUMERIC(14,2),
    irrf_retido    NUMERIC(14,2),
    prejuizo_acumulado NUMERIC(14,2),
    darf_gerado    NUMERIC(14,2),
    data_vencimento DATE,
    pago           BOOLEAN DEFAULT FALSE,
    UNIQUE (id_usuario, mes_referencia, tipo_operacao)
);

CREATE TABLE wealth.planejamento_tributario (
    id_planejamento BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL,
    ano_referencia  INT,
    estrategia      VARCHAR(60),
    beneficio_estimado NUMERIC(14,2)
);
