#!/bin/bash
# Builds build/Nell.app, or the bundle path given (release, ad-hoc signed). No Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-build/Nell.app}"
[[ "$APP" == *.app ]] || { echo "bundle path must end in .app (it's deleted and rebuilt): $APP" >&2; exit 1; }
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Nell" "$APP/Contents/MacOS/Nell"
cp -R Sources/Nell/Resources/. "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign -s - --force --deep "$APP"
echo "built $APP"
