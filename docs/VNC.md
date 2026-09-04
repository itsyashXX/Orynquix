# TigerVNC desktop

Orynquix V3.1 uses the Ubuntu `tigervnc-standalone-server` package and the distribution-provided `tigervncserver` wrapper. Ubuntu 24.04 provides this package for ARM64 and includes `/usr/bin/Xtigervnc` and `/usr/bin/tigervncserver`.

The wrapper supports the options Orynquix uses: explicit display number, geometry, depth, localhost binding, security types, password file, RFB port, and custom xstartup. References:

- <https://packages.ubuntu.com/en/noble/tigervnc-standalone-server>
- <https://packages.ubuntu.com/en/noble/arm64/tigervnc-standalone-server/filelist>
- <https://manpages.debian.org/testing/tigervnc-standalone-server/tigervncserver.1.en.html>
- <https://manpages.ubuntu.com/manpages/noble/man1/Xtigervnc.1.html>

## Defaults

```text
Display:       :1
Port:          5901
Address:       127.0.0.1 only
Geometry:      1280x720
Depth:         24
Security type: VncAuth
```

`VncAuth` is used only on the loopback interface. Orynquix V3.1 does not expose this unencrypted mode to the LAN. Future LAN support requires a separate explicit security design.

## Commands

```bash
orynquix start
orynquix stop
orynquix restart
orynquix status
orynquix sessions
orynquix passwd
orynquix resolution 1600x900
orynquix logs vnc
```

The session registry stores the exact TigerVNC PID, its Linux process start-time identity, display, port, resolution, and start timestamp. Stop operations require both PID command-line validation and start-time identity validation. Orynquix never kills VNC processes merely by name.

Stale `/tmp/.X1-lock` and `/tmp/.X11-unix/X1` entries are removed only after confirming that the recorded process is no longer active. An active unregistered `:1` session is treated as unrelated and left untouched.

## Startup

The generated xstartup creates a private `XDG_RUNTIME_DIR`, clears inherited session variables, and starts XFCE through a fresh D-Bus session:

```text
dbus-launch --exit-with-session xfce4-session
```

The VNC password is generated with `tigervncpasswd -f`, written atomically, owned by the desktop user, and set to mode `0600`. Traditional VNC authentication uses only eight password characters, so Orynquix requires 6–8 characters instead of silently ignoring extra characters.
