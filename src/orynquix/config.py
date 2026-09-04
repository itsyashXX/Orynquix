"""Validated TOML configuration with conservative Stage 1 defaults."""

from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from orynquix.errors import ExitCode, OrynquixError
from orynquix.paths import OrynquixPaths


@dataclass(frozen=True, slots=True)
class Settings:
    distribution: str = "debian"
    display: str = ":1"
    desktop_command: tuple[str, ...] = (
        "dbus-launch",
        "--exit-with-session",
        "xfce4-session",
    )
    audio_enabled: bool = True
    readiness_timeout_seconds: float = 25.0
    stop_timeout_seconds: float = 10.0
    shared_directory: Path | None = None
    telemetry_enabled: bool = False

    def validate(self) -> Settings:
        if self.distribution != "debian":
            raise OrynquixError(
                "Stage 1 supports only the Debian adapter",
                diagnostic_id="ORY-CONFIG-001",
                exit_code=ExitCode.USAGE,
            )
        if not self.display.startswith(":") or not self.display[1:].isdigit():
            raise OrynquixError(
                f"invalid X11 display: {self.display}",
                diagnostic_id="ORY-CONFIG-002",
                exit_code=ExitCode.USAGE,
            )
        if not self.desktop_command or any(not item for item in self.desktop_command):
            raise OrynquixError(
                "desktop command cannot be empty",
                diagnostic_id="ORY-CONFIG-003",
                exit_code=ExitCode.USAGE,
            )
        if not 1 <= self.readiness_timeout_seconds <= 120:
            raise OrynquixError(
                "readiness timeout must be between 1 and 120 seconds",
                diagnostic_id="ORY-CONFIG-004",
                exit_code=ExitCode.USAGE,
            )
        if not 1 <= self.stop_timeout_seconds <= 60:
            raise OrynquixError(
                "stop timeout must be between 1 and 60 seconds",
                diagnostic_id="ORY-CONFIG-005",
                exit_code=ExitCode.USAGE,
            )
        if self.telemetry_enabled:
            raise OrynquixError(
                "telemetry is deliberately disabled in Stage 1",
                diagnostic_id="ORY-CONFIG-006",
                exit_code=ExitCode.USAGE,
            )
        if self.shared_directory is not None:
            shared = self.shared_directory.expanduser().resolve()
            if not shared.exists() or not shared.is_dir():
                raise OrynquixError(
                    f"shared directory does not exist: {shared}",
                    diagnostic_id="ORY-CONFIG-007",
                    exit_code=ExitCode.USAGE,
                )
            if shared == Path.home().resolve() or shared == Path("/"):
                raise OrynquixError(
                    "sharing the entire home or root directory is not allowed",
                    diagnostic_id="ORY-CONFIG-008",
                    exit_code=ExitCode.PERMISSION_DENIED,
                )
            return replace(self, shared_directory=shared)
        return self

    def to_dict(self) -> dict[str, Any]:
        return {
            "distribution": self.distribution,
            "display": self.display,
            "desktop_command": list(self.desktop_command),
            "audio_enabled": self.audio_enabled,
            "readiness_timeout_seconds": self.readiness_timeout_seconds,
            "stop_timeout_seconds": self.stop_timeout_seconds,
            "shared_directory": str(self.shared_directory) if self.shared_directory else None,
            "telemetry_enabled": self.telemetry_enabled,
        }


def load_settings(paths: OrynquixPaths) -> Settings:
    if not paths.config_file.exists():
        return Settings().validate()
    try:
        with paths.config_file.open("rb") as handle:
            raw = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise OrynquixError(
            f"cannot read configuration: {exc}",
            diagnostic_id="ORY-CONFIG-009",
            exit_code=ExitCode.INVALID_STATE,
        ) from exc

    session = _mapping(raw.get("session"), "session")
    integration = _mapping(raw.get("integration"), "integration")
    privacy = _mapping(raw.get("privacy"), "privacy")
    shared_value = integration.get("shared_directory")
    settings = Settings(
        distribution=str(session.get("distribution", "debian")),
        display=str(session.get("display", ":1")),
        desktop_command=tuple(
            str(item)
            for item in session.get(
                "desktop_command", ["dbus-launch", "--exit-with-session", "xfce4-session"]
            )
        ),
        audio_enabled=bool(session.get("audio_enabled", True)),
        readiness_timeout_seconds=float(session.get("readiness_timeout_seconds", 25.0)),
        stop_timeout_seconds=float(session.get("stop_timeout_seconds", 10.0)),
        shared_directory=(Path(os.path.expandvars(str(shared_value))) if shared_value else None),
        telemetry_enabled=bool(privacy.get("telemetry_enabled", False)),
    )
    return settings.validate()


def write_default_settings(paths: OrynquixPaths) -> bool:
    """Write a default config once; return False when it already exists."""
    paths.ensure_control_dirs()
    if paths.config_file.exists():
        return False
    content = """# Orynquix Stage 1 configuration
[session]
distribution = "debian"
display = ":1"
desktop_command = ["dbus-launch", "--exit-with-session", "xfce4-session"]
audio_enabled = true
readiness_timeout_seconds = 25
stop_timeout_seconds = 10

[integration]
# Set only to one user-approved Android storage folder.
# shared_directory = "/data/data/com.termux/files/home/storage/shared/Orynquix"

[privacy]
telemetry_enabled = false
"""
    _atomic_text(paths.config_file, content, mode=0o600)
    return True


def save_settings(paths: OrynquixPaths, settings: Settings) -> None:
    settings = settings.validate()
    paths.ensure_control_dirs()
    desktop = ", ".join(_toml_string(item) for item in settings.desktop_command)
    lines = [
        "# Orynquix Stage 1 configuration",
        "[session]",
        f"distribution = {_toml_string(settings.distribution)}",
        f"display = {_toml_string(settings.display)}",
        f"desktop_command = [{desktop}]",
        f"audio_enabled = {str(settings.audio_enabled).lower()}",
        f"readiness_timeout_seconds = {settings.readiness_timeout_seconds:g}",
        f"stop_timeout_seconds = {settings.stop_timeout_seconds:g}",
        "",
        "[integration]",
    ]
    if settings.shared_directory:
        lines.append(f"shared_directory = {_toml_string(str(settings.shared_directory))}")
    else:
        lines.append("# No Android directory is exposed to the guest.")
    lines.extend(
        (
            "",
            "[privacy]",
            "telemetry_enabled = false",
            "",
        )
    )
    _atomic_text(paths.config_file, "\n".join(lines), mode=0o600)


def _mapping(value: object, name: str) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise OrynquixError(
            f"configuration section [{name}] must be a table",
            diagnostic_id="ORY-CONFIG-010",
            exit_code=ExitCode.USAGE,
        )
    return value


def _atomic_text(path: Path, content: str, *, mode: int) -> None:
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _toml_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'
