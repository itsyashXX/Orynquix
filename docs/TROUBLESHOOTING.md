# Troubleshooting

Start with **Check this phone** in the Orynquix GUI and open **Activity** for the diagnostic identifier. For advanced recovery, use:

```bash
orynquix doctor --runtime
orynquix status --json
```

Every expected failure prints a stable diagnostic identifier. Include that identifier when reporting a problem.

## Phone GUI does not open

Keep the `orynquix-gui` process running in Termux. If Android did not switch to the browser, open the one-time local launch URL printed by the process. The address must begin with `http://127.0.0.1`; Orynquix intentionally refuses LAN-facing GUI addresses.

If port 8765 is already occupied, stop the older GUI process or use `orynquix-gui --port 8766`. See [the Phone GUI guide](PHONE_GUI.md) for home-screen and local-token details.

## Termux is not detected

Run Orynquix inside the supported Termux application. Android's built-in shell, ADB shell, another terminal app and a Linux proot shell are not the host control environment. Avoid mixing Termux and companion applications from incompatible signing sources.

## Termux:X11 companion is missing

Install the current matching Termux:X11 Android companion from its official release source, install the Termux-side package through the bootstrap, open the companion once and retry.

## Display socket never appears (`ORY-LIFE-008`)

1. Open the Termux:X11 Android application.
2. Return to Termux and run `orynquix repair --yes`.
3. Run `orynquix start` again.
4. If it still fails, inspect the private `termux-x11.log` path shown by `orynquix paths` under runtime state.

Do not fix this by exposing an unauthenticated VNC server on Wi-Fi. A VNC fallback must bind to loopback and is not implemented in Stage 1.

## XFCE exits immediately

Run `orynquix bootstrap --yes` again. It checks whether `/usr/bin/xfce4-session` exists before deciding if the guest desktop step is complete. Then review `desktop.log` in the runtime-state log directory.

## Audio is degraded

Audio is optional in Stage 1. The desktop remains usable when PulseAudio fails. Run `pkg install pulseaudio`, check Android media volume and restart. You may also use `orynquix configure --disable-audio` to make the intentional disabled state explicit.

## Android kills the session

Exclude Termux and Termux:X11 from aggressive battery optimization, keep enough memory free and avoid heavy Android applications during the proof. `orynquix status` reports a missing or identity-changed required process as failed rather than pretending the session is running.

## Bootstrap was interrupted

Run:

```bash
orynquix doctor
orynquix bootstrap
orynquix bootstrap --yes
```

Bootstrap re-checks each step and resumes. It does not delete the rootfs or projects as a recovery shortcut.

## State is invalid or stuck

Preview then confirm repair:

```bash
orynquix repair
orynquix repair --yes
```

Invalid state is archived. Only processes whose PID, process-start time and command-line digest match the journal are stopped.

## Before sharing diagnostics

```bash
orynquix support-bundle
orynquix support-bundle --yes
```

Review the ZIP yourself. Automated redaction reduces risk but cannot guarantee that application-generated text contains no personal data.
