"""Orynquix command-line control plane."""

from __future__ import annotations

import argparse
import os
import sys
import traceback
from collections.abc import Sequence
from dataclasses import replace
from pathlib import Path
from typing import Any, TextIO

from orynquix import __version__
from orynquix.bootstrap import BootstrapManager
from orynquix.config import load_settings, save_settings
from orynquix.diagnostics import SupportBundle
from orynquix.errors import ExitCode, OrynquixError
from orynquix.lifecycle import LifecycleManager
from orynquix.models import Health
from orynquix.output import emit
from orynquix.paths import OrynquixPaths
from orynquix.probe import HostProbe
from orynquix.proof import ProofRunner
from orynquix.uninstall import Uninstaller


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="orynquix",
        description="Control a persistent no-root Linux workstation alongside Android.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    commands = parser.add_subparsers(dest="command", required=True)

    doctor = commands.add_parser("doctor", help="Run read-only host and runtime checks")
    _json_flag(doctor)
    doctor.add_argument(
        "--runtime",
        action="store_true",
        help="Treat installed runtime components as required",
    )
    doctor.add_argument("--strict", action="store_true", help="Return a non-zero code for warnings")

    bootstrap = commands.add_parser(
        "bootstrap", help="Plan or apply the idempotent Debian/XFCE installation"
    )
    _json_flag(bootstrap)
    bootstrap.add_argument(
        "--yes", action="store_true", help="Confirm package and rootfs installation"
    )

    configure = commands.add_parser("configure", help="Show or update safe Stage 1 settings")
    _json_flag(configure)
    shared = configure.add_mutually_exclusive_group()
    shared.add_argument(
        "--shared-directory",
        type=Path,
        help="Expose exactly this approved Android folder as /mnt/orynquix-share",
    )
    shared.add_argument(
        "--clear-shared-directory",
        action="store_true",
        help="Remove the Android shared-folder mapping",
    )
    audio = configure.add_mutually_exclusive_group()
    audio.add_argument("--enable-audio", action="store_true")
    audio.add_argument("--disable-audio", action="store_true")

    for name, help_text in (
        ("start", "Start Termux:X11 and the XFCE guest session"),
        ("status", "Report real dependency and process health"),
        ("stop", "Stop identity-verified Orynquix processes in reverse order"),
    ):
        command = commands.add_parser(name, help=help_text)
        _json_flag(command)

    repair = commands.add_parser("repair", help="Recover stale or invalid lifecycle state")
    _json_flag(repair)
    repair.add_argument("--yes", action="store_true", help="Confirm safe recovery actions")

    proof = commands.add_parser("proof", help="Run repeatable Stage 1 device acceptance cycles")
    _json_flag(proof)
    proof.add_argument("--cycles", type=int, default=5)
    proof.add_argument("--yes", action="store_true", help="Confirm repeated desktop starts")

    bundle = commands.add_parser(
        "support-bundle", help="Preview or create a redacted diagnostic archive"
    )
    _json_flag(bundle)
    bundle.add_argument("--yes", action="store_true", help="Create the reviewed archive")
    bundle.add_argument("--output", type=Path)

    uninstall = commands.add_parser(
        "uninstall", help="Remove Stage 1 control data while preserving projects"
    )
    _json_flag(uninstall)
    uninstall.add_argument("--yes", action="store_true", help="Confirm controlled removal")
    uninstall.add_argument(
        "--remove-rootfs",
        action="store_true",
        help="Also remove Debian only when Orynquix proves it created that rootfs",
    )

    paths = commands.add_parser("paths", help="Show system-data and preserved-project locations")
    _json_flag(paths)
    return parser


