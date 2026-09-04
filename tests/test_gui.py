from __future__ import annotations

import http.client
import io
import json
import os
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from orynquix.errors import OrynquixError
from orynquix.gui import (
    GuiController,
    GuiJobs,
    OrynquixGuiServer,
    load_or_create_gui_token,
    main,
    open_phone_gui,
)
from orynquix.paths import OrynquixPaths


class FakeGuiController:
    def __init__(self) -> None:
        self.actions: list[tuple[str, dict[str, object]]] = []
        self.status_error: OrynquixError | None = None
        self.release: threading.Event | None = None

    def status(self) -> dict[str, object]:
        if self.status_error is not None:
            raise self.status_error
        return {"ok": True, "state": "stopped", "services": []}

    def run_action(self, action: str, payload: dict[str, object]) -> dict[str, object]:
        self.actions.append((action, payload))
        if self.release is not None:
            self.release.wait(timeout=3)
        if action == "expected-error":
            raise OrynquixError("expected failure", diagnostic_id="TEST-GUI-001")
        if action == "value-error":
            raise ValueError("invalid action value")
        if action == "unexpected-error":
            raise RuntimeError("secret internal detail")
        return {"ok": True, "action": action, "payload": payload}


class GuiHttpTests(unittest.TestCase):
    def setUp(self) -> None:
        self.controller = FakeGuiController()
        self.token = "t" * 43
        self.server = OrynquixGuiServer(
            ("127.0.0.1", 0),
            self.controller,
            access_token=self.token,
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.cookie = self._authorize()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def _connection(self) -> http.client.HTTPConnection:
        return http.client.HTTPConnection("127.0.0.1", self.server.port, timeout=3)

    def _authorize(self) -> str:
        connection = self._connection()
        connection.request("GET", f"/launch?token={self.token}")
        response = connection.getresponse()
        response.read()
        self.assertEqual(response.status, 303)
        cookie = response.getheader("Set-Cookie")
        self.assertIsNotNone(cookie)
        connection.close()
        return str(cookie).split(";", 1)[0]

    def _json_request(
        self,
        method: str,
        path: str,
        value: object | None = None,
        *,
        headers: dict[str, str] | None = None,
    ) -> tuple[int, dict[str, object], http.client.HTTPResponse]:
        request_headers = {"Cookie": self.cookie}
        body: str | None = None
        if value is not None:
            body = json.dumps(value)
            request_headers.update(
                {
                    "Content-Type": "application/json",
                    "X-Orynquix-Request": "gui-v1",
                    "Origin": self.server.origin,
                }
            )
        request_headers.update(headers or {})
        connection = self._connection()
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        parsed = json.loads(response.read())
        status = response.status
        connection.close()
        return status, parsed, response

    def _start_job(self, action: str, payload: dict[str, object] | None = None) -> str:
        status, body, _ = self._json_request(
            "POST",
            "/api/jobs",
            {"action": action, "payload": payload or {}},
        )
        self.assertEqual(status, 202)
        return str(body["job_id"])

    def _wait_for_job(self, job_id: str) -> dict[str, object]:
        for _ in range(100):
            status, body, _ = self._json_request("GET", f"/api/jobs/{job_id}")
            self.assertEqual(status, 200)
            if body["state"] in {"succeeded", "failed"}:
                return body
            time.sleep(0.01)
        self.fail("GUI job did not finish")

    def test_auth_assets_status_and_security_headers(self) -> None:
        unauthenticated = self._connection()
        unauthenticated.request("GET", "/")
        response = unauthenticated.getresponse()
        self.assertEqual(response.status, 401)
        response.read()
        unauthenticated.close()

        bad_token = self._connection()
        bad_token.request("GET", "/launch?token=wrong")
        response = bad_token.getresponse()
        self.assertEqual(response.status, 401)
        response.read()
        bad_token.close()

        connection = self._connection()
        connection.request("GET", "/", headers={"Cookie": self.cookie})
        response = connection.getresponse()
        html = response.read().decode()
        self.assertEqual(response.status, 200)
        self.assertIn("Run phone proof", html)
        self.assertIn("default-src 'self'", response.getheader("Content-Security-Policy"))
        connection.close()

        for asset in ("app.css", "app.js", "icon.svg", "manifest.webmanifest"):
            connection = self._connection()
            connection.request("GET", f"/{asset}", headers={"Cookie": self.cookie})
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertTrue(response.read())
            connection.close()

        status, body, _ = self._json_request("GET", "/api/status")
        self.assertEqual(status, 200)
        self.assertEqual(body["state"], "stopped")

        status, _, _ = self._json_request("GET", "/missing")
        self.assertEqual(status, 404)
        status, _, _ = self._json_request("GET", "/api/jobs/missing")
        self.assertEqual(status, 404)

    def test_action_job_success_expected_and_contained_errors(self) -> None:
        succeeded = self._wait_for_job(self._start_job("start", {"sample": 1}))
        self.assertEqual(succeeded["state"], "succeeded")
        self.assertEqual(succeeded["result"]["action"], "start")

        expected = self._wait_for_job(self._start_job("expected-error"))
        self.assertEqual(expected["state"], "failed")
        self.assertEqual(expected["error"]["diagnostic_id"], "TEST-GUI-001")
        self.assertEqual(expected["error"]["message"], "expected failure")

        invalid = self._wait_for_job(self._start_job("value-error"))
        self.assertEqual(invalid["error"]["diagnostic_id"], "ORY-GUI-002")

        contained = self._wait_for_job(self._start_job("unexpected-error"))
        self.assertEqual(contained["error"]["diagnostic_id"], "ORY-GUI-003")
        self.assertNotIn("secret internal detail", json.dumps(contained))

    def test_only_one_job_runs_and_invalid_requests_are_rejected(self) -> None:
        self.controller.release = threading.Event()
        first_id = self._start_job("start")
        status, busy, _ = self._json_request(
            "POST",
            "/api/jobs",
            {"action": "stop", "payload": {}},
        )
        self.assertEqual(status, 409)
        self.assertEqual(busy["active_job_id"], first_id)
        self.controller.release.set()
        self.assertEqual(self._wait_for_job(first_id)["state"], "succeeded")

        cases = (
            ("POST", "/wrong", {"action": "start"}, {}, 404),
            ("POST", "/api/jobs", {"payload": {}}, {}, 400),
            ("POST", "/api/jobs", {"action": "start", "payload": []}, {}, 400),
            (
                "POST",
                "/api/jobs",
                {"action": "start"},
                {"X-Orynquix-Request": "wrong"},
                403,
            ),
            (
                "POST",
                "/api/jobs",
                {"action": "start"},
                {"Origin": "https://attacker.invalid"},
                403,
            ),
        )
        for method, path, value, headers, expected in cases:
            with self.subTest(path=path, expected=expected):
                status, _, _ = self._json_request(method, path, value, headers=headers)
                self.assertEqual(status, expected)

        connection = self._connection()
        connection.request(
            "POST",
            "/api/jobs",
            body="not-json",
            headers={
                "Cookie": self.cookie,
                "Content-Type": "application/json",
                "X-Orynquix-Request": "gui-v1",
                "Origin": self.server.origin,
            },
        )
        response = connection.getresponse()
        self.assertEqual(response.status, 400)
        response.read()
        connection.close()

        connection = self._connection()
        connection.request(
            "POST",
            "/api/jobs",
            body="plain",
            headers={
                "Cookie": self.cookie,
                "Content-Type": "text/plain",
                "X-Orynquix-Request": "gui-v1",
                "Origin": self.server.origin,
            },
        )
        response = connection.getresponse()
        self.assertEqual(response.status, 415)
        response.read()
        connection.close()

    def test_host_and_status_errors_are_contained(self) -> None:
        connection = self._connection()
        connection.putrequest("GET", "/", skip_host=True)
        connection.putheader("Host", "attacker.invalid")
        connection.endheaders()
        response = connection.getresponse()
        self.assertEqual(response.status, 403)
        response.read()
        connection.close()

        self.controller.status_error = OrynquixError("bad state", diagnostic_id="TEST-STATUS")
        status, body, _ = self._json_request("GET", "/api/status")
        self.assertEqual(status, 409)
        self.assertEqual(body["message"], "bad state")


class GuiLogicTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.paths = OrynquixPaths(
            base / "config",
            base / "data",
            base / "state",
            base / "cache",
            base / "projects",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_controller_routes_every_gui_action(self) -> None:
        lifecycle = MagicMock()
        lifecycle.status.return_value = {"state": "stopped"}
        lifecycle.start.return_value = {"state": "running"}
        lifecycle.stop.return_value = {"state": "stopped"}
        lifecycle.repair.return_value = {"state": "stopped"}
        probe = MagicMock()
        probe.run.return_value.to_dict.return_value = {"supported": True}
        bootstrap = MagicMock()
        bootstrap.apply.return_value = {"ok": True, "changed": True}
        proof = MagicMock()
        proof.run.return_value = {"ok": True, "report": {"completed_cycles": 5}}

        with (
            patch("orynquix.gui.LifecycleManager", return_value=lifecycle),
            patch("orynquix.gui.HostProbe", return_value=probe),
            patch("orynquix.gui.BootstrapManager", return_value=bootstrap),
            patch("orynquix.gui.ProofRunner", return_value=proof),
        ):
            controller = GuiController(self.paths)
            self.assertEqual(controller.status()["state"], "stopped")
            self.assertEqual(controller.run_action("status", {})["state"], "stopped")
            self.assertTrue(controller.run_action("doctor", {})["supported"])
            self.assertTrue(controller.run_action("setup", {})["ok"])
            self.assertEqual(controller.run_action("start", {})["state"], "running")
            self.assertEqual(controller.run_action("stop", {})["state"], "stopped")
            self.assertEqual(controller.run_action("repair", {})["state"], "stopped")
            self.assertTrue(controller.run_action("phone-proof", {"cycles": 5})["ok"])
            proof.run.assert_called_once_with(cycles=5, confirmed=True)
            bootstrap.apply.assert_called_once_with(confirmed=True)
            lifecycle.repair.assert_called_once_with(confirmed=True)

            for invalid in (True, 0, 11, "5"):
                with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                    controller.run_action("phone-proof", {"cycles": invalid})
            with self.assertRaises(ValueError):
                controller.run_action("not-real", {})

    def test_token_is_private_persistent_and_invalid_token_is_rejected(self) -> None:
        first = load_or_create_gui_token(self.paths)
        second = load_or_create_gui_token(self.paths)
        self.assertEqual(first, second)
        self.assertGreaterEqual(len(first), 32)
        self.assertEqual(self.paths.gui_token_file.stat().st_mode & 0o777, 0o600)

        self.paths.gui_token_file.write_text("short", encoding="ascii")
        with self.assertRaises(OrynquixError):
            load_or_create_gui_token(self.paths)

    def test_jobs_expose_missing_job(self) -> None:
        jobs = GuiJobs(FakeGuiController())
        self.assertIsNone(jobs.get("missing"))

    def test_server_refuses_non_loopback(self) -> None:
        with self.assertRaises(ValueError):
            OrynquixGuiServer(("0.0.0.0", 0), FakeGuiController(), access_token="x" * 40)

    def test_browser_openers_and_main_shutdown(self) -> None:
        completed = MagicMock(returncode=0)
        with (
            patch(
                "orynquix.gui.shutil.which",
                side_effect=lambda name: "/bin/open" if name == "termux-open-url" else None,
            ),
            patch("orynquix.gui.subprocess.run", return_value=completed) as run,
        ):
            self.assertTrue(open_phone_gui("http://127.0.0.1:1/launch"))
            run.assert_called_once()

        with (
            patch("orynquix.gui.shutil.which", return_value=None),
            patch("orynquix.gui.webbrowser.open", return_value=True),
        ):
            self.assertTrue(open_phone_gui("http://127.0.0.1:1/launch"))

        output = io.StringIO()
        with (
            patch.dict(os.environ, {"ORYNQUIX_HOME": str(self.paths.data_dir / "gui-home")}),
            patch("orynquix.gui.OrynquixGuiServer.serve_forever", side_effect=KeyboardInterrupt),
        ):
            result = main(
                ("--port", "0", "--no-open"),
                stdout=output,
                controller=FakeGuiController(),
            )
            self.assertEqual(result, 0)
        self.assertIn("Orynquix phone GUI is ready", output.getvalue())

        with self.assertRaises(SystemExit):
            main(
                ("--port", "70000", "--no-open"),
                stdout=io.StringIO(),
                controller=FakeGuiController(),
            )


if __name__ == "__main__":
    unittest.main()
