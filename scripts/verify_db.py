#!/usr/bin/env python3
"""
fin-db: Database Verification and Healthcheck Script
Connects to Neon PostgreSQL and checks schemas, tables, hypertables, views, and row counts.
"""

import os
import sys

try:
    import psycopg
except ImportError:
    print("Please install psycopg: pip install 'psycopg[binary]' or use 'uv run'")
    sys.exit(1)

DEFAULT_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_pwONKPD13RiC@ep-ancient-art-b5mstl4r-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"
)

def run_healthcheck(db_url):
    print("=" * 65)
    print("           FIN-DB: NEON DATABASE HEALTHCHECK")
    print("=" * 65)
    
    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            # 1. Database Info
            cur.execute("SELECT current_database(), current_user, version();")
            db, user, ver = cur.fetchone()
            print(f"Database: {db}")
            print(f"User:     {user}")
            print(f"Engine:   {ver.split(',')[0]}\n")

            # 2. Installed Extensions
            print("--- Installed Extensions ---")
            cur.execute("SELECT extname, extversion FROM pg_extension ORDER BY extname;")
            for name, version in cur.fetchall():
                print(f"  • {name:<20} v{version}")
            print()

            # 3. Schemas and Tables
            print("--- Schema & Table Inventory ---")
            cur.execute("""
                SELECT table_schema, count(*) 
                FROM information_schema.tables 
                WHERE table_schema NOT IN (
                    'information_schema', 'pg_catalog', 'timescaledb_information',
                    '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal',
                    '_timescaledb_functions', '_timescaledb_debug', 'timescaledb_experimental'
                )
                GROUP BY table_schema
                ORDER BY table_schema;
            """)
            total_tables = 0
            for schema, count in cur.fetchall():
                print(f"  • Schema {schema:<15}: {count:>3} tables/views")
                total_tables += count
            print(f"  -------------------------------------")
            print(f"  TOTAL APPLICATION OBJECTS: {total_tables}\n")

            # 4. Hypertables (TimescaleDB)
            print("--- TimescaleDB Hypertables ---")
            try:
                cur.execute("""
                    SELECT hypertable_schema, hypertable_name, num_chunks, compression_enabled 
                    FROM timescaledb_information.hypertables
                    ORDER BY hypertable_schema, hypertable_name;
                """)
                hypertables = cur.fetchall()
                print(f"  Total Hypertables: {len(hypertables)}")
                for s, name, chunks, comp in hypertables:
                    print(f"  • {s}.{name:<30} (chunks: {chunks}, compression: {comp})")
            except Exception as e:
                print(f"  Timescale info unavailable: {e}")
            print()

            # 5. Materialized Views
            print("--- Materialized Views ---")
            cur.execute("""
                SELECT schemaname, matviewname, ispopulated 
                FROM pg_matviews 
                WHERE schemaname NOT LIKE 'pg_%' AND schemaname NOT LIKE '_timescaledb_%'
                ORDER BY schemaname, matviewname;
            """)
            mvs = cur.fetchall()
            for s, name, pop in mvs:
                print(f"  • {s}.{name:<30} (populated: {pop})")
            print()

            # 6. Seed Data Summary
            print("--- Seed Records Summary ---")
            tables_to_check = [
                ("canonical", "currency"),
                ("canonical", "venue"),
                ("canonical", "source"),
                ("core", "moeda"),
                ("core", "fuso_horario"),
                ("core", "bolsa"),
                ("market", "benchmark"),
                ("analytics", "tag"),
                ("system", "oauth_provider"),
            ]
            for schema, table in tables_to_check:
                try:
                    cur.execute(f'SELECT count(*) FROM "{schema}"."{table}";')
                    cnt = cur.fetchone()[0]
                    print(f"  • {schema}.{table:<25}: {cnt:>4} rows")
                except Exception:
                    print(f"  • {schema}.{table:<25}: table not found")

    print("\n" + "=" * 65)
    print("           HEALTHCHECK COMPLETED SUCCESSFULLY")
    print("=" * 65)

if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_URL
    run_healthcheck(url)
