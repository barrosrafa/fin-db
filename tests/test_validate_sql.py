import importlib.util
import os
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, relative_path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


validate_sql = load_module("fin_validate_sql", "scripts/validate_sql.py")
common = load_module("fin_common", "scripts/common.py")


class SqlValidationTests(unittest.TestCase):
    def test_do_statement_with_dml_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "dml.sql"
            path.write_text(
                "DO $$ BEGIN INSERT INTO example_table(id) VALUES (1); END $$;\n",
                encoding="utf-8",
            )
            violations = validate_sql._validate_source(path)
        self.assertEqual(violations, [f"{path}: data-writing DoStmt"])

    def test_do_statement_with_delete_clause_is_not_false_positive(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "ddl.sql"
            path.write_text(
                "DO $$ BEGIN ALTER TABLE example_table ADD CONSTRAINT fk FOREIGN KEY (id) REFERENCES other_table(id) ON DELETE CASCADE; END $$;\n",
                encoding="utf-8",
            )
            violations = validate_sql._validate_source(path)
        self.assertEqual(violations, [])

    def test_load_dotenv_does_not_override_existing_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / ".env"
            path.write_text("FIN_DB_TEST='from-file'\n", encoding="utf-8")
            key = "FIN_DB_TEST"
            previous = os.environ.get(key)
            try:
                os.environ[key] = "from-process"
                common.load_dotenv(path)
                self.assertEqual(os.environ[key], "from-process")
            finally:
                if previous is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = previous


if __name__ == "__main__":
    unittest.main()
