#!/usr/bin/env python3
"""
fin-db: Verification Script for Migration 11 (Análise de Ações Full Coverage v3.9)
Executes SQL migration and verifies schemas, tables, columns, constraints and seeds.
"""

import os
import sys
from pathlib import Path
import psycopg

REPO_ROOT = Path(__file__).resolve().parent.parent
MIGRATION_FILE = REPO_ROOT / "sql" / "11_analise_de_acoes_coverage_v3.9" / "01_analise_de_acoes_tables_and_views.sql"
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_pwONKPD13RiC@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

EXPECTED_TABLES = [
    ("market", "cotacao_cambio_diaria"),
    ("core", "ativo_dupla_listagem"),
    ("asset_details", "detalhe_reit"),
    ("analytics", "mapa_sazonalidade_dividendo"),
    ("cms", "termo_glossario"),
    ("cms", "livro_investimento"),
    ("cms", "artigo_blog"),
    ("cms", "ticket_suporte"),
    ("suitability", "pergunta"),
    ("suitability", "opcao_resposta"),
    ("suitability", "categoria_risco"),
    ("suitability", "historico_respostas_usuario"),
    ("system", "plano_entitlement"),
    ("system", "webhook_evento_processado"),
]

def verify_and_apply():
    print("=" * 65)
    print("      EXECUTANDO MIGRATION 11 (ANÁLISE DE AÇÕES COVERAGE v3.9)")
    print("=" * 65)
    
    if not MIGRATION_FILE.exists():
        print(f"✗ Erro: Arquivo de migração não encontrado: {MIGRATION_FILE}")
        sys.exit(1)
        
    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        with conn.cursor() as cur:
            print("Executando DDL...")
            with open(MIGRATION_FILE, "r", encoding="utf-8") as f:
                sql = f.read()
            cur.execute(sql)
            print("DDL executado com sucesso!\n")
            
            print("--- Verificação das Novas Tabelas ---")
            for schema, table in EXPECTED_TABLES:
                cur.execute(
                    """
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = %s AND table_name = %s
                    );
                    """,
                    (schema, table)
                )
                exists = cur.fetchone()[0]
                if exists:
                    print(f"  • {schema}.{table:<32}: ✓ Criada com sucesso")
                else:
                    print(f"  • {schema}.{table:<32}: ✗ FALHA - Tabela não existe")
                    sys.exit(1)

            print("\n--- Verificação das Novas Colunas ---")
            # Proventos
            cur.execute(
                """
                SELECT column_name FROM information_schema.columns
                WHERE table_schema = 'market' AND table_name = 'provento'
                  AND column_name IN ('valor_bruto_usd', 'aliquota_retencao_fonte', 'valor_liquido_moeda');
                """
            )
            cols = [r[0] for r in cur.fetchall()]
            print(f"  • market.provento colunas internacionais: {cols} ({'✓' if len(cols) == 3 else '✗'})")
            
            # Corretoras
            cur.execute(
                """
                SELECT column_name FROM information_schema.columns
                WHERE table_schema = 'core' AND table_name = 'instituicao_financeira'
                  AND column_name IN ('taxa_corretagem_acoes', 'taxa_corretagem_fiis', 'spread_cambial_ptax_pct');
                """
            )
            cols_inst = [r[0] for r in cur.fetchall()]
            print(f"  • core.instituicao_financeira colunas tarifas: {cols_inst} ({'✓' if len(cols_inst) == 3 else '✗'})")

            print("\n--- Verificação de Contagem de Seeds Iniciais ---")
            queries = [
                ("cms.termo_glossario", "SELECT count(*) FROM cms.termo_glossario"),
                ("cms.livro_investimento", "SELECT count(*) FROM cms.livro_investimento"),
                ("cms.artigo_blog", "SELECT count(*) FROM cms.artigo_blog"),
                ("suitability.pergunta", "SELECT count(*) FROM suitability.pergunta"),
                ("suitability.categoria_risco", "SELECT count(*) FROM suitability.categoria_risco"),
                ("core.instituicao_financeira (corretoras)", "SELECT count(*) FROM core.instituicao_financeira WHERE tipo = 'CORRETORA'"),
                ("analytics.mapa_sazonalidade_dividendo", "SELECT count(*) FROM analytics.mapa_sazonalidade_dividendo"),
                ("asset_details.detalhe_reit", "SELECT count(*) FROM asset_details.detalhe_reit"),
            ]
            for label, q in queries:
                cur.execute(q)
                cnt = cur.fetchone()[0]
                print(f"  • {label:<42}: {cnt} registros")

    print("\n" + "=" * 65)
    print("      MIGRATION 11 (ANÁLISE DE AÇÕES) EXECUTADA COM SUCESSO!")
    print("=" * 65)

if __name__ == "__main__":
    verify_and_apply()
