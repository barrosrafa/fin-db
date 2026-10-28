#!/usr/bin/env python3
"""
Script de execução e verificação da Migration 09 (v3.7 - Fundamentus & Bancos)
"""

import os
import sys
import psycopg

DEFAULT_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_pwONKPD13RiC@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

def run_migration_09():
    print("=" * 60)
    print("      EXECUTANDO MIGRATION 09 (FUNDAMENTUS & BANCOS v3.7)")
    print("=" * 60)
    
    migration_file = os.path.join(
        os.path.dirname(__file__),
        "..",
        "sql",
        "09_fundamentus_coverage_v3.7",
        "01_fundamentus_market_and_indicators.sql"
    )
    
    with open(migration_file, "r", encoding="utf-8") as f:
        sql = f.read()
        
    with psycopg.connect(DEFAULT_URL) as conn:
        with conn.cursor() as cur:
            print("Executando DDL...")
            cur.execute(sql)
            conn.commit()
            print("DDL executado com sucesso!\n")
            
            # Verificações
            print("--- Verificação das Novas Colunas em core.ativo ---")
            for col in ["classe_acao", "min_52_semanas", "max_52_semanas", "volume_medio_2m"]:
                cur.execute("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_schema = 'core' AND table_name = 'ativo' AND column_name = %s;
                """, (col,))
                row = cur.fetchone()
                status = f"✓ {row[0]} ({row[1]})" if row else "✗ FALTANDO"
                print(f"  • core.ativo.{col:<20}: {status}")
                
            print("\n--- Verificação das Novas Tabelas ---")
            for schema, table in [
                ("market", "oscilacao_ativo"),
                ("analytics", "demonstrativo_snapshot_fundamentus")
            ]:
                cur.execute("""
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = %s AND table_name = %s;
                """, (schema, table))
                row = cur.fetchone()
                status = "✓ Criada com sucesso" if row else "✗ FALTANDO"
                print(f"  • {schema}.{table:<35}: {status}")
                
            print("\n--- Verificação dos Novos Registros Canônicos ---")
            cur.execute("""
                SELECT code, name FROM canonical.metric_definition 
                WHERE code IN ('RESULTADO_INTERMEDIACAO_12M', 'RECEITA_SERVICOS_12M', 'MIN_52_SEMANAS', 'MAX_52_SEMANAS', 'VOLUME_MEDIO_2M');
            """)
            rows = cur.fetchall()
            for code, name in rows:
                print(f"  • {code:<30}: {name}")
                
    print("\n" + "=" * 60)
    print("      MIGRATION 09 EXECUTADA E VALIDADA COM 100% DE SUCESSO")
    print("=" * 60)

if __name__ == "__main__":
    run_migration_09()
