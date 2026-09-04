"""Stable error types and process exit codes."""

from __future__ import annotations

from enum import IntEnum


class ExitCode(IntEnum):
    OK = 0
    USAGE = 2
    UNSUPPORTED_HOST = 10
    PREREQUISITE_MISSING = 11
    INVALID_STATE = 12
    OPERATION_FAILED = 20
    DEGRADED = 21
    LOCKED = 30
    PERMISSION_DENIED = 31
    INTERNAL_ERROR = 70


class OrynquixError(RuntimeError):
    """An expected failure that has a stable diagnostic identifier."""

    def __init__(
        self,
        message: str,
        *,
        diagnostic_id: str,
        exit_code: ExitCode = ExitCode.OPERATION_FAILED,
        hint: str | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.diagnostic_id = diagnostic_id
        self.exit_code = exit_code
        self.hint = hint

    def to_dict(self) -> dict[str, object]:
        result: dict[str, object] = {
            "ok": False,
            "error": self.message,
            "diagnostic_id": self.diagnostic_id,
            "exit_code": int(self.exit_code),
        }
        if self.hint:
            result["hint"] = self.hint
        return result
