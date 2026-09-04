from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from orynquix.models import Health
from orynquix.probe import HostProbe, _human_bytes, _read_meminfo
from tests.helpers import FakeRunner


class ProbeTests(unittest.TestCase):
    def test_supported_termux_host(self) -> None:
        runner = FakeRunner()
        with (
            tempfile.TemporaryDirectory() as temporary,
            patch("platform.machine", return_value="aarch64"),
        ):
            probe = HostProbe(
                runner=runner,
                environ={
                    "PREFIX": "/data/data/com.termux/files/usr",
                    "TERMUX_VERSION": "0.119",
                },
                home=Path(temporary),
            )
            report = probe.run(require_runtime=True)
        self.assertTrue(report.supported)
        self.assertNotEqual(report.overall, Health.FAIL)
        self.assertEqual(report.facts["android"]["release"], "15")

    def test_non_termux_host_is_unsupported(self) -> None:
        runner = FakeRunner()
        runner.commands.remove("pkg")
        with patch("platform.machine", return_value="x86_64"):
            report = HostProbe(runner=runner, environ={}, home=Path.home()).run()
        self.assertFalse(report.supported)
        failures = {item.key for item in report.checks if item.health == Health.FAIL}
        self.assertIn("architecture", failures)
        self.assertIn("termux", failures)

    def test_meminfo_and_units(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "meminfo"
            path.write_text("MemTotal: 100 kB\nMemAvailable: 25 kB\n", encoding="utf-8")
            self.assertEqual(_read_meminfo(path)["MemAvailable"], 25 * 1024)
        self.assertEqual(_human_bytes(1024**3), "1.0 GiB")
