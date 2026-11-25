#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
OUTPUT_DIR="${NETSTATS_BUILD_DIR:-$ROOT_DIR/build}"
cd "$ROOT_DIR"

SCRATCH="$ROOT_DIR/.build"
ARGS=(-c "$CONFIGURATION" --product NetStats)
if [[ "${NETSTATS_UNIVERSAL:-0}" == 1 ]]; then
    SCRATCH="$SCRATCH/universal"
    ARGS+=(--arch arm64 --arch x86_64)
fi
ARGS+=(--scratch-path "$SCRATCH")
swift build "${ARGS[@]}" >&2
BIN_DIR="$(swift build "${ARGS[@]}" --show-bin-path)"
# SwiftPM verifies the binary artifact checksum declared by the pinned dependency.
VENDOR="$SCRATCH/artifacts/sparkle/Sparkle"
SOURCE="$VENDOR/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
codesign --verify --deep --strict "$SOURCE"
mkdir -p "$OUTPUT_DIR"
STAGE="$(mktemp -d "$OUTPUT_DIR/.package.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/NetStats.app"
mkdir -p "$APP/Contents/"{MacOS,Resources,Frameworks}
cp "$BIN_DIR/NetStats" "$APP/Contents/MacOS/NetStats"
cp "$ROOT_DIR/Resources/Info.plist" "$APP/Contents/"
find "$ROOT_DIR/Resources" -maxdepth 1 -type f ! -name Info.plist -exec cp {} "$APP/Contents/Resources/" \;
cp "$VENDOR/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
ditto "$SOURCE" "$FRAMEWORK"
otool -L "$APP/Contents/MacOS/NetStats" | grep -F '@rpath/Sparkle.framework/Versions/B/Sparkle ' >/dev/null
otool -l "$APP/Contents/MacOS/NetStats" | grep -F 'path @executable_path/../Frameworks ' >/dev/null
IDENTITY="${NETSTATS_CODESIGN_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP" >&2
else
    # Manual Developer ID distribution signs nested code inside out.
    # https://sparkle-project.org/documentation/sandboxing/#code-signing
    SIGN=(--force --timestamp --options runtime --sign "$IDENTITY")
    B="$FRAMEWORK/Versions/B"
    codesign "${SIGN[@]}" "$B/XPCServices/Installer.xpc" >&2
    codesign "${SIGN[@]}" --preserve-metadata=entitlements "$B/XPCServices/Downloader.xpc" >&2
    codesign "${SIGN[@]}" "$B/Autoupdate" >&2
    codesign "${SIGN[@]}" "$B/Updater.app" >&2
    codesign "${SIGN[@]}" "$FRAMEWORK" >&2
    codesign "${SIGN[@]}" "$APP" >&2
fi
codesign --verify --deep --strict "$APP"
if [[ -d "$OUTPUT_DIR/NetStats.app" ]]; then mv "$OUTPUT_DIR/NetStats.app" "$STAGE/previous.app"; fi
if ! mv "$APP" "$OUTPUT_DIR/NetStats.app"; then
    if [[ -d "$STAGE/previous.app" ]]; then mv "$STAGE/previous.app" "$OUTPUT_DIR/NetStats.app"; fi
    exit 1
fi
echo "$OUTPUT_DIR/NetStats.app"
