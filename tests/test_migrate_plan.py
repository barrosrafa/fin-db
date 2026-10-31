import contextlib
import importlib.util
import io
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch, MagicMock

spec = importlib.util.spec_from_file_location('fin_migrate', Path(__file__).resolve().parents[1] / 'scripts/migrate.py')
migrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migrate)


class OfflinePlanTests(unittest.TestCase):
    def test_dry_run_never_connects_or_touches_ledger(self):
        output = io.StringIO()
        with patch.object(migrate.psycopg, 'connect', side_effect=AssertionError('Network forbidden')) as connect:
            with contextlib.redirect_stdout(output):
                migrate.run_migrations('', ['01_core_schema'], dry_run=True)
        connect.assert_not_called()
        self.assertIn('01_core_schema/', output.getvalue())
        self.assertIn('OFFLINE DRY RUN COMPLETE', output.getvalue())
        self.assertNotIn('02_improvements_v3.1/', output.getvalue())

    def test_applied_migration_drift_never_reexecutes_historical_sql(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / '01_change.sql'
            path.write_text('SELECT 12345;')
            connection = MagicMock()
            connection.__enter__.return_value = connection
            with patch.object(migrate, 'MIGRATION_STAGES', [('test', Path(folder))]), \
                 patch.object(migrate.psycopg, 'connect', return_value=connection), \
                 patch.object(migrate, 'ensure_migration_table'), \
                 patch.object(migrate, 'get_applied_migrations', return_value={'test/01_change.sql': 'different'}):
                with self.assertRaisesRegex(RuntimeError, 'refusing to reapply'):
                    migrate.run_migrations('local-test-only')
            statements = [str(call.args[0]) for call in connection.cursor.return_value.__enter__.return_value.execute.call_args_list]
            self.assertFalse(any('12345' in statement for statement in statements))


if __name__ == '__main__':
    unittest.main()

class MigrationPreflightTests(unittest.TestCase):
    def test_drift_in_later_file_prevents_earlier_pending_migration(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / '01_pending.sql').write_text('SELECT 917234;')
            (root / '02_applied.sql').write_text('SELECT 2;')
            conn = MagicMock()
            conn.__enter__.return_value = conn
            with patch.object(migrate, 'MIGRATION_STAGES', [('automatic', root)]), \
                 patch.object(migrate.psycopg, 'connect', return_value=conn), \
                 patch.object(migrate, 'ensure_migration_table'), \
                 patch.object(migrate, 'get_applied_migrations', return_value={'automatic/02_applied.sql': 'drift'}):
                with self.assertRaisesRegex(RuntimeError, 'Checksum drift'):
                    migrate.run_migrations('local-test-only')
            statements = str(conn.cursor.return_value.__enter__.return_value.execute.call_args_list)
            self.assertNotIn('917234', statements)

    def test_manual_annotation_is_rejected_without_connection_even_in_plan(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            (path / '01_change.sql').write_text('-- execution: manual\nSELECT 1;')
            with patch.object(migrate, 'MIGRATION_STAGES', [('automatic', path)]), \
                 patch.object(migrate.psycopg, 'connect') as connect:
                with self.assertRaisesRegex(RuntimeError, 'Manual migration forbidden'):
                    migrate.run_migrations('', dry_run=True)
            connect.assert_not_called()
