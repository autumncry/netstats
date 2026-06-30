#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="NetStats"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

APP_PATH="$("$ROOT_DIR/scripts/package_app.sh" "$CONFIGURATION" | tail -n 1)"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"

if [[ -n "${NETSTATS_CODESIGN_IDENTITY:-}" ]]; then
    codesign \
        --force \
        --timestamp \
        --options runtime \
        --sign "$NETSTATS_CODESIGN_IDENTITY" \
        "$STAGING_DIR/$APP_NAME.app"
else
    echo "Skipping codesign: NETSTATS_CODESIGN_IDENTITY is not set" >&2
fi

ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

if [[ -n "${NETSTATS_CODESIGN_IDENTITY:-}" ]]; then
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

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "$DMG_PATH"
