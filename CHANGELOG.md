# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic versioning.

## [Unreleased]

### Added

- Phase 1 modular installer foundation.
- Runtime Android/Termux device detection with honest unavailable states.
- Device-adaptive installation recommendations.
- Guided preset, browser, editor, and development-tool selection.
- Quiet package operation display with stage-level progress and private detailed logs.
- Idempotent verified stage state and safe installer locking.
- Ubuntu provider/rootfs validation and actual release reporting.
- Password-protected standard Ubuntu user and XDG initialization.
- Versioned Termux-side CLI install.
- Unit, dry-run, syntax, and static safety checks.
- Phase 2 XFCE desktop package installation and verification.
- TigerVNC localhost-only session with explicit authentication, display, port, geometry, and startup configuration.
- Managed VNC session registry with PID start-time identity protection.
- Safe start, stop, restart, status, session listing, password, resolution, and VNC log commands.
- Targeted stale X lock, X socket, PID file, and session metadata recovery.
- Mock VNC lifecycle integration tests and direct session safety tests.
- Version-exact V2-to-V3 CLI and Ubuntu marker migration checks.
- PID-reuse-safe forced termination and non-zombie process validation.

### Known limitations

- Requires ARM64 Termux device acceptance testing.
- Requires a real ARM64 Termux acceptance run before `0.2.0-alpha` can be tagged as device-validated.
- Visual identity, application compatibility, Android storage/audio integration, and Control Center remain later phases.
