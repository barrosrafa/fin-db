-- MIGRAÇÃO ESTRUTURAL: Base B -> Base A
-- Gerado exclusivamente a partir dos catálogos PostgreSQL capturados.
-- NÃO EXECUTAR automaticamente. Revisar e executar em transação controlada.
-- Nenhuma consulta de dados/seed foi usada.
--
-- Objetos internos _timescaledb* foram deliberadamente excluídos: são chunks/catalog
-- gerados pelo TimescaleDB e dependem do estado físico/dados; recriá-los manualmente
-- seria incorreto e poderia causar duplicação ou conflito com hypertables existentes.
-- O script inclui apenas DDL lógico ausente ou divergente, uma única vez.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '0';

-- ============================================================================
-- SCHEMA AUSENTE NA BASE A: public_dw
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS "public_dw";

-- ============================================================================
-- SCHEMA AUSENTE NA BASE A: public_intermediate
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS "public_intermediate";

-- ============================================================================
-- SCHEMA AUSENTE NA BASE A: public_staging
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS "public_staging";

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.dim_ativo
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."dim_ativo" (
    "ticker" character varying(12),
    "nome_resumido" character varying(150),
    "especificacao" text,
    "codigo_isin" character varying(12),
    "classe_ativo" text,
    "custo_total_ter" numeric(6,4),
    "indice_referencia" text
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.dim_emissor
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."dim_emissor" (
    "cnpj" text,
    "codigo_cvm" text,
    "razao_social" character varying(150),
    "nome_comercial" character varying(150),
    "setor_atividade" character varying(50),
    "situacao_registro" text,
    "data_registro" date
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.dim_fundo
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."dim_fundo" (
    "ticker" character varying,
    "cnpj" text,
    "razao_social" text,
    "gestora" text,
    "tipo_fundo" text
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.dim_imovel_fii
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."dim_imovel_fii" (
    "ticker" text,
    "nome_imovel" text,
    "cidade" text,
    "uf" text,
    "area_bruta_locavel" numeric(14,2)
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.fct_cotacao_diaria
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."fct_cotacao_diaria" (
    "data_pregao" date,
    "ticker" character varying(12),
    "preco_abertura" numeric(10,2),
    "preco_maximo" numeric(10,2),
    "preco_minimo" numeric(10,2),
    "preco_fechamento" numeric(10,2),
    "preco_medio" numeric(10,2),
    "volume_financeiro" numeric(18,2),
    "quantidade_titulos" bigint,
    "fonte_primaria" text
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.fct_demonstrativo_financeiro
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."fct_demonstrativo_financeiro" (
    "cnpj" text,
    "codigo_cvm" text,
    "data_referencia" date,
    "receita_liquida" numeric,
    "custos_produtos_vendidos" numeric,
    "lucro_bruto" numeric,
    "ebit" numeric,
    "resultado_financeiro" numeric,
    "lucro_liquido" numeric,
    "ativo_total" numeric,
    "patrimonio_liquido" numeric
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.fct_fii_snapshot_mensal
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."fct_fii_snapshot_mensal" (
    "ticker" character varying,
    "data_referencia" date,
    "cnpj_fundo" text,
    "razao_social" text,
    "gestora" text,
    "patrimonio_liquido" numeric,
    "vacancia_fisica_pct" numeric(8,4),
    "vacancia_financeira_pct" numeric(8,4),
    "total_imoveis" integer,
    "brick_score_global" numeric(6,2),
    "score_imobiliario" numeric(6,2),
    "score_financeiro" numeric(6,2),
    "score_inquilinos" numeric(6,2),
    "score_gestao" numeric(6,2),
    "score_credito" numeric(6,2),
    "score_preco" numeric(6,2),
    "walt_anos" numeric(6,2),
    "concentracao_top5_pct" numeric(6,2),
    "contratos_atipicos_pct" numeric(6,2)
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.fct_indicador_fundamentalista
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."fct_indicador_fundamentalista" (
    "ticker" text,
    "preco_lucro" numeric,
    "preco_vpa" numeric,
    "roe_pct" numeric,
    "dividend_yield_pct" numeric,
    "ev_ebitda" numeric,
    "preco_justo_graham" numeric(14,4),
    "preco_teto_bazin" numeric(14,4),
    "pontuacao_5_pilares" integer
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.fct_provento
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."fct_provento" (
    "ticker" character varying(12),
    "data_com" date,
    "data_pagamento" date,
    "mes_referencia" character varying(7),
    "valor_provento" numeric(12,6),
    "tipo_provento" text,
    "fonte" text
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.mart_screener_acoes
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."mart_screener_acoes" (
    "ticker" character varying(12),
    "data_pregao" date,
    "preco_fechamento" numeric(10,2),
    "preco_lucro" numeric,
    "preco_vpa" numeric,
    "roe_pct" numeric,
    "dividend_yield_pct" numeric,
    "ev_ebitda" numeric,
    "preco_justo_graham" numeric(14,4),
    "preco_teto_bazin" numeric(14,4),
    "margem_seguranca_graham_pct" numeric,
    "margem_seguranca_bazin_pct" numeric,
    "pontuacao_5_pilares" integer,
    "rsi_14" numeric(8,4),
    "tendencia_primaria" text,
    "suporte_1" numeric(14,4),
    "resistencia_1" numeric(14,4)
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.mart_screener_etfs
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."mart_screener_etfs" (
    "ticker" text,
    "preco_fechamento" numeric(10,2),
    "nav_patrimonial" numeric(14,4),
    "spread_nav_pct" numeric(8,4),
    "custo_total_ter" numeric(6,4),
    "taxa_administracao_primaria" numeric(6,4),
    "taxa_secundaria" numeric(6,4),
    "limite_aluguel_pct" numeric(8,4),
    "fluxo_cotas_30d" numeric(18,2),
    "indice_referencia" text
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_dw.mart_screener_fiis
-- ============================================================================
CREATE TABLE IF NOT EXISTS "public_dw"."mart_screener_fiis" (
    "ticker" character varying,
    "razao_social" text,
    "gestora" text,
    "preco_fechamento" numeric(10,2),
    "patrimonio_liquido" numeric,
    "vacancia_fisica_pct" numeric(8,4),
    "vacancia_financeira_pct" numeric(8,4),
    "total_imoveis" integer,
    "brick_score_global" numeric(6,2),
    "walt_anos" numeric(6,2),
    "proventos_acumulados_12m" numeric,
    "dividend_yield_12m_pct" numeric
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: system.schema_migrations
-- ============================================================================
CREATE TABLE IF NOT EXISTS "system"."schema_migrations" (
    "version" character varying(255) NOT NULL,
    "checksum" character varying(64) NOT NULL,
    "applied_at" timestamp with time zone DEFAULT now() NOT NULL
);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_advfn_tecnico
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_advfn_tecnico" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM advfn_tecnico.ticker) AS ticker,
            advfn_tecnico.pivot_point,
            advfn_tecnico.suporte_1,
            advfn_tecnico.suporte_2,
            advfn_tecnico.suporte_3,
            advfn_tecnico.suporte_4,
            advfn_tecnico.resistencia_1,
            advfn_tecnico.resistencia_2,
            advfn_tecnico.resistencia_3,
            advfn_tecnico.rsi_14,
            TRIM(BOTH FROM advfn_tecnico.tendencia_primaria) AS tendencia_primaria,
            advfn_tecnico.captured_at
           FROM raw.advfn_tecnico
        )
 SELECT ticker,
    pivot_point,
    suporte_1,
    suporte_2,
    suporte_3,
    suporte_4,
    resistencia_1,
    resistencia_2,
    resistencia_3,
    rsi_14,
    tendencia_primaria,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_analise_de_acoes_checklists
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_analise_de_acoes_checklists" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM analise_de_acoes_checklists.ticker) AS ticker,
            analise_de_acoes_checklists.preco_justo_graham,
            analise_de_acoes_checklists.preco_teto_bazin,
            analise_de_acoes_checklists.pontuacao_5_pilares,
            analise_de_acoes_checklists.dia_habitual_provento,
            analise_de_acoes_checklists.dados_completos AS payload_json,
            analise_de_acoes_checklists.captured_at
           FROM raw.analise_de_acoes_checklists
        )
 SELECT ticker,
    preco_justo_graham,
    preco_teto_bazin,
    pontuacao_5_pilares,
    dia_habitual_provento,
    payload_json,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_anbima_titulos
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_anbima_titulos" AS
 WITH source AS (
         SELECT anbima_mercado_secundario.data_referencia,
            TRIM(BOTH FROM anbima_mercado_secundario.codigo_selic) AS codigo_selic,
            TRIM(BOTH FROM anbima_mercado_secundario.tipo_titulo) AS tipo_titulo,
            anbima_mercado_secundario.data_vencimento,
            anbima_mercado_secundario.taxa_indicativa,
            anbima_mercado_secundario.pu_indicativo,
            anbima_mercado_secundario.taxa_minima,
            anbima_mercado_secundario.taxa_maxima,
            anbima_mercado_secundario.desvio_padrao
           FROM raw.anbima_mercado_secundario
        )
 SELECT data_referencia,
    codigo_selic,
    tipo_titulo,
    data_vencimento,
    taxa_indicativa,
    pu_indicativo,
    taxa_minima,
    taxa_maxima,
    desvio_padrao
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_b3_cotacoes
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_b3_cotacoes" AS
 WITH source AS (
         SELECT b3_cothist.data_pregao,
            TRIM(BOTH FROM b3_cothist.ticker) AS ticker,
            b3_cothist.cod_bdi,
            b3_cothist.tipo_mercado,
            TRIM(BOTH FROM b3_cothist.nome_resumido) AS nome_resumido,
            TRIM(BOTH FROM b3_cothist.especificacao) AS especificacao,
            b3_cothist.preco_abertura,
            b3_cothist.preco_maximo,
            b3_cothist.preco_minimo,
            b3_cothist.preco_medio,
            b3_cothist.preco_fechamento,
            b3_cothist.total_negocios,
            b3_cothist.quantidade_titulos,
            b3_cothist.volume_financeiro,
            TRIM(BOTH FROM b3_cothist.codigo_isin) AS codigo_isin,
            b3_cothist.captured_at
           FROM raw.b3_cothist
          WHERE NULLIF(TRIM(BOTH FROM b3_cothist.ticker), ''::text) IS NOT NULL AND b3_cothist.data_pregao IS NOT NULL AND b3_cothist.preco_fechamento IS NOT NULL
        )
 SELECT data_pregao,
    ticker,
    cod_bdi,
    tipo_mercado,
    nome_resumido,
    especificacao,
    preco_abertura,
    preco_maximo,
    preco_minimo,
    preco_medio,
    preco_fechamento,
    total_negocios,
    quantidade_titulos,
    volume_financeiro,
    codigo_isin,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_bcb_series
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_bcb_series" AS
 WITH source AS (
         SELECT bcb_sgs.data AS data_referencia,
            TRIM(BOTH FROM bcb_sgs.serie_nome) AS serie_nome,
            bcb_sgs.serie_id,
            bcb_sgs.valor AS valor_taxa,
            bcb_sgs.captured_at
           FROM raw.bcb_sgs
        )
 SELECT data_referencia,
    serie_nome,
    serie_id,
    valor_taxa,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_brick360_scores
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_brick360_scores" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM brick360_scores.ticker) AS ticker,
            brick360_scores.score_global,
            brick360_scores.score_imobiliario,
            brick360_scores.score_financeiro,
            brick360_scores.score_inquilinos,
            brick360_scores.score_gestao,
            brick360_scores.score_credito,
            brick360_scores.score_preco,
            brick360_scores.walt_anos,
            brick360_scores.concentracao_top5_pct,
            brick360_scores.contratos_atipicos_pct,
            brick360_scores.captured_at
           FROM raw.brick360_scores
          WHERE NULLIF(TRIM(BOTH FROM brick360_scores.ticker), ''::text) IS NOT NULL AND brick360_scores.score_global IS NOT NULL
        )
 SELECT ticker,
    score_global,
    score_imobiliario,
    score_financeiro,
    score_inquilinos,
    score_gestao,
    score_credito,
    score_preco,
    walt_anos,
    concentracao_top5_pct,
    contratos_atipicos_pct,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_clube_fii_imoveis
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_clube_fii_imoveis" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM clube_fii_graphql.ticker) AS ticker,
            NULL::text AS cnpj_fundo,
            TRIM(BOTH FROM clube_fii_graphql.nome_fundo) AS razao_social,
            NULL::text AS gestora,
            NULL::numeric(20,4) AS patrimonio_liquido,
            clube_fii_graphql.vacancia_fisica_pct::numeric(8,4) AS vacancia_fisica_pct,
            clube_fii_graphql.vacancia_financeira_pct::numeric(8,4) AS vacancia_financeira_pct,
            clube_fii_graphql.quantidade_imoveis AS total_imoveis,
            clube_fii_graphql.lista_imoveis AS lista_imoveis_json,
            clube_fii_graphql.captured_at
           FROM raw.clube_fii_graphql
          WHERE NULLIF(TRIM(BOTH FROM clube_fii_graphql.ticker), ''::text) IS NOT NULL
        )
 SELECT ticker,
    cnpj_fundo,
    razao_social,
    gestora,
    patrimonio_liquido,
    vacancia_fisica_pct,
    vacancia_financeira_pct,
    total_imoveis,
    lista_imoveis_json,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_cvm_demonstrativos
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_cvm_demonstrativos" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM cvm_demonstrativos.cnpj_cia) AS cnpj,
            TRIM(BOTH FROM cvm_demonstrativos.dados_brutos ->> 'CD_CVM'::text) AS codigo_cvm,
            TRIM(BOTH FROM cvm_demonstrativos.dados_brutos ->> 'DENOM_CIA'::text) AS denominacao_social,
            cvm_demonstrativos.data_referencia,
            cvm_demonstrativos.versao AS versao_documento,
            cvm_demonstrativos.tipo_demonstrativo AS demonstrativo_tipo,
            TRIM(BOTH FROM cvm_demonstrativos.conta) AS codigo_conta,
            TRIM(BOTH FROM cvm_demonstrativos.descricao_conta) AS descricao_conta,
            cvm_demonstrativos.valor_conta,
            cvm_demonstrativos.dados_brutos ->> 'ORDEM_EXERC'::text AS ordem_exercicio
           FROM raw.cvm_demonstrativos
          WHERE NULLIF(TRIM(BOTH FROM cvm_demonstrativos.cnpj_cia), ''::text) IS NOT NULL AND cvm_demonstrativos.data_referencia IS NOT NULL
        )
 SELECT cnpj,
    codigo_cvm,
    denominacao_social,
    data_referencia,
    versao_documento,
    demonstrativo_tipo,
    codigo_conta,
    descricao_conta,
    valor_conta,
    ordem_exercicio
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_cvm_fii_mensal
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_cvm_fii_mensal" AS
 WITH latest AS (
         SELECT convert_from(payload.body, 'UTF8'::name)::jsonb AS payload
           FROM raw.payload
          WHERE payload.source_url = 'cvm://fii_informe_mensal'::text
          ORDER BY payload.captured_at DESC
         LIMIT 1
        ), records AS (
         SELECT item.value AS item
           FROM latest,
            LATERAL jsonb_array_elements(latest.payload -> 'records'::text) item(value)
        )
 SELECT asset.ticker,
    records.item ->> 'CNPJ_Fundo_Classe'::text AS cnpj_fundo,
    (records.item ->> 'Data_Referencia'::text)::date AS data_referencia,
    (records.item ->> 'Versao'::text)::integer AS versao,
    records.item ->> 'Nome_Fundo_Classe'::text AS razao_social,
    records.item ->> 'Nome_Administrador'::text AS administrador,
    NULLIF(records.item ->> 'Patrimonio_Liquido'::text, ''::text)::numeric AS patrimonio_liquido,
    NULLIF(records.item ->> 'Valor_Patrimonial_Cotas'::text, ''::text)::numeric AS valor_patrimonial_cota,
    NULLIF(records.item ->> 'Total_Numero_Cotistas'::text, ''::text)::numeric AS cotistas_total
   FROM records
     LEFT JOIN LATERAL ( SELECT a.ticker
           FROM core.ativo a
             LEFT JOIN core.emissor_companhia e USING (id_emissor)
          WHERE a.tipo_ativo = 'FII'::core.tipo_ativo_enum AND (a.isin::text = NULLIF(records.item ->> 'Codigo_ISIN'::text, ''::text) OR e.cnpj::text = (records.item ->> 'CNPJ_Fundo_Classe'::text))
          ORDER BY (a.isin::text = NULLIF(records.item ->> 'Codigo_ISIN'::text, ''::text)) DESC NULLS LAST, a.ticker
         LIMIT 1) asset ON true;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_etfs_brasil_taxas
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_etfs_brasil_taxas" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM etfs_brasil_taxas.ticker) AS ticker,
            etfs_brasil_taxas.taxa_administracao_pct AS taxa_administracao_primaria,
            NULL::numeric(6,4) AS taxa_secundaria,
            NULL::numeric(6,4) AS custo_total_ter,
            etfs_brasil_taxas.nav_patrimonial,
            etfs_brasil_taxas.spread_nav_pct,
            etfs_brasil_taxas.limite_aluguel_pct,
            etfs_brasil_taxas.fluxo_cotas_30d,
            TRIM(BOTH FROM etfs_brasil_taxas.indice_referencia) AS indice_referencia,
            etfs_brasil_taxas.captured_at
           FROM raw.etfs_brasil_taxas
          WHERE NULLIF(TRIM(BOTH FROM etfs_brasil_taxas.ticker), ''::text) IS NOT NULL
        )
 SELECT ticker,
    taxa_administracao_primaria,
    taxa_secundaria,
    custo_total_ter,
    nav_patrimonial,
    spread_nav_pct,
    limite_aluguel_pct,
    fluxo_cotas_30d,
    indice_referencia,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_fiis_agenda_proventos
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_fiis_agenda_proventos" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM fiis_com_br_agenda.ticker) AS ticker,
            fiis_com_br_agenda.mes_referencia,
            fiis_com_br_agenda.data_com,
            fiis_com_br_agenda.data_pagamento,
            fiis_com_br_agenda.valor_provento,
            fiis_com_br_agenda.captured_at
           FROM raw.fiis_com_br_agenda
        )
 SELECT ticker,
    mes_referencia,
    data_com,
    data_pagamento,
    valor_provento,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_fundamentei_kpis
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_fundamentei_kpis" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM fundamentei_apollo.ticker) AS ticker,
            TRIM(BOTH FROM fundamentei_apollo.razao_social) AS razao_social,
            TRIM(BOTH FROM fundamentei_apollo.codigo_cvm) AS codigo_cvm,
            TRIM(BOTH FROM fundamentei_apollo.setor) AS setor_fundamentei,
            ((fundamentei_apollo.reclame_aqui ->> 'score'::text))::numeric(5,2) AS score_reclame_aqui,
            fundamentei_apollo.reclame_aqui ->> 'status'::text AS status_reclame_aqui,
            fundamentei_apollo.dados_brutos AS apollo_payload,
            fundamentei_apollo.captured_at
           FROM raw.fundamentei_apollo
        )
 SELECT ticker,
    razao_social,
    codigo_cvm,
    setor_fundamentei,
    score_reclame_aqui,
    status_reclame_aqui,
    apollo_payload,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_fundamentus_ativos
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_fundamentus_ativos" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM fundamentus_html.ticker) AS ticker,
            fundamentus_html.route AS rota_fundamentus,
            fundamentus_html.metricas ->> 'cotacao'::text AS cotacao_bruta,
            fundamentus_html.metricas ->> 'pl'::text AS pl_bruto,
            fundamentus_html.metricas ->> 'pvp'::text AS pvp_bruto,
            fundamentus_html.metricas AS todas_metricas,
            fundamentus_html.captured_at
           FROM raw.fundamentus_html
        )
 SELECT ticker,
    rota_fundamentus,
    cotacao_bruta,
    pl_bruto,
    pvp_bruto,
    todas_metricas,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_funds_explorer_ranking
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_funds_explorer_ranking" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM funds_explorer_payloads.ticker) AS ticker,
            funds_explorer_payloads.data_com,
            funds_explorer_payloads.data_pagamento,
            funds_explorer_payloads.valor_rendimento AS rendimento_cota,
            funds_explorer_payloads.dividend_yield_pct,
            funds_explorer_payloads.raw_item AS payload_json,
            funds_explorer_payloads.captured_at
           FROM raw.funds_explorer_payloads
        )
 SELECT ticker,
    data_com,
    data_pagamento,
    rendimento_cota,
    dividend_yield_pct,
    payload_json,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_investidor10_multiplos
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_investidor10_multiplos" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM investidor10_payloads.ticker) AS ticker,
            investidor10_payloads.endpoint AS endpoint_origem,
            COALESCE(investidor10_payloads.pl, 0::numeric) AS preco_lucro,
            COALESCE(investidor10_payloads.pvp, 0::numeric) AS preco_vpa,
            COALESCE(investidor10_payloads.roe, 0::numeric) AS roe_pct,
            COALESCE(investidor10_payloads.dividend_yield, 0::numeric) AS dividend_yield_pct,
            COALESCE(investidor10_payloads.ev_ebitda, 0::numeric) AS ev_ebitda,
            investidor10_payloads.dados_completos AS payload_json,
            investidor10_payloads.captured_at
           FROM raw.investidor10_payloads
        )
 SELECT ticker,
    endpoint_origem,
    preco_lucro,
    preco_vpa,
    roe_pct,
    dividend_yield_pct,
    ev_ebitda,
    payload_json,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_mais_retorno_fundos
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_mais_retorno_fundos" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM mais_retorno_metricas.identificador) AS identificador,
            mais_retorno_metricas.categoria,
            mais_retorno_metricas.sharpe AS indice_sharpe,
            mais_retorno_metricas.sortino AS indice_sortino,
            mais_retorno_metricas.volatilidade_anualizada AS volatilidade_anualizada_pct,
            mais_retorno_metricas.max_drawdown AS max_drawdown_pct,
            mais_retorno_metricas.metricas_completas AS payload_json,
            mais_retorno_metricas.captured_at
           FROM raw.mais_retorno_metricas
        )
 SELECT identificador,
    categoria,
    indice_sharpe,
    indice_sortino,
    volatilidade_anualizada_pct,
    max_drawdown_pct,
    payload_json,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_rejected_records
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_rejected_records" AS
 SELECT 'b3_cothist'::text AS source_table,
    'missing_required_fields'::text AS reason,
    to_jsonb(r.*) AS record
   FROM raw.b3_cothist r
  WHERE NOT (NULLIF(TRIM(BOTH FROM r.ticker), ''::text) IS NOT NULL AND r.data_pregao IS NOT NULL AND r.preco_fechamento IS NOT NULL)
