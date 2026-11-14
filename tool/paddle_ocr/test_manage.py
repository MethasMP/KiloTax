import contextlib
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import manage


class ManageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.runtime = Path(self.temp.name) / 'runtime'
        self.override = patch.object(manage, 'RUNTIME', self.runtime)
        self.override.start()
        self.addCleanup(self.override.stop)
        manage.initialize()

    def test_private_runtime_and_connection_do_not_expose_token_to_stdout(self):
        manage.private_write(self.runtime / 'token', 'unit-secret')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            path = manage.connection()
        self.assertNotIn('unit-secret', output.getvalue())
        self.assertIn('unit-secret', path.read_text())
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.runtime.stat().st_mode), 0o700)

    def test_process_ownership_rejects_an_unrelated_pid(self):
        manage.private_write(self.runtime / 'pid', '43210')
        with patch('manage.subprocess.run') as run:
            run.return_value.returncode = 0
            run.return_value.stdout = 'python unrelated_server.py'
            self.assertIsNone(manage.owned_process())
        with patch('manage.os.kill') as kill:
            with contextlib.redirect_stdout(io.StringIO()):
                manage.stop()
            kill.assert_not_called()

    def test_repeated_start_reuses_running_instance_without_rotating_token(self):
        manage.private_write(self.runtime / 'token', 'unit-secret')
        with patch('manage.owned_process', return_value=43210), patch('manage.health', return_value={'engine':'paddleocr'}), patch('manage.subprocess.Popen') as start:
            with contextlib.redirect_stdout(io.StringIO()):
                manage.start()
            start.assert_not_called()
        self.assertEqual((self.runtime / 'token').read_text(), 'unit-secret')
