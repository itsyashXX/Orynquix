# Installer output and component choices

## Default output

Orynquix intentionally keeps `apt`, `pkg`, download, extraction, and package-name chatter out of the normal installer display. The terminal shows only:

- the current verified stage;
- overall stage position and percentage;
- elapsed time for a long-running operation;
- a success, warning, skipped, running, or failed state;
- the detailed log location.

The displayed percentage is based on completed installer stages. It is not presented as byte-download progress because neither `pkg` nor every supported `apt` version provides one stable machine-readable progress interface. A stage advances only after its verifier succeeds.

Use `bash install.sh --verbose` to stream underlying package-manager output. Regardless of display mode, output is written to `~/.orynquix/logs/install.log`, with mode `0600`.

## Guided choices

The initial selector offers:

1. **Recommended** — selects a device-aware Lite, Standard, or Developer profile.
2. **Complete** — installs every optional component offered by the current installer.
3. **Minimal** — installs the desktop essentials and skips optional applications.
4. **Developer** — includes the full supported development bundle.
5. **Custom** — asks about each optional category.

Every interactive installation asks how the desktop should be opened: a VNC app, the Android browser through local noVNC, or both. Custom browser choices are Chromium, Firefox, both, or skip. Ubuntu's Chromium path normally requires Snap, which standard PRoot cannot provide; in that case Orynquix records and verifies a Firefox fallback instead of claiming Chromium succeeded. Editor choices are automatic compatibility selection, VS Code desktop, code-server, both, or skip. Development tools have a separate yes/no gate followed by Recommended, Full, Custom, or Skip.

Selections are persisted in `~/.orynquix/config.ini` and validated before use. Re-run with `--reconfigure` to ask again.

## Automation

Example:

```bash
bash install.sh \
  --non-interactive \
  --yes \
  --preset custom \
  --browser both \
  --editor auto \
  --dev-tools custom:git,python,node \
  --viewer both \
  --username orynquix
```

A new standard Linux user and initial TigerVNC authentication both require passwords. Non-interactive automation must pass them through already-open file descriptors with `--linux-password-fd N` and `--vnc-password-fd N`; passwords are never accepted as command-line values.
