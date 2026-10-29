#!/usr/bin/env python3
"""Read-only inventory and optional empty-database assertion for fin-db."""

import argparse
import os
import sys

try:
    import psycopg
    from psycopg import sql as psql
except ImportError:
    print("Install psycopg with: pip install 'psycopg[binary]'")
    sys.exit(1)

INTERNAL_SCHEMAS = (
    "information_schema", "pg_catalog", "neon_auth", "neon_identity",
    "_timescaledb_catalog", "_timescaledb_config", "_timescaledb_internal",
    "_timescaledb_functions", "_timescaledb_debug", "timescaledb_information",
    "timescaledb_experimental",
)


def run_healthcheck(db_url: str, assert_empty: bool = False) -> bool:
    if not db_url:
        raise ValueError("DATABASE_URL is required (or pass --url).")

    failures = []
    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT current_database(), current_user, version();")
            database, role, version = cur.fetchone()
            print(f"Database: {database}")
            print(f"Role: {role}")
            print(f"Engine: {version.split(',')[0]}")

            cur.execute("SELECT extname, extversion FROM pg_extension ORDER BY extname;")
            print("\nExtensions:")
            for name, ext_version in cur.fetchall():
                print(f"  {name}: {ext_version}")

            cur.execute(
                """
                SELECT table_schema,
                       count(*) FILTER (WHERE table_type = 'BASE TABLE') AS tables,
                       count(*) FILTER (WHERE table_type = 'VIEW') AS views
                  FROM information_schema.tables
                 WHERE table_schema <> ALL(%s)
                   AND table_schema NOT LIKE 'pg\\_%%' ESCAPE '\\'
                   AND table_schema NOT LIKE '\\_timescaledb\\_%%' ESCAPE '\\'
                 GROUP BY table_schema
                 ORDER BY table_schema;
                """,
                (list(INTERNAL_SCHEMAS),),
            )
            inventory = cur.fetchall()
            print("\nApplication schema inventory:")
            total_tables = total_views = 0
            for schema, tables, views in inventory:
                print(f"  {schema}: {tables} tables, {views} views")
                total_tables += tables
                total_views += views
            print(f"Total: {total_tables} tables, {total_views} views")

            cur.execute(
                """
                SELECT schemaname, matviewname, ispopulated
                  FROM pg_matviews
                 WHERE schemaname <> ALL(%s)
                   AND schemaname NOT LIKE 'pg\\_%%' ESCAPE '\\'
                   AND schemaname NOT LIKE '\\_timescaledb\\_%%' ESCAPE '\\'
                 ORDER BY schemaname, matviewname;
                """,
                (list(INTERNAL_SCHEMAS),),
            )
            materialized_views = cur.fetchall()
            print(f"\nMaterialized views: {len(materialized_views)}")
            for schema, name, populated in materialized_views:
                print(f"  {schema}.{name}: populated={populated}")

            cur.execute(
                """
                SELECT table_schema, table_name
                  FROM information_schema.tables
                 WHERE table_type = 'BASE TABLE'
                   AND table_schema <> ALL(%s)
                   AND table_schema NOT LIKE 'pg\\_%%' ESCAPE '\\'
                   AND table_schema NOT LIKE '\\_timescaledb\\_%%' ESCAPE '\\'
                 ORDER BY table_schema, table_name;
                """,
                (list(INTERNAL_SCHEMAS),),
            )
            tables = cur.fetchall()
            if assert_empty:
                for schema, table in tables:
                    cur.execute(
                        psql.SQL("SELECT EXISTS (SELECT 1 FROM {}.{} LIMIT 1)").format(
                            psql.Identifier(schema), psql.Identifier(table)
                        )
                    )
                    if cur.fetchone()[0]:
                        failures.append(f"{schema}.{table}")
                for schema, name, populated in materialized_views:
                    if populated:
                        cur.execute(
                            psql.SQL("SELECT EXISTS (SELECT 1 FROM {}.{} LIMIT 1)").format(
                                psql.Identifier(schema), psql.Identifier(name)
                            )
                        )
                        if cur.fetchone()[0]:
                            failures.append(f"{schema}.{name} (materialized view)")
                if failures:
                    print("\nNon-empty application relations:")
                    for qualified_name in failures:
                        print(f"  {qualified_name}")
                else:
                    print(
                        f"\nEmpty-data check passed: {len(tables)} tables and "
                        f"{len(materialized_views)} materialized views contain no rows."
                    )

    return not failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only fin-db schema inventory.")
    parser.add_argument("--url", default=os.environ.get("DATABASE_URL"), help="PostgreSQL connection URL")
    parser.add_argument("--assert-empty", action="store_true", help="Check every application table and materialized view for rows")
    args = parser.parse_args()
    try:
        return 0 if run_healthcheck(args.url, args.assert_empty) else 1
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
