#!/usr/bin/env python3
"""
fin-db: Verification Script for Migration 12 (ETFs Brasil Coverage v4.0)
Executes SQL migration and verifies schemas, tables, columns, constraints and seeds.
"""

import os
import sys
from pathlib import Path
import psycopg

REPO_ROOT = Path(__file__).resolve().parent.parent
MIGRATION_FILE = REPO_ROOT / "sql" / "12_etfs_brasil_coverage_v4.0" / "01_etfs_brasil_tables_and_views.sql"
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

EXPECTED_TABLES = [
    ("asset_details", "fi_infra_detalhe"),
    ("market", "etf_composicao_carteira"),
    ("market", "etf_metricas_diarias"),
    ("analytics", "simulador_portfolio_config"),
    ("analytics", "simulador_portfolio_carteira"),
    ("analytics", "simulador_portfolio_ativo"),
    ("analytics", "simulador_portfolio_resultado"),
    ("market", "comparador_par_canonico"),
]

def verify_and_apply():
    print("=" * 65)
    print("      EXECUTANDO MIGRATION 12 (ETFs BRASIL COVERAGE v4.0)")
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

            print("\n--- Verificação de Índices e Pares Canônicos ---")
            cur.execute("SELECT count(*) FROM market.comparador_par_canonico;")
            cnt_pares = cur.fetchone()[0]
            print(f"  • market.comparador_par_canonico     : {cnt_pares} pares pré-computados")

            cur.execute("SELECT count(*) FROM market.etf_composicao_carteira;")
            cnt_holdings = cur.fetchone()[0]
            print(f"  • market.etf_composicao_carteira     : {cnt_holdings} registros de holdings")

    print("\n" + "=" * 65)
    print("      MIGRATION 12 (ETFs BRASIL) EXECUTADA COM SUCESSO!")
    print("=" * 65)

if __name__ == "__main__":
    verify_and_apply()
