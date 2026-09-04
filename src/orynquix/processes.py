"""Process identity checks prevent signaling a reused PID."""

from __future__ import annotations

import hashlib
import os
import signal
import time
from pathlib import Path

from orynquix.errors import ExitCode, OrynquixError
from orynquix.models import ProcessRecord
from orynquix.timeutil import utc_now


def capture_process(name: str, pid: int, *, required: bool) -> ProcessRecord:
    try:
        start_ticks, digest = _read_identity(pid)
    except (FileNotFoundError, ProcessLookupError, PermissionError, ValueError) as exc:
        raise OrynquixError(
            f"{name} exited before its identity could be recorded",
            diagnostic_id="ORY-PROC-001",
            exit_code=ExitCode.OPERATION_FAILED,
        ) from exc
    try:
        group = os.getpgid(pid)
    except ProcessLookupError as exc:
        raise OrynquixError(
            f"{name} exited before its identity could be recorded",
            diagnostic_id="ORY-PROC-002",
            exit_code=ExitCode.OPERATION_FAILED,
        ) from exc
    return ProcessRecord(
        name=name,
        pid=pid,
        process_group=group,
        started_at=utc_now(),
        start_ticks=start_ticks,
        cmdline_sha256=digest,
        required=required,
    )


def process_matches(record: ProcessRecord) -> bool:
    try:
        start_ticks, digest = _read_identity(record.pid)
    except (FileNotFoundError, ProcessLookupError, PermissionError, ValueError):
        return False
    return start_ticks == record.start_ticks and digest == record.cmdline_sha256


def terminate_owned_process(record: ProcessRecord, *, timeout: float) -> bool:
    if not process_matches(record):
        return False
    try:
        os.killpg(record.process_group, signal.SIGTERM)
    except ProcessLookupError:
        return True
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not process_matches(record):
            return True
        time.sleep(0.1)
    if process_matches(record):
        try:
            os.killpg(record.process_group, signal.SIGKILL)
        except ProcessLookupError:
            return True
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        if not process_matches(record):
            return True
        time.sleep(0.05)
    return not process_matches(record)


def resident_memory_bytes(record: ProcessRecord) -> int | None:
    if not process_matches(record):
        return None
    status_path = Path("/proc") / str(record.pid) / "status"
    try:
        for line in status_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1]) * 1024
    except (OSError, ValueError, IndexError):
        return None
    return None


def _read_identity(pid: int) -> tuple[int, str]:
    proc = Path("/proc") / str(pid)
    stat = (proc / "stat").read_text(encoding="utf-8")
    closing = stat.rfind(")")
    if closing < 0:
        raise ValueError("malformed /proc stat")
    fields_after_comm = stat[closing + 2 :].split()
    # Field 22 overall is index 19 after the process name and pid fields.
    start_ticks = int(fields_after_comm[19])
    cmdline = (proc / "cmdline").read_bytes()
    if not cmdline:
        raise ProcessLookupError(pid)
    return start_ticks, hashlib.sha256(cmdline).hexdigest()
