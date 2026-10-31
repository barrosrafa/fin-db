#!/usr/bin/env python3
"""Apply the fin-db DDL migrations in dependency order, one file per transaction."""

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

try:
    import psycopg
    from psycopg import sql as psql
except ImportError:
    print("Install psycopg with: pip install 'psycopg[binary]'")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


load_dotenv(REPO_ROOT / ".env")

MIGRATION_STAGES = [
    ("00_baseline", REPO_ROOT / "sql/00_baseline"),
    ("01_core_schema", REPO_ROOT / "sql/01_core_schema"),
    ("02_improvements_v3.1", REPO_ROOT / "sql/02_improvements_v3.1"),
    ("03_platform_v3.2", REPO_ROOT / "sql/03_platform_v3.2"),
    ("05_coverage_v3.3", REPO_ROOT / "sql/05_coverage_v3.3"),
    ("06_rea_coverage_v3.4", REPO_ROOT / "sql/06_rea_coverage_v3.4"),
    ("07_portfolio_graph_reconciliation_v3.5", REPO_ROOT / "sql/07_portfolio_graph_reconciliation_v3.5"),
    ("08_status_invest_coverage_v3.6", REPO_ROOT / "sql/08_status_invest_coverage_v3.6"),
    ("09_fundamentus_coverage_v3.7", REPO_ROOT / "sql/09_fundamentus_coverage_v3.7"),
    ("10_oceans14_coverage_v3.8", REPO_ROOT / "sql/10_oceans14_coverage_v3.8"),
    ("11_analise_de_acoes_coverage_v3.9", REPO_ROOT / "sql/11_analise_de_acoes_coverage_v3.9"),
    ("12_etfs_brasil_coverage_v4.0", REPO_ROOT / "sql/12_etfs_brasil_coverage_v4.0"),
    ("13_billing_and_auth_v4.1", REPO_ROOT / "sql/13_billing_and_auth_v4.1"),
    ("14_ingestion_control_and_data_quality_v4.2", REPO_ROOT / "sql/14_ingestion_control_and_data_quality_v4.2"),
    ("15_dbt_raw_landing_views_v4.3", REPO_ROOT / "sql/15_dbt_raw_landing_views_v4.3"),
    ("16_market_data_quality_v4.4", REPO_ROOT / "sql/16_market_data_quality_v4.4"),
    ("17_orders_idempotency", REPO_ROOT / "sql/17_orders_idempotency"),
    ("18_empty_materialized_views", REPO_ROOT / "sql/18_empty_materialized_views"),
    ("19_merge_base_b", REPO_ROOT / "sql/19_merge_base_b"),
    ("20_scheduled_engine_v4.5", REPO_ROOT / "sql/20_scheduled_engine_v4.5"),
]

LOCK_KEY = 742198273
METADATA_SCHEMA = "fin_db_migrations"
METADATA_PREFIX = "fin-db-migrations:v1:"


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 64), b""):
            digest.update(chunk)
    return digest.hexdigest()


def migration_files(stages=None):
    for stage_name, stage_path in MIGRATION_STAGES:
        if stages and stage_name not in stages:
            continue
        if not stage_path.is_dir():
            raise FileNotFoundError(f"Migration stage directory is missing: {stage_path}")
        for path in sorted(stage_path.glob("*.sql")):
            yield stage_name, path


def direct_connection_url(db_url: str) -> str:
    """Use Neon direct endpoint for the TimescaleDB first-command requirement."""
    parts = urlsplit(db_url)
    if not parts.hostname or "-pooler." not in parts.hostname:
        return db_url
    direct_host = parts.hostname.replace("-pooler.", ".", 1)
    authority = parts.netloc.replace(parts.hostname, direct_host, 1)
    return urlunsplit((parts.scheme, authority, parts.path, parts.query, parts.fragment))


