"""Parse every checked-in SQL migration using PostgreSQL grammar, without a database."""
from pathlib import Path
from pglast import parse_sql


def validate():
    root = Path(__file__).resolve().parents[1]
    files = sorted((root / "sql").rglob("*.sql"))
    for path in files:
        try:
            parse_sql(path.read_text())
        except Exception as error:
            raise RuntimeError(f"Invalid PostgreSQL syntax: {path.relative_to(root)}") from error
    print(f"Parsed {len(files)} SQL files using PostgreSQL grammar; no database credentials used")


if __name__ == "__main__":
    validate()
