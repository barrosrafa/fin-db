-- =========================================================
-- 24. API DATA ACCESS OBJECTS v4.6
-- Views, table-valued functions, write functions and user audit triggers.
-- This migration is additive and intentionally contains no direct row DML.
-- =========================================================

CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS billing;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS market;

-- Stable read contract for the dividend seasonality API.
CREATE OR REPLACE VIEW analytics.vw_dividend_map
WITH (security_invoker = true)
AS
SELECT
    a.id_ativo,
    a.ticker,
    COALESCE(ec.nome_empresarial, a.ticker) AS nome,
    a.tipo_ativo::text AS tipo,
    s.mes_calendario,
    s.tipo_evento,
    s.probabilidade_pct,
    s.valor_medio_provento,
    s.ultimo_ano_pago
FROM analytics.mapa_sazonalidade_dividendo AS s
JOIN core.ativo AS a ON a.id_ativo = s.id_ativo
LEFT JOIN core.emissor_companhia AS ec ON ec.id_emissor = a.id_emissor;

CREATE INDEX IF NOT EXISTS idx_mapa_sazonalidade_api
    ON analytics.mapa_sazonalidade_dividendo (mes_calendario, probabilidade_pct DESC);

-- Stable read contract for the latest value of each benchmark.
CREATE OR REPLACE VIEW market.vw_benchmark_latest
WITH (security_invoker = true)
AS
SELECT DISTINCT ON (b.id_benchmark)
    b.id_benchmark,
    b.codigo,
    b.nome,
    b.fonte AS source,
    s.data_referencia,
    s.valor AS last_val
FROM market.benchmark AS b
JOIN market.benchmark_serie AS s ON s.id_benchmark = b.id_benchmark
WHERE b.codigo IN ('IBOV', 'IFIX', 'USDBRL', 'SELIC', 'SPX', 'BTCBRL')
ORDER BY b.id_benchmark, s.data_referencia DESC;

-- Read-optimized contract for benchmark cards and their seven-point sparkline.
CREATE MATERIALIZED VIEW IF NOT EXISTS market.mv_benchmarks AS
SELECT
    latest.id_benchmark,
    latest.codigo,
    latest.nome,
    latest.source,
    latest.data_referencia,
    latest.last_val,
    CASE
        WHEN points.previous_val IS NULL OR points.previous_val = 0 THEN NULL
        ELSE ((latest.last_val - points.previous_val) / points.previous_val) * 100
    END AS last_change,
    points.sparkline
FROM market.vw_benchmark_latest AS latest
LEFT JOIN LATERAL (
    SELECT
        array_agg(x.valor ORDER BY x.data_referencia ASC) AS sparkline,
        (array_agg(x.valor ORDER BY x.data_referencia DESC))[2] AS previous_val
    FROM (
        SELECT s.valor, s.data_referencia
        FROM market.benchmark_serie AS s
        WHERE s.id_benchmark = latest.id_benchmark
        ORDER BY s.data_referencia DESC
        LIMIT 7
    ) AS x
) AS points ON TRUE
WITH NO DATA;

CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_benchmarks_codigo
    ON market.mv_benchmarks (codigo);

-- Parameterized dividend calendar contract. SECURITY INVOKER preserves RLS.
CREATE OR REPLACE FUNCTION analytics.fn_dividend_calendar(
    p_limit      integer DEFAULT 50,
    p_offset     integer DEFAULT 0,
    p_event_type text DEFAULT 'ALL',
    p_status     text DEFAULT NULL,
    p_ticker     text DEFAULT NULL
)
RETURNS TABLE (
    id_provento       bigint,
    ticker            varchar,
    tipo              text,
    data_com          date,
    data_ex           date,
    data_pagamento    date,
    status            text,
    valor_bruto       numeric,
    aliquota_ir       numeric,
    valor_liquido     numeric,
    cotacao           numeric,
    yield_evento_pct  numeric,
    moeda             varchar
)
LANGUAGE sql
SECURITY INVOKER
STABLE
AS $$
    SELECT
        p.id_provento,
        a.ticker,
        p.tipo_provento::text,
        p.data_com,
        p.data_ex,
        p.data_pagamento,
        CASE WHEN p.data_pagamento >= CURRENT_DATE THEN 'FUTURO' ELSE 'PAGO' END,
        COALESCE(p.valor_por_acao, 0.0),
        COALESCE(p.aliquota_retencao_fonte,
                 CASE WHEN p.tipo_provento::text = 'JCP' THEN 15.0 ELSE 0.0 END),
        COALESCE(p.valor_por_acao, 0.0) *
            (1 - COALESCE(p.aliquota_retencao_fonte,
                 CASE WHEN p.tipo_provento::text = 'JCP' THEN 15.0 ELSE 0.0 END) / 100.0),
        quote.preco_fechamento,
        (COALESCE(p.valor_por_acao, 0.0) *
            (1 - COALESCE(p.aliquota_retencao_fonte,
                 CASE WHEN p.tipo_provento::text = 'JCP' THEN 15.0 ELSE 0.0 END) / 100.0)) /
            NULLIF(quote.preco_fechamento, 0) * 100,
        COALESCE(p.moeda, 'BRL')
    FROM market.provento AS p
    JOIN core.ativo AS a ON a.id_ativo = p.id_ativo
    LEFT JOIN LATERAL (
        SELECT cd.preco_fechamento
        FROM market.cotacao_diaria AS cd
        WHERE cd.id_ativo = a.id_ativo
        ORDER BY cd.data_pregao DESC
        LIMIT 1
    ) AS quote ON TRUE
    WHERE p.data_com IS NOT NULL
      AND (upper(COALESCE(p_event_type, 'ALL')) = 'ALL'
           OR p.tipo_provento::text = upper(p_event_type))
      AND (p_status IS NULL OR upper(p_status) = 'ALL'
           OR CASE WHEN p.data_pagamento >= CURRENT_DATE THEN 'FUTURO' ELSE 'PAGO' END = upper(p_status))
      AND (p_ticker IS NULL OR a.ticker = upper(trim(p_ticker)))
    ORDER BY CASE WHEN p.data_pagamento >= CURRENT_DATE THEN 0 ELSE 1 END,
             p.data_com DESC
    LIMIT GREATEST(p_limit, 0) OFFSET GREATEST(p_offset, 0);
