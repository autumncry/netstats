#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="NetStats"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DIST_DIR="${NETSTATS_DIST_DIR:-$ROOT_DIR/dist}"
mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d "$DIST_DIR/.dmg-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

APP_PATH="$("$ROOT_DIR/scripts/package_app.sh" "$CONFIGURATION" | tail -n 1)"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"

codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app"
cp "$ROOT_DIR/docs/first-launch.txt" "$STAGING_DIR/首次安装 - First Launch.txt"

ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [[ "${NETSTATS_CODESIGN_IDENTITY:-}" == "-" ]]; then
    codesign --force --sign - "$DMG_PATH"
elif [[ -n "${NETSTATS_CODESIGN_IDENTITY:-}" ]]; then
    codesign \
        --force \
        --timestamp \
        --sign "$NETSTATS_CODESIGN_IDENTITY" \
        "$DMG_PATH"
fi

if [[ -n "${NETSTATS_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NETSTATS_NOTARY_PROFILE" \
        --wait
    xcrun stapler staple "$DMG_PATH"
else
    echo "Skipping notarization: NETSTATS_NOTARY_PROFILE is not set" >&2
fi

(cd "$DIST_DIR" && shasum -a 256 "$APP_NAME-$VERSION.dmg" > "$APP_NAME-$VERSION.dmg.sha256")
echo "$DMG_PATH"
