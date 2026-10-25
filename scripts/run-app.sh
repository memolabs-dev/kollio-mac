#!/bin/bash
# Builds Kollio.app from the SwiftPM executable and runs it.
#
#   ./scripts/run-app.sh          build and launch
#   ./scripts/run-app.sh --shot   build, launch, window-only screenshot.
#                                 Fails closed when TCC is denied or the window is ambiguous.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT/packages/KollioApp"
APP="$ROOT/build/Kollio.app"

cd "$PACKAGE"
swift build -c debug --product Kollio

BIN="$(swift build -c debug --product Kollio --show-bin-path)/Kollio"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Kollio"
cp "$PACKAGE/Sources/KollioApp/Resources/Localizable.xcstrings" "$APP/Contents/Resources/" 2>/dev/null || true

# The localized strings produced by SwiftPM, if any.
find "$(swift build -c debug --show-bin-path)" -name "*.bundle" -maxdepth 1 -exec cp -R {} "$APP/Contents/Resources/" \; 2>/dev/null || true

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
    # No misleading stale artifact can survive a denied capture.
    rm -f "$ROOT/build/kollio.png"
    sleep 4
    swiftc -parse-as-library "$ROOT/scripts/capture-kollio-window.swift" -o "$ROOT/build/capture-kollio-window"
    "$ROOT/build/capture-kollio-window" "$ROOT/build/kollio.png"
    echo "Window-only screenshot saved in build/kollio.png; inspect it before using it publicly."
fi