UNION ALL
 SELECT 'cvm_demonstrativos'::text AS source_table,
    'missing_required_fields'::text AS reason,
    to_jsonb(r.*) AS record
   FROM raw.cvm_demonstrativos r
  WHERE NOT (NULLIF(TRIM(BOTH FROM r.cnpj_cia), ''::text) IS NOT NULL AND r.data_referencia IS NOT NULL)
UNION ALL
 SELECT 'brick360_scores'::text AS source_table,
    'missing_required_fields'::text AS reason,
    to_jsonb(r.*) AS record
   FROM raw.brick360_scores r
  WHERE NOT (NULLIF(TRIM(BOTH FROM r.ticker), ''::text) IS NOT NULL AND r.score_global IS NOT NULL)
UNION ALL
 SELECT 'etfs_brasil_taxas'::text AS source_table,
    'missing_required_fields'::text AS reason,
    to_jsonb(r.*) AS record
   FROM raw.etfs_brasil_taxas r
  WHERE NOT NULLIF(TRIM(BOTH FROM r.ticker), ''::text) IS NOT NULL
UNION ALL
 SELECT 'clube_fii_graphql'::text AS source_table,
    'missing_required_fields'::text AS reason,
    to_jsonb(r.*) AS record
   FROM raw.clube_fii_graphql r
  WHERE NOT NULLIF(TRIM(BOTH FROM r.ticker), ''::text) IS NOT NULL;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_staging.stg_status_invest_indicadores
