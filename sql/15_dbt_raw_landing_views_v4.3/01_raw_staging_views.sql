-- =============================================================================
-- 15. DBT RAW STAGING VIEWS (v4.3)
-- Ponte Operacional entre a tabela unificada raw.payload e os 16 modelos de Staging do dbt
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS raw;

-- 1. B3 COTAHIST
CREATE OR REPLACE VIEW raw.b3_cothist AS
SELECT 
    (p.metadata->>'data_pregao')::date as data_pregao,
    p.metadata->>'ticker' as ticker,
    p.metadata->>'cod_bdi' as cod_bdi,
    (p.metadata->>'tipo_mercado')::integer as tipo_mercado,
    p.metadata->>'nome_resumido' as nome_resumido,
    p.metadata->>'especificacao' as especificacao,
    (p.metadata->>'preco_abertura')::numeric(18,4) as preco_abertura,
    (p.metadata->>'preco_maximo')::numeric(18,4) as preco_maximo,
    (p.metadata->>'preco_minimo')::numeric(18,4) as preco_minimo,
    (p.metadata->>'preco_medio')::numeric(18,4) as preco_medio,
    (p.metadata->>'preco_fechamento')::numeric(18,4) as preco_fechamento,
    (p.metadata->>'total_negocios')::integer as total_negocios,
    (p.metadata->>'quantidade_titulos')::bigint as quantidade_titulos,
    (p.metadata->>'volume_financeiro')::numeric(20,4) as volume_financeiro,
    p.metadata->>'codigo_isin' as codigo_isin,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE 'b3%' OR p.metadata->>'source' = 'b3';

-- 2. Status Invest Payloads
CREATE OR REPLACE VIEW raw.status_invest_payloads AS
SELECT 
    p.metadata->>'ticker' as ticker,
    (p.metadata->>'data_referencia')::date as data_referencia,
    p.metadata->>'category' as category,
    (p.metadata->>'valor')::numeric(18,4) as valor,
    p.metadata->'detalhes' as detalhes,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%statusinvest%' OR p.metadata->>'source' = 'status_invest';

-- 3. CVM Demonstrativos
CREATE OR REPLACE VIEW raw.cvm_demonstrativos AS
SELECT 
    p.metadata->>'cnpj_cia' as cnpj_cia,
    p.metadata->>'tipo_demonstrativo' as tipo_demonstrativo,
    (p.metadata->>'data_referencia')::date as data_referencia,
    (p.metadata->>'versao')::integer as versao,
    p.metadata->>'conta' as conta,
    p.metadata->>'descricao_conta' as descricao_conta,
    (p.metadata->>'valor_conta')::numeric(20,4) as valor_conta,
    p.metadata->'detalhes' as dados_brutos,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE 'cvm%' OR p.metadata->>'source' = 'cvm';

-- 4. BCB SGS
CREATE OR REPLACE VIEW raw.bcb_sgs AS
SELECT 
    (p.metadata->>'data')::date as data,
    p.metadata->>'serie_nome' as serie_nome,
    (p.metadata->>'serie_id')::integer as serie_id,
    (p.metadata->>'valor')::numeric(14,6) as valor,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE 'bcb%' OR p.metadata->>'source' = 'bcb';

-- 5. Investidor10 Payloads
CREATE OR REPLACE VIEW raw.investidor10_payloads AS
SELECT 
    p.metadata->>'ticker' as ticker,
    p.metadata->>'endpoint' as endpoint,
    (p.metadata->>'pl')::numeric(14,4) as pl,
    (p.metadata->>'pvp')::numeric(14,4) as pvp,
    (p.metadata->>'roe')::numeric(10,4) as roe,
    (p.metadata->>'dividend_yield')::numeric(10,4) as dividend_yield,
    (p.metadata->>'ev_ebitda')::numeric(14,4) as ev_ebitda,
    p.metadata as dados_completos,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%investidor10%' OR p.metadata->>'source' = 'investidor10';

-- 6. Fundamentus HTML
CREATE OR REPLACE VIEW raw.fundamentus_html AS
SELECT 
    p.metadata->>'ticker' as ticker,
    p.metadata->>'route' as route,
    p.metadata->'metricas' as metricas,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%fundamentus%' OR p.metadata->>'source' = 'fundamentus';

