#!/usr/bin/env bash
# Renders the pause menu and a settings page in the Gamespice theme at 1280x720, 390x844 and 844x390 to screenshots/gamespice_*.png (xvfb-run: --headless draws nothing).
set -euo pipefail
cd "$(dirname "$0")/.."
exec timeout 180 xvfb-run -a godot --path . --resolution 1280x720 --script tools/gamespice_shot.gd