def ensure_timescaledb(db_url: str) -> None:
    direct_url = direct_connection_url(db_url)
    # Neon requires the extension command to be the first SQL statement on a
    # fresh direct connection. Keep it outside all migration transactions.
    with psycopg.connect(direct_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS timescaledb;")
            cur.execute("SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';")
            row = cur.fetchone()
            if not row:
                raise RuntimeError("TimescaleDB is required, but the extension is not installed.")
            print(f"TimescaleDB ready (version {row[0]}).")


def encode_history(history: dict[str, str]) -> str:
    return METADATA_PREFIX + json.dumps(history, sort_keys=True, separators=(",", ":"))


def write_history_comment(cur, history: dict[str, str]) -> None:
    comment = encode_history(history)
    statement = psql.SQL("COMMENT ON SCHEMA {} IS {}").format(
        psql.Identifier(METADATA_SCHEMA), psql.Literal(comment)
    )
    cur.execute(statement)


def ensure_history_schema(conn) -> dict[str, str]:
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute(psql.SQL("CREATE SCHEMA IF NOT EXISTS {}").format(psql.Identifier(METADATA_SCHEMA)))
            cur.execute(
                "SELECT obj_description(%s::regnamespace, 'pg_namespace');",
                (METADATA_SCHEMA,),
            )
            existing = cur.fetchone()[0]
            if existing is None:
                history = {}
                write_history_comment(cur, history)
                return history
            if not existing.startswith(METADATA_PREFIX):
                raise RuntimeError(
                    f"Schema {METADATA_SCHEMA!r} already exists with an unrecognized comment; "
                    "refusing to overwrite migration metadata."
                )
            try:
                history = json.loads(existing[len(METADATA_PREFIX):])
            except json.JSONDecodeError as exc:
                raise RuntimeError("Migration metadata comment is not valid JSON.") from exc
            if not isinstance(history, dict) or any(not isinstance(v, str) for v in history.values()):
                raise RuntimeError("Migration metadata has an unexpected format.")
            return history


def _has_executable_sql(source: str) -> bool:
    return any(
        line.strip() and not line.lstrip().startswith("--")
        for line in source.splitlines()
    )


def run_migrations(db_url: str, stages=None, dry_run: bool = False) -> tuple[int, int]:
    files = list(migration_files(stages))
    if dry_run:
        for stage_name, path in files:
            print(f"[DRY-RUN] {stage_name}/{path.name} SHA256={file_sha256(path)}")
        print(f"Offline plan complete: {len(files)} migration files; no connection opened.")
        return 0, len(files)

    if not db_url:
        raise ValueError("DATABASE_URL is required (or pass --url).")

    ensure_timescaledb(db_url)
    conn = psycopg.connect(db_url, autocommit=True)
    applied = skipped = 0
    lock_acquired = False
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_lock(%s);", (LOCK_KEY,))
            lock_acquired = True

        history = ensure_history_schema(conn)
        for stage_name, path in files:
            key = f"{stage_name}/{path.name}"
            checksum = file_sha256(path)
            previous = history.get(key)
            if previous is not None:
                if previous != checksum:
                    raise RuntimeError(
                        f"Checksum drift for applied migration {key}; refusing to replay changed SQL."
                    )
                print(f"[SKIP] {key} (checksum matches)")
                skipped += 1
                continue

            source = path.read_text(encoding="utf-8")
            if not _has_executable_sql(source):
                raise RuntimeError(f"Migration file contains no executable SQL: {key}")

            print(f"[APPLY] {key} ...", flush=True)
            next_history = dict(history)
            next_history[key] = checksum
            try:
                # autocommit stays enabled outside this explicit transaction,
                # so each file commits independently. A later failure cannot
                # roll back files that have already completed.
                with conn.transaction():
                    with conn.cursor() as cur:
                        cur.execute(source)
                        write_history_comment(cur, next_history)
            except Exception as exc:
                raise RuntimeError(f"Migration failed and only this file was rolled back: {key}: {exc}") from exc
            history = next_history
            applied += 1
            print("[OK]")

        print(f"Migration run complete: {applied} applied, {skipped} already current.")
        return applied, skipped
    finally:
        if lock_acquired:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT pg_advisory_unlock(%s);", (LOCK_KEY,))
            except Exception:
                pass
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply fin-db schema migrations (DDL only).")
    parser.add_argument("--url", default=os.environ.get("DATABASE_URL"), help="PostgreSQL connection URL")
    parser.add_argument("--stage", choices=[name for name, _ in MIGRATION_STAGES])
    parser.add_argument("--dry-run", action="store_true", help="List planned migrations without connecting")
    args = parser.parse_args()
    try:
        run_migrations(args.url, [args.stage] if args.stage else None, args.dry_run)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
