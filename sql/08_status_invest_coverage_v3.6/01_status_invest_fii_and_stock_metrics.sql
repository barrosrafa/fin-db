-- ==============================================================================
-- Migration: 01_status_invest_fii_and_stock_metrics.sql
-- Description: Suporte a métricas e indicadores de Ações e FIIs do Status Invest:
--              1. Extensão de asset_details.detalhe_fii com indicadores operacionais/fundamentalistas
--              2. Adequação de precisão numérica em analytics.indicador_fundamentalista para ativos B3 extremos
--              3. Seed de modalidades de gestão em asset_details.tipo_gestao_fii
--              4. Registro canônico de métricas em canonical.metric_definition
-- ==============================================================================

-- 1. Seed de Tipos de Gestão de FIIs
INSERT INTO asset_details.tipo_gestao_fii (nome) 
VALUES ('Ativa'), ('Passiva')
ON CONFLICT (nome) DO NOTHING;

-- 2. Extensão de colunas em asset_details.detalhe_fii para suportar o schema Status Invest
ALTER TABLE asset_details.detalhe_fii
    ADD COLUMN IF NOT EXISTS ultimo_dividendo NUMERIC(15, 6),
    ADD COLUMN IF NOT EXISTS valor_patrimonial_cota NUMERIC(15, 4),
    ADD COLUMN IF NOT EXISTS pvp NUMERIC(15, 4),
    ADD COLUMN IF NOT EXISTS dividend_yield NUMERIC(15, 4),
    ADD COLUMN IF NOT EXISTS percentual_em_caixa NUMERIC(15, 4),
    ADD COLUMN IF NOT EXISTS cagr_dividendos_3a NUMERIC(15, 4),
    ADD COLUMN IF NOT EXISTS cagr_valor_cota_3a NUMERIC(15, 4),
    ADD COLUMN IF NOT EXISTS patrimonio_liquido NUMERIC(20, 2),
    ADD COLUMN IF NOT EXISTS quantidade_cotas BIGINT;

COMMENT ON COLUMN asset_details.detalhe_fii.ultimo_dividendo IS 'Valor em reais (R$) do provento distribuído no último anúncio/mês';
COMMENT ON COLUMN asset_details.detalhe_fii.valor_patrimonial_cota IS 'Valor patrimonial por cota (VPA do FII) calculado no último informe';
COMMENT ON COLUMN asset_details.detalhe_fii.pvp IS 'Razão Preço / Valor Patrimonial da cota do FII';
COMMENT ON COLUMN asset_details.detalhe_fii.dividend_yield IS 'Dividend Yield percentual acumulado em 12 meses';
COMMENT ON COLUMN asset_details.detalhe_fii.percentual_em_caixa IS 'Percentual do patrimônio líquido mantido em disponibilidades/caixa';
COMMENT ON COLUMN asset_details.detalhe_fii.cagr_dividendos_3a IS 'Taxa de crescimento anual composta dos proventos nos últimos 3 anos (%)';
COMMENT ON COLUMN asset_details.detalhe_fii.cagr_valor_cota_3a IS 'Taxa de crescimento anual composta do valor patrimonial da cota nos últimos 3 anos (%)';
COMMENT ON COLUMN asset_details.detalhe_fii.patrimonio_liquido IS 'Patrimônio Líquido total do Fundo Imobiliário em reais (R$)';
COMMENT ON COLUMN asset_details.detalhe_fii.quantidade_cotas IS 'Número total de cotas emitidas pelo fundo';

