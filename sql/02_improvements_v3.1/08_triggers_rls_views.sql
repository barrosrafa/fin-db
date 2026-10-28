-- =========================================================
-- 7. TRIGGERS, FUNÇÕES E RLS
-- =========================================================

-- 7.1 Função genérica de auditoria
CREATE OR REPLACE FUNCTION system.fn_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO system.auditoria_log (operacao, tabela, registro_id, old_value)
        VALUES ('DELETE', TG_TABLE_NAME, OLD.id::text, to_jsonb(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO system.auditoria_log (operacao, tabela, registro_id, old_value, new_value)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id::text, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO system.auditoria_log (operacao, tabela, registro_id, new_value)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id::text, to_jsonb(NEW));
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 7.2 Aplicar em tabelas críticas (exemplos)
CREATE TRIGGER trg_audit_posicao
    AFTER INSERT OR UPDATE OR DELETE ON core.posicao_custodia
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

CREATE TRIGGER trg_audit_carteira
    AFTER INSERT OR UPDATE OR DELETE ON core.carteira
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

CREATE TRIGGER trg_audit_ordem
    AFTER INSERT OR UPDATE OR DELETE ON core.ordem
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

CREATE TRIGGER trg_audit_apuracao_ir
    AFTER INSERT OR UPDATE OR DELETE ON wealth.apuracao_ir
    FOR EACH ROW EXECUTE FUNCTION system.fn_auditoria();

-- 7.3 Trigger de updated_at automático
CREATE OR REPLACE FUNCTION system.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_carteira_updated
    BEFORE UPDATE ON core.carteira
    FOR EACH ROW EXECUTE FUNCTION system.fn_set_updated_at();

CREATE TRIGGER trg_ordem_updated
    BEFORE UPDATE ON core.ordem
    FOR EACH ROW EXECUTE FUNCTION system.fn_set_updated_at();

-- 7.4 RLS — Row Level Security
ALTER TABLE core.carteira            ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.posicao_custodia    ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.nota_corretagem     ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.transacao_operacao  ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.ordem               ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.lote_ativo          ENABLE ROW LEVEL SECURITY;
ALTER TABLE wealth.apuracao_ir       ENABLE ROW LEVEL SECURITY;
ALTER TABLE wealth.meta_financeira   ENABLE ROW LEVEL SECURITY;
ALTER TABLE social.watchlist         ENABLE ROW LEVEL SECURITY;
ALTER TABLE social.anotacao_ativo    ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.api_key           ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.dispositivo       ENABLE ROW LEVEL SECURITY;

-- Políticas idempotentes (usuário só vê suas carteiras com validação segura de UUID)
DROP POLICY IF EXISTS p_carteira_owner ON core.carteira;
CREATE POLICY p_carteira_owner ON core.carteira
    FOR ALL
    USING (id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid);

DROP POLICY IF EXISTS p_posicao_owner ON core.posicao_custodia;
CREATE POLICY p_posicao_owner ON core.posicao_custodia
    FOR ALL
    USING (id_carteira IN (
        SELECT id_carteira FROM core.carteira
        WHERE id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid
    ));

DROP POLICY IF EXISTS p_ordem_owner ON core.ordem;
CREATE POLICY p_ordem_owner ON core.ordem
    FOR ALL
    USING (id_carteira IN (
        SELECT id_carteira FROM core.carteira
        WHERE id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid
    ));

DROP POLICY IF EXISTS p_lote_owner ON core.lote_ativo;
CREATE POLICY p_lote_owner ON core.lote_ativo
    FOR ALL
    USING (id_carteira IN (
        SELECT id_carteira FROM core.carteira
        WHERE id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid
    ));

DROP POLICY IF EXISTS p_ir_owner ON wealth.apuracao_ir;
CREATE POLICY p_ir_owner ON wealth.apuracao_ir
    FOR ALL
    USING (id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid);

DROP POLICY IF EXISTS p_watchlist_owner ON social.watchlist;
CREATE POLICY p_watchlist_owner ON social.watchlist
    FOR ALL
    USING (id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid);

DROP POLICY IF EXISTS p_anotacao_owner ON social.anotacao_ativo;
CREATE POLICY p_anotacao_owner ON social.anotacao_ativo
    FOR ALL
    USING (id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid);

DROP POLICY IF EXISTS p_apikey_owner ON system.api_key;
CREATE POLICY p_apikey_owner ON system.api_key
    FOR ALL
    USING (id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid);

DROP POLICY IF EXISTS p_dispositivo_owner ON system.dispositivo;
CREATE POLICY p_dispositivo_owner ON system.dispositivo
    FOR ALL
    USING (id_usuario = NULLIF(current_setting('app.current_user_id', TRUE), '')::uuid);

-- 7.5 Views úteis para o app
CREATE OR REPLACE VIEW core.v_posicao_atual AS
SELECT
    pc.id_posicao,
    pc.id_carteira,
    pc.id_ativo,
    a.ticker,
    a.tipo_ativo,
    pc.quantidade_total,
    pc.quantidade_disponivel,
    pc.quantidade_bloqueada,
    pc.preco_medio_ponderado,
    pc.preco_atual,
    pc.valor_mercado,
    pc.rentabilidade,
    pc.data_ultima_atualizacao
FROM core.posicao_custodia pc
JOIN core.ativo a ON a.id_ativo = pc.id_ativo
WHERE pc.quantidade_total > 0;

CREATE OR REPLACE VIEW wealth.v_patrimonio_resumo AS
SELECT
    id_usuario,
    data_referencia,
    total_ativos,
    total_passivos,
    patrimonio_liquido,
    total_ativos - LAG(total_ativos) OVER (PARTITION BY id_usuario ORDER BY data_referencia) AS variacao
FROM wealth.patrimonio_global
ORDER BY id_usuario, data_referencia DESC;

-- 7.6 Continuous Aggregates adicionais
CREATE MATERIALIZED VIEW analytics.cagg_provento_mensal
AS
SELECT
    id_ativo,
    time_bucket('1 month', data_pagamento) AS mes,
    sum(valor_por_acao) AS total_pago,
    count(*) AS num_eventos
FROM market.provento
WHERE data_pagamento IS NOT NULL
GROUP BY id_ativo, mes;

-- [Timescale Cloud Only]: SELECT add_continuous_aggregate_policy('analytics.cagg_provento_mensal',
    start_offset => INTERVAL '10 years',
    end_offset   => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');
