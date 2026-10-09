#!/usr/bin/env bash
# Renders the demo's every screen, in several themes, to screenshots/.
#
#   tools/screenshot.sh
#
# xvfb-run because this needs a rendering context; `--headless` gives a null renderer and
# every frame it saves is empty.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p screenshots
exec timeout 180 xvfb-run -a godot --path . --resolution 1600x900 --script tools/screenshot.gd
