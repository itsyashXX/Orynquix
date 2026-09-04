# Current limitations

Orynquix is an Ubuntu userspace running through Termux and PRoot. It does not replace Android, boot an Ubuntu kernel, provide an Android ROM, or provide VM isolation.

Standard PRoot cannot reliably supply the kernel features required by a local Docker daemon, Snap confinement, AppArmor enforcement, kernel modules, privileged mounts, low-level network administration, or direct hardware acceleration. Systemd is not used as an essential runtime dependency.

V3.1 release `0.2.1-alpha` implements the Phase 1 foundation and Phase 2 XFCE/TigerVNC engine. Visual identity, browsers, editor compatibility, Android storage, audio, Control Center, backup, update, and broader targeted repair remain gated later phases. The installer and CLI do not claim those components are installed yet.

Automated tests run on standard Linux. A real ARM64 Termux device test is still required before the release can be called device-validated.
