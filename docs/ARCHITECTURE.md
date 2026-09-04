# Architecture

Orynquix separates the Termux host control plane from the Ubuntu userspace.

- `install.sh` coordinates verified, resumable stages.
- `installer/` owns stage actions and component-specific verification.
- `lib/` contains shared validation, filesystem, process, output, and Ubuntu adapters.
- `bin/orynquix` is the Termux-side management command.
- `~/.orynquix/` stores private configuration, state, logs, and backups.
- `~/.local/share/orynquix/app/` stores versioned CLI releases.
- `/usr/local/libexec/orynquix/vnc-session` manages the Ubuntu-side TigerVNC process.
- `/usr/local/libexec/orynquix/web-session` manages the optional localhost noVNC/WebSocket proxy.
- `/usr/local/libexec/orynquix/start-xfce` applies verified Orynquix appearance settings and starts XFCE.
- `~/.local/share/orynquix/state/vnc-session.ini` stores the owned session PID and process start identity.

The host CLI is the only component allowed to invoke `proot-distro login`. Internal Ubuntu scripts never recurse into PRoot. A marker at `/etc/orynquix-release` and `ORYNQUIX_INSIDE_PROOT=1` make nested-entry mistakes explicit.

Each installer stage has a separate action and verifier. State is written only after the verifier succeeds. Important configuration uses a temporary file, validated content, a previous-version backup, and an atomic rename.

The VNC backend uses a fixed requested display and refuses to choose `:2`, `:3`, or another display automatically. It validates both the recorded PID command line and `/proc` process start time before termination, so a recycled PID cannot be mistaken for an owned session.

Current `proot-distro` releases pull OCI images and do not advertise the old distribution plugin list. The Ubuntu adapter detects the interface from command capabilities: current providers install `ubuntu:24.04 --name ubuntu`; legacy providers use the `ubuntu` alias. The extracted rootfs is accepted only when `/etc/os-release` identifies Ubuntu.

VNC and the optional noVNC proxy share one backend. The CLI and GUI-facing launchers do not carry separate lifecycle implementations. Both listeners bind to `127.0.0.1`, and each tracked process requires matching PID, start time, command, and ports before termination.
