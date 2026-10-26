-- =========================================================
-- CONTINUOUS AGGREGATES
-- =========================================================
CREATE MATERIALIZED VIEW analytics.cagg_cotacao_mensal
AS
SELECT
    id_ativo,
    time_bucket('1 month', data_pregao) AS mes,
    first(preco_abertura, data_pregao) AS preco_abertura,
    max(preco_maximo) AS preco_maximo,
    min(preco_minimo) AS preco_minimo,
    last(preco_fechamento, data_pregao) AS preco_fechamento,
    sum(volume_total) AS volume_total
FROM market.cotacao_diaria
GROUP BY id_ativo, mes;

-- [Timescale Cloud Only]: SELECT add_continuous_aggregate_policy('analytics.cagg_cotacao_mensal',
    start_offset => INTERVAL '10 years',
    end_offset   => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');