-- 3. Adequação de precisão em analytics.indicador_fundamentalista para acomodar ativos reais extremos (RJ, centavos, etc.)
ALTER TABLE analytics.indicador_fundamentalista
    ALTER COLUMN pl TYPE NUMERIC(18, 4),
    ALTER COLUMN pvp TYPE NUMERIC(18, 4),
    ALTER COLUMN psr TYPE NUMERIC(18, 4),
    ALTER COLUMN dividend_yield TYPE NUMERIC(18, 4),
    ALTER COLUMN payout TYPE NUMERIC(18, 4),
    ALTER COLUMN roe TYPE NUMERIC(18, 4),
    ALTER COLUMN roic TYPE NUMERIC(18, 4),
    ALTER COLUMN ebitda_margem TYPE NUMERIC(18, 4),
    ALTER COLUMN margem_liquida TYPE NUMERIC(18, 4),
    ALTER COLUMN divida_liquida_ebitda TYPE NUMERIC(18, 4),
    ALTER COLUMN lpa TYPE NUMERIC(18, 4),
    ALTER COLUMN vpa TYPE NUMERIC(18, 4),
    ALTER COLUMN ev_ebitda TYPE NUMERIC(18, 4),
    ALTER COLUMN ev_ebit TYPE NUMERIC(18, 4),
    ALTER COLUMN liquidez_corrente TYPE NUMERIC(18, 4),
    ALTER COLUMN giro_ativo TYPE NUMERIC(18, 4),
    ALTER COLUMN peg_ratio TYPE NUMERIC(18, 4),
    ALTER COLUMN p_ebitda TYPE NUMERIC(18, 4),
    ALTER COLUMN p_ebit TYPE NUMERIC(18, 4),
    ALTER COLUMN p_ativo TYPE NUMERIC(18, 4),
    ALTER COLUMN p_cap_giro TYPE NUMERIC(18, 4),
    ALTER COLUMN p_ativo_circ_liq TYPE NUMERIC(18, 4),
    ALTER COLUMN p_fco TYPE NUMERIC(18, 4),
    ALTER COLUMN p_fcl TYPE NUMERIC(18, 4),
    ALTER COLUMN ev_receita TYPE NUMERIC(18, 4),
    ALTER COLUMN divida_liquida_pl TYPE NUMERIC(18, 4),
    ALTER COLUMN divida_bruta_pl TYPE NUMERIC(18, 4),
    ALTER COLUMN divida_liquida_ebit TYPE NUMERIC(18, 4),
    ALTER COLUMN patrimonio_ativos TYPE NUMERIC(18, 4),
    ALTER COLUMN passivos_ativos TYPE NUMERIC(18, 4),
    ALTER COLUMN margem_bruta TYPE NUMERIC(18, 4),
    ALTER COLUMN margem_ebit TYPE NUMERIC(18, 4),
    ALTER COLUMN roa TYPE NUMERIC(18, 4),
    ALTER COLUMN ebit_ativo TYPE NUMERIC(18, 4),
    ALTER COLUMN liquidez_seca TYPE NUMERIC(18, 4),
    ALTER COLUMN liquidez_imediata TYPE NUMERIC(18, 4),
    ALTER COLUMN cobertura_juros TYPE NUMERIC(18, 4),
    ALTER COLUMN cagr_receita_5a TYPE NUMERIC(18, 4),
    ALTER COLUMN cagr_lucro_5a TYPE NUMERIC(18, 4),
    ALTER COLUMN buyback_yield TYPE NUMERIC(18, 4),
    ALTER COLUMN total_yield TYPE NUMERIC(18, 4),
    ALTER COLUMN payout_total TYPE NUMERIC(18, 4),
    ALTER COLUMN fco_por_acao TYPE NUMERIC(18, 4),
    ALTER COLUMN fcl_por_acao TYPE NUMERIC(18, 4),
    ALTER COLUMN vpta TYPE NUMERIC(18, 4),
    ALTER COLUMN valor_mercado TYPE NUMERIC(24, 2),
    ALTER COLUMN enterprise_value TYPE NUMERIC(24, 2);

-- 4. Registro Canônico de Novas Métricas de FIIs (canonical.metric_definition)
INSERT INTO canonical.metric_definition (code, name, category, default_unit, higher_is_better, description)
VALUES 
    ('FII_ULTIMO_DIVIDENDO', 'Último Dividendo por Cota', 'FII_YIELD', 'BRL', true, 'Último provento mensal por cota anunciado pelo FII'),
    ('FII_VALOR_PATRIMONIAL_COTA', 'Valor Patrimonial por Cota', 'VALUATION', 'BRL', true, 'Valor Patrimonial por Cota do FII'),
    ('FII_PERCENTUAL_CAIXA', 'Percentual em Caixa', 'LIQUIDITY', '%', null, 'Percentual do patrimônio alocado em liquidez/caixa'),
    ('FII_CAGR_DIVIDENDOS_3A', 'CAGR Dividendos 3 Anos', 'GROWTH', '%', true, 'Crescimento composto anualizado dos dividendos em 3 anos'),
    ('FII_CAGR_VALOR_COTA_3A', 'CAGR Valor da Cota 3 Anos', 'GROWTH', '%', true, 'Crescimento composto anualizado do valor patrimonial da cota em 3 anos')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    default_unit = EXCLUDED.default_unit,
    higher_is_better = EXCLUDED.higher_is_better,
    description = EXCLUDED.description;
