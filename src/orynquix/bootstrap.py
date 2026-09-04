"""Idempotent, journaled Stage 1 installer for supported Termux hosts."""

from __future__ import annotations

from typing import Any

from orynquix.adapters.command import LocalRunner, Runner
from orynquix.config import write_default_settings
from orynquix.errors import ExitCode, OrynquixError
from orynquix.guest import (
    CONTAINER_NAME,
    IMAGE_REFERENCE,
    container_installed,
    install_argv,
    login_argv,
)
from orynquix.journal import Journal
from orynquix.locking import OperationLock
from orynquix.models import BootstrapStep
from orynquix.paths import OrynquixPaths
from orynquix.probe import HostProbe
from orynquix.state import read_json, write_json_atomic
from orynquix.timeutil import utc_now

GUEST_PACKAGES = (
    "ca-certificates",
    "curl",
    "dbus-x11",
    "git",
    "thunar",
    "x11-apps",
    "xfce4",
    "xfce4-terminal",
)


class BootstrapManager:
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
        self.journal = Journal(paths.journal_file)

    def plan(self) -> tuple[BootstrapStep, ...]:
        installed = container_installed(self.runner)
        guest_ready = self._guest_has_desktop() if installed else False
        package_commands: list[tuple[str, ...]] = []
        if self.runner.which("proot-distro") is None:
            package_commands.append(("pkg", "install", "-y", "proot-distro"))
        if self.runner.which("termux-x11") is None:
            package_commands.extend(
                (
                    ("pkg", "install", "-y", "x11-repo"),
                    ("pkg", "install", "-y", "termux-x11-nightly"),
                )
            )
        if self.runner.which("pulseaudio") is None:
            package_commands.append(("pkg", "install", "-y", "pulseaudio"))
        return (
            BootstrapStep(
                key="control-directories",
                description="Create private control directories and preserved projects directory",
                complete=(
                    self.paths.state_dir.is_dir()
                    and self.paths.config_dir.is_dir()
                    and self.paths.projects_dir.is_dir()
                ),
            ),
            BootstrapStep(
                key="host-packages",
                description="Install the supported Termux host packages",
                complete=not package_commands,
                commands=tuple(package_commands),
            ),
            BootstrapStep(
                key="debian-rootfs",
                description="Install the Debian stable ARM64 guest userspace",
                complete=installed,
                commands=(() if installed else (install_argv(),)),
            ),
            BootstrapStep(
                key="xfce-desktop",
                description="Install XFCE, X11 test tools, DBus, terminal and file manager",
                complete=guest_ready,
                commands=(
                    (
                        "proot-distro",
                        "login",
                        CONTAINER_NAME,
                        "--",
                        "env",
                        "DEBIAN_FRONTEND=noninteractive",
                        "apt-get",
                        "update",
                    ),
                    (
                        "proot-distro",
                        "login",
                        CONTAINER_NAME,
                        "--",
                        "env",
                        "DEBIAN_FRONTEND=noninteractive",
                        "apt-get",
                        "install",
                        "-y",
                        *GUEST_PACKAGES,
                    ),
                )
                if not guest_ready
                else (),
            ),
            BootstrapStep(
                key="default-config",
                description="Create the privacy-preserving Stage 1 configuration",
                complete=self.paths.config_file.exists(),
            ),
        )

    def apply(self, *, confirmed: bool) -> dict[str, Any]:
        if not confirmed:
            return {
                "ok": True,
                "changed": False,
                "confirmation_required": True,
                "steps": [step.to_dict() for step in self.plan()],
            }
        report = self.probe.run(require_runtime=False)
        if not report.supported:
            raise OrynquixError(
                "this device did not pass the Stage 1 host checks",
                diagnostic_id="ORY-BOOT-001",
                exit_code=ExitCode.UNSUPPORTED_HOST,
                hint="Run `orynquix doctor --json` and resolve every failed host check.",
            )
        self.paths.ensure_control_dirs()
        with OperationLock(self.paths.lock_file):
            initial_plan = self.plan()
            changed: list[str] = []
            rootfs_existed = container_installed(self.runner)
            state = self._bootstrap_state()
            state.update(
                {
                    "schema_version": 1,
                    "status": "running",
                    "updated_at": utc_now(),
                    "rootfs_created_by_orynquix": bool(
                        state.get("rootfs_created_by_orynquix", False)
                    ),
                    "container_name": CONTAINER_NAME,
                    "image_reference": IMAGE_REFERENCE,
                }
            )
            write_json_atomic(self.paths.bootstrap_file, state)
            self.journal.append("bootstrap.started")
            try:
                control_step = next(
                    step for step in initial_plan if step.key == "control-directories"
                )
                self.paths.ensure_projects_dir()
                if not control_step.complete:
                    changed.append("control-directories")

                host_step = next(step for step in initial_plan if step.key == "host-packages")
                for command in host_step.commands:
                    self._run_step("host-packages", command)
                if host_step.commands:
                    changed.append("host-packages")

                if not container_installed(self.runner):
                    self._run_step("debian-rootfs", install_argv())
                    changed.append("debian-rootfs")
                    state["rootfs_created_by_orynquix"] = not rootfs_existed
                    write_json_atomic(self.paths.bootstrap_file, state)

                desktop_step = next(step for step in initial_plan if step.key == "xfce-desktop")
                if not desktop_step.complete:
                    for command in desktop_step.commands:
                        self._run_step("xfce-desktop", command, timeout=1800)
                    changed.append("xfce-desktop")

                if write_default_settings(self.paths):
                    changed.append("default-config")

                state.update({"status": "complete", "updated_at": utc_now()})
                write_json_atomic(self.paths.bootstrap_file, state)
                self.journal.append("bootstrap.completed", changed=changed)
            except Exception as exc:
                state.update(
                    {
                        "status": "interrupted",
                        "updated_at": utc_now(),
                        "last_error": type(exc).__name__,
                    }
                )
                write_json_atomic(self.paths.bootstrap_file, state)
                self.journal.append("bootstrap.interrupted", error_type=type(exc).__name__)
                raise

        final_plan = self.plan()
        complete = all(step.complete for step in final_plan)
        if not complete:
            raise OrynquixError(
                "bootstrap ended but one or more readiness checks are incomplete",
                diagnostic_id="ORY-BOOT-002",
                exit_code=ExitCode.OPERATION_FAILED,
            )
        return {
            "ok": True,
            "changed": bool(changed),
            "changed_steps": changed,
            "projects_preserved_at": str(self.paths.projects_dir),
            "steps": [step.to_dict() for step in final_plan],
        }

    def _run_step(self, key: str, command: tuple[str, ...], *, timeout: float = 600) -> None:
        self.journal.append("bootstrap.step.started", step=key, executable=command[0])
        self.runner.run(command, timeout=timeout, check=True)
        self.journal.append("bootstrap.step.completed", step=key)

    def _guest_has_desktop(self) -> bool:
        if not container_installed(self.runner):
            return False
        result = self.runner.run(
            login_argv("test", "-x", "/usr/bin/xfce4-session"),
            timeout=30,
        )
        return result.ok

    def _bootstrap_state(self) -> dict[str, Any]:
        if not self.paths.bootstrap_file.exists():
            return {}
        return read_json(self.paths.bootstrap_file)
