"""Single-writer operation lock."""

from __future__ import annotations

import fcntl
from pathlib import Path
from types import TracebackType

from orynquix.errors import ExitCode, OrynquixError


class OperationLock:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._handle: object | None = None

    def __enter__(self) -> OperationLock:
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        handle = self.path.open("a+", encoding="utf-8")
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            handle.close()
            raise OrynquixError(
                "another Orynquix operation is already running",
                diagnostic_id="ORY-LOCK-001",
                exit_code=ExitCode.LOCKED,
                hint="Wait for it to finish, then run `orynquix status`.",
            ) from exc
        self._handle = handle
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        if self._handle is not None:
            handle = self._handle
            assert hasattr(handle, "fileno") and hasattr(handle, "close")
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
            handle.close()
            self._handle = None
