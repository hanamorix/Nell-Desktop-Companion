#!/bin/bash
# Builds build/Nell.app, or the bundle path given: a universal (arm64 + x86_64) release, ad-hoc signed. No Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-build/Nell.app}"
[[ "$APP" == *.app ]] || { echo "bundle path must end in .app (it's deleted and rebuilt): $APP" >&2; exit 1; }
SLICES=()
for ARCH in arm64 x86_64; do
  # one scratch folder per architecture: they'd otherwise share .build/out and overwrite each other
  swift build -c release --arch "$ARCH" --scratch-path ".build/$ARCH"
  SLICES+=("$(swift build -c release --arch "$ARCH" --scratch-path ".build/$ARCH" --show-bin-path)/Nell")
done
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/Nell"
cp -R Sources/Nell/Resources/. "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign -s - --force --deep "$APP"
echo "built $APP ($(lipo -archs "$APP/Contents/MacOS/Nell"))"