-- ============================================================================
CREATE OR REPLACE VIEW "public_staging"."stg_status_invest_indicadores" AS
 WITH source AS (
         SELECT TRIM(BOTH FROM status_invest_payloads.ticker) AS ticker,
            status_invest_payloads.data_referencia,
            status_invest_payloads.category AS categoria_ativo,
            status_invest_payloads.valor AS valor_cotacao,
            status_invest_payloads.detalhes AS payload_json,
            status_invest_payloads.captured_at
           FROM raw.status_invest_payloads
        )
 SELECT ticker,
    data_referencia,
    categoria_ativo,
    valor_cotacao,
    payload_json,
    captured_at
   FROM source;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_intermediate.int_cotacoes_consolidadas
-- ============================================================================
CREATE OR REPLACE VIEW "public_intermediate"."int_cotacoes_consolidadas" AS
 SELECT q.data_pregao,
    a.ticker,
    q.preco_abertura,
    q.preco_maximo,
    q.preco_minimo,
    q.preco_fechamento,
    q.preco_medio,
    q.volume_total AS volume_financeiro,
    NULL::bigint AS quantidade_titulos,
    'MARKET_CANONICAL'::text AS fonte_primaria
   FROM market.cotacao_diaria q
     JOIN core.ativo a USING (id_ativo);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_intermediate.int_demonstrativos_padronizados
