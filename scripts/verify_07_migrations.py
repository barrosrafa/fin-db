#!/usr/bin/env python3
"""
Verification script for 07_portfolio_graph_reconciliation_v3.5 SQL migrations.
Checks file presence, required schemas, tables, bitemporal ranges, and seeds.
"""
import os
import re
import sys

MIGRATION_DIR = os.path.join(
    os.path.dirname(__file__), "..", "sql", "07_portfolio_graph_reconciliation_v3.5"
)

REQUIRED_FILES = [
    "01_graph_bitemporal_and_mdm.sql",
    "02_reconciliation_and_taxonomies.sql",
    "03_seeds_anbima_and_legacy_cris.sql",
]

REQUIRED_TABLES = [
    "graph.entities",
    "graph.entity_aliases",
    "graph.edges_bitemporal",
    "canonical.cri_legacy_seeds",
    "wealth.user_graph_overrides",
    "audit.inference_logs",
    "audit.discrepancies",
    "reconciliation.divergence_taxonomies",
    "reconciliation.metric_snapshots",
    "reconciliation.divergences",
    "reconciliation.canonical_metrics",
]

REQUIRED_TAXONOMIES = [
    "PRICE_TIMESTAMP_MISMATCH",
    "DIVIDEND_WINDOW_MISMATCH",
    "TAX_TREATMENT_MISMATCH",
    "CAPITAL_BASE_MISMATCH",
    "AMORTIZATION_ACCOUNTING",
    "SOURCE_STALENESS_OR_ERROR",
]


def main():
    print(f"Checking migration directory: {MIGRATION_DIR}")
    if not os.path.exists(MIGRATION_DIR):
        print(f"ERROR: Migration directory not found: {MIGRATION_DIR}")
        sys.exit(1)

    combined_sql = ""
    for filename in REQUIRED_FILES:
        filepath = os.path.join(MIGRATION_DIR, filename)
        if not os.path.exists(filepath):
            print(f"ERROR: Required migration file missing: {filename}")
            sys.exit(1)
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
            combined_sql += "\n" + content
        print(f"✓ Found {filename}")

    # Verify tables
    for table in REQUIRED_TABLES:
        pattern = rf"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?{re.escape(table)}"
        if not re.search(pattern, combined_sql, re.IGNORECASE):
            print(f"ERROR: Table declaration missing for {table}")
            sys.exit(1)
        print(f"✓ Table {table} declared")

    # Verify bitemporal ranges
    if "valid_range tstzrange" not in combined_sql and "valid_range TSTZRANGE" not in combined_sql:
        print("ERROR: valid_range TSTZRANGE column missing in graph.edges_bitemporal")
        sys.exit(1)
    if "transaction_range tstzrange" not in combined_sql and "transaction_range TSTZRANGE" not in combined_sql:
        print("ERROR: transaction_range TSTZRANGE column missing in graph.edges_bitemporal")
        sys.exit(1)
    print("✓ Bitemporal ranges (valid_range, transaction_range) present")

    # Verify coverage_category
    if "coverage_category" not in combined_sql:
        print("ERROR: coverage_category missing in edges")
        sys.exit(1)
    print("✓ coverage_category present")

    # Verify taxonomies in seeds
    for tax in REQUIRED_TAXONOMIES:
        if tax not in combined_sql:
            print(f"ERROR: Required taxonomy seed missing: {tax}")
            sys.exit(1)
        print(f"✓ Taxonomy {tax} seeded")

    print("\nALL VERIFICATIONS PASSED!")


if __name__ == "__main__":
    main()
