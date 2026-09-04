"""Append-only operation journal used for recovery and support bundles."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from orynquix.timeutil import utc_now


class Journal:
    def __init__(self, path: Path) -> None:
        self.path = path

    def append(self, event: str, **fields: Any) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        record = {"timestamp": utc_now(), "event": event, **fields}
        descriptor = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
        with os.fdopen(descriptor, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True, separators=(",", ":")))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
