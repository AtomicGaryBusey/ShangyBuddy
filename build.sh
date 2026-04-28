#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Shangy"
APP_DIR="$ROOT/dist/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "==> Building Swift package (release)"
swift build -c release --package-path "$ROOT"
BIN_PATH="$ROOT/.build/release/$APP_NAME"
test -x "$BIN_PATH" || { echo "binary not found at $BIN_PATH"; exit 1; }

echo "==> Assembling .app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$BIN_PATH" "$BIN_DIR/$APP_NAME"
cp "$ROOT/Sources/Shangy/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "==> Ad-hoc codesigning (required for ScreenCaptureKit permissions)"
codesign --force --deep --sign - "$APP_DIR"

echo
echo "Built: $APP_DIR"
echo "Run:   open \"$APP_DIR\""
echo
echo "First launch: macOS will prompt for Screen Recording. Approve in"
echo "System Settings > Privacy & Security > Screen Recording, then relaunch."
