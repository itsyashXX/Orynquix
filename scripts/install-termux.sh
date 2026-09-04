#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

if [[ "${PREFIX:-}" != *"com.termux"* ]] || ! command -v pkg >/dev/null 2>&1; then
  echo "Orynquix must be installed from inside the supported Termux app." >&2
  exit 10
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "Stage 1 currently supports ARM64 Android devices only." >&2
  exit 10
fi

pkg install -y python
python -m pip install --disable-pip-version-check .

echo
echo "Orynquix phone GUI installed. No Linux rootfs was changed yet."
echo "The graphical setup opens in your Android browser and stays on this phone."

if [[ -t 1 && "${ORYNQUIX_SKIP_GUI_LAUNCH:-0}" != "1" ]]; then
  echo "Opening Orynquix…"
  exec orynquix-gui
fi

echo "Open the interface with: orynquix-gui"
