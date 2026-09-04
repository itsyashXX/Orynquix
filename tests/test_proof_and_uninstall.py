from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from orynquix.errors import OrynquixError
from orynquix.models import SessionRecord, SessionState
from orynquix.paths import OrynquixPaths
from orynquix.proof import ProofRunner
from orynquix.state import SessionStore, write_json_atomic
from orynquix.timeutil import utc_now
from orynquix.uninstall import Uninstaller
from tests.helpers import FakeRunner, PassingProbe


class FakeLifecycle:
    def __init__(self, paths: OrynquixPaths, *, fail_start: bool = False) -> None:
        self.paths = paths
        self.fail_start = fail_start
        self.repairs = 0
        self.stops = 0

    def start(self) -> dict[str, object]:
        if self.fail_start:
            raise OrynquixError("simulated", diagnostic_id="TEST-PROOF")
        record = SessionRecord(
            schema_version=1,
            session_id="test-session",
            state=SessionState.RUNNING,
            updated_at=utc_now(),
        )
        SessionStore(self.paths).save(record)
        return {"ok": True, "state": SessionState.RUNNING}

    def status(self) -> dict[str, object]:
        return {"ok": True, "state": SessionStore(self.paths).load().state}

    def stop(self) -> dict[str, object]:
        self.stops += 1
        SessionStore(self.paths).save(SessionRecord.stopped(now=utc_now()))
        return {"ok": True, "state": SessionState.STOPPED}

    def repair(self, *, confirmed: bool) -> dict[str, object]:
        self.assert_confirmed(confirmed)
        self.repairs += 1
        SessionStore(self.paths).save(SessionRecord.stopped(now=utc_now()))
        return {"ok": True, "state": SessionState.STOPPED}

    @staticmethod
    def assert_confirmed(confirmed: bool) -> None:
        if not confirmed:
            raise AssertionError("repair must be confirmed in proof recovery")


class ProofAndUninstallTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.prefix = self.base / "prefix"
        self.rootfs = self.prefix / "var/lib/proot-distro/containers/orynquix-debian/rootfs"
        self.rootfs.mkdir(parents=True)
        self.paths = OrynquixPaths(
            self.base / "config",
            self.base / "data",
            self.base / "state",
            self.base / "cache",
            self.base / "projects",
        )
        self.previous_prefix = os.environ.get("PREFIX")
        os.environ["PREFIX"] = str(self.prefix)

    def tearDown(self) -> None:
        if self.previous_prefix is None:
            os.environ.pop("PREFIX", None)
        else:
            os.environ["PREFIX"] = self.previous_prefix
        self.temporary.cleanup()

    def test_proof_preview_success_and_failure_recovery(self) -> None:
        runner = FakeRunner()
        lifecycle = FakeLifecycle(self.paths)
        proof = ProofRunner(self.paths, lifecycle=lifecycle, runner=runner, probe=PassingProbe())
        self.assertTrue(proof.run(cycles=2, confirmed=False)["confirmation_required"])
        result = proof.run(cycles=2, confirmed=True)
        self.assertTrue(result["ok"])
        self.assertEqual(result["report"]["completed_cycles"], 2)
        self.assertEqual(result["report"]["rootfs_size_bytes"], 123456)
        self.assertTrue(Path(result["path"]).exists())

        failing_lifecycle = FakeLifecycle(self.paths, fail_start=True)
        failed = ProofRunner(
            self.paths,
            lifecycle=failing_lifecycle,
            runner=runner,
            probe=PassingProbe(),
        ).run(cycles=1, confirmed=True)
        self.assertFalse(failed["ok"])
        self.assertEqual(failing_lifecycle.repairs, 1)
        with self.assertRaises(OrynquixError):
            proof.run(cycles=0, confirmed=True)

    def test_uninstall_preserves_projects_and_owned_rootfs_rule(self) -> None:
        self.paths.ensure_control_dirs()
        self.paths.ensure_projects_dir()
        project = self.paths.projects_dir / "keep.txt"
        project.write_text("user data", encoding="utf-8")
        lifecycle = FakeLifecycle(self.paths)
        runner = FakeRunner()
        uninstaller = Uninstaller(self.paths, runner=runner, lifecycle=lifecycle)
        preview = uninstaller.run(confirmed=False, remove_rootfs=False)
        self.assertIn(str(self.paths.projects_dir), preview["preserve"])

        write_json_atomic(
            self.paths.bootstrap_file,
            {
                "schema_version": 1,
                "status": "complete",
                "updated_at": utc_now(),
                "rootfs_created_by_orynquix": False,
            },
        )
        with self.assertRaises(OrynquixError):
            uninstaller.run(confirmed=True, remove_rootfs=True)

        write_json_atomic(
            self.paths.bootstrap_file,
            {
                "schema_version": 1,
                "status": "complete",
                "updated_at": utc_now(),
                "rootfs_created_by_orynquix": True,
            },
        )
        result = uninstaller.run(confirmed=True, remove_rootfs=True)
        self.assertTrue(result["rootfs_removed"])
        self.assertTrue(project.exists())
        self.assertIn(("proot-distro", "remove", "orynquix-debian"), runner.calls)
