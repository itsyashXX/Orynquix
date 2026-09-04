# Security design

Orynquix requires no Android root and does not modify Android system partitions, SELinux policy, boot images, or bootloader state.

- VNC and optional noVNC/WebSocket access bind to localhost only.
- Linux and VNC passwords are never accepted as command-line values or written to logs.
- Non-interactive password input uses a caller-controlled file descriptor.
- Configuration values, usernames, resolutions, and paths are validated before use.
- Important configuration is written atomically with private permissions.
- Installer state and logs use private directories and files.
- The installer uses an owned lock and only recovers it after its recorded PID is no longer active.
- Orynquix never substitutes Debian when the Ubuntu provider is unavailable.
- Signed Mozilla and Microsoft repositories are pinned to HTTPS and their expected signing-key fingerprints are verified before use.
- Official code-server release packages are downloaded over HTTPS, validated as a Debian package for the active architecture, and checked against the publisher's SHA-256 digest when the release API supplies one.
- Telemetry and analytics are absent.

The threat model is userspace convenience and damage prevention, not VM-grade isolation. Termux can enter the PRoot root account, so the Ubuntu password does not create an Android security boundary.
