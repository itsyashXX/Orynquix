#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

orynquix doctor --runtime
orynquix proof --cycles 5 --yes

echo
echo "Attach a screenshot or short recording and review the JSON report before Stage 2."

