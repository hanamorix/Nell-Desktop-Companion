#!/bin/bash
# A sandboxed second Nell that plays every visual state: bash scripts/showcase.sh [scene | list]
# No scene cycles all scenes forever; a scene name loops just that one. Quit it with: kill <its pid>.
set -euo pipefail
cd "$(dirname "$0")/.."
# Its own bundle and bundle id: rebuilding build/Nell.app would delete files out from under the user's running Nell.
APP=build/showcase/Nell.app
BIN="$APP/Contents/MacOS/Nell"
if [ ! -x "$BIN" ] || [ -n "$(find Sources Package.swift scripts/Info.plist scripts/bundle.sh -newer "$BIN" -print -quit)" ]; then
  bash scripts/bundle.sh "$APP"
  plutil -replace CFBundleIdentifier -string local.nell.companion.showcase "$APP/Contents/Info.plist"
  plutil -replace CFBundleName -string "Nell Showcase" "$APP/Contents/Info.plist"
  codesign -s - --force --deep "$APP"
fi
if [ "${1:-}" = list ]; then exec "$BIN" --showcase list; fi
open -n --stderr "$PWD/build/showcase/stderr.log" "$APP" --args --showcase ${1:+"$1"}