-- ============================================================================
CREATE OR REPLACE VIEW "public_intermediate"."int_demonstrativos_padronizados" AS
 WITH cvm_raw AS (
         SELECT stg_cvm_demonstrativos.cnpj,
            stg_cvm_demonstrativos.codigo_cvm,
            stg_cvm_demonstrativos.data_referencia,
            stg_cvm_demonstrativos.demonstrativo_tipo,
            stg_cvm_demonstrativos.codigo_conta,
            stg_cvm_demonstrativos.descricao_conta,
            stg_cvm_demonstrativos.valor_conta
           FROM public_staging.stg_cvm_demonstrativos
        ), pivoted AS (
         SELECT cvm_raw.cnpj,
            cvm_raw.codigo_cvm,
            cvm_raw.data_referencia,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '3.01'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS receita_liquida,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '3.02'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS custos_produtos_vendidos,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '3.03'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS lucro_bruto,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '3.05'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS ebit,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '3.07'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS resultado_financeiro,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '3.11'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS lucro_liquido,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '1'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS ativo_total,
            max(
                CASE
                    WHEN cvm_raw.codigo_conta = '2.03'::text THEN cvm_raw.valor_conta
                    ELSE NULL::numeric
                END) AS patrimonio_liquido
           FROM cvm_raw
          GROUP BY cvm_raw.cnpj, cvm_raw.codigo_cvm, cvm_raw.data_referencia
        )
 SELECT cnpj,
    codigo_cvm,
    data_referencia,
    COALESCE(receita_liquida, 0::numeric) AS receita_liquida,
    COALESCE(custos_produtos_vendidos, 0::numeric) AS custos_produtos_vendidos,
    COALESCE(lucro_bruto, 0::numeric) AS lucro_bruto,
    COALESCE(ebit, 0::numeric) AS ebit,
    COALESCE(resultado_financeiro, 0::numeric) AS resultado_financeiro,
    COALESCE(lucro_liquido, 0::numeric) AS lucro_liquido,
    COALESCE(ativo_total, 0::numeric) AS ativo_total,
    COALESCE(patrimonio_liquido, 0::numeric) AS patrimonio_liquido
   FROM pivoted;

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_intermediate.int_fii_metricas_consolidadas
-- ============================================================================
CREATE OR REPLACE VIEW "public_intermediate"."int_fii_metricas_consolidadas" AS
 WITH cvm AS (
         SELECT DISTINCT ON (stg_cvm_fii_mensal.ticker) stg_cvm_fii_mensal.ticker,
            stg_cvm_fii_mensal.cnpj_fundo,
            stg_cvm_fii_mensal.data_referencia,
            stg_cvm_fii_mensal.versao,
            stg_cvm_fii_mensal.razao_social,
            stg_cvm_fii_mensal.administrador,
            stg_cvm_fii_mensal.patrimonio_liquido,
            stg_cvm_fii_mensal.valor_patrimonial_cota,
            stg_cvm_fii_mensal.cotistas_total
           FROM public_staging.stg_cvm_fii_mensal
          WHERE stg_cvm_fii_mensal.ticker IS NOT NULL
          ORDER BY stg_cvm_fii_mensal.ticker, stg_cvm_fii_mensal.data_referencia DESC, stg_cvm_fii_mensal.versao DESC, stg_cvm_fii_mensal.cnpj_fundo
        ), clube AS (
         SELECT DISTINCT ON (stg_clube_fii_imoveis.ticker) stg_clube_fii_imoveis.ticker,
            stg_clube_fii_imoveis.cnpj_fundo,
            stg_clube_fii_imoveis.razao_social,
            stg_clube_fii_imoveis.gestora,
            stg_clube_fii_imoveis.patrimonio_liquido,
            stg_clube_fii_imoveis.vacancia_fisica_pct,
            stg_clube_fii_imoveis.vacancia_financeira_pct,
            stg_clube_fii_imoveis.total_imoveis
           FROM public_staging.stg_clube_fii_imoveis
          ORDER BY stg_clube_fii_imoveis.ticker, stg_clube_fii_imoveis.captured_at DESC
        ), brick AS (
         SELECT DISTINCT ON (stg_brick360_scores.ticker) stg_brick360_scores.ticker,
            stg_brick360_scores.score_global,
            stg_brick360_scores.score_imobiliario,
            stg_brick360_scores.score_financeiro,
            stg_brick360_scores.score_inquilinos,
            stg_brick360_scores.score_gestao,
            stg_brick360_scores.score_credito,
            stg_brick360_scores.score_preco,
            stg_brick360_scores.walt_anos,
            stg_brick360_scores.concentracao_top5_pct,
            stg_brick360_scores.contratos_atipicos_pct
           FROM public_staging.stg_brick360_scores
          ORDER BY stg_brick360_scores.ticker, stg_brick360_scores.captured_at DESC
        )
 SELECT COALESCE(v.ticker, c.ticker::character varying, b.ticker::character varying) AS ticker,
    v.data_referencia,
    COALESCE(v.cnpj_fundo, c.cnpj_fundo) AS cnpj_fundo,
    COALESCE(v.razao_social, c.razao_social) AS razao_social,
    c.gestora,
    COALESCE(v.patrimonio_liquido, c.patrimonio_liquido) AS patrimonio_liquido,
    c.vacancia_fisica_pct,
    c.vacancia_financeira_pct,
    c.total_imoveis,
    b.score_global AS brick_score_global,
    b.score_imobiliario,
    b.score_financeiro,
    b.score_inquilinos,
    b.score_gestao,
    b.score_credito,
    b.score_preco,
    b.walt_anos,
    b.concentracao_top5_pct,
    b.contratos_atipicos_pct
   FROM clube c
     FULL JOIN brick b ON b.ticker = c.ticker
     FULL JOIN cvm v ON v.ticker::text = COALESCE(c.ticker, b.ticker);

