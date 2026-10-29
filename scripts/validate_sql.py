"""Validate PostgreSQL syntax and ensure migrations do not execute row DML."""
from pathlib import Path
import re
from pglast import parse_sql
from pglast.stream import RawStream

FORBIDDEN_NODES = {"InsertStmt", "UpdateStmt", "DeleteStmt", "MergeStmt", "CopyStmt", "TruncateStmt"}


def validate():
    root = Path(__file__).resolve().parents[1]
    files = sorted((root / "sql").rglob("*.sql"))
    violations = []
    for path in files:
        source = path.read_text(encoding="utf-8")
        try:
            statements = parse_sql(source)
        except Exception as error:
            raise RuntimeError(f"Invalid PostgreSQL syntax: {path.relative_to(root)}") from error
        for raw in statements:
            node_type = type(raw.stmt).__name__
            rendered = RawStream()(raw.stmt).upper()
            if node_type in FORBIDDEN_NODES:
                violations.append(f"{path.relative_to(root)}: {node_type}")
            # CREATE FUNCTION is DDL: DML in its body runs only when the
            # function is invoked later by application code or a trigger.
            elif node_type == "DoStmt" and any(re.search(rf"\\b{word}\\b", rendered) for word in ("INSERT", "UPDATE", "DELETE", "MERGE")):
                violations.append(f"{path.relative_to(root)}: data-writing {node_type}")
            elif node_type == "TransactionStmt":
                violations.append(f"{path.relative_to(root)}: transaction wrapper belongs in the runner")
    if violations:
        raise RuntimeError("DDL-only validation failed:\n  " + "\n  ".join(violations))
    print(f"Validated {len(files)} PostgreSQL SQL files; syntax is valid and no row-writing statements remain.")


if __name__ == "__main__":
    validate()
