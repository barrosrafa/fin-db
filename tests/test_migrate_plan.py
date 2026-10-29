import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location(
    "fin_migrate", Path(__file__).resolve().parents[1] / "scripts/migrate.py"
)
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)


class MigrationRunnerTests(unittest.TestCase):
    def test_dry_run_never_connects(self):
        output = io.StringIO()
        with patch.object(migrate.psycopg, "connect", side_effect=AssertionError("network forbidden")) as connect:
            with contextlib.redirect_stdout(output):
                applied, total = migrate.run_migrations("", ["01_core_schema"], dry_run=True)
        connect.assert_not_called()
        self.assertEqual((applied, total), (0, len(list((migrate.REPO_ROOT / "sql/01_core_schema").glob("*.sql")))))
        self.assertIn("01_core_schema/", output.getvalue())
        self.assertIn("no connection opened", output.getvalue())
        self.assertNotIn("02_improvements_v3.1/", output.getvalue())

    def test_neon_pooler_hostname_is_converted_to_direct_hostname(self):
        source = "postgresql://user:secret@ep-example-pooler.c-7.us-east-2.aws.neon.tech/db?sslmode=require"
        result = migrate.direct_connection_url(source)
        self.assertEqual(
            result,
            "postgresql://user:secret@ep-example.c-7.us-east-2.aws.neon.tech/db?sslmode=require",
        )
        self.assertEqual(migrate.direct_connection_url("postgresql://localhost/db"), "postgresql://localhost/db")

    def test_each_migration_file_gets_its_own_transaction(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            (path / "01_first.sql").write_text("SELECT 1;\n")
            (path / "02_second.sql").write_text("SELECT 2;\n")
            conn = MagicMock()
            output = io.StringIO()
            with patch.object(migrate, "MIGRATION_STAGES", [("test", path)]), \
                 patch.object(migrate, "ensure_timescaledb"), \
                 patch.object(migrate, "ensure_history_schema", return_value={}), \
                 patch.object(migrate.psycopg, "connect", return_value=conn):
                with contextlib.redirect_stdout(output):
                    result = migrate.run_migrations("postgresql://test/db")
            self.assertEqual(result, (2, 0))
            self.assertEqual(conn.transaction.call_count, 2)
            self.assertIn("2 applied", output.getvalue())
            conn.close.assert_called_once()

    def test_changed_checksum_is_rejected_before_sql_runs(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            (path / "01_change.sql").write_text("SELECT 12345;\n")
            conn = MagicMock()
            with patch.object(migrate, "MIGRATION_STAGES", [("test", path)]), \
                 patch.object(migrate, "ensure_timescaledb"), \
                 patch.object(migrate, "ensure_history_schema", return_value={"test/01_change.sql": "old"}), \
                 patch.object(migrate.psycopg, "connect", return_value=conn):
                with self.assertRaisesRegex(RuntimeError, "refusing to replay changed SQL"):
                    migrate.run_migrations("postgresql://test/db")
            executed = [str(call.args[0]) for call in conn.cursor.return_value.__enter__.return_value.execute.call_args_list]
            self.assertFalse(any("12345" in statement for statement in executed))
            conn.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
