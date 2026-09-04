from __future__ import annotations

import os
import subprocess
import sys
from collections.abc import Mapping, Sequence
from contextlib import suppress
from pathlib import Path
from typing import IO

from orynquix.adapters.command import CommandResult
from orynquix.guest import CONTAINER_NAME
from orynquix.models import Check, Health, ProbeReport
from orynquix.timeutil import utc_now


class PassingProbe:
    def run(self, *, require_runtime: bool = False) -> ProbeReport:
        return ProbeReport(
            generated_at=utc_now(),
            supported=True,
            facts={"test": True, "require_runtime": require_runtime},
            checks=(Check("test", Health.PASS, "test host"),),
        )


class FakeRunner:
    def __init__(self) -> None:
        self.commands = {
            "pkg",
            "getprop",
            "pm",
            "proot-distro",
            "termux-x11",
            "pulseaudio",
            "pactl",
            "am",
            "du",
        }
        self.calls: list[tuple[str, ...]] = []
        self.audio_start_ok = True
        self.audio_running = False
        self.desktop_ready = True
        self.container_installed = True
        self.spawned: list[subprocess.Popen[bytes]] = []

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
        command = tuple(argv)
        self.calls.append(command)
        returncode = 0
        stdout = ""
        stderr = ""
        if command[:2] == ("getprop", "ro.build.version.release"):
            stdout = "15\n"
        elif command[:2] == ("getprop", "ro.build.version.sdk"):
            stdout = "35\n"
        elif command[:2] == ("pm", "path"):
            stdout = "package:/data/app/com.termux.x11/base.apk\n"
        elif command[:3] == ("proot-distro", "list", "--quiet"):
            stdout = f"{CONTAINER_NAME}\n" if self.container_installed else ""
        elif command[:2] == ("pulseaudio", "--check"):
            returncode = 0 if self.audio_running else 1
        elif command[:2] == ("pulseaudio", "--start"):
            returncode = 0 if self.audio_start_ok else 1
            self.audio_running = self.audio_start_ok
        elif "test" in command and "/usr/bin/xfce4-session" in command:
            returncode = 0 if self.desktop_ready else 1
        elif command[:2] == ("du", "-sb"):
            stdout = "123456\trootfs\n"
        return CommandResult(command, returncode, stdout, stderr)

    def spawn(
        self,
        argv: Sequence[str],
        *,
        env: Mapping[str, str] | None = None,
        stdout: IO[bytes] | int | None = None,
        stderr: IO[bytes] | int | None = None,
    ) -> subprocess.Popen[bytes]:
        self.calls.append(tuple(argv))
        process = subprocess.Popen(
            (sys.executable, "-c", "import time; time.sleep(60)"),
            stdin=subprocess.DEVNULL,
            stdout=stdout,
            stderr=stderr,
            start_new_session=True,
        )
        self.spawned.append(process)
        return process

    def cleanup(self) -> None:
        for process in self.spawned:
            if process.poll() is None:
                with suppress(ProcessLookupError):
                    os.killpg(os.getpgid(process.pid), 9)
                process.wait(timeout=5)


def make_display_socket(temp: Path, display: int = 1) -> Path:
    socket = temp / ".X11-unix" / f"X{display}"
    socket.parent.mkdir(parents=True)
    socket.touch()
    return socket
