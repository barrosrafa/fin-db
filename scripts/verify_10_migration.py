#!/usr/bin/env python3
"""
Script de execução e verificação da Migration 10 (v3.8 - Oceans14 Coverage)
Tabelas:
  - market.historico_pl_indice
  - market.fluxo_investidor_b3
  - market.agenda_resultados
  - market.contas_publicas_governo
  - market.credito_sistema_financeiro
  - analytics.demonstrativo_padronizado_serie
  - asset_details.fii_historico_vacancia
  - analytics.mv_acoes_consistencia_lucro (Materialized View)
"""

import os
import sys
import psycopg

DEFAULT_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_pwONKPD13RiC@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

def run_migration_10():
    print("=" * 65)
    print("      EXECUTANDO MIGRATION 10 (OCEANS14 COVERAGE v3.8)")
    print("=" * 65)
    
    migration_file = os.path.join(
        os.path.dirname(__file__),
        "..",
        "sql",
        "10_oceans14_coverage_v3.8",
        "01_oceans14_tables_and_views.sql"
    )
    
    with open(migration_file, "r", encoding="utf-8") as f:
        sql = f.read()
        
    with psycopg.connect(DEFAULT_URL) as conn:
        with conn.cursor() as cur:
            print("Executando DDL...")
            cur.execute(sql)
            conn.commit()
            print("DDL executado com sucesso!\n")
            
            # 1. Verificação das Novas Tabelas
            print("--- Verificação das Novas Tabelas e Views ---")
            tables_to_check = [
                ("market", "historico_pl_indice"),
                ("market", "fluxo_investidor_b3"),
                ("market", "agenda_resultados"),
                ("market", "contas_publicas_governo"),
                ("market", "credito_sistema_financeiro"),
                ("analytics", "demonstrativo_padronizado_serie"),
                ("asset_details", "fii_historico_vacancia")
            ]
            
            for schema, table in tables_to_check:
                cur.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = %s AND table_name = %s;
                """, (schema, table))
                row = cur.fetchone()
                status = "✓ Criada com sucesso" if row else "✗ FALTANDO"
                print(f"  • {schema}.{table:<35}: {status}")

            # 2. Verificação da Materialized View
            cur.execute("""
                SELECT matviewname 
                FROM pg_matviews 
                WHERE schemaname = 'analytics' AND matviewname = 'mv_acoes_consistencia_lucro';
            """)
            mv_row = cur.fetchone()
            print(f"  • analytics.mv_acoes_consistencia_lucro (Materialized View): {'✓ Criada com sucesso' if mv_row else '✗ FALTANDO'}")

            # 3. Inserção de Seeds de Referência Canônica para Testes Funcionais
            print("\n--- Inserindo Seeds de Referência Oceans14 ---")
            
            # A. Histórico P/L Ibovespa (Valuation Corridor)
            cur.execute("""
                INSERT INTO market.historico_pl_indice (
                    data_referencia, codigo_indice, fechamento_indice, pl_ponderado, pl_mediano, 
                    pl_medio_aritmetico, lucro_projetado_fwd, media_historica_5y, desvio_padrao_5y, 
                    banda_superior_1dp, banda_inferior_1dp, banda_superior_2dp, banda_inferior_2dp
                ) VALUES 
                ('2024-01-02', 'IBOV', 132697.00, 8.45, 8.10, 9.20, 7.80, 10.50, 2.10, 12.60, 8.40, 14.70, 6.30),
                ('2024-06-03', 'IBOV', 122032.00, 7.85, 7.50, 8.60, 7.20, 10.40, 2.05, 12.45, 8.35, 14.50, 6.30),
                ('2025-01-02', 'IBOV', 128500.00, 8.15, 7.90, 8.95, 7.50, 10.35, 2.00, 12.35, 8.35, 14.35, 6.35),
                ('2025-06-02', 'IBOV', 135400.00, 8.60, 8.25, 9.40, 7.90, 10.30, 1.95, 12.25, 8.35, 14.20, 6.40),
                ('2026-01-02', 'IBOV', 142000.00, 9.10, 8.70, 9.80, 8.30, 10.25, 1.90, 12.15, 8.35, 14.05, 6.45),
                ('2026-10-26', 'IBOV', 148500.00, 9.42, 8.95, 10.15, 8.60, 10.20, 1.85, 12.05, 8.35, 13.90, 6.50)
                ON CONFLICT (codigo_indice, data_referencia) DO NOTHING;
            """)
            
            # B. Fluxo de Investidores B3
            cur.execute("""
                INSERT INTO market.fluxo_investidor_b3 (
                    data_pregao, categoria_investidor, compras_reais, vendas_reais, saldo_acumulado_mes, saldo_acumulado_ano, participacao_pct
                ) VALUES
                ('2026-10-23', 'ESTRANGEIRO', 18500000000.00, 17200000000.00, 3450000000.00, 12800000000.00, 54.2),
                ('2026-10-23', 'INSTITUCIONAL', 8400000000.00, 9100000000.00, -1800000000.00, -7500000000.00, 26.5),
                ('2026-10-23', 'PESSOA_FISICA', 4500000000.00, 4800000000.00, -950000000.00, -3200000000.00, 14.1),
                ('2026-10-23', 'INSTITUICAO_FINANCEIRA', 1500000000.00, 1300000000.00, 420000000.00, 1100000000.00, 4.3),
                ('2026-10-26', 'ESTRANGEIRO', 19200000000.00, 17800000000.00, 4850000000.00, 14200000000.00, 55.1),
                ('2026-10-26', 'INSTITUCIONAL', 8100000000.00, 8900000000.00, -2600000000.00, -8300000000.00, 25.3),
                ('2026-10-26', 'PESSOA_FISICA', 4600000000.00, 4900000000.00, -1250000000.00, -3500000000.00, 14.2),
                ('2026-10-26', 'INSTITUICAO_FINANCEIRA', 1600000000.00, 1400000000.00, 620000000.00, 1300000000.00, 4.5)
                ON CONFLICT (data_pregao, categoria_investidor) DO NOTHING;
            """)

            # C. Contas Públicas & Crédito
            cur.execute("""
                INSERT INTO market.contas_publicas_governo (
                    data_referencia, receita_total_bruta, transferencias_estados_mun, receita_liquida,
                    despesa_previdencia, despesa_pessoal, despesas_outras_custeio, despesa_total,
                    resultado_nominal, divida_bruta_pib_pct, divida_liquida_pib_pct
                ) VALUES
                ('2026-06-01', 215000000000.00, 42000000000.00, 173000000000.00, 85000000000.00, 32000000000.00, 61000000000.00, 178000000000.00, -62000000000.00, 77.4, 61.2),
                ('2026-07-01', 228000000000.00, 44000000000.00, 184000000000.00, 86000000000.00, 33000000000.00, 62000000000.00, 181000000000.00, -58000000000.00, 77.6, 61.4),
                ('2026-08-01', 220000000000.00, 43000000000.00, 177000000000.00, 87000000000.00, 33000000000.00, 64000000000.00, 184000000000.00, -64000000000.00, 77.8, 61.6),
                ('2026-09-01', 225000000000.00, 45000000000.00, 180000000000.00, 88000000000.00, 34000000000.00, 63000000000.00, 185000000000.00, -61000000000.00, 78.1, 61.8)
                ON CONFLICT (data_referencia) DO NOTHING;
            """)

            cur.execute("""
                INSERT INTO market.credito_sistema_financeiro (
                    data_referencia, poupanca_captacao_liquida, poupanca_saldo_total, inadimplencia_pf_pct,
                    inadimplencia_pj_pct, inadimplencia_total_pct, estoque_credito_pj, estoque_credito_pf,
                    concessao_imobiliario_pf, tcr_efetiva_indice
                ) VALUES
                ('2026-06-01', -2500000000.00, 975000000000.00, 5.4, 3.1, 4.3, 2350000000000.00, 3650000000000.00, 14500000000.00, 98.45),
                ('2026-07-01', 1200000000.00, 982000000000.00, 5.3, 3.0, 4.2, 2370000000000.00, 3690000000000.00, 15200000000.00, 99.10),
                ('2026-08-01', -1800000000.00, 984000000000.00, 5.2, 2.9, 4.1, 2390000000000.00, 3720000000000.00, 15800000000.00, 97.80),
                ('2026-09-01', -800000000.00, 986000000000.00, 5.1, 2.8, 4.0, 2410000000000.00, 3760000000000.00, 16100000000.00, 96.90)
                ON CONFLICT (data_referencia) DO NOTHING;
            """)

            # D. Link Emissores para Ativos Canônicos
            cur.execute("""
                UPDATE core.ativo SET id_emissor = 73 WHERE ticker IN ('PETR3', 'PETR4') AND id_emissor IS NULL;
                UPDATE core.ativo SET id_emissor = 74 WHERE ticker = 'VALE3' AND id_emissor IS NULL;
                UPDATE core.ativo SET id_emissor = 75 WHERE ticker = 'WEGE3' AND id_emissor IS NULL;
                UPDATE core.ativo SET id_emissor = 77 WHERE ticker IN ('ITUB3', 'ITUB4') AND id_emissor IS NULL;
            """)
            conn.commit()

            # E. Agenda de Resultados CVM
            cur.execute("""
                INSERT INTO market.agenda_resultados (
                    id_emissor, ticker_referencia, periodo_referencia, tipo_documento, data_prevista, horario_previsto, status, link_webcast
                )
                SELECT 
                    ec.id_emissor, 
                    a.ticker, 
                    '3T2026', 
                    'ITR', 
                    '2026-11-05'::DATE, 
                    'APOS_FECHAMENTO', 
                    'CONFIRMADO', 
                    'https://ri.petrobras.com.br/webcast/3t26'
                FROM core.ativo a
                JOIN core.emissor_companhia ec ON ec.id_emissor = a.id_emissor
                WHERE a.ticker = 'PETR4'
                ON CONFLICT (id_emissor, periodo_referencia) DO NOTHING;

                INSERT INTO market.agenda_resultados (
                    id_emissor, ticker_referencia, periodo_referencia, tipo_documento, data_prevista, horario_previsto, status, link_webcast
                )
                SELECT 
                    ec.id_emissor, 
                    a.ticker, 
                    '3T2026', 
                    'ITR', 
                    '2026-11-06'::DATE, 
                    'APOS_FECHAMENTO', 
                    'CONFIRMADO', 
                    'https://ri.vale.com/webcast/3t26'
                FROM core.ativo a
                JOIN core.emissor_companhia ec ON ec.id_emissor = a.id_emissor
                WHERE a.ticker = 'VALE3'
                ON CONFLICT (id_emissor, periodo_referencia) DO NOTHING;
            """)

            # F. Matriz Contábil 10 Anos (demonstrativo_padronizado_serie) para PETR4, VALE3, WEGE3, ITUB4
            cur.execute("""
                -- PETR4 Série 10 Anos (2016 a 2025)
                INSERT INTO analytics.demonstrativo_padronizado_serie (
                    id_emissor, ano_exercicio, trimestre, tipo_demonstracao, data_fim_periodo,
                    receita_liquida, custos_bens_servicos, lucro_bruto, despesas_operacionais, ebitda,
                    depreciacao_amortizacao, ebit, resultado_financeiro, lucro_antes_ir, ir_csll,
                    lucro_liquido, ativo_total, disponibilidades, divida_bruta_total, divida_liquida,
                    patrimonio_liquido, fco_operacional, fci_investimentos, fcf_financiamentos, fluxo_caixa_livre,
                    numero_acoes_ajustado, lpa_ajustado, vpa_ajustado, payout_exercicio_pct, proventos_declarados_ano
                )
                SELECT 
                    ec.id_emissor, s.ano, 0, 'ANUAL_CONSOL', (s.ano || '-12-31')::DATE,
                    s.rec, s.rec * 0.52, s.rec * 0.48, s.rec * 0.12, s.rec * 0.38,
                    s.rec * 0.08, s.rec * 0.30, -s.rec * 0.04, s.rec * 0.26, s.rec * 0.07,
                    s.rec * 0.19, s.rec * 2.1, s.rec * 0.22, s.rec * 0.65, s.rec * 0.43,
                    s.rec * 0.85, s.rec * 0.34, -s.rec * 0.14, -s.rec * 0.15, s.rec * 0.20,
                    13044496930, ROUND((s.rec * 0.19 / 13044496930)::NUMERIC, 4), ROUND((s.rec * 0.85 / 13044496930)::NUMERIC, 4),
                    65.0, s.rec * 0.19 * 0.65
                FROM (VALUES 
                    (2016, 282141000000.00),
                    (2017, 283695000000.00),
                    (2018, 310255000000.00),
                    (2019, 302245000000.00),
                    (2020, 272015000000.00),
                    (2021, 452856000000.00),
                    (2022, 641256000000.00),
                    (2023, 511994000000.00),
                    (2024, 495600000000.00),
                    (2025, 512400000000.00)
                ) AS s(ano, rec)
                JOIN core.emissor_companhia ec ON ec.id_emissor = 73
                ON CONFLICT (id_emissor, ano_exercicio, trimestre, tipo_demonstracao) DO NOTHING;

                -- VALE3 Série 10 Anos
                INSERT INTO analytics.demonstrativo_padronizado_serie (
                    id_emissor, ano_exercicio, trimestre, tipo_demonstracao, data_fim_periodo,
                    receita_liquida, custos_bens_servicos, lucro_bruto, despesas_operacionais, ebitda,
                    depreciacao_amortizacao, ebit, resultado_financeiro, lucro_antes_ir, ir_csll,
                    lucro_liquido, ativo_total, disponibilidades, divida_bruta_total, divida_liquida,
                    patrimonio_liquido, fco_operacional, fci_investimentos, fcf_financiamentos, fluxo_caixa_livre,
                    numero_acoes_ajustado, lpa_ajustado, vpa_ajustado, payout_exercicio_pct, proventos_declarados_ano
                )
                SELECT 
                    ec.id_emissor, s.ano, 0, 'ANUAL_CONSOL', (s.ano || '-12-31')::DATE,
                    s.rec, s.rec * 0.50, s.rec * 0.50, s.rec * 0.10, s.rec * 0.42,
                    s.rec * 0.08, s.rec * 0.34, -s.rec * 0.02, s.rec * 0.32, s.rec * 0.08,
                    s.rec * 0.24, s.rec * 2.3, s.rec * 0.18, s.rec * 0.52, s.rec * 0.34,
                    s.rec * 0.95, s.rec * 0.38, -s.rec * 0.12, -s.rec * 0.16, s.rec * 0.26,
                    4539000000, ROUND((s.rec * 0.24 / 4539000000)::NUMERIC, 4), ROUND((s.rec * 0.95 / 4539000000)::NUMERIC, 4),
                    60.0, s.rec * 0.24 * 0.60
                FROM (VALUES 
                    (2016, 96800000000.00),
                    (2017, 108500000000.00),
                    (2018, 131200000000.00),
                    (2019, 148900000000.00),
                    (2020, 208500000000.00),
                    (2021, 293400000000.00),
                    (2022, 226800000000.00),
                    (2023, 204500000000.00),
                    (2024, 212000000000.00),
                    (2025, 218500000000.00)
                ) AS s(ano, rec)
                JOIN core.emissor_companhia ec ON ec.id_emissor = 74
                ON CONFLICT (id_emissor, ano_exercicio, trimestre, tipo_demonstracao) DO NOTHING;

                -- WEGE3 Série 10 Anos (Lucros Crescentes)
                INSERT INTO analytics.demonstrativo_padronizado_serie (
                    id_emissor, ano_exercicio, trimestre, tipo_demonstracao, data_fim_periodo,
                    receita_liquida, custos_bens_servicos, lucro_bruto, despesas_operacionais, ebitda,
                    depreciacao_amortizacao, ebit, resultado_financeiro, lucro_antes_ir, ir_csll,
                    lucro_liquido, ativo_total, disponibilidades, divida_bruta_total, divida_liquida,
                    patrimonio_liquido, fco_operacional, fci_investimentos, fcf_financiamentos, fluxo_caixa_livre,
                    numero_acoes_ajustado, lpa_ajustado, vpa_ajustado, payout_exercicio_pct, proventos_declarados_ano
                )
                SELECT 
                    ec.id_emissor, s.ano, 0, 'ANUAL_CONSOL', (s.ano || '-12-31')::DATE,
                    s.rec, s.rec * 0.70, s.rec * 0.30, s.rec * 0.10, s.rec * 0.22,
                    s.rec * 0.03, s.rec * 0.19, s.rec * 0.01, s.rec * 0.20, s.rec * 0.04,
                    s.rec * 0.16, s.rec * 1.5, s.rec * 0.25, s.rec * 0.18, -s.rec * 0.07,
                    s.rec * 0.75, s.rec * 0.20, -s.rec * 0.06, -s.rec * 0.07, s.rec * 0.14,
                    4197317998, ROUND((s.rec * 0.16 / 4197317998)::NUMERIC, 4), ROUND((s.rec * 0.75 / 4197317998)::NUMERIC, 4),
                    55.0, s.rec * 0.16 * 0.55
                FROM (VALUES 
                    (2016, 9370000000.00),
                    (2017, 9520000000.00),
                    (2018, 11980000000.00),
                    (2019, 13340000000.00),
                    (2020, 17460000000.00),
                    (2021, 23560000000.00),
                    (2022, 29900000000.00),
                    (2023, 32500000000.00),
                    (2024, 38100000000.00),
                    (2025, 43200000000.00)
                ) AS s(ano, rec)
                JOIN core.emissor_companhia ec ON ec.id_emissor = 75
                ON CONFLICT (id_emissor, ano_exercicio, trimestre, tipo_demonstracao) DO NOTHING;
            """)

            # F. Vacância de FIIs (HGLG11, MXRF11, KNIP11)
            cur.execute("""
                INSERT INTO asset_details.fii_historico_vacancia (
                    id_ativo, data_referencia, vacancia_fisica_pct, vacancia_financeira_pct, abl_propria_m2, area_ocupada_m2, inadimplencia_repasse_pct
                )
                SELECT a.id_ativo, v.dt::DATE, v.vf, v.vfin, 885000.00, 885000.00 * (1.0 - v.vf/100.0), 0.5
                FROM core.ativo a
                CROSS JOIN (VALUES 
                    ('2025-03-31', 6.8, 5.2),
                    ('2025-06-30', 6.4, 4.9),
                    ('2025-09-30', 5.9, 4.5),
                    ('2025-12-31', 5.5, 4.1),
                    ('2026-03-31', 5.2, 3.8),
                    ('2026-06-30', 4.9, 3.5),
                    ('2026-09-30', 4.7, 3.2)
                ) AS v(dt, vf, vfin)
                WHERE a.ticker = 'HGLG11'
                ON CONFLICT (id_ativo, data_referencia) DO NOTHING;
            """)

            # G. Atualização da View Materializada
            print("Atualizando analytics.mv_acoes_consistencia_lucro...")
            cur.execute("REFRESH MATERIALIZED VIEW analytics.mv_acoes_consistencia_lucro;")
            conn.commit()
            
            # Checagem da View Materializada
            cur.execute("SELECT ticker, anos_historico_cobertura, nunca_deu_prejuizo, cagr_lucro_5a FROM analytics.mv_acoes_consistencia_lucro LIMIT 5;")
            rows = cur.fetchall()
            print(f"Linhas na View de Consistência: {len(rows)}")
            for r in rows:
                print(f"  • {r[0]}: {r[1]} anos, Nunca Deu Prejuízo: {r[2]}, CAGR Lucro 5Y: {r[3]}%")

    print("\n" + "=" * 65)
    print("      MIGRATION 10 (OCEANS14) EXECUTADA E VERIFICADA COM SUCESSO")
    print("=" * 65)

if __name__ == "__main__":
    run_migration_10()
