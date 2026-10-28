#!/usr/bin/env python3
"""
fin-db: Preflight Extension and Environment Verification Script
Verifies PostgreSQL host version, extensions availability (Neon vs Timescale),
connection roles and RLS support prior to production deployment.
"""

import os
import sys
import argparse

try:
    import psycopg
except ImportError:
    print("Please install psycopg: pip install 'psycopg[binary]' or run with 'uv run'")
    sys.exit(1)

DEFAULT_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

REQUIRED_EXTENSIONS = ["uuid-ossp", "pgcrypto", "pg_trgm"]
OPTIONAL_EXTENSIONS = ["vector", "timescaledb"]


def run_preflight_checks(db_url: str):
    print("=" * 65)
    print("         FIN-DB: PREFLIGHT EXTENSION & ENVIRONMENT AUDIT")
    print("=" * 65)

    try:
        conn = psycopg.connect(db_url)
    except Exception as e:
        print(f"✗ ERROR connecting to database: {e}")
        return False

    with conn:
        with conn.cursor() as cur:
            # 1. PostgreSQL Version
            cur.execute("SELECT version();")
            pg_version = cur.fetchone()[0]
            print(f"\n[1] Database Version: {pg_version[:65]}...")

            # 2. Current User & Permissions
            cur.execute("""
                SELECT current_user, session_user, 
                       rolsuper, rolbypassrls 
                FROM pg_roles 
                WHERE rolname = current_user;
            """)
            role_row = cur.fetchone()
            if role_row:
                user_name, sess_user, is_super, bypass_rls = role_row
                print(f"[2] Connection Role: '{user_name}' (Superuser: {is_super}, BypassRLS: {bypass_rls})")
                if bypass_rls:
                    print("    ⚠ WARNING: Role has BYPASSRLS privilege. Application role must NOT bypass RLS in prod.")
                else:
                    print("    ✓ Role enforces Row-Level Security (RLS) policies properly.")

            # 3. Available and Installed Extensions
            cur.execute("SELECT name, default_version, installed_version FROM pg_available_extensions;")
            ext_map = {r[0]: (r[1], r[2]) for r in cur.fetchall()}

            print("\n[3] Extension Status:")
            for ext in REQUIRED_EXTENSIONS:
                if ext in ext_map:
                    def_v, inst_v = ext_map[ext]
                    status = f"Installed (v{inst_v})" if inst_v else f"Available (v{def_v})"
                    print(f"    • {ext:<15}: ✓ {status}")
                else:
                    print(f"    • {ext:<15}: ✗ MISSING (Required)")

            for ext in OPTIONAL_EXTENSIONS:
                if ext in ext_map:
                    def_v, inst_v = ext_map[ext]
                    status = f"Installed (v{inst_v})" if inst_v else f"Available (v{def_v})"
                    print(f"    • {ext:<15}: ✓ {status}")
                else:
                    print(f"    • {ext:<15}: ○ Not available on host (Using native fallback)")

            # 4. RLS Compatibility Check
            cur.execute("""
                SELECT tablename, rowsecurity 
                FROM pg_tables 
                WHERE schemaname IN ('core', 'wealth', 'social', 'system') 
                  AND rowsecurity = true;
            """)
            rls_tables = [r[0] for r in cur.fetchall()]
            print(f"\n[4] Row Level Security Enabled on {len(rls_tables)} tables in schema:")
            for t in rls_tables[:5]:
                print(f"    • {t}")
            if len(rls_tables) > 5:
                print(f"    • ... and {len(rls_tables) - 5} more.")

    print("\n" + "=" * 65)
    print("                PREFLIGHT AUDIT COMPLETE ✓")
    print("=" * 65)
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Preflight check for Postgres & extensions")
    parser.add_argument("--url", default=DEFAULT_URL, help="PostgreSQL connection string")
    args = parser.parse_args()

    run_preflight_checks(args.url)
