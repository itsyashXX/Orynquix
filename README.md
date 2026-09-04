# Orynquix

**Ubuntu Desktop, shaped for Android.**

Orynquix is building a polished Ubuntu development environment for Android using Termux, PRoot, XFCE, and TigerVNC—without Android root access.

> Orynquix is an Ubuntu userspace, not an Android ROM, virtual machine, replacement kernel, or Canonical product.

## Current release status

V3.2 (`3.2.0-alpha`) fixes the current `proot-distro` v5 provisioning break while retaining compatibility with the legacy Ubuntu-alias model. It adds real selected-application installation, an original Orynquix XFCE appearance, and a choice of VNC-app, Android-browser, or both access methods.

- runtime device, architecture, CPU, memory, storage, Android, kernel, and Termux detection;
- device-adaptive Lite, Standard, and Developer recommendations;
- a guided Recommended / Complete / Minimal / Developer / Custom selector;
- Chromium / Firefox / Both / Skip selection;
- automatic VS Code / desktop VS Code / code-server / Both / Skip selection;
- a separate coding-tools decision and Recommended / Full / Custom / Skip submenu;
- quiet package operations with truthful verified-stage progress and private detailed logs;
- safe resume state and stale-lock recovery;
- current OCI-image and legacy-alias `proot-distro` discovery, Ubuntu-only provisioning, and actual `/etc/os-release` reporting;
- standard Ubuntu user creation with password-protected `sudo`;
- validated XFCE, terminal, file manager, D-Bus, and supporting desktop packages;
- TigerVNC on the fixed managed display `:1`, bound to localhost by default;
- private VNC password generation with no plaintext password storage or command arguments;
- a generated XFCE xstartup with a fresh D-Bus session and private XDG runtime directory;
- exact PID and process-start identity tracking, safe stale-state recovery, and guarded shutdown;
- an installed Termux-side `orynquix` CLI with desktop lifecycle, `enter`, `info`, `device`, `doctor`, and logs;
- localhost-only noVNC/browser access with its own exact-PID process registry;
- selected Firefox, VS Code, code-server, and development-tool installation with post-install verification;
- a Snap-free Firefox fallback when a compatible Chromium package is unavailable;
- an original Orynquix wallpaper, XFCE theme settings, and real desktop launchers;
- atomic configuration, input validation, nested-PRoot prevention, and zero telemetry.

Android storage/audio integration, Control Center, backup, update, and broader targeted repair commands remain gated. See [current limitations](docs/LIMITATIONS.md).

## Requirements

- Termux from a currently supported source such as F-Droid or GitHub releases—not the obsolete Play Store build;
- Android 12 or newer is the initial test target;
- ARM64 (`aarch64`) is mandatory for the first public device release;
- `x86_64` is experimental where its packages are available;
- at least 4 GiB RAM recommended (3 GiB Lite target);
- at least 8 GiB free storage recommended for later desktop/application phases;
- a stable HTTPS connection.

## Installation

The eventual supported flow is:

```bash
pkg update -y
pkg install git -y
git clone https://github.com/itsyashxx/orynquix.git
cd orynquix
bash install.sh
```

Cloning downloads the repository; it does not execute the installer.

This alpha should first be exercised with a no-change planning run:

```bash
bash install.sh --dry-run --non-interactive --yes --preset standard
```

The installer hides individual package/download lines by default and writes them to `~/.orynquix/logs/install.log`. Use `--verbose` only when you want the underlying package-manager output on screen.

For all installer flags:

```bash
bash install.sh --help
```

## Desktop commands

```bash
orynquix
orynquix start
orynquix stop
orynquix restart
orynquix status
orynquix sessions
orynquix passwd
orynquix resolution 1600x900
orynquix ui-scale 1.25
orynquix theme light
orynquix open
orynquix apps
orynquix install PACKAGE
orynquix remove PACKAGE
orynquix search QUERY
orynquix firefox https://example.com
orynquix code
orynquix code-server
orynquix logs vnc
orynquix logs web
orynquix enter
orynquix info
orynquix device
orynquix doctor
orynquix logs install
orynquix version
orynquix help
```

For VNC-app access, connect to `127.0.0.1:5901` after `orynquix start`. For browser access, run `orynquix open` or open the localhost URL printed by `orynquix start`. Browser access is still VNC transported through a local noVNC/WebSocket proxy; it is not a public web service.

## Documentation

- [Installer choices and quiet output](docs/INSTALLER_UX.md)
- [Architecture](docs/ARCHITECTURE.md)
- [TigerVNC desktop](docs/VNC.md)
- [Applications and compatibility](docs/APPLICATIONS.md)
- [Security design](docs/SECURITY.md)
- [Limitations](docs/LIMITATIONS.md)
- [Development and tests](docs/DEVELOPMENT.md)

## Development

```bash
bash tests/run.sh
bash tests/integration-mock.sh
bash tests/provider-compat.sh
bash tests/vnc-session.sh
bash tests/web-session.sh
bash tests/static-safety.sh
```

GitHub Actions additionally runs Bash syntax checks and ShellCheck. After installing on a real Termux device, run `bash tests/device-acceptance.sh`; a visual VNC/XFCE check still remains mandatory before tagging a device-validated release.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a change. Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License

Orynquix source code is licensed under the [MIT License](LICENSE). Third-party packages keep their own licenses. Orynquix is not affiliated with or endorsed by Canonical Ltd.
