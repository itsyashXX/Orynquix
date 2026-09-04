from __future__ import annotations

import os
import tempfile
import unittest
from collections.abc import Mapping, Sequence
from pathlib import Path

from orynquix.adapters.command import CommandResult
from orynquix.bootstrap import BootstrapManager
from orynquix.errors import OrynquixError
from orynquix.guest import CONTAINER_NAME
from orynquix.paths import OrynquixPaths
from orynquix.state import read_json
from tests.helpers import PassingProbe


class BootstrapRunner:
    def __init__(self, rootfs: Path, *, fail_desktop: bool = False) -> None:
        self.rootfs = rootfs
        self.commands = {"pkg"}
        self.desktop_ready = False
        self.fail_desktop = fail_desktop
        self.calls: list[tuple[str, ...]] = []

    def which(self, command: str) -> str | None:
        return f"/fake/{command}" if command in self.commands else None

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout: float = 30,
        env: Mapping[str, str] | None = None,
        check: bool = False,
    ) -> CommandResult:
        del timeout, env
        command = tuple(argv)
        self.calls.append(command)
        returncode = 0
        stderr = ""
        if command[:3] == ("pkg", "install", "-y"):
            package = command[3]
            if package == "proot-distro":
                self.commands.add("proot-distro")
            elif package == "termux-x11-nightly":
                self.commands.add("termux-x11")
            elif package == "pulseaudio":
                self.commands.add("pulseaudio")
        elif command[:3] == ("proot-distro", "install", "debian:stable"):
            self.rootfs.mkdir(parents=True)
        elif command[:3] == ("proot-distro", "list", "--quiet"):
            stdout = f"{CONTAINER_NAME}\n" if self.rootfs.is_dir() else ""
            return CommandResult(command, 0, stdout, "")
        elif "test" in command and "/usr/bin/xfce4-session" in command:
            returncode = 0 if self.desktop_ready else 1
        elif "apt-get" in command and "install" in command:
            if self.fail_desktop:
                returncode = 9
                stderr = "simulated apt interruption"
            else:
                self.desktop_ready = True
        result = CommandResult(command, returncode, "", stderr)
        if check and not result.ok:
            raise OrynquixError(
                "simulated command failure",
                diagnostic_id="TEST-CMD",
            )
        return result

    def spawn(self, *args: object, **kwargs: object) -> object:
        raise AssertionError("bootstrap does not spawn services")


class BootstrapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.prefix = self.base / "prefix"
        self.rootfs = self.prefix / "var/lib/proot-distro/containers/orynquix-debian/rootfs"
        self.paths = OrynquixPaths(
            self.base / "config",
            self.base / "data",
            self.base / "state",
            self.base / "cache",
            self.base / "projects",
        )
        self.previous_prefix = os.environ.get("PREFIX")
        os.environ["PREFIX"] = str(self.prefix)

    def tearDown(self) -> None:
        if self.previous_prefix is None:
            os.environ.pop("PREFIX", None)
        else:
            os.environ["PREFIX"] = self.previous_prefix
        self.temporary.cleanup()

    def test_plan_apply_and_second_run_are_idempotent(self) -> None:
        runner = BootstrapRunner(self.rootfs)
        manager = BootstrapManager(self.paths, runner=runner, probe=PassingProbe())
        preview = manager.apply(confirmed=False)
        self.assertTrue(preview["confirmation_required"])
        self.assertTrue(any(not step["complete"] for step in preview["steps"]))

        first = manager.apply(confirmed=True)
        self.assertTrue(first["changed"])
        self.assertTrue(self.rootfs.is_dir())
        self.assertTrue(self.paths.projects_dir.is_dir())
        self.assertTrue(read_json(self.paths.bootstrap_file)["rootfs_created_by_orynquix"])

        mutation_count = len(
            [call for call in runner.calls if "install" in call and "test" not in call]
        )
        second = manager.apply(confirmed=True)
        self.assertFalse(second["changed"])
        self.assertEqual(
            len([call for call in runner.calls if "install" in call and "test" not in call]),
            mutation_count,
        )

    def test_interruption_is_recorded_for_safe_resume(self) -> None:
        runner = BootstrapRunner(self.rootfs, fail_desktop=True)
        manager = BootstrapManager(self.paths, runner=runner, probe=PassingProbe())
        with self.assertRaises(OrynquixError):
            manager.apply(confirmed=True)
        state = read_json(self.paths.bootstrap_file)
        self.assertEqual(state["status"], "interrupted")
        self.assertTrue(self.rootfs.exists())
