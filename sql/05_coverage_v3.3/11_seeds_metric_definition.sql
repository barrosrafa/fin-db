-- =========================================================
-- M10: canonical.metric_definition (Catálogo de Indicadores Fundamentalistas)
-- Cobertura: Fundamentus, Fundamentei, analisedeacoes.com
-- =========================================================

-- Extensão não-bloqueante para suporte a orientação de métrica (higher is better)
ALTER TABLE canonical.metric_definition
    ADD COLUMN IF NOT EXISTS higher_is_better BOOLEAN;

-- Carga idempotente de novos indicadores de análise
INSERT INTO canonical.metric_definition (code, name, description, default_unit, category, higher_is_better)
VALUES
    ('pl', 'Preço/Lucro', 'Relação preço sobre lucro', 'ratio', 'valuation', false),
    ('pvp', 'Preço/Valor Patrimonial', 'Preço sobre valor patrimonial', 'ratio', 'valuation', false),
    ('psr', 'Preço/Receita', 'Preço sobre receita', 'ratio', 'valuation', false),
    ('dy', 'Dividend Yield', 'Dividendos sobre preço', 'percent', 'proventos', true),
    ('roe', 'ROE', 'Retorno sobre patrimônio líquido', 'percent', 'rentabilidade', true),
    ('roic', 'ROIC', 'Retorno sobre capital investido', 'percent', 'rentabilidade', true),
    ('roa', 'ROA', 'Retorno sobre ativos', 'percent', 'rentabilidade', true),
    ('ev_ebitda', 'EV/EBITDA', 'Enterprise value sobre EBITDA', 'ratio', 'valuation', false),
    ('ev_ebit', 'EV/EBIT', 'Enterprise value sobre EBIT', 'ratio', 'valuation', false),
    ('margem_bruta', 'Margem Bruta', 'Lucro bruto sobre receita', 'percent', 'rentabilidade', true),
    ('margem_ebit', 'Margem EBIT', 'EBIT sobre receita', 'percent', 'rentabilidade', true),
    ('margem_liquida', 'Margem Líquida', 'Lucro líquido sobre receita', 'percent', 'rentabilidade', true),
    ('liquidez_corrente', 'Liquidez Corrente', 'Ativo circulante sobre passivo circulante', 'ratio', 'liquidez', true),
    ('divida_ebitda', 'Dívida Líquida/EBITDA', 'Dívida líquida sobre EBITDA', 'ratio', 'endividamento', false),
    ('divida_pl', 'Dívida/Patrimônio', 'Dívida sobre patrimônio líquido', 'ratio', 'endividamento', false),
    ('cagr_receita_5a', 'CAGR Receita 5a', 'Crescimento anual composto da receita em 5 anos', 'percent', 'crescimento', true),
    ('cagr_lucro_5a', 'CAGR Lucro 5a', 'Crescimento anual composto do lucro em 5 anos', 'percent', 'crescimento', true),
    ('payout', 'Payout', 'Payout de dividendos', 'percent', 'proventos', null),
    ('graham_preco_justo', 'Preço Justo Graham', 'Preço justo pela fórmula de Graham', 'currency', 'valuation', true),
    ('bazin_preco_justo', 'Preço Justo Bazin', 'Preço justo pelo método Bazin', 'currency', 'valuation', true)
ON CONFLICT (code) DO NOTHING;
