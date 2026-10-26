-- =========================================================
-- 5. WEALTH: Novas tabelas
-- =========================================================

-- 5.1 Aportes Programados (Recurring Investments)
CREATE TABLE wealth.aporte_programado (
    id_aporte       BIGSERIAL PRIMARY KEY,
    id_usuario      UUID NOT NULL REFERENCES core.usuario(id_usuario) ON DELETE CASCADE,
    id_carteira     UUID NOT NULL REFERENCES core.carteira(id_carteira) ON DELETE CASCADE,
    id_ativo        INT NOT NULL REFERENCES core.ativo(id_ativo) ON DELETE CASCADE,
    valor           NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    frequencia      VARCHAR(20) CHECK (frequencia IN ('SEMANAL','QUINZENAL','MENSAL','BIMESTRAL','TRIMESTRAL')),
    dia_execucao    INT,
    data_inicio     DATE NOT NULL,
    data_fim        DATE,
    status          VARCHAR(20) DEFAULT 'ATIVO' CHECK (status IN ('ATIVO','PAUSADO','ENCERRADO')),
    ultima_execucao DATE,
    proxima_execucao DATE,
    data_criacao    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_aporte_usuario ON wealth.aporte_programado(id_usuario, status);

CREATE TABLE wealth.aporte_execucao (
    id_execucao    BIGSERIAL PRIMARY KEY,
    id_aporte      BIGINT NOT NULL REFERENCES wealth.aporte_programado(id_aporte) ON DELETE CASCADE,
    data           DATE NOT NULL,
    valor_executado NUMERIC(14,2),
    cotacao        NUMERIC(12,4),
    quantidade_comprada NUMERIC(18,6),
    id_transacao   BIGINT REFERENCES core.transacao_operacao(id_transacao) ON DELETE SET NULL,
    status         VARCHAR(20) CHECK (status IN ('EXECUTADO','FALHOU','CANCELADO','PENDENTE')),
    erro_mensagem  TEXT
);
CREATE INDEX idx_aporte_exec_aporte ON wealth.aporte_execucao(id_aporte, data DESC);
