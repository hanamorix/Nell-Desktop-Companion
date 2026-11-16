#!/bin/bash
# Builds dist/Nell-<version>.dmg: Nell.app (universal, ad-hoc signed), an Applications link, "How to open Nell.txt",
# and her icon on the volume. Uses only hdiutil. It bundles into a temporary folder, never build/Nell.app.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(plutil -extract CFBundleShortVersionString raw scripts/Info.plist)"
DMG="dist/Nell-$VERSION.dmg"
WORK="$(mktemp -d)"
STAGE="$WORK/stage" MNT="$WORK/mnt"
detach() { for _ in 1 2 3 4 5; do hdiutil detach "$1" -quiet && return 0; sleep 2; done; hdiutil detach "$1" -force; }
trap 'hdiutil detach "$MNT" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

mkdir -p "$STAGE" "$MNT" dist
bash scripts/bundle.sh "$STAGE/Nell.app"
ln -s /Applications "$STAGE/Applications"
cp Sources/Nell/Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
cp LICENSE "$STAGE/LICENSE.txt"
cp artwork/LICENSE "$STAGE/LICENSE-artwork.txt"
cp THIRD_PARTY.md "$STAGE/THIRD_PARTY.md"
cat > "$STAGE/How to open Nell.txt" <<'EOF'
How to open Nell
================

1. Drag Nell into the Applications folder (the shortcut next to her), then open her from there.

2. The first time, macOS stops her. Nell is free and open source, but she isn't notarised
   by Apple, so macOS says it can't check her for malware. To let her in:

   macOS 15 (Sequoia) or later
     - Open Nell once. macOS says it can't open her. Click Done.
     - Open System Settings > Privacy & Security, and scroll down to Security.
     - Next to the message about Nell, click "Open Anyway", then confirm with your password.
     - Open Nell again and click "Open Anyway".

   macOS 14 (Sonoma)
     - In Applications, Control-click (or right-click) Nell and choose Open.
     - Click Open in the dialog.

   You only do this once. After that she opens like any other app.

What Nell needs
---------------
- macOS 14 or later, on an Apple silicon or Intel Mac.
- kitty 0.50.0 or later, the terminal Nell drives. If you don't have it, or yours is too old,
  Nell offers to install the current one for you:
  she downloads the official, signed release from kitty's own project.
- Claude Code, installed and logged in to your account. Nell uses your own Claude Code;
  she doesn't install it for you. Run "claude" once in Terminal to log in before opening Nell.

More: https://github.com/hanamorix/Nell-Desktop-Companion#readme
EOF

# A read-write image first, so the volume can be flagged to use its custom icon; then compress it.
hdiutil create -volname Nell -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg"
hdiutil attach "$WORK/rw.dmg" -nobrowse -noautoopen -mountpoint "$MNT"
SetFile -a C "$MNT"
detach "$MNT"
rm -f "$DMG"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG"
hdiutil verify "$DMG"
echo "packaged $DMG ($(du -h "$DMG" | cut -f1))"
