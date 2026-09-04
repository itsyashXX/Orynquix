"""Atomic state persistence for resumable operations."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from orynquix.errors import ExitCode, OrynquixError
from orynquix.models import SessionRecord
from orynquix.paths import OrynquixPaths
from orynquix.timeutil import utc_now


class SessionStore:
    def __init__(self, paths: OrynquixPaths) -> None:
        self.paths = paths

    def load(self) -> SessionRecord:
        if not self.paths.session_file.exists():
            return SessionRecord.stopped(now=utc_now())
        value = read_json(self.paths.session_file)
        try:
            return SessionRecord.from_dict(value)
        except (KeyError, TypeError, ValueError) as exc:
            raise OrynquixError(
                f"session state is invalid: {exc}",
                diagnostic_id="ORY-STATE-001",
                exit_code=ExitCode.INVALID_STATE,
                hint="Run `orynquix repair --yes` to archive invalid state and recover.",
            ) from exc

    def save(self, record: SessionRecord) -> None:
        self.paths.ensure_control_dirs()
        write_json_atomic(self.paths.session_file, record.to_dict())


def read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise OrynquixError(
            f"cannot read state file {path.name}: {exc}",
            diagnostic_id="ORY-STATE-002",
            exit_code=ExitCode.INVALID_STATE,
        ) from exc
    if not isinstance(value, dict):
        raise OrynquixError(
            f"state file {path.name} must contain an object",
            diagnostic_id="ORY-STATE-003",
            exit_code=ExitCode.INVALID_STATE,
        )
    return value


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