-- 7. Clube FII GraphQL
CREATE OR REPLACE VIEW raw.clube_fii_graphql AS
SELECT 
    p.metadata->>'ticker' as ticker,
    p.metadata->>'nome_fundo' as nome_fundo,
    p.metadata->>'segmento' as segmento,
    p.metadata->>'mandato' as mandato,
    (p.metadata->>'quantidade_imoveis')::integer as quantidade_imoveis,
    (p.metadata->>'vacancia_fisica_pct')::numeric(6,2) as vacancia_fisica_pct,
    (p.metadata->>'vacancia_financeira_pct')::numeric(6,2) as vacancia_financeira_pct,
    p.metadata->'imoveis' as lista_imoveis,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%clubefii%' OR p.metadata->>'source' = 'clube_fii';

-- 8. Brick360 Scores
CREATE OR REPLACE VIEW raw.brick360_scores AS
SELECT 
    p.metadata->>'ticker' as ticker,
    (p.metadata->>'score_global')::numeric(6,2) as score_global,
    (p.metadata->>'score_imobiliario')::numeric(6,2) as score_imobiliario,
    (p.metadata->>'score_financeiro')::numeric(6,2) as score_financeiro,
    (p.metadata->>'score_inquilinos')::numeric(6,2) as score_inquilinos,
    (p.metadata->>'score_gestao')::numeric(6,2) as score_gestao,
    (p.metadata->>'score_credito')::numeric(6,2) as score_credito,
    (p.metadata->>'score_preco')::numeric(6,2) as score_preco,
    (p.metadata->>'walt_anos')::numeric(6,2) as walt_anos,
    (p.metadata->>'concentracao_top5_pct')::numeric(6,2) as concentracao_top5_pct,
    (p.metadata->>'contratos_atipicos_pct')::numeric(6,2) as contratos_atipicos_pct,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%brick360%' OR p.metadata->>'source' = 'brick360';

-- 9. ADVFN Técnico
CREATE OR REPLACE VIEW raw.advfn_tecnico AS
SELECT 
    p.metadata->>'ticker' as ticker,
    (p.metadata->>'pivot_point')::numeric(14,4) as pivot_point,
    (p.metadata->>'suporte_1')::numeric(14,4) as suporte_1,
    (p.metadata->>'suporte_2')::numeric(14,4) as suporte_2,
    (p.metadata->>'suporte_3')::numeric(14,4) as suporte_3,
    (p.metadata->>'suporte_4')::numeric(14,4) as suporte_4,
    (p.metadata->>'resistencia_1')::numeric(14,4) as resistencia_1,
    (p.metadata->>'resistencia_2')::numeric(14,4) as resistencia_2,
    (p.metadata->>'resistencia_3')::numeric(14,4) as resistencia_3,
    (p.metadata->>'rsi_14')::numeric(8,4) as rsi_14,
    p.metadata->>'tendencia_primaria' as tendencia_primaria,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%advfn%' OR p.metadata->>'source' = 'advfn';

-- 10. ETFs Brasil Taxas
CREATE OR REPLACE VIEW raw.etfs_brasil_taxas AS
SELECT 
    p.metadata->>'ticker' as ticker,
    p.metadata->>'nome_etf' as nome_etf,
    p.metadata->>'administrador' as administrador,
    (p.metadata->>'taxa_administracao_pct')::numeric(6,4) as taxa_administracao_pct,
    (p.metadata->>'patrimonio_liquido')::numeric(18,2) as patrimonio_liquido,
    (p.metadata->>'nav_patrimonial')::numeric(14,4) as nav_patrimonial,
    (p.metadata->>'spread_nav_pct')::numeric(8,4) as spread_nav_pct,
    (p.metadata->>'limite_aluguel_pct')::numeric(8,4) as limite_aluguel_pct,
    (p.metadata->>'fluxo_cotas_30d')::numeric(18,2) as fluxo_cotas_30d,
    p.metadata->>'indice_referencia' as indice_referencia,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%etfsbrasil%' OR p.metadata->>'source' = 'etfs_brasil';