-- ============================================================================
-- RELAÇÃO AUSENTE NA BASE A: public_intermediate.int_proventos_ajustados
-- ============================================================================
CREATE OR REPLACE VIEW "public_intermediate"."int_proventos_ajustados" AS
 SELECT a.ticker,
    p.mes_referencia,
    p.data_com,
    p.data_pagamento,
    p.valor_por_acao AS valor_provento,
    p.tipo_provento::text AS tipo_provento,
    'MARKET_CANONICAL'::text AS fonte
   FROM market.provento p
     JOIN core.ativo a USING (id_ativo);

-- ============================================================================
-- COLUNAS AUSENTES OU COM DEFINIÇÃO DIFERENTE
-- ============================================================================
ALTER TABLE "asset_details"."tesouro_direto" ALTER COLUMN "tipo_titulo" TYPE character varying(100) USING "tipo_titulo"::character varying(100);
ALTER TABLE "core"."ativo" ADD COLUMN IF NOT EXISTS "canonical_instrument_id" uuid;
ALTER TABLE "core"."ativo" ALTER COLUMN "tipo_titulo" TYPE character varying(100) USING "tipo_titulo"::character varying(100);
ALTER TABLE "core"."carteira" ADD COLUMN IF NOT EXISTS "principal" boolean DEFAULT true;
ALTER TABLE "market"."cotacao_diaria" ALTER COLUMN "variacao_percentual" TYPE numeric(12,4) USING "variacao_percentual"::numeric(12,4);
ALTER TABLE "market"."desdobramento_split" ALTER COLUMN "fator" TYPE numeric(18,6) USING "fator"::numeric(18,6);
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "classe_ativo" text;
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "codigo_isin" character varying(12);
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "custo_total_ter" numeric(6,4);
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "especificacao" text;
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "indice_referencia" text;
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "nome_resumido" character varying(150);
ALTER TABLE "public_dw"."dim_ativo" ADD COLUMN IF NOT EXISTS "ticker" character varying(12);
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "cnpj" text;
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "codigo_cvm" text;
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "data_registro" date;
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "nome_comercial" character varying(150);
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "razao_social" character varying(150);
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "setor_atividade" character varying(50);
ALTER TABLE "public_dw"."dim_emissor" ADD COLUMN IF NOT EXISTS "situacao_registro" text;
ALTER TABLE "public_dw"."dim_fundo" ADD COLUMN IF NOT EXISTS "cnpj" text;
ALTER TABLE "public_dw"."dim_fundo" ADD COLUMN IF NOT EXISTS "gestora" text;
ALTER TABLE "public_dw"."dim_fundo" ADD COLUMN IF NOT EXISTS "razao_social" text;
ALTER TABLE "public_dw"."dim_fundo" ADD COLUMN IF NOT EXISTS "ticker" character varying;
ALTER TABLE "public_dw"."dim_fundo" ADD COLUMN IF NOT EXISTS "tipo_fundo" text;
ALTER TABLE "public_dw"."dim_imovel_fii" ADD COLUMN IF NOT EXISTS "area_bruta_locavel" numeric(14,2);
ALTER TABLE "public_dw"."dim_imovel_fii" ADD COLUMN IF NOT EXISTS "cidade" text;
ALTER TABLE "public_dw"."dim_imovel_fii" ADD COLUMN IF NOT EXISTS "nome_imovel" text;
ALTER TABLE "public_dw"."dim_imovel_fii" ADD COLUMN IF NOT EXISTS "ticker" text;
ALTER TABLE "public_dw"."dim_imovel_fii" ADD COLUMN IF NOT EXISTS "uf" text;
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "data_pregao" date;
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "fonte_primaria" text;
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "preco_abertura" numeric(10,2);
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "preco_fechamento" numeric(10,2);
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "preco_maximo" numeric(10,2);
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "preco_medio" numeric(10,2);
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "preco_minimo" numeric(10,2);
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "quantidade_titulos" bigint;
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "ticker" character varying(12);
ALTER TABLE "public_dw"."fct_cotacao_diaria" ADD COLUMN IF NOT EXISTS "volume_financeiro" numeric(18,2);
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "ativo_total" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "cnpj" text;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "codigo_cvm" text;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "custos_produtos_vendidos" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "data_referencia" date;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "ebit" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "lucro_bruto" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "lucro_liquido" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "patrimonio_liquido" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "receita_liquida" numeric;
ALTER TABLE "public_dw"."fct_demonstrativo_financeiro" ADD COLUMN IF NOT EXISTS "resultado_financeiro" numeric;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "brick_score_global" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "cnpj_fundo" text;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "concentracao_top5_pct" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "contratos_atipicos_pct" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "data_referencia" date;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "gestora" text;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "patrimonio_liquido" numeric;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "razao_social" text;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "score_credito" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "score_financeiro" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "score_gestao" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "score_imobiliario" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "score_inquilinos" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "score_preco" numeric(6,2);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "ticker" character varying;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "total_imoveis" integer;
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "vacancia_financeira_pct" numeric(8,4);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "vacancia_fisica_pct" numeric(8,4);
ALTER TABLE "public_dw"."fct_fii_snapshot_mensal" ADD COLUMN IF NOT EXISTS "walt_anos" numeric(6,2);
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "dividend_yield_pct" numeric;
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "ev_ebitda" numeric;
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "pontuacao_5_pilares" integer;
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "preco_justo_graham" numeric(14,4);
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "preco_lucro" numeric;
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "preco_teto_bazin" numeric(14,4);
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "preco_vpa" numeric;
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "roe_pct" numeric;
ALTER TABLE "public_dw"."fct_indicador_fundamentalista" ADD COLUMN IF NOT EXISTS "ticker" text;
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "data_com" date;
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "data_pagamento" date;
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "fonte" text;
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "mes_referencia" character varying(7);
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "ticker" character varying(12);
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "tipo_provento" text;
ALTER TABLE "public_dw"."fct_provento" ADD COLUMN IF NOT EXISTS "valor_provento" numeric(12,6);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "data_pregao" date;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "dividend_yield_pct" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "ev_ebitda" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "margem_seguranca_bazin_pct" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "margem_seguranca_graham_pct" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "pontuacao_5_pilares" integer;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "preco_fechamento" numeric(10,2);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "preco_justo_graham" numeric(14,4);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "preco_lucro" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "preco_teto_bazin" numeric(14,4);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "preco_vpa" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "resistencia_1" numeric(14,4);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "roe_pct" numeric;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "rsi_14" numeric(8,4);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "suporte_1" numeric(14,4);
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "tendencia_primaria" text;
ALTER TABLE "public_dw"."mart_screener_acoes" ADD COLUMN IF NOT EXISTS "ticker" character varying(12);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "custo_total_ter" numeric(6,4);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "fluxo_cotas_30d" numeric(18,2);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "indice_referencia" text;
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "limite_aluguel_pct" numeric(8,4);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "nav_patrimonial" numeric(14,4);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "preco_fechamento" numeric(10,2);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "spread_nav_pct" numeric(8,4);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "taxa_administracao_primaria" numeric(6,4);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "taxa_secundaria" numeric(6,4);
ALTER TABLE "public_dw"."mart_screener_etfs" ADD COLUMN IF NOT EXISTS "ticker" text;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "brick_score_global" numeric(6,2);
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "dividend_yield_12m_pct" numeric;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "gestora" text;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "patrimonio_liquido" numeric;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "preco_fechamento" numeric(10,2);
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "proventos_acumulados_12m" numeric;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "razao_social" text;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "ticker" character varying;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "total_imoveis" integer;
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "vacancia_financeira_pct" numeric(8,4);
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "vacancia_fisica_pct" numeric(8,4);
ALTER TABLE "public_dw"."mart_screener_fiis" ADD COLUMN IF NOT EXISTS "walt_anos" numeric(6,2);
ALTER TABLE "system"."schema_migrations" ADD COLUMN IF NOT EXISTS "applied_at" timestamp with time zone DEFAULT now() NOT NULL;
ALTER TABLE "system"."schema_migrations" ADD COLUMN IF NOT EXISTS "checksum" character varying(64) NOT NULL;
ALTER TABLE "system"."schema_migrations" ADD COLUMN IF NOT EXISTS "version" character varying(255) NOT NULL;

