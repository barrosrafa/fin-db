#!/usr/bin/env python3
"""
fin-db: Automated Migration Runner
Applies SQL migrations and seeds in correct dependency order to Neon or PostgreSQL.
"""

import os
import sys
import argparse
from pathlib import Path

try:
    import psycopg
except ImportError:
    print("Please install psycopg: pip install 'psycopg[binary]' or run with 'uv run'")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

MIGRATION_STAGES = [
    ("00_baseline", REPO_ROOT / "sql" / "00_baseline"),
    ("01_core_schema", REPO_ROOT / "sql" / "01_core_schema"),
    ("02_improvements_v3.1", REPO_ROOT / "sql" / "02_improvements_v3.1"),
    ("03_platform_v3.2", REPO_ROOT / "sql" / "03_platform_v3.2"),
    ("04_seeds", REPO_ROOT / "sql" / "04_seeds"),
    ("05_coverage_v3.3", REPO_ROOT / "sql" / "05_coverage_v3.3"),
    ("06_rea_coverage_v3.4", REPO_ROOT / "sql" / "06_rea_coverage_v3.4"),
    ("07_portfolio_graph_reconciliation_v3.5", REPO_ROOT / "sql" / "07_portfolio_graph_reconciliation_v3.5"),
    ("08_status_invest_coverage_v3.6", REPO_ROOT / "sql" / "08_status_invest_coverage_v3.6"),
    ("09_fundamentus_coverage_v3.7", REPO_ROOT / "sql" / "09_fundamentus_coverage_v3.7"),
    ("10_oceans14_coverage_v3.8", REPO_ROOT / "sql" / "10_oceans14_coverage_v3.8"),
    ("11_analise_de_acoes_coverage_v3.9", REPO_ROOT / "sql" / "11_analise_de_acoes_coverage_v3.9"),
    ("12_etfs_brasil_coverage_v4.0", REPO_ROOT / "sql" / "12_etfs_brasil_coverage_v4.0"),
]

def run_migrations(db_url, stages_to_run=None):
    if not db_url:
        print("ERROR: DATABASE_URL not provided via CLI argument or environment variable.")
        sys.exit(1)

    print("=" * 65)
    print("                 FIN-DB: MIGRATION RUNNER")
    print("=" * 65)
    
    with psycopg.connect(db_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            for stage_name, stage_path in MIGRATION_STAGES:
                if stages_to_run and stage_name not in stages_to_run:
                    continue

                if not stage_path.exists():
                    print(f"Directory not found: {stage_path}")
                    continue

                sql_files = sorted(stage_path.glob("*.sql"))
                print(f"\n▶ Stage: {stage_name} ({len(sql_files)} files)")

                for sql_file in sql_files:
                    print(f"  • Applying {sql_file.name}...", end=" ", flush=True)
                    try:
                        with open(sql_file, "r", encoding="utf-8") as f:
                            sql = f.read()
                        cur.execute(sql)
                        print("✓ OK")
                    except Exception as e:
                        print(f"✗ FAILED: {e}")
                        sys.exit(1)

    print("\n" + "=" * 65)
    print("                 ALL MIGRATIONS APPLIED!")
    print("=" * 65)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run fin-db database migrations")
    parser.add_argument("--url", default=DEFAULT_URL, help="PostgreSQL connection string")
    parser.add_argument("--stage", choices=[s[0] for s in MIGRATION_STAGES], help="Run only specific stage")
    args = parser.parse_args()

    stages = [args.stage] if args.stage else None
    run_migrations(args.url, stages)
