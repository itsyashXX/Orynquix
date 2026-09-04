# Current limitations

Orynquix is an Ubuntu userspace running through Termux and PRoot. It does not replace Android, boot an Ubuntu kernel, provide an Android ROM, or provide VM isolation.

Standard PRoot cannot reliably supply the kernel features required by a local Docker daemon, Snap confinement, AppArmor enforcement, kernel modules, privileged mounts, low-level network administration, or direct hardware acceleration. Systemd is not used as an essential runtime dependency.

V3.2 release `3.2.0-alpha` implements the foundation, XFCE/TigerVNC engine, localhost browser access, selected development applications, and initial Orynquix visual identity. Android storage and audio integration, clipboard guarantees, Control Center, backup, update, and broader targeted repair remain gated; the CLI does not advertise unfinished commands.

Ubuntu 24.04 is the default desktop target because the `proot-distro` v5 maintainer identifies it as the working Ubuntu desktop path. Ubuntu 26.04 can be explicitly requested with `--ubuntu-release 26.04`, but is experimental under PRoot because newer desktop packages may depend on namespace-based `bwrap` behavior unavailable there.

Ubuntu Chromium is Snap-based and Snap confinement is not reliable in standard PRoot. Orynquix therefore uses an existing compatible Chromium binary when present and otherwise installs the signed Mozilla Firefox DEB. VS Code and Firefox desktop launchers use narrowly scoped sandbox compatibility switches because normal Linux namespaces are unavailable; this is weaker isolation than a native Linux installation.

Automated tests use a faithful command-level mock and direct process-safety tests on standard Linux. A real ARM64 Termux device test and manual visual/application launch check are still required before the release can be called device-validated.
