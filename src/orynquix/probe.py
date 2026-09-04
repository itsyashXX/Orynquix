"""Read-only Android/Termux environment inspection."""

from __future__ import annotations

import os
import platform
import shutil
import sys
from collections.abc import Mapping
from pathlib import Path

from orynquix.adapters.command import LocalRunner, Runner
from orynquix.models import Check, Health, ProbeReport
from orynquix.timeutil import utc_now

ARM64_NAMES = frozenset({"aarch64", "arm64", "armv8l"})
MIN_FREE_BYTES = 6 * 1024**3
RECOMMENDED_FREE_BYTES = 10 * 1024**3


class HostProbe:
    def __init__(
        self,
        *,
        runner: Runner | None = None,
        environ: Mapping[str, str] | None = None,
        home: Path | None = None,
    ) -> None:
        self.runner = runner or LocalRunner()
        self.environ = dict(os.environ if environ is None else environ)
        self.home = (home or Path.home()).resolve()

    def run(self, *, require_runtime: bool = False) -> ProbeReport:
        checks: list[Check] = []
        facts: dict[str, object] = {}

        machine = platform.machine().lower()
        facts["architecture"] = machine
        checks.append(
            Check(
                key="architecture",
                health=Health.PASS if machine in ARM64_NAMES else Health.FAIL,
                summary=f"CPU architecture: {machine or 'unknown'}",
                remediation=(
                    None
                    if machine in ARM64_NAMES
                    else "Stage 1 targets ARM64 Android devices only."
                ),
            )
        )

        termux_prefix = self.environ.get("PREFIX", "")
        termux_app = self.environ.get("TERMUX_VERSION")
        is_termux = "com.termux" in termux_prefix and self.runner.which("pkg") is not None
        facts["termux"] = {
            "detected": is_termux,
            "prefix": _redact_home(termux_prefix, self.home),
            "version": termux_app,
            "release_source": (
                self.environ.get("TERMUX_APK_RELEASE")
                or self.environ.get("TERMUX_APP__APK_RELEASE")
                or "unknown"
            ),
        }
        checks.append(
            Check(
                key="termux",
                health=Health.PASS if is_termux else Health.FAIL,
                summary=(
                    "Supported Termux environment detected" if is_termux else "Termux not detected"
                ),
                remediation=(
                    None
                    if is_termux
                    else (
                        "Run Orynquix inside the current supported Termux app, not Android's shell."
                    )
                ),
            )
        )

        android_release = self._getprop("ro.build.version.release")
        android_sdk = self._getprop("ro.build.version.sdk")
        facts["android"] = {"release": android_release, "sdk": android_sdk}
        android_major = _leading_integer(android_release)
        android_supported = android_major is not None and android_major >= 8
        checks.append(
            Check(
                key="android",
                health=(
                    Health.PASS
                    if android_supported
                    else (Health.FAIL if android_major is not None else Health.WARN)
                ),
                summary=(
                    f"Android {android_release} (SDK {android_sdk or 'unknown'})"
                    if android_release
                    else "Android version could not be read"
                ),
                remediation=(
                    None
                    if android_supported
                    else (
                        "Termux:X11 requires Android 8 or newer."
                        if android_major is not None
                        else "Ensure `getprop` is available in Termux."
                    )
                ),
            )
        )

        version = sys.version_info
        python_ok = version >= (3, 12)
        facts["python"] = platform.python_version()
        checks.append(
            Check(
                key="python",
                health=Health.PASS if python_ok else Health.FAIL,
                summary=f"Python {platform.python_version()}",
                remediation=(
                    None if python_ok else "Install Python 3.12 or newer with `pkg install python`."
                ),
            )
        )

        try:
            disk = shutil.disk_usage(self.home)
            free_bytes = disk.free
            facts["storage"] = {
                "total_bytes": disk.total,
                "free_bytes": free_bytes,
                "minimum_free_bytes": MIN_FREE_BYTES,
                "recommended_free_bytes": RECOMMENDED_FREE_BYTES,
            }
            if free_bytes < MIN_FREE_BYTES:
                disk_health = Health.FAIL
                disk_summary = f"Only {_human_bytes(free_bytes)} free"
                disk_fix = f"Free at least {_human_bytes(MIN_FREE_BYTES)} before installation."
            elif free_bytes < RECOMMENDED_FREE_BYTES:
                disk_health = Health.WARN
                disk_summary = f"{_human_bytes(free_bytes)} free; limited safety headroom"
                disk_fix = f"{_human_bytes(RECOMMENDED_FREE_BYTES)} free is recommended."
            else:
                disk_health = Health.PASS
                disk_summary = f"{_human_bytes(free_bytes)} free"
                disk_fix = None
            checks.append(
                Check(
                    key="storage",
                    health=disk_health,
                    summary=disk_summary,
                    remediation=disk_fix,
                    data={"free_bytes": free_bytes},
                )
            )
        except OSError as exc:
            facts["storage"] = {"error": str(exc)}
            checks.append(
                Check(
                    key="storage",
                    health=Health.FAIL,
                    summary="Storage headroom could not be measured",
                    details=str(exc),
                )
            )

        memory = _read_meminfo()
        facts["memory"] = memory
        available = int(memory.get("MemAvailable", 0))
        checks.append(
            Check(
                key="memory",
                health=Health.PASS if available >= 1024**3 else Health.WARN,
                summary=(
                    f"{_human_bytes(available)} memory currently available"
                    if available
                    else "Available memory could not be measured"
                ),
                remediation=(
                    None
                    if available >= 1024**3
                    else "Close heavy Android apps before starting the desktop."
                ),
                data={"available_bytes": available},
            )
        )

        runtime_commands = {
            "proot-distro": "Install with `pkg install proot-distro`.",
            "termux-x11": "Install the Termux:X11 companion and its Termux package.",
            "pulseaudio": "Install with `pkg install pulseaudio` (audio may remain degraded).",
        }
        command_facts: dict[str, object] = {}
        for command, remediation in runtime_commands.items():
            location = self.runner.which(command)
            command_facts[command] = bool(location)
            required = command != "pulseaudio"
            if location:
                health = Health.PASS
            elif require_runtime and required:
                health = Health.FAIL
            else:
                health = Health.WARN
            checks.append(
                Check(
                    key=f"command.{command}",
                    health=health,
                    summary=(
                        f"{command} is available" if location else f"{command} is not installed"
                    ),
                    remediation=None if location else remediation,
                )
            )
        facts["commands"] = command_facts
        facts["package_versions"] = self._package_versions()

        companion = self._android_package_present("com.termux.x11")
        facts["termux_x11_companion"] = companion
        companion_health = (
            Health.PASS if companion else (Health.FAIL if require_runtime else Health.WARN)
        )
        checks.append(
            Check(
                key="termux_x11_companion",
                health=companion_health,
                summary=(
                    "Termux:X11 Android companion is installed"
                    if companion
                    else "Termux:X11 Android companion was not detected"
                ),
                remediation=(
                    None
                    if companion
                    else "Install Termux:X11 from the official Termux:X11 release source."
                ),
            )
        )

        hard_keys = {"architecture", "termux", "android", "python", "storage"}
        if require_runtime:
            hard_keys.update({"command.proot-distro", "command.termux-x11", "termux_x11_companion"})
        supported = not any(
            check.health == Health.FAIL and check.key in hard_keys for check in checks
        )
        return ProbeReport(
            generated_at=utc_now(), supported=supported, facts=facts, checks=tuple(checks)
        )

    def _getprop(self, key: str) -> str | None:
        if self.runner.which("getprop") is None:
            return None
        result = self.runner.run(("getprop", key), timeout=3)
        value = result.stdout.strip()
        return value or None

    def _android_package_present(self, package: str) -> bool:
        if self.runner.which("pm"):
            result = self.runner.run(("pm", "path", package), timeout=5)
            return result.ok and "package:" in result.stdout
        if self.runner.which("cmd"):
            result = self.runner.run(("cmd", "package", "path", package), timeout=5)
            return result.ok and "package:" in result.stdout
        return False

    def _package_versions(self) -> dict[str, str]:
        if self.runner.which("dpkg-query") is None:
            return {}
        versions: dict[str, str] = {}
        for package in ("proot-distro", "termux-x11-nightly", "pulseaudio"):
            result = self.runner.run(("dpkg-query", "-W", "-f=${Version}", package), timeout=5)
            if result.ok and result.stdout.strip():
                versions[package] = result.stdout.strip()
        return versions


def _read_meminfo(path: Path = Path("/proc/meminfo")) -> dict[str, int]:
    result: dict[str, int] = {}
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            key, raw = line.split(":", 1)
            parts = raw.strip().split()
            if parts:
                result[key] = int(parts[0]) * 1024
    except (OSError, ValueError):
        return {}
    return result


def _human_bytes(value: int) -> str:
    amount = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if amount < 1024 or unit == "TiB":
            return f"{amount:.1f} {unit}"
        amount /= 1024
    return f"{amount:.1f} TiB"


def _redact_home(value: str, home: Path) -> str:
    return value.replace(str(home), "$HOME") if value else value


def _leading_integer(value: str | None) -> int | None:
    if not value:
        return None
    digits = ""
    for character in value:
        if not character.isdigit():
            break
        digits += character
    return int(digits) if digits else None
