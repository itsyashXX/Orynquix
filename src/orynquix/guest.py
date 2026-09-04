"""Current PRoot-Distro container identity and command construction."""

from __future__ import annotations

import os
from pathlib import Path

from orynquix.adapters.command import Runner

CONTAINER_NAME = "orynquix-debian"
IMAGE_REFERENCE = "debian:stable"
GUEST_ARCHITECTURE = "aarch64"


def container_installed(runner: Runner) -> bool:
    if runner.which("proot-distro") is None:
        return False
    result = runner.run(("proot-distro", "list", "--quiet"), timeout=30)
    if not result.ok:
        return False
    return CONTAINER_NAME in {line.strip() for line in result.stdout.splitlines()}


def install_argv() -> tuple[str, ...]:
    return (
        "proot-distro",
        "install",
        IMAGE_REFERENCE,
        "--name",
        CONTAINER_NAME,
        "--architecture",
        GUEST_ARCHITECTURE,
    )


def login_argv(*command: str) -> tuple[str, ...]:
    return ("proot-distro", "login", CONTAINER_NAME, "--", *command)


def rootfs_candidates() -> tuple[Path, ...]:
    prefix = Path(os.environ.get("PREFIX", "/data/data/com.termux/files/usr"))
    runtime = prefix / "var/lib/proot-distro"
    return (
        runtime / "containers" / CONTAINER_NAME / "rootfs",
        runtime / "installed-rootfs" / CONTAINER_NAME,
    )


def existing_rootfs() -> Path | None:
    return next((path for path in rootfs_candidates() if path.is_dir()), None)
