-- Mantém apenas a definição das materialized views; nenhuma linha é retida/populada.
REFRESH MATERIALIZED VIEW analytics.busca_ativo WITH NO DATA;
REFRESH MATERIALIZED VIEW analytics.cagg_cotacao_mensal WITH NO DATA;
REFRESH MATERIALIZED VIEW analytics.cagg_provento_mensal WITH NO DATA;
REFRESH MATERIALIZED VIEW analytics.mv_acoes_consistencia_lucro WITH NO DATA;
