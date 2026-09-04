"""Filesystem layout and destructive-operation guards."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from orynquix.errors import ExitCode, OrynquixError


@dataclass(frozen=True, slots=True)
class OrynquixPaths:
    config_dir: Path
    data_dir: Path
    state_dir: Path
    cache_dir: Path
    projects_dir: Path

    @classmethod
    def discover(cls) -> OrynquixPaths:
        override = os.environ.get("ORYNQUIX_HOME")
        if override:
            base = Path(override).expanduser().resolve()
            return cls(
                config_dir=base / "config",
                data_dir=base / "data",
                state_dir=base / "state",
                cache_dir=base / "cache",
                projects_dir=base / "projects",
            )

        home = Path.home().resolve()
        config_home = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
        data_home = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
        state_home = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))
        cache_home = Path(os.environ.get("XDG_CACHE_HOME", home / ".cache"))
        projects = Path(os.environ.get("ORYNQUIX_PROJECTS", home / "OrynquixProjects"))
        return cls(
            config_dir=(config_home / "orynquix").resolve(),
            data_dir=(data_home / "orynquix").resolve(),
            state_dir=(state_home / "orynquix").resolve(),
            cache_dir=(cache_home / "orynquix").resolve(),
            projects_dir=projects.expanduser().resolve(),
        )

    @property
    def config_file(self) -> Path:
        return self.config_dir / "config.toml"

    @property
    def session_file(self) -> Path:
        return self.state_dir / "session.json"

    @property
    def bootstrap_file(self) -> Path:
        return self.state_dir / "bootstrap.json"

    @property
    def lock_file(self) -> Path:
        return self.state_dir / "operation.lock"

    @property
    def journal_file(self) -> Path:
        return self.state_dir / "journal.jsonl"

    @property
    def gui_token_file(self) -> Path:
        return self.state_dir / "gui-token"

    @property
    def log_dir(self) -> Path:
        return self.state_dir / "logs"

    @property
    def reports_dir(self) -> Path:
        return self.state_dir / "reports"

    def ensure_control_dirs(self) -> None:
        for path in (self.config_dir, self.data_dir, self.state_dir, self.cache_dir, self.log_dir):
            path.mkdir(parents=True, exist_ok=True, mode=0o700)

    def ensure_projects_dir(self) -> None:
        self.projects_dir.mkdir(parents=True, exist_ok=True, mode=0o700)

    def assert_safe_controlled_path(self, target: Path) -> Path:
        """Reject broad or user-data paths before any recursive removal."""
        candidate = target.expanduser().resolve()
        protected = {Path("/"), Path.home().resolve(), self.projects_dir.resolve()}
        if candidate in protected:
            raise OrynquixError(
                f"refusing destructive operation on protected path: {candidate}",
                diagnostic_id="ORY-PATH-001",
                exit_code=ExitCode.PERMISSION_DENIED,
            )
        controlled_roots = {
            self.config_dir.resolve(),
            self.data_dir.resolve(),
            self.state_dir.resolve(),
            self.cache_dir.resolve(),
        }
        if candidate not in controlled_roots:
            raise OrynquixError(
                f"path is not an Orynquix-controlled root: {candidate}",
                diagnostic_id="ORY-PATH-002",
                exit_code=ExitCode.PERMISSION_DENIED,
            )
        return candidate
