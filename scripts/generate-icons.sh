#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONS_DIR="$ROOT_DIR/build/icons"
ICONSET_DIR="$ICONS_DIR/TermTPIcon.iconset"

cd "$ROOT_DIR"
mkdir -p "$ICONS_DIR"

swift run TermCIconTool "$ICONS_DIR"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICONS_DIR/TermTPIcon-1024.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICONS_DIR/TermTPIcon-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$ICONS_DIR/TermTPIcon.icns"