-- ============================================================================
-- CONSTRAINT: analytics.demonstrativo_financeiro.demonstrativo_financeiro_id_emissor_data_referencia_tipo_do_key
-- ============================================================================
ALTER TABLE "analytics"."demonstrativo_financeiro" DROP CONSTRAINT IF EXISTS "demonstrativo_financeiro_id_emissor_data_referencia_tipo_do_key";
ALTER TABLE "analytics"."demonstrativo_financeiro" ADD CONSTRAINT "demonstrativo_financeiro_id_emissor_data_referencia_tipo_do_key" UNIQUE NULLS NOT DISTINCT (id_emissor, data_referencia, tipo_documento, versao);

-- ============================================================================
-- CONSTRAINT: canonical.financial_statement.financial_statement_legal_entity_id_instrument_id_statement_key
-- ============================================================================
ALTER TABLE "canonical"."financial_statement" DROP CONSTRAINT IF EXISTS "financial_statement_legal_entity_id_instrument_id_statement_key";
ALTER TABLE "canonical"."financial_statement" ADD CONSTRAINT "financial_statement_legal_entity_id_instrument_id_statement_key" UNIQUE NULLS NOT DISTINCT (legal_entity_id, instrument_id, statement_type, period_end, consolidation, source_id);

-- ============================================================================
-- CONSTRAINT: core.ativo.ativo_canonical_instrument_id_fkey
-- ============================================================================
ALTER TABLE "core"."ativo" ADD CONSTRAINT "ativo_canonical_instrument_id_fkey" FOREIGN KEY (canonical_instrument_id) REFERENCES canonical.instrument(instrument_id);