$$;

CREATE OR REPLACE FUNCTION analytics.fn_dividend_calendar_count(
    p_event_type text DEFAULT 'ALL',
    p_status     text DEFAULT NULL,
    p_ticker     text DEFAULT NULL
)
RETURNS bigint
LANGUAGE sql
SECURITY INVOKER
STABLE
AS $$
    SELECT count(*)
    FROM market.provento AS p
    JOIN core.ativo AS a ON a.id_ativo = p.id_ativo
    WHERE p.data_com IS NOT NULL
      AND (upper(COALESCE(p_event_type, 'ALL')) = 'ALL'
           OR p.tipo_provento::text = upper(p_event_type))
      AND (p_status IS NULL OR upper(p_status) = 'ALL'
           OR CASE WHEN p.data_pagamento >= CURRENT_DATE THEN 'FUTURO' ELSE 'PAGO' END = upper(p_status))
      AND (p_ticker IS NULL OR a.ticker = upper(trim(p_ticker)));
$$;

-- Transactional, idempotent write contracts for billing.
CREATE OR REPLACE FUNCTION core.fn_update_user_tier(p_email text, p_tier text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
AS $$
    UPDATE core.usuario
       SET tier = p_tier
     WHERE email = p_email;
$$;

CREATE OR REPLACE FUNCTION billing.fn_process_webhook(
    p_event_id       text,
    p_gateway        text,
    p_event_type     text,
    p_payload        jsonb,
    p_customer_email text,
    p_plan_tier      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
    IF p_event_type IN ('PAYMENT_RECEIVED', 'PAYMENT_CONFIRMED', 'invoice.payment_succeeded')
       AND p_customer_email IS NOT NULL THEN
        PERFORM core.fn_update_user_tier(p_customer_email, p_plan_tier);
    END IF;

    INSERT INTO billing.webhook_inbox
        (event_id, gateway_provider, event_type, payload, status, processed_at)
    VALUES
        (p_event_id, p_gateway, p_event_type, COALESCE(p_payload, '{}'::jsonb), 'PROCESSED', NOW())
    ON CONFLICT (event_id) DO UPDATE
       SET status = 'PROCESSED', processed_at = NOW(),
           error_message = NULL;
END;
$$;

-- User audit is explicit because the current schema has no webhook_audit table.
ALTER TABLE core.usuario
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS core.usuario_audit (
    id_auditoria     bigserial PRIMARY KEY,
    id_usuario       uuid,
    operacao         varchar(10) NOT NULL,
    dados_antigos    jsonb,
    dados_novos      jsonb,
    usuario_executor text NOT NULL DEFAULT current_user,
    ocorrido_em      timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION core.fn_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION core.fn_audit_usuario()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO core.usuario_audit (id_usuario, operacao, dados_novos)
        VALUES (NEW.id_usuario, 'INSERT', to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO core.usuario_audit (id_usuario, operacao, dados_antigos, dados_novos)
        VALUES (NEW.id_usuario, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
    ELSE
        INSERT INTO core.usuario_audit (id_usuario, operacao, dados_antigos)
        VALUES (OLD.id_usuario, 'DELETE', to_jsonb(OLD));
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_usuario_updated_at ON core.usuario;
CREATE TRIGGER trg_usuario_updated_at
BEFORE UPDATE ON core.usuario
FOR EACH ROW EXECUTE FUNCTION core.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_usuario_audit ON core.usuario;
CREATE TRIGGER trg_usuario_audit
AFTER INSERT OR UPDATE OR DELETE ON core.usuario
FOR EACH ROW EXECUTE FUNCTION core.fn_audit_usuario();

-- Runtime contracts are explicit; no blanket privileges are added.
GRANT USAGE ON SCHEMA analytics, billing, core, market TO fin_api_rw;
GRANT SELECT ON analytics.vw_dividend_map,
               market.vw_benchmark_latest,
               market.mv_benchmarks TO fin_api_rw, fin_readonly_public;
GRANT EXECUTE ON FUNCTION analytics.fn_dividend_calendar(integer, integer, text, text, text),
                 analytics.fn_dividend_calendar_count(text, text, text),
                 billing.fn_process_webhook(text, text, text, jsonb, text, text),
                 core.fn_update_user_tier(text, text) TO fin_api_rw;
GRANT INSERT ON core.usuario_audit TO fin_api_rw;
GRANT USAGE, SELECT ON SEQUENCE core.usuario_audit_id_auditoria_seq TO fin_api_rw;
