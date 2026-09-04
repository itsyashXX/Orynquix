"""Human and machine-readable output without hidden side effects."""

from __future__ import annotations

import json
from typing import Any, TextIO


def emit(value: dict[str, Any], *, json_output: bool, stream: TextIO) -> None:
    if json_output:
        json.dump(value, stream, indent=2, sort_keys=True, default=str)
        stream.write("\n")
        return
    rendered = _human(value)
    stream.write(rendered)
    if not rendered.endswith("\n"):
        stream.write("\n")


def _human(value: dict[str, Any]) -> str:
    if "checks" in value:
        lines = [
            f"Orynquix doctor: {str(value.get('overall', 'unknown')).upper()}",
            "",
        ]
        icons = {"pass": "[OK]", "warn": "[!!]", "fail": "[XX]", "skip": "[--]"}
        for check in value["checks"]:
            health = str(check.get("health", "unknown"))
            lines.append(f"{icons.get(health, '[??]')} {check.get('summary', check.get('key'))}")
            if check.get("remediation"):
                lines.append(f"     Fix: {check['remediation']}")
        return "\n".join(lines)

    if "steps" in value:
        lines = ["Orynquix bootstrap plan", ""]
        for step in value["steps"]:
            status = "ready" if step.get("complete") else "pending"
            lines.append(f"[{status:7}] {step.get('description', step.get('key'))}")
        if value.get("confirmation_required"):
            lines.extend(("", "Run `orynquix bootstrap --yes` to apply this plan."))
        elif value.get("ok"):
            lines.extend(("", "Bootstrap is complete."))
        return "\n".join(lines)

    if "state" in value:
        lines = [f"Orynquix session: {str(value['state']).upper()}"]
        for service in value.get("services", []):
            lines.append(
                f"  - {service.get('name')}: {service.get('health')} — {service.get('message')}"
            )
        if value.get("diagnostic_id"):
            lines.append(f"Diagnostic: {value['diagnostic_id']}")
        if value.get("projects_preserved_at"):
            lines.append(f"Projects preserved at: {value['projects_preserved_at']}")
        return "\n".join(lines)

    if value.get("confirmation_required"):
        lines = [str(value.get("message", "Confirmation required."))]
        if value.get("files"):
            lines.append("Included files: " + ", ".join(str(item) for item in value["files"]))
        if value.get("privacy"):
            lines.append(str(value["privacy"]))
        return "\n".join(lines)

    if not value.get("ok", True):
        lines = [f"Error: {value.get('error', 'operation failed')}"]
        if value.get("diagnostic_id"):
            lines.append(f"Diagnostic: {value['diagnostic_id']}")
        if value.get("hint"):
            lines.append(f"Next: {value['hint']}")
        return "\n".join(lines)

    lines = []
    for key, item in value.items():
        if key == "ok":
            continue
        label = key.replace("_", " ").capitalize()
        if isinstance(item, list):
            lines.append(f"{label}:")
            lines.extend(f"  - {entry}" for entry in item)
        elif isinstance(item, dict):
            lines.append(f"{label}: {json.dumps(item, default=str)}")
        else:
            lines.append(f"{label}: {item}")
    return "\n".join(lines) or "Done."
