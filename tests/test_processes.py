from __future__ import annotations

import os
import subprocess
import sys
import unittest
from unittest.mock import patch

from orynquix.models import ProcessRecord
from orynquix.processes import capture_process, process_matches, terminate_owned_process


class ProcessIdentityTests(unittest.TestCase):
    def test_capture_match_and_safe_termination(self) -> None:
        process = subprocess.Popen(
            (sys.executable, "-c", "import time; time.sleep(60)"), start_new_session=True
        )
        try:

            def identity(pid: int) -> tuple[int, str]:
                self.assertEqual(pid, process.pid)
                if process.poll() is not None:
                    raise ProcessLookupError(pid)
                return 123, "a" * 64

            with patch("orynquix.processes._read_identity", side_effect=identity):
                record = capture_process("test", process.pid, required=True)
                self.assertTrue(process_matches(record))
                self.assertTrue(terminate_owned_process(record, timeout=1))
                process.wait(timeout=5)
                self.assertFalse(process_matches(record))
        finally:
            if process.poll() is None:
                os.killpg(os.getpgid(process.pid), 9)
                process.wait(timeout=5)

    def test_mismatched_identity_is_never_signaled(self) -> None:
        with patch("orynquix.processes._read_identity", return_value=(100, "b" * 64)):
            current = capture_process("self", os.getpid(), required=True)
        mismatched = ProcessRecord(
            name=current.name,
            pid=current.pid,
            process_group=current.process_group,
            started_at=current.started_at,
            start_ticks=current.start_ticks + 1,
            cmdline_sha256=current.cmdline_sha256,
            required=current.required,
        )
        with patch("orynquix.processes._read_identity", return_value=(100, "b" * 64)):
            self.assertFalse(process_matches(mismatched))
            self.assertFalse(terminate_owned_process(mismatched, timeout=0.1))
