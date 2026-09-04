from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from orynquix.cli import main
from orynquix.config import write_default_settings
from orynquix.diagnostics import SupportBundle
from orynquix.paths import OrynquixPaths
from orynquix.state import write_json_atomic
from tests.helpers import PassingProbe


class DiagnosticsAndCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.paths = OrynquixPaths(
            self.base / "config",
            self.base / "data",
            self.base / "state",
            self.base / "cache",
            self.base / "projects",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_support_bundle_preview_and_redaction(self) -> None:
        write_default_settings(self.paths)
        write_json_atomic(
            self.paths.bootstrap_file,
            {
                "schema_version": 1,
                "status": "complete",
                "updated_at": "2026-09-02T00:00:00+00:00",
                "rootfs_created_by_orynquix": True,
                "api_token": "secret-value",
            },
        )
        bundle = SupportBundle(self.paths, probe=PassingProbe())
        self.assertTrue(bundle.preview()["confirmation_required"])
        result = bundle.create(self.base / "support.zip")
        self.assertTrue(result["review_before_sharing"])
        with zipfile.ZipFile(result["path"]) as archive:
            bootstrap = archive.read("bootstrap.json").decode()
        self.assertIn("[REDACTED]", bootstrap)
        self.assertNotIn("secret-value", bootstrap)

    def test_cli_paths_json(self) -> None:
        output = io.StringIO()
        error = io.StringIO()
        with patch.dict(os.environ, {"ORYNQUIX_HOME": str(self.base / "home")}):
            code = main(("paths", "--json"), stdout=output, stderr=error)
        self.assertEqual(code, 0)
        self.assertEqual(error.getvalue(), "")
        value = json.loads(output.getvalue())
        self.assertIn("preserved_projects", value)

    def test_cli_expected_error_is_structured(self) -> None:
        output = io.StringIO()
        error = io.StringIO()
        with patch.dict(os.environ, {"ORYNQUIX_HOME": str(self.base / "home")}):
            code = main(
                ("configure", "--shared-directory", str(self.base / "missing"), "--json"),
                stdout=output,
                stderr=error,
            )
        self.assertNotEqual(code, 0)
        self.assertEqual(json.loads(error.getvalue())["diagnostic_id"], "ORY-CONFIG-007")
