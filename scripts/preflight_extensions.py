#!/usr/bin/env python3
"""Read-only PostgreSQL extension, role, and RLS preflight."""

import argparse
import os
import sys
from pathlib import Path

try:
    import psycopg
except ImportError:
    print("Install psycopg with: pip install 'psycopg[binary]'")
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"
if ENV_FILE.exists():
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip("'\""))

REQUIRED_EXTENSIONS = ("uuid-ossp", "pgcrypto", "pg_trgm", "vector", "timescaledb")
INTERNAL_SCHEMAS = ("information_schema", "pg_catalog", "_timescaledb_catalog", "_timescaledb_config", "_timescaledb_internal")


def run_preflight_checks(db_url: str) -> bool:
    if not db_url:
        raise ValueError("DATABASE_URL is required (or pass --url).")

    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT version();")
            print(f"PostgreSQL: {cur.fetchone()[0].split(',')[0]}")

            cur.execute("SELECT current_user, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user;")
            role, is_superuser, bypass_rls = cur.fetchone()
            print(f"Role: {role}; superuser={is_superuser}; bypass_rls={bypass_rls}")
            if bypass_rls:
                print("WARNING: connected role bypasses row-level security.")

            cur.execute("SELECT name, default_version, installed_version FROM pg_available_extensions;")
            extensions = {name: (default, installed) for name, default, installed in cur.fetchall()}
            print("\nRequired extensions:")
            missing = []
            for name in REQUIRED_EXTENSIONS:
                entry = extensions.get(name)
                if entry is None:
                    print(f"  MISSING: {name}")
                    missing.append(name)
                else:
                    default, installed = entry
                    state = f"installed {installed}" if installed else f"available {default}, not installed"
                    print(f"  {name}: {state}")
                    if not installed:
                        missing.append(name)

            cur.execute(
                """
                SELECT count(*)
                  FROM pg_tables
                 WHERE schemaname <> ALL(%s)
                   AND rowsecurity = true;
                """,
                (list(INTERNAL_SCHEMAS),),
            )
            print(f"\nTables with RLS enabled: {cur.fetchone()[0]}")
    return not missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only PostgreSQL preflight.")
    parser.add_argument("--url", default=os.environ.get("DATABASE_URL"), help="PostgreSQL connection URL")
    args = parser.parse_args()
    try:
        return 0 if run_preflight_checks(args.url) else 1
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