def main(
    argv: Sequence[str] | None = None,
    *,
    stdout: TextIO | None = None,
    stderr: TextIO | None = None,
) -> int:
    output = stdout or sys.stdout
    error_output = stderr or sys.stderr
    args = build_parser().parse_args(argv)
    json_output = bool(getattr(args, "json", False))
    paths = OrynquixPaths.discover()
    try:
        result, code = _dispatch(args, paths)
        emit(result, json_output=json_output, stream=output)
        return int(code)
    except OrynquixError as exc:
        emit(exc.to_dict(), json_output=json_output, stream=error_output)
        return int(exc.exit_code)
    except KeyboardInterrupt:
        cancellation = OrynquixError(
            "operation cancelled",
            diagnostic_id="ORY-CLI-001",
            exit_code=ExitCode.OPERATION_FAILED,
        )
        emit(cancellation.to_dict(), json_output=json_output, stream=error_output)
        return int(cancellation.exit_code)
    except Exception as exc:  # pragma: no cover - final containment boundary
        wrapped = OrynquixError(
            f"unexpected internal error: {type(exc).__name__}",
            diagnostic_id="ORY-INT-001",
            exit_code=ExitCode.INTERNAL_ERROR,
            hint="Create a support bundle and report the diagnostic identifier.",
        )
        emit(wrapped.to_dict(), json_output=json_output, stream=error_output)
        if os.environ.get("ORYNQUIX_DEBUG") == "1":
            traceback.print_exc(file=error_output)
        return int(wrapped.exit_code)


def _dispatch(args: argparse.Namespace, paths: OrynquixPaths) -> tuple[dict[str, Any], ExitCode]:
    if args.command == "doctor":
        report = HostProbe().run(require_runtime=bool(args.runtime))
        result = report.to_dict()
        if not report.supported:
            return result, ExitCode.UNSUPPORTED_HOST
        if args.strict and report.overall == Health.WARN:
            return result, ExitCode.DEGRADED
        return result, ExitCode.OK

    if args.command == "bootstrap":
        result = BootstrapManager(paths).apply(confirmed=bool(args.yes))
        return result, ExitCode.OK

    if args.command == "configure":
        settings = load_settings(paths)
        changed = False
        if args.shared_directory is not None:
            settings = replace(settings, shared_directory=args.shared_directory)
            changed = True
        elif args.clear_shared_directory:
            settings = replace(settings, shared_directory=None)
            changed = True
        if args.enable_audio:
            settings = replace(settings, audio_enabled=True)
            changed = True
        elif args.disable_audio:
            settings = replace(settings, audio_enabled=False)
            changed = True
        settings = settings.validate()
        if changed:
            save_settings(paths, settings)
        return {"ok": True, "changed": changed, "settings": settings.to_dict()}, ExitCode.OK

    lifecycle = LifecycleManager(paths)
    if args.command == "start":
        return lifecycle.start(), ExitCode.OK
    if args.command == "status":
        result = lifecycle.status()
        code = ExitCode.OK if result["state"] != "failed" else ExitCode.OPERATION_FAILED
        return result, code
    if args.command == "stop":
        return lifecycle.stop(), ExitCode.OK
    if args.command == "repair":
        return lifecycle.repair(confirmed=bool(args.yes)), ExitCode.OK
    if args.command == "proof":
        result = ProofRunner(paths, lifecycle=lifecycle).run(
            cycles=args.cycles, confirmed=bool(args.yes)
        )
        return result, ExitCode.OK if result.get("ok") else ExitCode.OPERATION_FAILED
    if args.command == "support-bundle":
        bundle = SupportBundle(paths)
        if not args.yes:
            return bundle.preview(), ExitCode.OK
        return bundle.create(args.output), ExitCode.OK
    if args.command == "uninstall":
        result = Uninstaller(paths, lifecycle=lifecycle).run(
            confirmed=bool(args.yes), remove_rootfs=bool(args.remove_rootfs)
        )
        return result, ExitCode.OK
    if args.command == "paths":
        return {
            "ok": True,
            "configuration": str(paths.config_dir),
            "system_data": str(paths.data_dir),
            "runtime_state": str(paths.state_dir),
            "cache": str(paths.cache_dir),
            "preserved_projects": str(paths.projects_dir),
        }, ExitCode.OK
    raise AssertionError(f"unhandled command: {args.command}")


def _json_flag(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--json", action="store_true", help="Emit stable JSON output")
