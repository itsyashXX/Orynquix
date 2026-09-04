"""Repeatable on-device Stage 1 acceptance evidence."""

from __future__ import annotations

import time
from typing import Any

from orynquix.adapters.command import LocalRunner, Runner
from orynquix.errors import ExitCode, OrynquixError
from orynquix.guest import existing_rootfs, login_argv
from orynquix.lifecycle import LifecycleManager
from orynquix.paths import OrynquixPaths
from orynquix.probe import HostProbe
from orynquix.processes import resident_memory_bytes
from orynquix.state import SessionStore, write_json_atomic
from orynquix.timeutil import utc_now


class ProofRunner:
    def __init__(
        self,
        paths: OrynquixPaths,
        *,
        lifecycle: LifecycleManager | None = None,
        runner: Runner | None = None,
        probe: HostProbe | None = None,
    ) -> None:
        self.paths = paths
        self.runner = runner or LocalRunner()
        self.probe = probe or HostProbe(runner=self.runner)
        self.lifecycle = lifecycle or LifecycleManager(paths, runner=self.runner, probe=self.probe)

    def run(self, *, cycles: int, confirmed: bool) -> dict[str, Any]:
        if not 1 <= cycles <= 20:
            raise OrynquixError(
                "proof cycles must be between 1 and 20",
                diagnostic_id="ORY-PROOF-001",
                exit_code=ExitCode.USAGE,
            )
        if not confirmed:
            return {
                "ok": True,
                "confirmation_required": True,
                "cycles": cycles,
                "message": "The proof will repeatedly open and stop the real graphical session.",
            }

        self.paths.reports_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        results: list[dict[str, Any]] = []
        success = True
        for index in range(1, cycles + 1):
            cycle: dict[str, Any] = {"cycle": index}
            start_time = time.monotonic()
            try:
                started = self.lifecycle.start()
                cycle["start_seconds"] = round(time.monotonic() - start_time, 3)
                cycle["start_state"] = str(started["state"])
                record = SessionStore(self.paths).load()
                memory_values = [
                    value
                    for process in record.processes
                    if (value := resident_memory_bytes(process)) is not None
                ]
                cycle["managed_rss_bytes"] = sum(memory_values)
                cycle["status"] = self.lifecycle.status()
                stop_time = time.monotonic()
                stopped = self.lifecycle.stop()
                cycle["stop_seconds"] = round(time.monotonic() - stop_time, 3)
                cycle["stop_state"] = str(stopped["state"])
                cycle["passed"] = stopped["state"] == "stopped"
            except Exception as exc:
                success = False
                cycle["passed"] = False
                cycle["error_type"] = type(exc).__name__
                cycle["diagnostic_id"] = getattr(exc, "diagnostic_id", "ORY-PROOF-002")
                try:
                    self.lifecycle.repair(confirmed=True)
                except Exception:
                    cycle["automatic_repair"] = False
                else:
                    cycle["automatic_repair"] = True
            results.append(cycle)
            if not cycle["passed"]:
                break

        persistence = self._persistence_check()
        if not persistence["passed"]:
            success = False
        rootfs_size = self._rootfs_size()
        report = {
            "schema_version": 1,
            "generated_at": utc_now(),
            "ok": success and len(results) == cycles,
            "requested_cycles": cycles,
            "completed_cycles": len(results),
            "host": self.probe.run(require_runtime=True).to_dict(),
            "cycles": results,
            "persistence": persistence,
            "rootfs_size_bytes": rootfs_size,
            "projects_directory": str(self.paths.projects_dir),
            "limitations": [
                "Screenshot or screen recording must be attached by the device owner.",
                "Audio may be degraded without blocking the graphical proof.",
                "Only this declared device is covered by the generated evidence.",
            ],
        }
        output = self.paths.reports_dir / f"stage-1-proof-{utc_now().replace(':', '-')}.json"
        write_json_atomic(output, report)
        return {"ok": report["ok"], "path": str(output), "report": report}

    def _persistence_check(self) -> dict[str, Any]:
        marker = "/root/.orynquix-stage1-persistence"
        create = self.runner.run(login_argv("touch", marker), timeout=30)
        verify = self.runner.run(login_argv("test", "-f", marker), timeout=30)
        return {
            "passed": create.ok and verify.ok,
            "marker": marker,
            "create_exit_code": create.returncode,
            "verify_exit_code": verify.returncode,
        }

    def _rootfs_size(self) -> int | None:
        rootfs = existing_rootfs()
        if rootfs is None or self.runner.which("du") is None:
            return None
        result = self.runner.run(("du", "-sb", str(rootfs)), timeout=120)
        if not result.ok:
            return None
        try:
            return int(result.stdout.split()[0])
        except (ValueError, IndexError):
            return None
