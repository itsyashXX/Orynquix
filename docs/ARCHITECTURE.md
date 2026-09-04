# Architecture

Orynquix separates the Termux host control plane from the Ubuntu userspace.

- `install.sh` coordinates verified, resumable stages.
- `installer/` owns stage actions and component-specific verification.
- `lib/` contains shared validation, filesystem, process, output, and Ubuntu adapters.
- `bin/orynquix` is the Termux-side management command.
- `~/.orynquix/` stores private configuration, state, logs, and backups.
- `~/.local/share/orynquix/app/` stores versioned CLI releases.
- `/usr/local/libexec/orynquix/vnc-session` manages the Ubuntu-side TigerVNC process.
- `~/.local/share/orynquix/state/vnc-session.ini` stores the owned session PID and process start identity.

The host CLI is the only component allowed to invoke `proot-distro login`. Internal Ubuntu scripts never recurse into PRoot. A marker at `/etc/orynquix-release` and `ORYNQUIX_INSIDE_PROOT=1` make nested-entry mistakes explicit.

Each installer stage has a separate action and verifier. State is written only after the verifier succeeds. Important configuration uses a temporary file, validated content, a previous-version backup, and an atomic rename.

The VNC backend uses a fixed requested display and refuses to choose `:2`, `:3`, or another display automatically. It validates both the recorded PID command line and `/proc` process start time before termination, so a recycled PID cannot be mistaken for an owned session.