-- ============================================================================
-- CONSTRAINT: system.schema_migrations.schema_migrations_pkey
-- ============================================================================
ALTER TABLE "system"."schema_migrations" ADD CONSTRAINT "schema_migrations_pkey" PRIMARY KEY (version);

-- ============================================================================
-- ÍNDICE: core.idx_ativo_canonical_id
-- ============================================================================
CREATE INDEX idx_ativo_canonical_id ON core.ativo USING btree (canonical_instrument_id);

-- ============================================================================
-- ÍNDICE: market.uq_split_ativo_data_tipo
-- ============================================================================
CREATE UNIQUE INDEX uq_split_ativo_data_tipo ON market.desdobramento_split USING btree (id_ativo, data_ex, tipo);

-- ============================================================================
-- ÍNDICE: market.uq_provento_ativo_tipo_ex_valor
-- ============================================================================
CREATE UNIQUE INDEX uq_provento_ativo_tipo_ex_valor ON market.provento USING btree (id_ativo, tipo_provento, data_ex, valor_por_acao);

-- ============================================================================
-- FUNÇÃO: system.fn_auditoria()
-- ============================================================================
CREATE OR REPLACE FUNCTION system.fn_auditoria()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
        DECLARE
            v_rec_id text;
        BEGIN
            IF (TG_OP = 'DELETE') THEN
                v_rec_id := coalesce((to_jsonb(OLD)->>'id'), (to_jsonb(OLD)->>'id_carteira'), (to_jsonb(OLD)->>'id_posicao'), (to_jsonb(OLD)->>'id_ativo'), 'unknown');
                INSERT INTO system.auditoria_log (operacao, tabela, registro_id, old_value)
                VALUES ('DELETE', TG_TABLE_NAME, v_rec_id, to_jsonb(OLD));
                RETURN OLD;
            ELSIF (TG_OP = 'UPDATE') THEN
                v_rec_id := coalesce((to_jsonb(NEW)->>'id'), (to_jsonb(NEW)->>'id_carteira'), (to_jsonb(NEW)->>'id_posicao'), (to_jsonb(NEW)->>'id_ativo'), 'unknown');
                INSERT INTO system.auditoria_log (operacao, tabela, registro_id, old_value, new_value)
                VALUES ('UPDATE', TG_TABLE_NAME, v_rec_id, to_jsonb(OLD), to_jsonb(NEW));
                RETURN NEW;
            ELSIF (TG_OP = 'INSERT') THEN
                v_rec_id := coalesce((to_jsonb(NEW)->>'id'), (to_jsonb(NEW)->>'id_carteira'), (to_jsonb(NEW)->>'id_posicao'), (to_jsonb(NEW)->>'id_ativo'), 'unknown');
                INSERT INTO system.auditoria_log (operacao, tabela, registro_id, new_value)
                VALUES ('INSERT', TG_TABLE_NAME, v_rec_id, to_jsonb(NEW));
                RETURN NEW;
            END IF;
        END;
        $function$
