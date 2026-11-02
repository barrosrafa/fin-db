"""Validate PostgreSQL syntax and ensure migrations do not execute row DML."""

from __future__ import annotations

from pathlib import Path
import re
from collections.abc import Iterable

from pglast import parse_plpgsql, parse_sql
from pglast.stream import RawStream

FORBIDDEN_NODES = {"InsertStmt", "UpdateStmt", "DeleteStmt", "MergeStmt", "CopyStmt", "TruncateStmt"}
def _contains_do_dml(rendered: str) -> bool:
    """Inspect executed SQL, keeping GRANT/policy keywords out of DML checks."""
    def walk(node):
        if isinstance(node, list):
            return any(walk(item) for item in node)
        if not isinstance(node, dict):
            return False
        if "PLpgSQL_stmt_execsql" in node:
            query = node["PLpgSQL_stmt_execsql"]["sqlstmt"]["PLpgSQL_expr"]["query"]
            return any(type(raw.stmt).__name__ in FORBIDDEN_NODES for raw in parse_sql(query))
        if "PLpgSQL_stmt_dynexecute" in node:
            query = node["PLpgSQL_stmt_dynexecute"]["query"]["PLpgSQL_expr"]["query"]
            # Inspect literal SQL templates without mistaking role privileges or
            # has_table_privilege(..., 'INSERT') arguments for executed writes.
            for literal in re.findall(r"'((?:[^']|'')*)'", query):
                if re.match(r"\s*(INSERT|UPDATE|DELETE|MERGE|COPY|TRUNCATE)\b", literal, re.I):
                    return True
        return any(walk(value) for value in node.values())

    return walk(parse_plpgsql(rendered))


def _validate_source(path: Path) -> list[str]:
    violations: list[str] = []
    source = path.read_text(encoding="utf-8")
    try:
        statements = parse_sql(source)
    except Exception as error:
        raise RuntimeError(f"Invalid PostgreSQL syntax: {path}") from error

    for raw in statements:
        node_type = type(raw.stmt).__name__
        rendered = RawStream()(raw.stmt).upper()
        if node_type in FORBIDDEN_NODES:
            violations.append(f"{path}: {node_type}")
        # CREATE FUNCTION is DDL: DML in its body runs only when the
        # function is invoked later by application code or a trigger.
        elif node_type == "DoStmt" and _contains_do_dml(rendered):
            violations.append(f"{path}: data-writing {node_type}")
        elif node_type == "TransactionStmt":
            violations.append(f"{path}: transaction wrapper belongs in the runner")
    return violations


def validate():
    root = Path(__file__).resolve().parents[1]
    files = sorted((root / "sql").rglob("*.sql"))
    violations: list[str] = []
    for path in files:
        violations.extend(
            violation.replace(str(path), str(path.relative_to(root)), 1)
            for violation in _validate_source(path)
        )
    if violations:
        raise RuntimeError("DDL-only validation failed:\n  " + "\n  ".join(violations))
    print(f"Validated {len(files)} PostgreSQL SQL files; syntax is valid and no row-writing statements remain.")


if __name__ == "__main__":
    validate()
