# Stage 1 Device Proof

Stage 1 closes only when one declared ARM64 Android device repeatedly installs, starts, operates, stops and resumes the same persistent graphical session without root. The Phone GUI is the primary proof surface; CLI commands below remain useful for exact evidence capture and recovery.

## 1. Record the baseline

From the repository checkout, preserve:

```bash
git branch --show-current
git rev-parse HEAD
git remote -v
git status --short
orynquix doctor --json > device-before.json
```

Do not publish serial numbers, Android IDs, tokens, private paths or unrelated command history.

## 2. Prove guided, idempotent setup

Open `orynquix-gui`, choose **Setup**, confirm **Set up my workstation**, and let the graphical flow finish. Run the same confirmed Setup action a second time; it must report that the workstation is already set up rather than reinstalling an intact rootfs.

For exact JSON capture, the equivalent advanced sequence is:

Review then apply:

```bash
orynquix bootstrap
orynquix bootstrap --yes
orynquix bootstrap --yes
orynquix doctor --runtime --json > device-runtime.json
```

The second confirmed run must report no package/rootfs/desktop changes. It must not reinstall an intact Debian rootfs.

## 3. Prove the real graphical path

From GUI Home, tap **Start workspace**, then switch to the Termux:X11 Android app. Home must report **Workspace ready** only after the required display and desktop services pass their readiness checks.

The equivalent advanced commands are:

```bash
orynquix start
orynquix status --json
```

In XFCE:

1. open XFCE Terminal;
2. open Thunar;
3. type text using the intended keyboard;
4. use pointer/touch input;
5. create a file under `~/OrynquixProjects` or the configured shared folder;
6. take a screenshot or short recording that contains no secrets.

Stop from the GUI Home button. The equivalent advanced command is:

```bash
orynquix stop
```

## 4. Run the five-cycle gate

Open **Proof** in the Phone GUI, review the explanation, and confirm **Run five-cycle proof**. Keep Termux open and the device awake. The result must appear in Activity and the full report must be saved under Orynquix's reports directory.

The equivalent advanced command is:

```bash
orynquix proof --cycles 5 --yes
```

The generated report must show five passed cycles, stopped final state, real start/stop timings, managed-process RSS and a successful persistence check. A degraded audio result may be accepted only when display, XFCE, terminal, files and input work.

## 5. Exercise recovery

With no valuable uncommitted guest work open, interrupt one bootstrap or graphical start, then run:

```bash
orynquix status --json
orynquix repair
orynquix repair --yes
orynquix bootstrap --yes
```

The command must preserve the projects directory, archive invalid state when applicable and never signal a process whose identity does not match the recorded process.

## 6. Exercise rollback

Preview only:

```bash
orynquix uninstall
```

Verify the preview lists `~/OrynquixProjects` under preserved paths. A full test device rollback is:

```bash
orynquix uninstall --yes --remove-rootfs
```

Rootfs removal must be refused if Orynquix cannot prove that its bootstrap created Debian.

## 7. Evidence package

- exact branch and commit SHA;
- redacted `device-before.json` and `device-runtime.json`;
- first and second bootstrap results;
- five-cycle proof JSON;
- screenshot or recording;
- install, cold/warm launch, idle/managed memory and rootfs-size measurements;
- recovery and rollback results;
- known limitations and degraded components;
- owner approval before Stage 2.
