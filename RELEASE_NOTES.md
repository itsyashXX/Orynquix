# Orynquix Stage 1 Alpha 2 — Phone GUI

**Branch:** `feat/stage-1-technical-proof`  
**Commit:** recorded in `BUILD_INFO.txt` inside the release bundle

This corrected build makes the touch-first Orynquix Phone GUI the primary product surface. It manages a no-root Termux control plane for a dedicated Debian stable ARM64 container, Termux:X11 and XFCE. The existing CLI remains an advanced recovery and automation interface; it is no longer the normal phone workflow.

## Included

- touch-first Home, Setup, Proof and Activity interface;
- graphical guided setup, device check, start/stop, repair and five-cycle proof;
- authenticated loopback-only local server with origin and request protections;
- complete source archive;
- installable Python wheel;
- Python source distribution;
- checksums;
- engineering brief, GUI, architecture, device-proof and troubleshooting documents;
- 43 automated tests with more than 80% branch-aware coverage;
- safe bootstrap, lifecycle, repair, proof, diagnostics and rollback commands.

## Start on ARM64 Android

Extract the source archive in Termux, enter the `Orynquix` directory, then run:

```bash
bash scripts/install-termux.sh
```

The installer opens the Orynquix GUI in the Android browser. Tap **Check this phone**, then use **Setup** to install the persistent Debian/XFCE workstation. Tap **Start workspace** and switch to the Termux:X11 app to use the real Linux desktop.

The final hardware gate is under **Proof → Run five-cycle proof**. Do not begin Stage 2 until the proof report and real graphical-session recording are reviewed.
