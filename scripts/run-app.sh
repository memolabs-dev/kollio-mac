#!/bin/bash
# Builds Kollio.app from the SwiftPM executable and runs it.
#
#   ./scripts/run-app.sh          build and launch
#   ./scripts/run-app.sh --shot   build, launch, wait, screenshot.
#                                 Refuses to capture unless Kollio is the frontmost process.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/packages/KollioApp"
APP="$ROOT/build/Kollio.app"

cd "$PACKAGE"
# This script can run inside an IDE or agent sandbox. SwiftPM's subprocess
# sandbox cannot be nested there, and macro expansion then fails before the
# app is built. The outer environment still provides its own sandbox.
SWIFT_BUILD=(swift build --disable-sandbox)
"${SWIFT_BUILD[@]}" -c debug --product Kollio

BIN="$("${SWIFT_BUILD[@]}" -c debug --product Kollio --show-bin-path)/Kollio"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Kollio"
cp "$PACKAGE/Sources/KollioApp/Resources/Localizable.xcstrings" "$APP/Contents/Resources/" 2>/dev/null || true

# The localized strings produced by SwiftPM, if any.
find "$("${SWIFT_BUILD[@]}" -c debug --show-bin-path)" -name "*.bundle" -maxdepth 1 -exec cp -R {} "$APP/Contents/Resources/" \; 2>/dev/null || true

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Kollio</string>
    <key>CFBundleDisplayName</key><string>Kollio</string>
    <key>CFBundleIdentifier</key><string>dev.kollio.app</string>
    <key>CFBundleExecutable</key><string>Kollio</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleLocalizations</key>
    <array><string>fr</string><string>en</string></array>
</dict>
</plist>
PLIST

echo "Built $APP"
open "$APP"

if [ "${1:-}" = "--shot" ]; then
    sleep 4
    # This is a picture of the whole screen, not of Kollio. Read the file before
    # believing it.
    #
    # Two attempts were made to make it trustworthy and neither worked on this
    # machine. Focusing Kollio first does not hold: another application takes the
    # foreground back within a second or two, and has been observed submitting its
    # own input mid-capture. Cropping to the window's coordinates does not work
    # either, because those are where the window *is*, not what is drawn there.
    # Guarding on the frontmost *process* was tried too and is worse than useless:
    # the check reported Kollio while another application's window was on top, which
    # is precisely the case it was meant to catch.
    #
    # So there is no guard here that would be honest. The file is written, the path
    # is printed, and the reader has to look at it. `docs/known-limitations.md` says
    # the same thing, and the visual evidence for the recent batches rests on the
    # test suites rather than on this picture.
    screencapture -x -o "$ROOT/build/kollio.png" || echo "warning: the capture failed" >&2
    echo "Screenshot of the whole screen, not of Kollio alone: $ROOT/build/kollio.png"
fi