;

-- ============================================================================
-- POLICY RLS: core.carteira.p_carteira_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_carteira_owner" ON "core"."carteira";
CREATE POLICY "p_carteira_owner" ON "core"."carteira" AS PERMISSIVE FOR ALL TO public USING ((id_usuario = (current_setting('app.current_user_id'::text, true))::uuid));

-- ============================================================================
-- POLICY RLS: core.lote_ativo.p_lote_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_lote_owner" ON "core"."lote_ativo";
CREATE POLICY "p_lote_owner" ON "core"."lote_ativo" AS PERMISSIVE FOR ALL TO public USING ((id_carteira IN ( SELECT carteira.id_carteira
   FROM core.carteira
  WHERE (carteira.id_usuario = (current_setting('app.current_user_id'::text, true))::uuid))));

-- ============================================================================
-- POLICY RLS: core.ordem.p_ordem_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_ordem_owner" ON "core"."ordem";
CREATE POLICY "p_ordem_owner" ON "core"."ordem" AS PERMISSIVE FOR ALL TO public USING ((id_carteira IN ( SELECT carteira.id_carteira
   FROM core.carteira
  WHERE (carteira.id_usuario = (current_setting('app.current_user_id'::text, true))::uuid))));

-- ============================================================================
-- POLICY RLS: core.posicao_custodia.p_posicao_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_posicao_owner" ON "core"."posicao_custodia";
CREATE POLICY "p_posicao_owner" ON "core"."posicao_custodia" AS PERMISSIVE FOR ALL TO public USING ((id_carteira IN ( SELECT carteira.id_carteira
   FROM core.carteira
  WHERE (carteira.id_usuario = (current_setting('app.current_user_id'::text, true))::uuid))));

-- ============================================================================
-- POLICY RLS: social.anotacao_ativo.p_anotacao_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_anotacao_owner" ON "social"."anotacao_ativo";
CREATE POLICY "p_anotacao_owner" ON "social"."anotacao_ativo" AS PERMISSIVE FOR ALL TO public USING ((id_usuario = (current_setting('app.current_user_id'::text, true))::uuid));

-- ============================================================================
-- POLICY RLS: social.watchlist.p_watchlist_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_watchlist_owner" ON "social"."watchlist";
CREATE POLICY "p_watchlist_owner" ON "social"."watchlist" AS PERMISSIVE FOR ALL TO public USING ((id_usuario = (current_setting('app.current_user_id'::text, true))::uuid));

-- ============================================================================
-- POLICY RLS: system.api_key.p_apikey_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_apikey_owner" ON "system"."api_key";
CREATE POLICY "p_apikey_owner" ON "system"."api_key" AS PERMISSIVE FOR ALL TO public USING ((id_usuario = (current_setting('app.current_user_id'::text, true))::uuid));

-- ============================================================================
-- POLICY RLS: system.dispositivo.p_dispositivo_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_dispositivo_owner" ON "system"."dispositivo";
CREATE POLICY "p_dispositivo_owner" ON "system"."dispositivo" AS PERMISSIVE FOR ALL TO public USING ((id_usuario = (current_setting('app.current_user_id'::text, true))::uuid));

-- ============================================================================
-- POLICY RLS: wealth.apuracao_ir.p_ir_owner
-- ============================================================================
DROP POLICY IF EXISTS "p_ir_owner" ON "wealth"."apuracao_ir";
CREATE POLICY "p_ir_owner" ON "wealth"."apuracao_ir" AS PERMISSIVE FOR ALL TO public USING ((id_usuario = (current_setting('app.current_user_id'::text, true))::uuid));



-- ============================================================================
-- RECONCILIAÇÃO: OBJETOS PRESENTES SOMENTE NA BASE A
-- ============================================================================
-- Necessário para que o catálogo final seja igual ao da Base B. A remoção é
-- intencional e destrutiva para esses objetos/colunas; o runner executa o arquivo
-- em uma transação própria.
DROP TABLE IF EXISTS "market"."quote_quality_evidence";
ALTER TABLE "market"."cotacao_diaria" DROP COLUMN IF EXISTS "calendar_version";
ALTER TABLE "market"."cotacao_diaria" DROP COLUMN IF EXISTS "collected_at";
ALTER TABLE "market"."cotacao_diaria" DROP COLUMN IF EXISTS "price_kind";
ALTER TABLE "market"."cotacao_diaria" DROP COLUMN IF EXISTS "quality_status";
ALTER TABLE "market"."cotacao_diaria" DROP COLUMN IF EXISTS "source_id";
ALTER TABLE "market"."cotacao_intraday" DROP COLUMN IF EXISTS "price_kind";
ALTER TABLE "market"."cotacao_intraday" DROP COLUMN IF EXISTS "source_id";

-- FIM DA MIGRAÇÃO ESTRUTURAL
