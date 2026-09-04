from __future__ import annotations

import io
import json
import unittest

from orynquix.output import emit


class OutputTests(unittest.TestCase):
    def render(self, value: dict[str, object], *, json_output: bool = False) -> str:
        stream = io.StringIO()
        emit(value, json_output=json_output, stream=stream)
        return stream.getvalue()

    def test_json_output(self) -> None:
        self.assertEqual(
            json.loads(self.render({"ok": True, "value": 3}, json_output=True))["value"], 3
        )

    def test_doctor_and_bootstrap_human_output(self) -> None:
        doctor = self.render(
            {
                "overall": "warn",
                "checks": [
                    {"health": "pass", "summary": "ARM64"},
                    {"health": "warn", "summary": "Audio", "remediation": "Install it"},
                ],
            }
        )
        self.assertIn("[OK] ARM64", doctor)
        self.assertIn("Fix: Install it", doctor)
        bootstrap = self.render(
            {
                "ok": True,
                "confirmation_required": True,
                "steps": [{"complete": False, "description": "Install Debian"}],
            }
        )
        self.assertIn("bootstrap --yes", bootstrap)

    def test_lifecycle_confirmation_error_and_generic_output(self) -> None:
        lifecycle = self.render(
            {
                "ok": False,
                "state": "failed",
                "diagnostic_id": "ORY-X",
                "services": [{"name": "display", "health": "fail", "message": "gone"}],
            }
        )
        self.assertIn("FAILED", lifecycle)
        self.assertIn("ORY-X", lifecycle)
        confirmation = self.render(
            {
                "ok": True,
                "confirmation_required": True,
                "message": "Review first",
                "files": ["a.json"],
                "privacy": "redacted",
            }
        )
        self.assertIn("Review first", confirmation)
        error = self.render(
            {"ok": False, "error": "bad", "diagnostic_id": "ORY-E", "hint": "repair"}
        )
        self.assertIn("Next: repair", error)
        generic = self.render({"ok": True, "name": "Orynquix", "items": ["a"], "data": {"x": 1}})
        self.assertIn("Name: Orynquix", generic)
        self.assertIn("  - a", generic)