-- 11. ANBIMA Mercado Secundário
CREATE OR REPLACE VIEW raw.anbima_mercado_secundario AS
SELECT 
    (p.metadata->>'data_referencia')::date as data_referencia,
    p.metadata->>'codigo_selic' as codigo_selic,
    p.metadata->>'tipo_titulo' as tipo_titulo,
    (p.metadata->>'data_vencimento')::date as data_vencimento,
    (p.metadata->>'taxa_indicativa')::numeric(10,4) as taxa_indicativa,
    (p.metadata->>'pu_indicativo')::numeric(18,6) as pu_indicativo,
    (p.metadata->>'taxa_minima')::numeric(10,4) as taxa_minima,
    (p.metadata->>'taxa_maxima')::numeric(10,4) as taxa_maxima,
    (p.metadata->>'desvio_padrao')::numeric(10,4) as desvio_padrao
FROM raw.payload p
WHERE p.source_url LIKE '%anbima%' OR p.metadata->>'source' = 'anbima';

-- 12. Fundamentei Apollo
CREATE OR REPLACE VIEW raw.fundamentei_apollo AS
SELECT 
    p.metadata->>'ticker' as ticker,
    p.metadata->>'razao_social' as razao_social,
    p.metadata->>'codigo_cvm' as codigo_cvm,
    p.metadata->>'setor' as setor,
    p.metadata->'reclame_aqui' as reclame_aqui,
    p.metadata as dados_brutos,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%fundamentei%' OR p.metadata->>'source' = 'fundamentei';

-- 13. Funds Explorer Payloads
CREATE OR REPLACE VIEW raw.funds_explorer_payloads AS
SELECT 
    p.metadata->>'ticker' as ticker,
    (p.metadata->>'data_com')::date as data_com,
    (p.metadata->>'data_pagamento')::date as data_pagamento,
    (p.metadata->>'valor_rendimento')::numeric(14,6) as valor_rendimento,
    (p.metadata->>'dividend_yield_pct')::numeric(8,4) as dividend_yield_pct,
    p.metadata as raw_item,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%fundsexplorer%' OR p.metadata->>'source' = 'funds_explorer';

-- 14. FIIs.com.br Agenda
CREATE OR REPLACE VIEW raw.fiis_com_br_agenda AS
SELECT 
    p.metadata->>'ticker' as ticker,
    p.metadata->>'mes_referencia' as mes_referencia,
    (p.metadata->>'data_com')::date as data_com,
    (p.metadata->>'data_pagamento')::date as data_pagamento,
    (p.metadata->>'valor_provento')::numeric(14,6) as valor_provento,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%fiis.com.br%' OR p.metadata->>'source' = 'fiis_com_br';

-- 15. Mais Retorno Métricas
CREATE OR REPLACE VIEW raw.mais_retorno_metricas AS
SELECT 
    p.metadata->>'identificador' as identificador,
    p.metadata->>'categoria' as categoria,
    (p.metadata->>'sharpe')::numeric(10,4) as sharpe,
    (p.metadata->>'sortino')::numeric(10,4) as sortino,
    (p.metadata->>'volatilidade_anualizada')::numeric(10,4) as volatilidade_anualizada,
    (p.metadata->>'max_drawdown')::numeric(10,4) as max_drawdown,
    p.metadata as metricas_completas,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%maisretorno%' OR p.metadata->>'source' = 'mais_retorno';

-- 16. Análise de Ações Checklists
CREATE OR REPLACE VIEW raw.analise_de_acoes_checklists AS
SELECT 
    p.metadata->>'ticker' as ticker,
    (p.metadata->>'preco_justo_graham')::numeric(14,4) as preco_justo_graham,
    (p.metadata->>'preco_teto_bazin')::numeric(14,4) as preco_teto_bazin,
    (p.metadata->>'pontuacao_5_pilares')::integer as pontuacao_5_pilares,
    (p.metadata->>'dia_habitual_provento')::integer as dia_habitual_provento,
    p.metadata as dados_completos,
    p.captured_at
FROM raw.payload p
WHERE p.source_url LIKE '%analisedeacoes%' OR p.metadata->>'source' = 'analise_de_acoes';
