#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/TermTP.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
scripts/generate-icons.sh
swift build -c debug --product TermCApp
SWIFT_BUILD_BIN_DIR="$(swift build -c debug --show-bin-path)"
SWIFT_BUILD_BIN_DIR="$(cd "$SWIFT_BUILD_BIN_DIR" && pwd -P)"
TERMC_EXECUTABLE="$SWIFT_BUILD_BIN_DIR/TermCApp"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$TERMC_EXECUTABLE" "$MACOS_DIR/TermTP"
cp "$BUILD_DIR/icons/TermTPIcon-1024.png" "$RESOURCES_DIR/TermTPIcon-1024.png"
cp "$BUILD_DIR/icons/TermTPIcon.icns" "$RESOURCES_DIR/TermTPIcon.icns"
cp "$BUILD_DIR/icons/TermTPMenuBarTemplate.png" "$RESOURCES_DIR/TermTPMenuBarTemplate.png"

for bundle in "$SWIFT_BUILD_BIN_DIR"/*.bundle; do
    [ -d "$bundle" ] || continue
    cp -R "$bundle" "$RESOURCES_DIR/"
done

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TermTP</string>
    <key>CFBundleIdentifier</key>
    <string>local.termtp.app</string>
    <key>CFBundleName</key>
    <string>TermTP</string>
    <key>CFBundleDisplayName</key>
    <string>TermTP</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>TermTPIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
