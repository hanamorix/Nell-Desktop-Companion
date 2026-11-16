#!/bin/bash
# Builds build/Nell.app, or the bundle path given: a universal (arm64 + x86_64) release, ad-hoc signed. No Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-build/Nell.app}"
[[ "$APP" == *.app ]] || { echo "bundle path must end in .app (it's deleted and rebuilt): $APP" >&2; exit 1; }
SLICES=()
# the binary is shared publicly: map this checkout's path out of every #filePath and debug string
PREFIX=(-Xswiftc -file-prefix-map -Xswiftc "$PWD=.")
for ARCH in arm64 x86_64; do
  # one scratch folder per architecture: they'd otherwise share .build/out and overwrite each other
  swift build -c release --arch "$ARCH" --scratch-path ".build/$ARCH" "${PREFIX[@]}"
  SLICES+=("$(swift build -c release --arch "$ARCH" --scratch-path ".build/$ARCH" "${PREFIX[@]}" --show-bin-path)/Nell")
done
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/Nell"
# debug stabs name each object file by its absolute build path
strip -S "$APP/Contents/MacOS/Nell"
if grep -a -q "$PWD" "$APP/Contents/MacOS/Nell"; then echo "build path still inside the binary" >&2; exit 1; fi
cp -R Sources/Nell/Resources/. "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
# the licences travel with the binary and the art inside it
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp artwork/LICENSE "$APP/Contents/Resources/LICENSE-artwork.txt"
cp THIRD_PARTY.md "$APP/Contents/Resources/THIRD_PARTY.md"
codesign -s - --force --deep "$APP"
echo "built $APP ($(lipo -archs "$APP/Contents/MacOS/Nell"))"
