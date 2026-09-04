"""Typed domain models shared across the control plane."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import StrEnum
from typing import Any


class Health(StrEnum):
    PASS = "pass"
    WARN = "warn"
    FAIL = "fail"
    SKIP = "skip"


class SessionState(StrEnum):
    STOPPED = "stopped"
    STARTING = "starting"
    RUNNING = "running"
    DEGRADED = "degraded"
    FAILED = "failed"
    REPAIRING = "repairing"
    STOPPING = "stopping"


ALLOWED_TRANSITIONS: dict[SessionState, frozenset[SessionState]] = {
    SessionState.STOPPED: frozenset({SessionState.STARTING, SessionState.REPAIRING}),
    SessionState.STARTING: frozenset(
        {SessionState.RUNNING, SessionState.DEGRADED, SessionState.FAILED, SessionState.STOPPING}
    ),
    SessionState.RUNNING: frozenset(
        {SessionState.DEGRADED, SessionState.FAILED, SessionState.STOPPING}
    ),
    SessionState.DEGRADED: frozenset(
        {SessionState.RUNNING, SessionState.FAILED, SessionState.STOPPING}
    ),
    SessionState.FAILED: frozenset({SessionState.REPAIRING, SessionState.STOPPING}),
    SessionState.REPAIRING: frozenset({SessionState.STOPPED, SessionState.FAILED}),
    SessionState.STOPPING: frozenset({SessionState.STOPPED, SessionState.FAILED}),
}


@dataclass(frozen=True, slots=True)
class Check:
    key: str
    health: Health
    summary: str
    details: str | None = None
    remediation: str | None = None
    data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class ProbeReport:
    generated_at: str
    supported: bool
    facts: dict[str, Any]
    checks: tuple[Check, ...]

    @property
    def overall(self) -> Health:
        health_values = {check.health for check in self.checks}
        if Health.FAIL in health_values:
            return Health.FAIL
        if Health.WARN in health_values:
            return Health.WARN
        return Health.PASS

    def to_dict(self) -> dict[str, Any]:
        return {
            "generated_at": self.generated_at,
            "supported": self.supported,
            "overall": self.overall,
            "facts": self.facts,
            "checks": [check.to_dict() for check in self.checks],
        }


@dataclass(frozen=True, slots=True)
class ProcessRecord:
    name: str
    pid: int
    process_group: int
    started_at: str
    start_ticks: int
    cmdline_sha256: str
    required: bool

    @classmethod
    def from_dict(cls, value: dict[str, Any]) -> ProcessRecord:
        return cls(
            name=str(value["name"]),
            pid=int(value["pid"]),
            process_group=int(value["process_group"]),
            started_at=str(value["started_at"]),
            start_ticks=int(value["start_ticks"]),
            cmdline_sha256=str(value["cmdline_sha256"]),
            required=bool(value["required"]),
        )


@dataclass(frozen=True, slots=True)
class ServiceHealth:
    name: str
    health: Health
    message: str
    required: bool

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class SessionRecord:
    schema_version: int
    session_id: str
    state: SessionState
    updated_at: str
    processes: tuple[ProcessRecord, ...] = ()
    services: tuple[ServiceHealth, ...] = ()
    diagnostic_id: str | None = None

    @classmethod
    def stopped(cls, *, now: str) -> SessionRecord:
        return cls(schema_version=1, session_id="none", state=SessionState.STOPPED, updated_at=now)

    @classmethod
    def from_dict(cls, value: dict[str, Any]) -> SessionRecord:
        return cls(
            schema_version=int(value.get("schema_version", 1)),
            session_id=str(value.get("session_id", "none")),
            state=SessionState(str(value.get("state", SessionState.STOPPED))),
            updated_at=str(value["updated_at"]),
            processes=tuple(ProcessRecord.from_dict(item) for item in value.get("processes", [])),
            services=tuple(
                ServiceHealth(
                    name=str(item["name"]),
                    health=Health(str(item["health"])),
                    message=str(item["message"]),
                    required=bool(item["required"]),
                )
                for item in value.get("services", [])
            ),
            diagnostic_id=(str(value["diagnostic_id"]) if value.get("diagnostic_id") else None),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "session_id": self.session_id,
            "state": self.state,
            "updated_at": self.updated_at,
            "processes": [asdict(process) for process in self.processes],
            "services": [service.to_dict() for service in self.services],
            "diagnostic_id": self.diagnostic_id,
        }

    def transition(
        self,
        target: SessionState,
        *,
        now: str,
        processes: tuple[ProcessRecord, ...] | None = None,
        services: tuple[ServiceHealth, ...] | None = None,
        diagnostic_id: str | None = None,
    ) -> SessionRecord:
        if target not in ALLOWED_TRANSITIONS[self.state]:
            msg = f"invalid state transition: {self.state} -> {target}"
            raise ValueError(msg)
        return SessionRecord(
            schema_version=self.schema_version,
            session_id=self.session_id,
            state=target,
            updated_at=now,
            processes=self.processes if processes is None else processes,
            services=self.services if services is None else services,
            diagnostic_id=diagnostic_id,
        )


@dataclass(frozen=True, slots=True)
class BootstrapStep:
    key: str
    description: str
    complete: bool
    commands: tuple[tuple[str, ...], ...] = ()

    def to_dict(self) -> dict[str, Any]:
        return {
            "key": self.key,
            "description": self.description,
            "complete": self.complete,
            "commands": [list(command) for command in self.commands],
        }
