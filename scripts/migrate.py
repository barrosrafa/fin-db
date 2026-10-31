#!/usr/bin/env python3
"""
fin-db: Robust Transactional Migration Runner with Ledger, Checksums & Advisory Lock
Applies SQL migrations and seeds in strict dependency order with idempotency.
"""

import os
import sys
import argparse
import hashlib
from pathlib import Path

try:
    import psycopg
except ImportError:
    print("Please install psycopg: pip install 'psycopg[binary]' or run with 'uv run'")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent

# Tenta carregar .env automaticamente se presente
env_file = REPO_ROOT / ".env"
if env_file.exists():
    try:
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    if k not in os.environ and v:
                        os.environ[k] = v
    except Exception:
        pass

DEFAULT_URL = os.environ.get("DATABASE_URL", "")

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
    ("13_billing_and_auth_v4.1", REPO_ROOT / "sql" / "13_billing_and_auth_v4.1"),
    ("14_ingestion_control_and_data_quality_v4.2", REPO_ROOT / "sql" / "14_ingestion_control_and_data_quality_v4.2"),
    ("15_dbt_raw_landing_views_v4.3", REPO_ROOT / "sql" / "15_dbt_raw_landing_views_v4.3"),
    ("16_market_data_quality_v4.4", REPO_ROOT / "sql" / "16_market_data_quality_v4.4"),
    ("17_scheduled_engine_v4.5", REPO_ROOT / "sql" / "17_scheduled_engine_v4.5"),
    ("18_runtime_security", REPO_ROOT / "sql" / "18_runtime_security"),
]

LOCK_KEY = 742198273  # Deterministic 32-bit int for pg_advisory_lock


def get_file_sha256(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def ensure_migration_table(conn):
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS system;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS system.schema_migrations (
                version    VARCHAR(255) PRIMARY KEY,
                checksum   VARCHAR(64) NOT NULL,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        """)
    conn.commit()


def get_applied_migrations(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT version, checksum FROM system.schema_migrations;")
        return dict(cur.fetchall())


def run_migrations(db_url: str, stages_to_run=None, dry_run: bool = False):
    # Manual files cannot enter either an automatic plan or an automatic apply.
    for stage_name, stage_path in MIGRATION_STAGES:
        if stages_to_run and stage_name not in stages_to_run:
            continue
        for path in stage_path.glob("*.sql"):
            header = path.read_text(encoding="utf-8")[:1000].lower()
            if ("manual" in stage_name.lower() or "manual" in path.stem.lower()
                    or "-- execution: manual" in header):
                raise RuntimeError(f"Manual migration forbidden in automatic runner: {stage_name}/{path.name}")
    if dry_run:
        # Planning must be offline: no credentials, advisory locks, or ledger writes.
        for stage_name, stage_path in MIGRATION_STAGES:
            if stages_to_run and stage_name not in stages_to_run:
                continue
            for sql_file in sorted(stage_path.glob("*.sql")):
                print(f"[DRY-RUN] {stage_name}/{sql_file.name} SHA256={get_file_sha256(sql_file)}")
        print("OFFLINE DRY RUN COMPLETE: no database connection opened.")
        return

    if not db_url:
        print("ERROR: DATABASE_URL not provided via CLI argument or environment variable.")
        sys.exit(1)

    print("=" * 70)
    print("        FIN-DB: ROBUST TRANSACTIONAL MIGRATION RUNNER")
    print("=" * 70)

    try:
        conn = psycopg.connect(db_url, autocommit=True, connect_timeout=15)
    except Exception as e:
        print(f"ERROR: Failed to connect to database ({type(e).__name__})")
        sys.exit(1)

    with conn:
        with conn.cursor() as domain_cursor:
            domain_cursor.execute("SELECT current_database()")
            if domain_cursor.fetchone()[0] == "fin_cms":
                raise RuntimeError("Financial migrations cannot run on the dedicated CMS database")
        with conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_lock(%s);", (LOCK_KEY,))

        try:
            ensure_migration_table(conn)
            applied_map = get_applied_migrations(conn)
            # Validate every selected historical checksum before applying any new file.
            for stage_name, stage_path in MIGRATION_STAGES:
                if stages_to_run and stage_name not in stages_to_run:
                    continue
                for path in sorted(stage_path.glob("*.sql")):
                    key = f"{stage_name}/{path.name}"
                    if key in applied_map and applied_map[key] != get_file_sha256(path):
                        raise RuntimeError(f"Checksum drift for applied migration {key}; refusing to reapply historical SQL")
                    if "manual" in stage_name.lower() or "manual" in path.stem.lower():
                        raise RuntimeError(f"Manual migration forbidden in automatic runner: {key}")

            total_applied = 0
            total_skipped = 0

            for stage_name, stage_path in MIGRATION_STAGES:
                if stages_to_run and stage_name not in stages_to_run:
                    continue

                if not stage_path.exists():
                    print(f"Directory not found: {stage_path}")
                    continue

                sql_files = sorted(stage_path.glob("*.sql"))
                print(f"\n▶ Stage: {stage_name} ({len(sql_files)} files)")

                for sql_file in sql_files:
                    version_key = f"{stage_name}/{sql_file.name}"
                    current_checksum = get_file_sha256(sql_file)

                    if version_key in applied_map:
                        stored_checksum = applied_map[version_key]
                        if stored_checksum != current_checksum:
                            raise RuntimeError(f"Checksum drift for applied migration {version_key}; refusing to reapply historical SQL")
                        else:
                            print(f"  • {sql_file.name} [Already applied ✓]")
                            total_skipped += 1
                            continue

                    if dry_run:
                        print(f"  [DRY-RUN] Would apply: {sql_file.name} (SHA: {current_checksum[:8]})")
                        total_applied += 1
                        continue

                    print(f"  • Applying {sql_file.name}...", end=" ", flush=True)
                    try:
                        with open(sql_file, "r", encoding="utf-8") as f:
                            sql = f.read()

                        with conn.transaction():
                            with conn.cursor() as cur:
                                cur.execute(sql)
                                cur.execute(
                                    """
                                    INSERT INTO system.schema_migrations (version, checksum)
                                    VALUES (%s, %s)
                                    ON CONFLICT (version) DO UPDATE SET 
                                        checksum = EXCLUDED.checksum, 
                                        applied_at = NOW();
                                    """,
                                    (version_key, current_checksum),
                                )
                        print("✓ OK")
                        total_applied += 1
                    except Exception as e:
                        print(f"\n✗ FAILED on {version_key} ({type(e).__name__})")
                        sys.exit(1)

            print("\n" + "=" * 70)
            status_text = "DRY RUN COMPLETE" if dry_run else "ALL MIGRATIONS SYNCHRONIZED"
            print(f"  {status_text}: {total_applied} applied, {total_skipped} skipped.")
            print("=" * 70)

        finally:
            with conn.cursor() as cur:
                cur.execute("SELECT pg_advisory_unlock(%s);", (LOCK_KEY,))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run fin-db database migrations")
    parser.add_argument("--url", default=DEFAULT_URL, help="PostgreSQL connection string")
    parser.add_argument("--stage", choices=[s[0] for s in MIGRATION_STAGES], help="Run only specific stage")
    parser.add_argument("--dry-run", "--plan", action="store_true", help="Inspect pending migrations without executing")
    args = parser.parse_args()

    stages = [args.stage] if args.stage else None
    run_migrations(args.url, stages, dry_run=args.dry_run)
