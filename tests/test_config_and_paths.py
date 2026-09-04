from __future__ import annotations

import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from orynquix.config import Settings, load_settings, save_settings, write_default_settings
from orynquix.errors import OrynquixError
from orynquix.paths import OrynquixPaths


class ConfigAndPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.paths = OrynquixPaths(
            base / "config", base / "data", base / "state", base / "cache", base / "projects"
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_default_config_is_write_once_and_loads(self) -> None:
        self.assertTrue(write_default_settings(self.paths))
        self.assertFalse(write_default_settings(self.paths))
        self.assertEqual(load_settings(self.paths), Settings())

    def test_config_round_trip_with_explicit_share(self) -> None:
        share = Path(self.temporary.name) / "android-share"
        share.mkdir()
        settings = replace(Settings(), shared_directory=share, audio_enabled=False)
        save_settings(self.paths, settings)
        loaded = load_settings(self.paths)
        self.assertEqual(loaded.shared_directory, share.resolve())
        self.assertFalse(loaded.audio_enabled)

    def test_home_share_and_telemetry_are_rejected(self) -> None:
        with self.assertRaises(OrynquixError):
            replace(Settings(), shared_directory=Path.home()).validate()
        with self.assertRaises(OrynquixError):
            replace(Settings(), telemetry_enabled=True).validate()

    def test_destructive_guard_protects_projects_and_unknown_paths(self) -> None:
        with self.assertRaises(OrynquixError):
            self.paths.assert_safe_controlled_path(self.paths.projects_dir)
        with self.assertRaises(OrynquixError):
            self.paths.assert_safe_controlled_path(Path(self.temporary.name) / "unknown")
        self.assertEqual(
            self.paths.assert_safe_controlled_path(self.paths.cache_dir),
            self.paths.cache_dir.resolve(),
        )
