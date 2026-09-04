from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from orynquix.errors import OrynquixError
from orynquix.models import Health, ServiceHealth, SessionRecord, SessionState
from orynquix.paths import OrynquixPaths
from orynquix.state import SessionStore
from orynquix.timeutil import utc_now


class ModelsAndStateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.paths = OrynquixPaths(
            base / "config", base / "data", base / "state", base / "cache", base / "projects"
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_valid_state_transition_round_trip(self) -> None:
        stopped = SessionRecord.stopped(now=utc_now())
        starting = stopped.transition(SessionState.STARTING, now=utc_now())
        running = starting.transition(
            SessionState.RUNNING,
            now=utc_now(),
            services=(ServiceHealth("display", Health.PASS, "ready", True),),
        )
        store = SessionStore(self.paths)
        store.save(running)
        self.assertEqual(store.load(), running)
        self.assertEqual(json.loads(self.paths.session_file.read_text())["state"], "running")

    def test_invalid_transition_is_rejected(self) -> None:
        stopped = SessionRecord.stopped(now=utc_now())
        with self.assertRaises(ValueError):
            stopped.transition(SessionState.RUNNING, now=utc_now())

    def test_corrupt_state_has_stable_diagnostic(self) -> None:
        self.paths.ensure_control_dirs()
        self.paths.session_file.write_text("not-json", encoding="utf-8")
        with self.assertRaises(OrynquixError) as raised:
            SessionStore(self.paths).load()
        self.assertEqual(raised.exception.diagnostic_id, "ORY-STATE-002")

    def test_missing_state_is_stopped(self) -> None:
        self.assertEqual(SessionStore(self.paths).load().state, SessionState.STOPPED)
