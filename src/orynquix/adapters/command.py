"""Safe subprocess execution using argument arrays only."""

from __future__ import annotations

import os
import shutil
import subprocess
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import IO, Protocol

from orynquix.errors import ExitCode, OrynquixError


@dataclass(frozen=True, slots=True)
class CommandResult:
    argv: tuple[str, ...]
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0


class Runner(Protocol):
    def which(self, command: str) -> str | None: ...

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout: float = 30,
        env: Mapping[str, str] | None = None,
        check: bool = False,
    ) -> CommandResult: ...

    def spawn(
        self,
        argv: Sequence[str],
        *,
        env: Mapping[str, str] | None = None,
        stdout: IO[bytes] | int | None = None,
        stderr: IO[bytes] | int | None = None,
    ) -> subprocess.Popen[bytes]: ...


class LocalRunner:
    def which(self, command: str) -> str | None:
        return shutil.which(command)

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout: float = 30,
        env: Mapping[str, str] | None = None,
        check: bool = False,
    ) -> CommandResult:
        safe_argv = _validate_argv(argv)
        merged_env = os.environ.copy()
        if env:
            merged_env.update(env)
        try:
            completed = subprocess.run(
                safe_argv,
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
                env=merged_env,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise OrynquixError(
                f"command could not run: {safe_argv[0]}: {exc}",
                diagnostic_id="ORY-CMD-001",
                exit_code=ExitCode.OPERATION_FAILED,
            ) from exc
        result = CommandResult(
            argv=safe_argv,
            returncode=completed.returncode,
            stdout=completed.stdout,
            stderr=completed.stderr,
        )
        if check and not result.ok:
            detail = result.stderr.strip() or result.stdout.strip() or "no command output"
            raise OrynquixError(
                f"command failed ({result.returncode}): {safe_argv[0]}: {detail}",
                diagnostic_id="ORY-CMD-002",
                exit_code=ExitCode.OPERATION_FAILED,
            )
        return result

    def spawn(
        self,
        argv: Sequence[str],
        *,
        env: Mapping[str, str] | None = None,
        stdout: IO[bytes] | int | None = None,
        stderr: IO[bytes] | int | None = None,
    ) -> subprocess.Popen[bytes]:
        safe_argv = _validate_argv(argv)
        merged_env = os.environ.copy()
        if env:
            merged_env.update(env)
        try:
            return subprocess.Popen(
                safe_argv,
                env=merged_env,
                stdin=subprocess.DEVNULL,
                stdout=stdout,
                stderr=stderr,
                start_new_session=True,
            )
        except OSError as exc:
            raise OrynquixError(
                f"service could not start: {safe_argv[0]}: {exc}",
                diagnostic_id="ORY-CMD-003",
                exit_code=ExitCode.OPERATION_FAILED,
            ) from exc


def open_binary_log(path: Path) -> IO[bytes]:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    return path.open("ab", buffering=0)


def _validate_argv(argv: Sequence[str]) -> tuple[str, ...]:
    safe = tuple(str(item) for item in argv)
    if not safe or not safe[0]:
        raise ValueError("argv must contain an executable")
    if any("\x00" in item for item in safe):
        raise ValueError("argv cannot contain NUL bytes")
    return safe
