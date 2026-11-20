#!/usr/bin/env bash
# Starts a native window at 16:9, 21:9, 4:3 and portrait, with keep_aspect off and on, and saves each as the
# screen shows it to screenshots/aspect/; fails on a black bar while keep_aspect is off (and on none while
# it is on). Run it on a GPU box: gpu.sh shot.
#
#   tools/aspect_shot.sh
set -uo pipefail
cd "$(dirname "$0")/.."
out=screenshots/aspect
mkdir -p "$out"
rc=0
for keep in "" --keep; do
	for size in 1600x900 2520x1080 1200x900 720x1280; do
		timeout 120 xvfb-run -a -s "-screen 0 ${size}x24" godot --path . --resolution "$size" \
			res://examples/aspect_probe.tscn -- --out="$out" $keep || rc=1
	done
done
exit $rc
