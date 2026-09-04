from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from orynquix.config import Settings, save_settings
from orynquix.errors import OrynquixError
from orynquix.lifecycle import LifecycleManager
from orynquix.models import ProcessRecord, SessionRecord, SessionState
from orynquix.paths import OrynquixPaths
from orynquix.state import SessionStore, write_json_atomic
from orynquix.timeutil import utc_now
from tests.helpers import FakeRunner, PassingProbe, make_display_socket


class LifecycleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.paths = OrynquixPaths(
            base / "config", base / "data", base / "state", base / "cache", base / "projects"
        )
        self.runner = FakeRunner()
        self.alive: dict[int, bool] = {}
        self.capture_patcher = patch(
            "orynquix.lifecycle.capture_process", side_effect=self._capture
        )
        self.matches_patcher = patch(
            "orynquix.lifecycle.process_matches", side_effect=self._matches
        )
        self.terminate_patcher = patch(
            "orynquix.lifecycle.terminate_owned_process", side_effect=self._terminate
        )
        self.capture_patcher.start()
        self.matches_patcher.start()
        self.terminate_patcher.start()
        self.previous_tmpdir = os.environ.get("TMPDIR")
        os.environ["TMPDIR"] = str(base / "tmp")
        make_display_socket(base / "tmp")
        self.manager = LifecycleManager(self.paths, runner=self.runner, probe=PassingProbe())
        write_json_atomic(
            self.paths.bootstrap_file,
            {
                "schema_version": 1,
                "status": "complete",
                "updated_at": utc_now(),
                "rootfs_created_by_orynquix": True,
                "container_name": "orynquix-debian",
                "image_reference": "debian:stable",
            },
        )

    def tearDown(self) -> None:
        try:
            if self.manager.status()["state"] != SessionState.STOPPED:
                self.manager.repair(confirmed=True)
        finally:
            self.runner.cleanup()
            self.terminate_patcher.stop()
            self.matches_patcher.stop()
            self.capture_patcher.stop()
            if self.previous_tmpdir is None:
                os.environ.pop("TMPDIR", None)
            else:
                os.environ["TMPDIR"] = self.previous_tmpdir
            self.temporary.cleanup()

    def _capture(self, name: str, pid: int, *, required: bool) -> ProcessRecord:
        self.alive[pid] = True
        return ProcessRecord(name, pid, pid, "now", pid, f"{pid:064x}", required)

    def _matches(self, record: ProcessRecord) -> bool:
        return self.alive.get(record.pid, False)

    def _terminate(self, record: ProcessRecord, *, timeout: float) -> bool:
        del timeout
        if not self._matches(record):
            return False
        self.alive[record.pid] = False
        return True

    def test_start_status_idempotent_and_stop(self) -> None:
        started = self.manager.start()
        self.assertEqual(started["state"], SessionState.RUNNING)
        again = self.manager.start()
        self.assertTrue(again["already_started"])
        status = self.manager.status()
        self.assertEqual(status["state"], SessionState.RUNNING)
        stopped = self.manager.stop()
        self.assertEqual(stopped["state"], SessionState.STOPPED)
        self.assertTrue(self.manager.stop()["already_stopped"])

    def test_audio_failure_is_degraded_not_failed(self) -> None:
        self.runner.audio_start_ok = False
        started = self.manager.start()
        self.assertEqual(started["state"], SessionState.DEGRADED)
        self.manager.stop()

    def test_repair_requires_confirmation(self) -> None:
        preview = self.manager.repair(confirmed=False)
        self.assertTrue(preview["confirmation_required"])

    def test_required_process_loss_is_failed_then_repaired(self) -> None:
        self.manager.start()
        record = SessionStore(self.paths).load()
        desktop = next(process for process in record.processes if process.name == "desktop")
        self.alive[desktop.pid] = False
        status = self.manager.status()
        self.assertEqual(status["state"], SessionState.FAILED)
        repaired = self.manager.repair(confirmed=True)
        self.assertEqual(repaired["state"], SessionState.STOPPED)

    def test_invalid_state_is_archived_by_repair(self) -> None:
        self.paths.ensure_control_dirs()
        self.paths.session_file.write_text("invalid", encoding="utf-8")
        repaired = self.manager.repair(confirmed=True)
        self.assertEqual(repaired["state"], SessionState.STOPPED)
        self.assertTrue(list(self.paths.state_dir.glob("session.invalid.*.json")))

    def test_stuck_starting_state_is_reported_failed(self) -> None:
        record = SessionRecord(
            schema_version=1,
            session_id="stuck",
            state=SessionState.STARTING,
            updated_at=utc_now(),
        )
        SessionStore(self.paths).save(record)
        self.assertEqual(self.manager.status()["state"], SessionState.FAILED)
        self.manager.repair(confirmed=True)

    def test_display_timeout_records_failure(self) -> None:
        socket = Path(os.environ["TMPDIR"]) / ".X11-unix/X1"
        socket.unlink()
        save_settings(self.paths, Settings(readiness_timeout_seconds=1))
        with self.assertRaises(OrynquixError) as raised:
            self.manager.start()
        self.assertEqual(raised.exception.diagnostic_id, "ORY-LIFE-008")
        self.assertEqual(self.manager.status()["state"], SessionState.FAILED)
        self.manager.repair(confirmed=True)
