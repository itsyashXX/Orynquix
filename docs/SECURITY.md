# Security design

Orynquix requires no Android root and does not modify Android system partitions, SELinux policy, boot images, or bootloader state.

- VNC will bind to localhost by default when introduced in Phase 2.
- Linux and VNC passwords are never accepted as command-line values or written to logs.
- Non-interactive password input uses a caller-controlled file descriptor.
- Configuration values, usernames, resolutions, and paths are validated before use.
- Important configuration is written atomically with private permissions.
- Installer state and logs use private directories and files.
- The installer uses an owned lock and only recovers it after its recorded PID is no longer active.
- Orynquix never substitutes Debian when the Ubuntu provider is unavailable.
- Telemetry and analytics are absent.

The threat model is userspace convenience and damage prevention, not VM-grade isolation. Termux can enter the PRoot root account, so the Ubuntu password does not create an Android security boundary.
