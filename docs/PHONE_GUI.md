# Orynquix Phone GUI

The Phone GUI is the primary Stage 1 interface. It is a touch-first Android control center for setting up, starting, stopping, checking, repairing and proving the real Debian/XFCE workstation. The existing command line remains available for recovery and automation, but normal phone use does not require copying lifecycle commands.

## Open it

The interactive Termux installer opens the GUI automatically. On later launches, keep Termux running and use:

```bash
orynquix-gui
```

Orynquix opens the Android browser to a private local address. The process must keep running in Termux while the GUI is open. Closing the browser does not delete the workstation or projects.

The interface has four touch-first areas:

- **Home** shows real session, display and desktop health and provides the main Start/Stop action.
- **Setup** runs the idempotent Debian/XFCE installation after an explicit confirmation.
- **Proof** runs the five-cycle real-phone acceptance gate after an explicit confirmation.
- **Activity** records results and copyable diagnostic identifiers for the current GUI session.

The GUI does not fake a desktop in the browser. **Start workspace** launches the real Termux:X11 and XFCE graphical session. Switch to the Termux:X11 Android app to use the Linux desktop; return to the browser control center for status and lifecycle actions.

## Local security model

- The GUI binds only to `127.0.0.1`; it is not exposed to Wi-Fi, cellular networks or the public internet.
- A private random token authorizes the browser and is stored in Orynquix's private state directory with owner-only permissions.
- The launch URL immediately exchanges the token for a strict local browser cookie and removes it from the visible address.
- Mutating requests require the correct origin, host, JSON content type and an Orynquix request marker.
- The GUI calls the same operation lock, process-identity checks, journal and filesystem guards as the recovery CLI.

`proot` remains a compatibility layer, not a security sandbox.

## Android home-screen access

After the GUI opens successfully, the browser may offer **Add to Home screen** or **Install app**. This creates a convenient icon for the interface; it does not turn Orynquix into a custom ROM and Termux still needs to be running.

If a saved home-screen icon says the launcher is unavailable, start `orynquix-gui` in Termux again and reopen it from the fresh browser tab.

## Troubleshooting

- **The page did not open:** keep the GUI process running and open the one-time local launch URL printed by Termux.
- **Port 8765 is already used:** stop the older GUI process, or launch with `orynquix-gui --port 8766`.
- **Start needs attention:** open Activity and copy the diagnostic identifier. Run Setup if runtime components are missing.
- **The lifecycle is failed:** the Home button changes to **Repair workspace** and asks for confirmation before cleanup.
- **The desktop is not visible:** open the Termux:X11 companion app. A ready browser status does not move Android to that app automatically on every device.

Advanced recovery remains available with `orynquix status --json`, `orynquix repair --yes` and the other documented CLI commands.
