"""Touch-first local GUI for the Orynquix phone workstation.

The GUI is served only on loopback and controls the same typed, journaled
operations as the recovery CLI.  It intentionally uses the Python standard
library so a supported Termux installation does not need a browser framework
or a public network listener.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys
import threading
import uuid
import webbrowser
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from http import HTTPStatus
from http.cookies import CookieError, SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from importlib.resources import files
from pathlib import Path
from typing import Any, Protocol, TextIO
from urllib.parse import parse_qs, urlencode, urlparse

from orynquix.bootstrap import BootstrapManager
from orynquix.errors import OrynquixError
from orynquix.lifecycle import LifecycleManager
from orynquix.paths import OrynquixPaths
from orynquix.probe import HostProbe
from orynquix.proof import ProofRunner

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
MAX_REQUEST_BYTES = 8_192
ASSET_TYPES = {
    ".css": "text/css; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".svg": "image/svg+xml; charset=utf-8",
    ".webmanifest": "application/manifest+json; charset=utf-8",
}


class ActionController(Protocol):
    """Operations exposed to the local GUI server."""

    def status(self) -> dict[str, Any]: ...

    def run_action(self, action: str, payload: Mapping[str, Any]) -> dict[str, Any]: ...


class GuiController:
    """Translate user-facing GUI actions into safe control-plane calls."""

    def __init__(self, paths: OrynquixPaths) -> None:
        self.paths = paths

    def status(self) -> dict[str, Any]:
        return LifecycleManager(self.paths).status()

    def run_action(self, action: str, payload: Mapping[str, Any]) -> dict[str, Any]:
        lifecycle = LifecycleManager(self.paths)
        if action == "status":
            return lifecycle.status()
        if action == "doctor":
            return HostProbe().run(require_runtime=True).to_dict()
        if action == "setup":
            return BootstrapManager(self.paths).apply(confirmed=True)
        if action == "start":
            return lifecycle.start()
        if action == "stop":
            return lifecycle.stop()
        if action == "repair":
            return lifecycle.repair(confirmed=True)
        if action == "phone-proof":
            cycles = payload.get("cycles", 5)
            if isinstance(cycles, bool) or not isinstance(cycles, int) or not 1 <= cycles <= 10:
                raise ValueError("phone proof cycles must be an integer from 1 to 10")
            return ProofRunner(self.paths, lifecycle=lifecycle).run(
                cycles=cycles,
                confirmed=True,
            )
        raise ValueError(f"unknown GUI action: {action}")


@dataclass(slots=True)
class GuiJob:
    job_id: str
    action: str
    state: str = "queued"
    result: dict[str, Any] | None = None
    error: dict[str, Any] | None = None
    _thread: threading.Thread | None = field(default=None, repr=False)

    def to_dict(self) -> dict[str, Any]:
        value: dict[str, Any] = {
            "job_id": self.job_id,
            "action": self.action,
            "state": self.state,
        }
        if self.result is not None:
            value["result"] = self.result
        if self.error is not None:
            value["error"] = self.error
        return value


class GuiJobs:
    """Run one mutating GUI operation at a time without blocking HTTP polling."""

    def __init__(self, controller: ActionController) -> None:
        self.controller = controller
        self._jobs: dict[str, GuiJob] = {}
        self._active_job_id: str | None = None
        self._lock = threading.Lock()

    def start(self, action: str, payload: Mapping[str, Any]) -> GuiJob:
        with self._lock:
            if self._active_job_id is not None:
                active = self._jobs[self._active_job_id]
                if active.state in {"queued", "running"}:
                    raise GuiBusyError(active.job_id)
            job = GuiJob(job_id=str(uuid.uuid4()), action=action)
            self._jobs[job.job_id] = job
            self._active_job_id = job.job_id
            job._thread = threading.Thread(
                target=self._run,
                args=(job, dict(payload)),
                daemon=True,
                name=f"orynquix-gui-{action}",
            )
            job._thread.start()
            return job

    def get(self, job_id: str) -> GuiJob | None:
        with self._lock:
            return self._jobs.get(job_id)

    def _run(self, job: GuiJob, payload: Mapping[str, Any]) -> None:
        with self._lock:
            job.state = "running"
        try:
            result = self.controller.run_action(job.action, payload)
        except OrynquixError as exc:
            with self._lock:
                job.state = "failed"
                job.error = {**exc.to_dict(), "message": exc.message}
        except (TypeError, ValueError) as exc:
            with self._lock:
                job.state = "failed"
                job.error = {
                    "ok": False,
                    "message": str(exc),
                    "diagnostic_id": "ORY-GUI-002",
                }
        except Exception as exc:  # pragma: no cover - final containment boundary
            with self._lock:
                job.state = "failed"
                job.error = {
                    "ok": False,
                    "message": f"unexpected GUI operation error: {type(exc).__name__}",
                    "diagnostic_id": "ORY-GUI-003",
                }
        else:
            with self._lock:
                job.state = "succeeded"
                job.result = result
        finally:
            with self._lock:
                if self._active_job_id == job.job_id:
                    self._active_job_id = None


class GuiBusyError(RuntimeError):
    def __init__(self, job_id: str) -> None:
        super().__init__("another Orynquix operation is still running")
        self.job_id = job_id


class OrynquixGuiServer(ThreadingHTTPServer):
    """Authenticated loopback HTTP server for the phone GUI."""

    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        address: tuple[str, int],
        controller: ActionController,
        *,
        access_token: str,
    ) -> None:
        if address[0] not in {"127.0.0.1", "localhost"}:
            raise ValueError("the Orynquix GUI may bind only to loopback")
        self.access_token = access_token
        self.jobs = GuiJobs(controller)
        self.assets_root = files("orynquix").joinpath("gui_assets")
        super().__init__(address, OrynquixGuiRequestHandler)

    @property
    def port(self) -> int:
        return int(self.server_address[1])

    @property
    def origin(self) -> str:
        return f"http://{DEFAULT_HOST}:{self.port}"

    @property
    def launch_url(self) -> str:
        return f"{self.origin}/launch?{urlencode({'token': self.access_token})}"


class OrynquixGuiRequestHandler(BaseHTTPRequestHandler):
    server: OrynquixGuiServer
    server_version = "OrynquixGUI/1"
    sys_version = ""

    def do_GET(self) -> None:
        if not self._host_allowed():
            self._json(HTTPStatus.FORBIDDEN, {"ok": False, "message": "invalid host"})
            return
        parsed = urlparse(self.path)
        if parsed.path == "/launch":
            token = parse_qs(parsed.query).get("token", [""])[0]
            if not secrets.compare_digest(token, self.server.access_token):
                self._json(HTTPStatus.UNAUTHORIZED, {"ok": False, "message": "invalid token"})
                return
            self.send_response(HTTPStatus.SEE_OTHER)
            self._security_headers()
            self.send_header(
                "Set-Cookie",
                f"orynquix_session={self.server.access_token}; HttpOnly; SameSite=Strict; Path=/",
            )
            self.send_header("Location", "/")
            self.end_headers()
            return
        if not self._authorized():
            self._json(HTTPStatus.UNAUTHORIZED, {"ok": False, "message": "open the GUI launcher"})
            return
        if parsed.path == "/api/status":
            try:
                result = self.server.jobs.controller.status()
            except OrynquixError as exc:
                self._json(HTTPStatus.CONFLICT, {**exc.to_dict(), "message": exc.message})
            except Exception as exc:  # pragma: no cover - final containment boundary
                self._json(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    {
                        "ok": False,
                        "message": f"status unavailable: {type(exc).__name__}",
                        "diagnostic_id": "ORY-GUI-004",
                    },
                )
            else:
                self._json(HTTPStatus.OK, result)
            return
        if parsed.path.startswith("/api/jobs/"):
            job_id = parsed.path.removeprefix("/api/jobs/")
            job = self.server.jobs.get(job_id)
            if job is None:
                self._json(HTTPStatus.NOT_FOUND, {"ok": False, "message": "job not found"})
            else:
                self._json(HTTPStatus.OK, job.to_dict())
            return
        self._asset(parsed.path)

    def do_POST(self) -> None:
        if not self._host_allowed() or not self._authorized() or not self._origin_allowed():
            self._json(HTTPStatus.FORBIDDEN, {"ok": False, "message": "request rejected"})
            return
        if self.headers.get("X-Orynquix-Request") != "gui-v1":
            self._json(HTTPStatus.FORBIDDEN, {"ok": False, "message": "request marker missing"})
            return
        if urlparse(self.path).path != "/api/jobs":
            self._json(HTTPStatus.NOT_FOUND, {"ok": False, "message": "not found"})
            return
        content_type = self.headers.get("Content-Type", "").split(";", 1)[0]
        if content_type != "application/json":
            self._json(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, {"ok": False, "message": "JSON required"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = -1
        if length < 0 or length > MAX_REQUEST_BYTES:
            self._json(
                HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                {"ok": False, "message": "invalid size"},
            )
            return
        try:
            body = json.loads(self.rfile.read(length))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "message": "invalid JSON"})
            return
        if not isinstance(body, dict) or not isinstance(body.get("action"), str):
            self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "message": "action is required"})
            return
        payload = body.get("payload", {})
        if not isinstance(payload, dict):
            self._json(HTTPStatus.BAD_REQUEST, {"ok": False, "message": "invalid payload"})
            return
        try:
            job = self.server.jobs.start(body["action"], payload)
        except GuiBusyError as exc:
            self._json(
                HTTPStatus.CONFLICT,
                {"ok": False, "message": str(exc), "active_job_id": exc.job_id},
            )
        else:
            self._json(HTTPStatus.ACCEPTED, job.to_dict())

    def log_message(self, format: str, *args: object) -> None:
        return

    def _asset(self, path: str) -> None:
        requested = "index.html" if path in {"", "/"} else path.lstrip("/")
        allowed = {
            "app.css",
            "app.js",
            "icon.svg",
            "index.html",
            "manifest.webmanifest",
            "service-worker.js",
        }
        if requested not in allowed:
            self._json(HTTPStatus.NOT_FOUND, {"ok": False, "message": "not found"})
            return
        asset = self.server.assets_root.joinpath(requested)
        try:
            data = asset.read_bytes()
        except (FileNotFoundError, OSError):
            self._json(HTTPStatus.NOT_FOUND, {"ok": False, "message": "asset missing"})
            return
        content_type = ASSET_TYPES.get(Path(requested).suffix, "application/octet-stream")
        self.send_response(HTTPStatus.OK)
        self._security_headers()
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header(
            "Cache-Control",
            "no-store" if requested == "index.html" else "private, max-age=3600",
        )
        self.end_headers()
        self.wfile.write(data)

    def _json(self, status: HTTPStatus, value: Mapping[str, Any]) -> None:
        data = json.dumps(value, separators=(",", ":"), default=str).encode("utf-8")
        self.send_response(status)
        self._security_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _security_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; connect-src 'self'; img-src 'self' data:; "
            "style-src 'self'; script-src 'self'; object-src 'none'; "
            "base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
        )

    def _host_allowed(self) -> bool:
        host = self.headers.get("Host", "")
        return host in {f"127.0.0.1:{self.server.port}", f"localhost:{self.server.port}"}

    def _origin_allowed(self) -> bool:
        origin = self.headers.get("Origin")
        return origin is None or origin == self.server.origin

    def _authorized(self) -> bool:
        raw = self.headers.get("Cookie", "")
        cookie = SimpleCookie()
        try:
            cookie.load(raw)
        except CookieError:
            return False
        session = cookie.get("orynquix_session")
        return session is not None and secrets.compare_digest(
            session.value,
            self.server.access_token,
        )


def load_or_create_gui_token(paths: OrynquixPaths) -> str:
    """Return the private, persistent browser token used by the local GUI."""
    paths.ensure_control_dirs()
    token_file = paths.gui_token_file
    try:
        token = token_file.read_text(encoding="ascii").strip()
    except FileNotFoundError:
        token = secrets.token_urlsafe(32)
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        try:
            descriptor = os.open(token_file, flags, 0o600)
        except FileExistsError:
            token = token_file.read_text(encoding="ascii").strip()
        else:
            with os.fdopen(descriptor, "w", encoding="ascii") as stream:
                stream.write(token)
    token_file.chmod(0o600)
    if len(token) < 32:
        raise OrynquixError(
            "the local GUI token is invalid",
            diagnostic_id="ORY-GUI-001",
            hint="Remove only the Orynquix GUI token file, then relaunch the interface.",
        )
    return token


def open_phone_gui(url: str) -> bool:
    """Open the authenticated loopback URL with the Android or host browser."""
    termux_open = shutil.which("termux-open-url")
    if termux_open is not None:
        result = subprocess.run((termux_open, url), check=False, timeout=10)
        return result.returncode == 0
    android_am = shutil.which("am")
    if android_am is not None and os.environ.get("PREFIX", "").startswith("/data/data/com.termux"):
        result = subprocess.run(
            (android_am, "start", "-a", "android.intent.action.VIEW", "-d", url),
            check=False,
            timeout=10,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return result.returncode == 0
    return bool(webbrowser.open(url, new=1))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="orynquix-gui",
        description="Open the touch-first Orynquix phone interface.",
    )
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--no-open", action="store_true", help=argparse.SUPPRESS)
    return parser


def main(
    argv: Sequence[str] | None = None,
    *,
    stdout: TextIO | None = None,
    controller: ActionController | None = None,
) -> int:
    args = build_parser().parse_args(argv)
    if not 0 <= args.port <= 65_535:
        build_parser().error("--port must be from 0 to 65535")
    output = stdout or sys.stdout
    paths = OrynquixPaths.discover()
    token = load_or_create_gui_token(paths)
    server = OrynquixGuiServer(
        (DEFAULT_HOST, args.port),
        controller or GuiController(paths),
        access_token=token,
    )
    opened = args.no_open or open_phone_gui(server.launch_url)
    print(f"Orynquix phone GUI is ready at {server.origin}", file=output, flush=True)
    if not opened:
        print(f"Open this one-time launch URL: {server.launch_url}", file=output, flush=True)
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
