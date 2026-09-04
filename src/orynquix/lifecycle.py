"""Dependency-aware graphical session lifecycle manager."""

from __future__ import annotations

import os
import time
import uuid
from pathlib import Path
from typing import Any

from orynquix.adapters.command import LocalRunner, Runner, open_binary_log
from orynquix.config import Settings, load_settings
from orynquix.errors import ExitCode, OrynquixError
from orynquix.guest import CONTAINER_NAME, container_installed, login_argv
from orynquix.journal import Journal
from orynquix.locking import OperationLock
from orynquix.models import Health, ProcessRecord, ServiceHealth, SessionRecord, SessionState
from orynquix.paths import OrynquixPaths
from orynquix.probe import HostProbe
from orynquix.processes import capture_process, process_matches, terminate_owned_process
from orynquix.state import SessionStore, read_json
from orynquix.timeutil import utc_now


class LifecycleManager:
    def __init__(
        self,
        paths: OrynquixPaths,
        *,
        runner: Runner | None = None,
        probe: HostProbe | None = None,
    ) -> None:
        self.paths = paths
        self.runner = runner or LocalRunner()
        self.probe = probe or HostProbe(runner=self.runner)
        self.store = SessionStore(paths)
        self.journal = Journal(paths.journal_file)

    def start(self) -> dict[str, Any]:
        self.paths.ensure_control_dirs()
        settings = load_settings(self.paths)
        with OperationLock(self.paths.lock_file):
            previous = self.store.load()
            if previous.state in {SessionState.RUNNING, SessionState.DEGRADED}:
                current = self._evaluate(previous, persist=True)
                if current.state in {SessionState.RUNNING, SessionState.DEGRADED}:
                    result = self._status_dict(current)
                    result["already_started"] = True
                    return result
            if previous.state in {SessionState.STARTING, SessionState.STOPPING}:
                raise OrynquixError(
                    f"session is stuck in {previous.state}",
                    diagnostic_id="ORY-LIFE-001",
                    exit_code=ExitCode.INVALID_STATE,
                    hint="Run `orynquix repair --yes`, then retry.",
                )
            if previous.state == SessionState.FAILED:
                raise OrynquixError(
                    "the previous session failed and requires repair",
                    diagnostic_id="ORY-LIFE-002",
                    exit_code=ExitCode.INVALID_STATE,
                    hint="Run `orynquix repair --yes`, then retry.",
                )

            report = self.probe.run(require_runtime=True)
            if not report.supported:
                raise OrynquixError(
                    "runtime prerequisites are incomplete",
                    diagnostic_id="ORY-LIFE-003",
                    exit_code=ExitCode.PREREQUISITE_MISSING,
                    hint="Run `orynquix doctor --runtime --json` for corrective steps.",
                )
            self._assert_bootstrapped()

            session = SessionRecord(
                schema_version=1,
                session_id=str(uuid.uuid4()),
                state=SessionState.STARTING,
                updated_at=utc_now(),
            )
            self.store.save(session)
            self.journal.append("session.starting", session_id=session.session_id)
            processes: list[ProcessRecord] = []
            services: list[ServiceHealth] = []
            try:
                display_process = self._spawn_service(
                    "display",
                    ("termux-x11", settings.display),
                    required=True,
                    log_name="termux-x11.log",
                )
                processes.append(display_process)
                self._open_x11_companion()
                self._wait_for_display(settings, display_process)
                services.append(ServiceHealth("display", Health.PASS, "Termux:X11 is ready", True))

                audio_health = self._start_audio(settings)
                services.append(audio_health)

                self._prepare_guest_runtime()

                desktop_process = self._spawn_service(
                    "desktop",
                    self._desktop_argv(settings),
                    required=True,
                    log_name="desktop.log",
                )
                processes.append(desktop_process)
                self._wait_for_process(
                    desktop_process,
                    timeout=min(5, settings.readiness_timeout_seconds),
                )
                services.append(
                    ServiceHealth("desktop", Health.PASS, "XFCE session is running", True)
                )

                if settings.shared_directory:
                    services.append(
                        ServiceHealth(
                            "shared-storage",
                            Health.PASS,
                            "Approved folder mapped at /mnt/orynquix-share",
                            False,
                        )
                    )
                else:
                    services.append(
                        ServiceHealth(
                            "shared-storage",
                            Health.SKIP,
                            "No Android folder is exposed to the guest",
                            False,
                        )
                    )

                final_state = (
                    SessionState.DEGRADED
                    if any(service.health == Health.WARN for service in services)
                    else SessionState.RUNNING
                )
                session = session.transition(
                    final_state,
                    now=utc_now(),
                    processes=tuple(processes),
                    services=tuple(services),
                )
                self.store.save(session)
                self.journal.append(
                    "session.started", session_id=session.session_id, state=session.state
                )
                return self._status_dict(session)
            except Exception as exc:
                for process in reversed(processes):
                    terminate_owned_process(process, timeout=2)
                diagnostic_id = (
                    exc.diagnostic_id if isinstance(exc, OrynquixError) else "ORY-LIFE-004"
                )
                failed = session.transition(
                    SessionState.FAILED,
                    now=utc_now(),
                    processes=tuple(processes),
                    services=tuple(services),
                    diagnostic_id=diagnostic_id,
                )
                self.store.save(failed)
                self.journal.append(
                    "session.failed",
                    session_id=session.session_id,
                    diagnostic_id=diagnostic_id,
                    error_type=type(exc).__name__,
                )
                if isinstance(exc, OrynquixError):
                    raise
                raise OrynquixError(
                    f"session failed to start: {exc}",
                    diagnostic_id=diagnostic_id,
                    exit_code=ExitCode.OPERATION_FAILED,
                ) from exc

    def status(self) -> dict[str, Any]:
        record = self.store.load()
        current = self._evaluate(record, persist=record.state != SessionState.STOPPED)
        return self._status_dict(current)

    def stop(self) -> dict[str, Any]:
        self.paths.ensure_control_dirs()
        settings = load_settings(self.paths)
        with OperationLock(self.paths.lock_file):
            record = self.store.load()
            if record.state == SessionState.STOPPED:
                result = self._status_dict(record)
                result["already_stopped"] = True
                return result
            stopping = SessionRecord(
                schema_version=record.schema_version,
                session_id=record.session_id,
                state=SessionState.STOPPING,
                updated_at=utc_now(),
                processes=record.processes,
                services=record.services,
            )
            self.store.save(stopping)
            self.journal.append("session.stopping", session_id=record.session_id)
            cleanup: list[dict[str, object]] = []
            failed = False
            for process in reversed(record.processes):
                matched = process_matches(process)
                stopped = terminate_owned_process(process, timeout=settings.stop_timeout_seconds)
                cleanup.append(
                    {
                        "name": process.name,
                        "identity_matched": matched,
                        "stopped": stopped,
                    }
                )
                if matched and not stopped:
                    failed = True
            if failed:
                failed_record = SessionRecord(
                    schema_version=record.schema_version,
                    session_id=record.session_id,
                    state=SessionState.FAILED,
                    updated_at=utc_now(),
                    processes=record.processes,
                    services=record.services,
                    diagnostic_id="ORY-LIFE-005",
                )
                self.store.save(failed_record)
                self.journal.append(
                    "session.stop_failed",
                    session_id=record.session_id,
                    diagnostic_id="ORY-LIFE-005",
                )
                raise OrynquixError(
                    "one or more owned processes could not be stopped",
                    diagnostic_id="ORY-LIFE-005",
                    exit_code=ExitCode.OPERATION_FAILED,
                    hint="Run `orynquix repair --yes` and inspect the support bundle.",
                )
            stopped_record = SessionRecord.stopped(now=utc_now())
            self.store.save(stopped_record)
            self.journal.append("session.stopped", session_id=record.session_id)
            result = self._status_dict(stopped_record)
            result["cleanup"] = cleanup
            return result

    def repair(self, *, confirmed: bool) -> dict[str, Any]:
        self.paths.ensure_control_dirs()
        if not confirmed:
            return {
                "ok": True,
                "confirmation_required": True,
                "message": (
                    "Repair archives invalid state and stops only identity-verified processes."
                ),
            }
        with OperationLock(self.paths.lock_file):
            try:
                record = self.store.load()
            except OrynquixError:
                archived = self.paths.session_file.with_name(
                    f"session.invalid.{int(time.time())}.json"
                )
                os.replace(self.paths.session_file, archived)
                record = SessionRecord.stopped(now=utc_now())
                self.journal.append("repair.archived_invalid_state", archive=archived.name)
            repaired: list[str] = []
            for process in reversed(record.processes):
                if process_matches(process):
                    if terminate_owned_process(process, timeout=5):
                        repaired.append(process.name)
                    else:
                        raise OrynquixError(
                            f"could not stop identity-verified process: {process.name}",
                            diagnostic_id="ORY-LIFE-006",
                            exit_code=ExitCode.OPERATION_FAILED,
                        )
            stopped = SessionRecord.stopped(now=utc_now())
            self.store.save(stopped)
            self.journal.append("repair.completed", stopped_services=repaired)
            return {"ok": True, "state": stopped.state, "stopped_services": repaired}

    def _spawn_service(
        self, name: str, argv: tuple[str, ...], *, required: bool, log_name: str
    ) -> ProcessRecord:
        log = open_binary_log(self.paths.log_dir / log_name)
        try:
            process = self.runner.spawn(argv, stdout=log, stderr=log)
        finally:
            log.close()
        time.sleep(0.15)
        if process.poll() is not None:
            raise OrynquixError(
                f"{name} exited immediately; inspect {log_name}",
                diagnostic_id=f"ORY-LIFE-{name.upper()}-START",
                exit_code=ExitCode.OPERATION_FAILED,
            )
        return capture_process(name, process.pid, required=required)

    def _open_x11_companion(self) -> None:
        if self.runner.which("am") is None:
            return
        self.runner.run(
            (
                "am",
                "start",
                "--user",
                "0",
                "-n",
                "com.termux.x11/com.termux.x11.MainActivity",
            ),
            timeout=10,
        )

    def _wait_for_display(self, settings: Settings, process: ProcessRecord) -> None:
        display_number = settings.display[1:]
        temporary = Path(os.environ.get("TMPDIR", "/data/data/com.termux/files/usr/tmp"))
        socket = temporary / ".X11-unix" / f"X{display_number}"
        deadline = time.monotonic() + settings.readiness_timeout_seconds
        while time.monotonic() < deadline:
            if not process_matches(process):
                raise OrynquixError(
                    "Termux:X11 stopped before becoming ready",
                    diagnostic_id="ORY-LIFE-007",
                    exit_code=ExitCode.OPERATION_FAILED,
                )
            if socket.exists():
                return
            time.sleep(0.2)
        raise OrynquixError(
            f"Termux:X11 did not create display socket {settings.display}",
            diagnostic_id="ORY-LIFE-008",
            exit_code=ExitCode.OPERATION_FAILED,
            hint=(
                "Open Termux:X11, then retry. See the troubleshooting guide if the socket "
                "stays absent."
            ),
        )

    def _start_audio(self, settings: Settings) -> ServiceHealth:
        if not settings.audio_enabled:
            return ServiceHealth("audio", Health.SKIP, "Audio disabled by configuration", False)
        if self.runner.which("pulseaudio") is None:
            return ServiceHealth("audio", Health.WARN, "PulseAudio is unavailable", False)
        start = self.runner.run(("pulseaudio", "--start", "--exit-idle-time=30"), timeout=10)
        if not start.ok:
            return ServiceHealth(
                "audio",
                Health.WARN,
                "Audio failed; the graphical session can still run",
                False,
            )
        if self.runner.which("pactl") is None:
            return ServiceHealth(
                "audio", Health.WARN, "PulseAudio control utility is unavailable", False
            )
        tcp_check = self.runner.run(("pactl", "--server", "tcp:127.0.0.1", "info"), timeout=5)
        if not tcp_check.ok:
            loaded = self.runner.run(
                (
                    "pactl",
                    "load-module",
                    "module-native-protocol-tcp",
                    "auth-ip-acl=127.0.0.1",
                    "auth-anonymous=1",
                ),
                timeout=10,
            )
            if not loaded.ok:
                return ServiceHealth(
                    "audio",
                    Health.WARN,
                    "PulseAudio loopback transport failed; desktop remains usable",
                    False,
                )
        return ServiceHealth("audio", Health.PASS, "PulseAudio is available", False)

    def _assert_bootstrapped(self) -> None:
        if not self.paths.bootstrap_file.exists():
            raise OrynquixError(
                "Orynquix has not been bootstrapped",
                diagnostic_id="ORY-LIFE-013",
                exit_code=ExitCode.PREREQUISITE_MISSING,
                hint="Run `orynquix bootstrap`, review the plan, then apply it with `--yes`.",
            )
        state = read_json(self.paths.bootstrap_file)
        if (
            state.get("status") != "complete"
            or state.get("container_name") != CONTAINER_NAME
            or not container_installed(self.runner)
        ):
            raise OrynquixError(
                "the dedicated Orynquix Debian container is incomplete",
                diagnostic_id="ORY-LIFE-014",
                exit_code=ExitCode.PREREQUISITE_MISSING,
                hint="Run `orynquix bootstrap --yes` to resume the verified installation.",
            )

    def _prepare_guest_runtime(self) -> None:
        result = self.runner.run(
            login_argv("install", "-d", "-m", "700", "/tmp/runtime-orynquix"),
            timeout=30,
        )
        if not result.ok:
            raise OrynquixError(
                "could not prepare the guest runtime directory",
                diagnostic_id="ORY-LIFE-012",
                exit_code=ExitCode.OPERATION_FAILED,
            )

    def _desktop_argv(self, settings: Settings) -> tuple[str, ...]:
        command: list[str] = ["proot-distro", "login", "--shared-x11"]
        if settings.shared_directory:
            command.extend(("--bind", f"{settings.shared_directory}:/mnt/orynquix-share"))
        command.extend(
            (
                CONTAINER_NAME,
                "--",
                "env",
                f"DISPLAY={settings.display}",
                "PULSE_SERVER=127.0.0.1",
                "XDG_RUNTIME_DIR=/tmp/runtime-orynquix",
                *settings.desktop_command,
            )
        )
        return tuple(command)

    def _wait_for_process(self, process: ProcessRecord, *, timeout: float) -> None:
        deadline = time.monotonic() + timeout
        stable_since = time.monotonic()
        while time.monotonic() < deadline:
            if not process_matches(process):
                raise OrynquixError(
                    f"{process.name} stopped during readiness checks",
                    diagnostic_id="ORY-LIFE-009",
                    exit_code=ExitCode.OPERATION_FAILED,
                )
            if time.monotonic() - stable_since >= 1:
                return
            time.sleep(0.1)

    def _evaluate(self, record: SessionRecord, *, persist: bool) -> SessionRecord:
        if record.state == SessionState.STOPPED:
            return record
        if record.state == SessionState.FAILED:
            return record
        if record.state in {SessionState.STARTING, SessionState.STOPPING} and not record.processes:
            failed = SessionRecord(
                schema_version=record.schema_version,
                session_id=record.session_id,
                state=SessionState.FAILED,
                updated_at=utc_now(),
                processes=record.processes,
                services=record.services,
                diagnostic_id="ORY-LIFE-011",
            )
            if persist:
                self.store.save(failed)
            return failed
        services: list[ServiceHealth] = []
        required_failed = False
        optional_failed = False
        process_names = {process.name for process in record.processes}
        for process in record.processes:
            alive = process_matches(process)
            if not alive and process.required:
                required_failed = True
            elif not alive:
                optional_failed = True
            services.append(
                ServiceHealth(
                    process.name,
                    Health.PASS if alive else Health.FAIL,
                    (
                        "Process identity verified"
                        if alive
                        else "Process is absent or identity changed"
                    ),
                    process.required,
                )
            )
        for service in record.services:
            if service.name not in process_names:
                services.append(service)

        if required_failed:
            target = SessionState.FAILED
            diagnostic_id = "ORY-LIFE-010"
        elif optional_failed or any(service.health == Health.WARN for service in services):
            target = SessionState.DEGRADED
            diagnostic_id = None
        else:
            target = SessionState.RUNNING
            diagnostic_id = None
        if target == record.state:
            return SessionRecord(
                schema_version=record.schema_version,
                session_id=record.session_id,
                state=record.state,
                updated_at=record.updated_at,
                processes=record.processes,
                services=tuple(services),
                diagnostic_id=record.diagnostic_id,
            )
        updated = record.transition(
            target,
            now=utc_now(),
            services=tuple(services),
            diagnostic_id=diagnostic_id,
        )
        if persist:
            self.store.save(updated)
            self.journal.append(
                "session.health_changed",
                session_id=record.session_id,
                previous=record.state,
                current=target,
            )
        return updated

    @staticmethod
    def _status_dict(record: SessionRecord) -> dict[str, Any]:
        return {
            "ok": record.state in {SessionState.STOPPED, SessionState.RUNNING},
            "session_id": record.session_id,
            "state": record.state,
            "updated_at": record.updated_at,
            "diagnostic_id": record.diagnostic_id,
            "services": [service.to_dict() for service in record.services],
        }
