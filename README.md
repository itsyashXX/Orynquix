# Orynquix

**A persistent, repairable Linux workstation that runs alongside Android without root.**

Orynquix turns a supported ARM64 Android phone into a portable graphical coding environment by coordinating Termux, Debian, Termux:X11 and XFCE. It is not a custom ROM, Android replacement, virtual machine, Windows emulator or promise that every desktop application will run.

This repository currently contains the **Stage 1 graphical technical-proof build**. Its primary surface is a touch-first phone GUI that sets up, launches, checks, repairs and proves the real Linux workstation. A typed CLI remains underneath as an advanced recovery and automation interface; it is not the normal product experience.

The approved design basis is preserved in [the pre-build engineering brief](docs/ORYNQUIX_PREBUILD_ENGINEERING_BRIEF.md).

## What works in Stage 1

- Touch-first Orynquix Phone GUI for setup, lifecycle, diagnostics and proof
- Authenticated loopback-only local interface with no cloud service or telemetry
- Read-only Android, ARM64, Python, RAM, storage and prerequisite diagnostics
- Human-readable and stable JSON output
- Idempotent Debian stable ARM64 and XFCE bootstrap
- Termux:X11 display launch and readiness checks
- Optional PulseAudio with honest degraded-mode reporting
- `start`, `status`, `stop` and `repair` lifecycle commands
- Strong process identity checks before any signal is sent
- Interrupted-bootstrap state and append-only operation journal
- Explicit single-folder Android storage mapping
- Five-cycle on-device proof runner with timing, memory and persistence evidence
- Redacted support bundles with a privacy preview
- Conservative uninstall that preserves projects and refuses unowned rootfs removal
- No telemetry and no non-loopback listener; optional audio transport is loopback-only

## Architecture

```text
Android
  └─ Termux host services
      ├─ Orynquix Phone GUI (127.0.0.1 only)
      ├─ Orynquix Python control plane
      │   ├─ doctor / bootstrap / lifecycle / repair
      │   ├─ atomic state / operation lock / journal
      │   └─ reports / support bundle / rollback
      ├─ Termux:X11 + optional PulseAudio
      └─ Debian ARM64 through proot-distro
          └─ XFCE + terminal + files + X11 test tools
```

`proot` is a compatibility layer, not a security sandbox. Orynquix never treats the guest as an isolation boundary.

## Supported starting point

- ARM64 Android phone or tablet
- Current supported Termux build from a consistent official source
- Matching Termux:X11 Android companion
- Python 3.12 or newer
- At least 6 GiB free; 10 GiB recommended
- No root required

The first proof supports Debian stable and XFCE only. Device support is evidence-based; passing on one phone does not claim support for every phone.

## Install and open the phone GUI

Install Termux and Termux:X11 from their current official release sources. Do not mix companion apps from unrelated signing sources.

Inside Termux:

```bash
pkg update
pkg install -y git python
git clone https://github.com/itsyashXX/Orynquix.git
cd Orynquix
bash scripts/install-termux.sh
```

The interactive installer opens the Orynquix Phone GUI in the Android browser. From there:

- tap **Check this phone** to inspect prerequisites;
- open **Setup** and tap **Set up my workstation**;
- tap **Start workspace** to launch the real Termux:X11/XFCE desktop;
- switch to the Termux:X11 Android app to use Linux;
- return to the browser GUI to stop, repair or run Phone Proof.

On later launches, keep Termux open and start the interface with:

```bash
orynquix-gui
```

The GUI stays entirely on the phone and listens only on loopback. See [the Phone GUI guide](docs/PHONE_GUI.md) for its security model, home-screen access and troubleshooting.

## Advanced recovery CLI

The GUI uses the safe Python control plane directly. The following commands remain available for recovery, scripting and evidence capture:

```bash
orynquix doctor --json
orynquix bootstrap --yes
orynquix start
orynquix status
orynquix stop
orynquix repair --yes
```

## User data boundary

Orynquix system state lives under the standard XDG configuration, data, state and cache directories. User projects live separately at:

```text
~/OrynquixProjects
```

`orynquix uninstall --yes` does not remove that projects directory. The dedicated `orynquix-debian` container is removed only with the additional `--remove-rootfs` flag and only when the journal proves Orynquix created it. An unrelated container named `debian` is never used or removed.

To expose an Android folder, grant Termux storage access, create a dedicated folder, and map only that folder:

```bash
termux-setup-storage
mkdir -p ~/storage/shared/Orynquix
orynquix configure --shared-directory ~/storage/shared/Orynquix
```

The guest sees it at `/mnt/orynquix-share`. Orynquix refuses to map the entire home directory or filesystem root.

## Close Stage 1 on a real device

Open **Proof** in the Phone GUI and tap **Run five-cycle proof**. The interface records the result under Activity and the control plane saves the full JSON evidence report.

The report does not replace the required screenshot or short screen recording. Follow [the device proof guide](docs/STAGE1_DEVICE_PROOF.md) and review all evidence before beginning Stage 2. The `orynquix proof --cycles 5 --yes` CLI route remains an advanced fallback.

## Development

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -e '.[dev]'
make check
```

Host-independent logic is tested on Linux CI. A real Termux/X11/Android device remains mandatory for the Stage 1 release gate.

## Compatibility promise

Applications will eventually be labeled exactly one of: **Native**, **Integrated Android**, **Web/PWA**, **Translated — Experimental**, **Remote**, or **Unsupported**. Orynquix will not display an Install action for an unverified idea.

## Status and license

Orynquix is pre-alpha software. Stage 1 uses the recommended Apache License 2.0; see [LICENSE](LICENSE). Security reports should follow [SECURITY.md](SECURITY.md).
