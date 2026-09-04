"""Stage-scoped rollback that preserves user projects by construction."""

from __future__ import annotations

import shutil
from typing import Any

from orynquix.adapters.command import LocalRunner, Runner
from orynquix.errors import ExitCode, OrynquixError
from orynquix.guest import CONTAINER_NAME
from orynquix.lifecycle import LifecycleManager
from orynquix.paths import OrynquixPaths
from orynquix.state import read_json


class Uninstaller:
    def __init__(
        self,
        paths: OrynquixPaths,
        *,
        runner: Runner | None = None,
        lifecycle: LifecycleManager | None = None,
    ) -> None:
        self.paths = paths
        self.runner = runner or LocalRunner()
        self.lifecycle = lifecycle or LifecycleManager(paths, runner=self.runner)

    def run(self, *, confirmed: bool, remove_rootfs: bool) -> dict[str, Any]:
        controlled = (
            self.paths.config_dir,
            self.paths.data_dir,
            self.paths.cache_dir,
            self.paths.state_dir,
        )
        plan = {
            "remove": [str(path) for path in controlled if path.exists()],
            "preserve": [str(self.paths.projects_dir)],
            "remove_debian_rootfs": remove_rootfs,
        }
        if not confirmed:
            return {"ok": True, "confirmation_required": True, **plan}

        state = self.lifecycle.status()
        if state["state"] != "stopped":
            self.lifecycle.stop()

        rootfs_owned = False
        if self.paths.bootstrap_file.exists():
            bootstrap = read_json(self.paths.bootstrap_file)
            rootfs_owned = bool(bootstrap.get("rootfs_created_by_orynquix", False))
        if remove_rootfs:
            if not rootfs_owned:
                raise OrynquixError(
                    "Debian rootfs was not proven to be created by Orynquix; refusing removal",
                    diagnostic_id="ORY-UNINSTALL-001",
                    exit_code=ExitCode.PERMISSION_DENIED,
                )
            self.runner.run(("proot-distro", "remove", CONTAINER_NAME), timeout=600, check=True)

        removed: list[str] = []
        for path in controlled:
            if not path.exists():
                continue
            safe = self.paths.assert_safe_controlled_path(path)
            shutil.rmtree(safe)
            removed.append(str(safe))
        return {
            "ok": True,
            "removed": removed,
            "rootfs_removed": remove_rootfs,
            "projects_preserved_at": str(self.paths.projects_dir),
        }
