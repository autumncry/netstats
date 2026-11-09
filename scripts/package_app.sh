#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="NetStats"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"

cd "$ROOT_DIR"
BUILD_ARGS=(-c "$CONFIGURATION" --product "$APP_NAME")
if [[ "${NETSTATS_UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64 --scratch-path "$ROOT_DIR/.build/universal")
fi
swift build "${BUILD_ARGS[@]}"
EXECUTABLE_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
find "$ROOT_DIR/Resources" -maxdepth 1 -type f ! -name "Info.plist" -exec cp {} "$APP_DIR/Contents/Resources/" \;
cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "$APP_DIR"
