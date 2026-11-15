#!/bin/bash
# Exports the master sprite to the app's sheet: 64 frames 8 per row, tags (user data lands as "data"), slices with per-frame keys, layers.
# No --trim / --ignore-empty: frame indices and 128×128 cells must stay as drawn.
set -euo pipefail
cd "$(dirname "$0")/.."
ASEPRITE="${ASEPRITE:-/Applications/Aseprite Source.app/Contents/MacOS/aseprite}"
"$ASEPRITE" -b artwork/sprites/nell-master.aseprite \
  --sheet Sources/Nell/Resources/sprites/nell.png --data Sources/Nell/Resources/sprites/nell.json \
  --format json-array --sheet-columns 8 --list-tags --list-slices --list-layers
