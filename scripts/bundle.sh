#!/bin/bash
# Builds build/Nell.app (release, ad-hoc signed). No Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
APP=build/Nell.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Nell" "$APP/Contents/MacOS/Nell"
cp -R Sources/Nell/Resources/. "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign -s - --force --deep "$APP"
echo "built $APP"
