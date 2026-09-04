# Development

Run the local quality gate before committing:

```bash
find . -type f \( -name '*.sh' -o -path './bin/orynquix' \) -print0 | xargs -0 -n1 bash -n
shellcheck -x install.sh bin/orynquix lib/*.sh installer/*.sh tests/*.sh
bash tests/run.sh
bash tests/integration-mock.sh
bash tests/provider-compat.sh
bash tests/vnc-session.sh
bash tests/web-session.sh
bash tests/static-safety.sh
```

Use `bash install.sh --dry-run --non-interactive --yes --preset standard` on a non-Termux development host. A dry run may inspect the host but leaves its home directory unchanged.

Device acceptance testing must use a clean, supported Termux installation. Record Android version, architecture, detected memory/storage, `proot-distro` version, actual Ubuntu release, rerun result, interruption recovery, and generated permissions. Never commit passwords, logs containing personal paths, or device identifiers.

After installation on a test device, run `bash tests/device-acceptance.sh`. It starts and stops a desktop only when one was not already running and checks the selected VNC/noVNC listeners. A visual VNC or browser-viewer check, plus Terminal, Files, browser, and selected-editor launch checks, remain mandatory.
