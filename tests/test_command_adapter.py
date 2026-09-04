from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from orynquix.adapters.command import LocalRunner, _validate_argv, open_binary_log
from orynquix.errors import OrynquixError


class CommandAdapterTests(unittest.TestCase):
    def test_run_success_failure_and_check(self) -> None:
        runner = LocalRunner()
        self.assertIsNotNone(runner.which("python3"))
        success = runner.run((sys.executable, "-c", "print('hello')"))
        self.assertTrue(success.ok)
        self.assertEqual(success.stdout.strip(), "hello")
        failure = runner.run((sys.executable, "-c", "raise SystemExit(4)"))
        self.assertEqual(failure.returncode, 4)
        with self.assertRaises(OrynquixError):
            runner.run((sys.executable, "-c", "raise SystemExit(5)"), check=True)

    def test_timeout_and_invalid_argv(self) -> None:
        with self.assertRaises(OrynquixError):
            LocalRunner().run((sys.executable, "-c", "import time; time.sleep(2)"), timeout=0.01)
        with self.assertRaises(ValueError):
            _validate_argv(())
        with self.assertRaises(ValueError):
            _validate_argv(("bad\x00command",))

    def test_spawn_and_log(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            log = open_binary_log(Path(temporary) / "service.log")
            process = LocalRunner().spawn(
                (sys.executable, "-c", "print('service')"), stdout=log, stderr=log
            )
            log.close()
            self.assertEqual(process.wait(timeout=5), 0)
            self.assertIn("service", (Path(temporary) / "service.log").read_text())

    def test_spawn_missing_executable_has_stable_error(self) -> None:
        with self.assertRaises(OrynquixError):
            LocalRunner().spawn(
                ("/definitely/missing/orynquix-command",), stdout=subprocess.DEVNULL
            )
