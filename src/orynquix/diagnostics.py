"""Privacy-previewed support bundles with conservative redaction."""

from __future__ import annotations

import io
import json
import re
import zipfile
from pathlib import Path
from typing import Any

from orynquix.config import load_settings
from orynquix.paths import OrynquixPaths
from orynquix.probe import HostProbe
from orynquix.state import SessionStore, read_json
from orynquix.timeutil import utc_now

SENSITIVE_KEY = re.compile(r"(?i)(token|secret|password|credential|authorization|cookie|api.?key)")
SENSITIVE_TEXT = re.compile(
    r"(?i)(bearer\s+)[a-z0-9._~+\-/]+=*|((?:token|password|secret|api.?key)\s*[=:]\s*)\S+"
)


class SupportBundle:
    def __init__(self, paths: OrynquixPaths, *, probe: HostProbe | None = None) -> None:
        self.paths = paths
        self.probe = probe or HostProbe()

    def preview(self) -> dict[str, Any]:
        available = ["doctor.json", "configuration.json", "manifest.json"]
        if self.paths.session_file.exists():
            available.append("session.json")
        if self.paths.bootstrap_file.exists():
            available.append("bootstrap.json")
        if self.paths.journal_file.exists():
            available.append("journal.jsonl")
        return {
            "ok": True,
            "confirmation_required": True,
            "files": available,
            "privacy": (
                "Home paths are replaced with $HOME. Keys and values that resemble credentials "
                "are redacted. Review the archive before sharing it."
            ),
        }

    def create(self, output: Path | None = None) -> dict[str, Any]:
        self.paths.reports_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        destination = output or (
            self.paths.reports_dir / f"orynquix-support-{utc_now().replace(':', '-')}.zip"
        )
        destination = destination.expanduser().resolve()
        destination.parent.mkdir(parents=True, exist_ok=True)
        home = str(Path.home().resolve())
        payloads: dict[str, str] = {
            "manifest.json": _json_text(
                {
                    "schema_version": 1,
                    "created_at": utc_now(),
                    "redaction": "automatic; owner review still required",
                }
            ),
            "doctor.json": _json_text(_sanitize(self.probe.run().to_dict(), home=home)),
            "configuration.json": _json_text(
                _sanitize(load_settings(self.paths).to_dict(), home=home)
            ),
        }
        if self.paths.session_file.exists():
            payloads["session.json"] = _json_text(
                _sanitize(SessionStore(self.paths).load().to_dict(), home=home)
            )
        if self.paths.bootstrap_file.exists():
            payloads["bootstrap.json"] = _json_text(
                _sanitize(read_json(self.paths.bootstrap_file), home=home)
            )
        if self.paths.journal_file.exists():
            journal_lines: list[str] = []
            for line in self.paths.journal_file.read_text(encoding="utf-8").splitlines():
                try:
                    value = json.loads(line)
                    journal_lines.append(json.dumps(_sanitize(value, home=home), sort_keys=True))
                except json.JSONDecodeError:
                    journal_lines.append(_sanitize_text(line, home=home))
            payloads["journal.jsonl"] = "\n".join(journal_lines) + "\n"

        temporary = destination.with_suffix(destination.suffix + ".tmp")
        try:
            with zipfile.ZipFile(
                temporary, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
            ) as archive:
                for name, content in sorted(payloads.items()):
                    archive.writestr(name, content)
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)
        return {
            "ok": True,
            "path": str(destination),
            "files": sorted(payloads),
            "review_before_sharing": True,
        }


def _sanitize(value: Any, *, home: str) -> Any:
    if isinstance(value, dict):
        return {
            str(key): (
                "[REDACTED]" if SENSITIVE_KEY.search(str(key)) else _sanitize(item, home=home)
            )
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [_sanitize(item, home=home) for item in value]
    if isinstance(value, tuple):
        return [_sanitize(item, home=home) for item in value]
    if isinstance(value, str):
        return _sanitize_text(value, home=home)
    return value


def _sanitize_text(value: str, *, home: str) -> str:
    result = value.replace(home, "$HOME") if home else value
    return SENSITIVE_TEXT.sub(lambda match: f"{match.group(1) or match.group(2)}[REDACTED]", result)


def _json_text(value: Any) -> str:
    stream = io.StringIO()
    json.dump(value, stream, indent=2, sort_keys=True)
    stream.write("\n")
    return stream.getvalue()
