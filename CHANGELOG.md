# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic versioning.

## [Unreleased]

## [3.2.0-alpha] - 2026-09-04

### Fixed

- Detects the current OCI-based `proot-distro` v5 interface even when `proot-distro list` advertises no Ubuntu alias.
- Provisions current releases as a named `ubuntu:24.04` container while keeping the legacy `ubuntu` alias path.
- Preserves and resumes verified installation state from the earlier `0.2.1-alpha` build.

### Added

- VNC app, Android browser/noVNC, or combined desktop-access selection.
- Localhost-only noVNC proxy with PID/start-time ownership validation and safe stale-state recovery.
- Real Firefox, VS Code, code-server, and development-tool installers with post-install checks.
- Automatic VS Code-to-code-server and Chromium-to-Firefox compatibility fallbacks.
- Original Orynquix wallpaper, XFCE appearance configuration, and verified desktop launchers.
- Expanded application-management and launch commands in the Termux CLI.
- Current/legacy provider compatibility tests and browser-session safety tests.

### Known limitations

- A real ARM64 Termux device acceptance run and visual desktop check are still required before this alpha can be marked device-validated.
- Android storage/audio integration, Control Center, backup, update, and broader targeted repairs remain future gates.

## [3.1.0-alpha]

### Fixed

- Interactive preset, browser, editor, and development-tool menus now return the selected value to their callers under `set -u`.
- Menu numbers are normalized as base-10 input, preventing leading-zero arithmetic errors.
- The public version correctly identifies that build as V3.1 (`3.1.0-alpha`).

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
- Version-exact V3-to-V3.1 CLI and Ubuntu marker migration checks.
- PID-reuse-safe forced termination and non-zombie process validation.

### Known limitations

- Requires ARM64 Termux device acceptance testing.
- Requires a real ARM64 Termux acceptance run before `3.1.0-alpha` can be tagged as device-validated.
- Visual identity, application compatibility, Android storage/audio integration, and Control Center remain later phases.
