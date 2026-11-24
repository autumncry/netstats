#!/usr/bin/env bash
# Build a signed release candidate locally. Publish only after the final DMG
# can be downloaded from its permanent GitHub Release URL.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DIST="${NETSTATS_DIST_DIR:-$ROOT/dist}"
INFO="${NETSTATS_BUILD_DIR:-$ROOT/build}/NetStats.app/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")"
TAG="$(python3 -c 'import json; print(json.load(open("npm/package.json"))["githubReleaseTag"])')"
ARCHIVE="NetStats-$VERSION.dmg"
# NetStats ships one universal artifact under this name. Never sign a host-only
# test build for this feed; Intel and Apple Silicon share the same update URL.
TMP="$(mktemp -d "$DIST/.appcast.XXXXXX")"
MOUNT="$TMP/image"
mounted=0
cleanup() {
    if [[ "$mounted" == 1 ]] && ! hdiutil detach "$MOUNT" >&2; then
        echo "Could not detach $MOUNT; leaving the staging directory in place." >&2
        return
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT
(cd "$DIST" && shasum -a 256 -c "$ARCHIVE.sha256" >&2)
ln "$DIST/$ARCHIVE" "$TMP/$ARCHIVE"
mkdir "$MOUNT"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$TMP/$ARCHIVE" >&2
mounted=1
IMAGE_APP="$MOUNT/NetStats.app"
codesign --verify --strict --deep "$IMAGE_APP"
cmp "$INFO" "$IMAGE_APP/Contents/Info.plist"
cmp "${INFO%/Info.plist}/MacOS/NetStats" "$IMAGE_APP/Contents/MacOS/NetStats"
case "$(lipo -archs "$IMAGE_APP/Contents/MacOS/NetStats")" in
    "arm64 x86_64"|"x86_64 arm64") ;;
    *) echo "The stable update DMG must contain a universal NetStats executable" >&2; exit 1 ;;
esac
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$IMAGE_APP/Contents/Info.plist")" == com.ronnycao.netstats ]]
cmp "$ROOT/docs/first-launch.txt" "$MOUNT/首次安装 - First Launch.txt"
hdiutil detach "$MOUNT" >&2
mounted=0
rmdir "$MOUNT"
cp "$ROOT/docs/release-notes/$TAG.md" "$TMP/NetStats-$VERSION.md"

# These tools come from Sparkle's pinned, checksum-verified SwiftPM binary artifact.
TOOL="$ROOT/.build/universal/artifacts/sparkle/Sparkle/bin/generate_appcast"
[[ "$(shasum -a 256 "$TOOL" | cut -d' ' -f1)" == cdc53c1da293c5f89648929678df2072f72a9f18d91744a06fcb8cc0e12a3219 ]]
"$TOOL" --account NetStats --maximum-deltas 0 --embed-release-notes \
    --download-url-prefix "https://github.com/autumncry/netstats/releases/download/$TAG/" \
    --link "https://github.com/autumncry/netstats" \
    --full-release-notes-url "https://github.com/autumncry/netstats/releases/tag/$TAG" \
    -o "$TMP/appcast.xml" "$TMP" >&2
xcrun swift "$ROOT/scripts/verify_appcast.swift" "$INFO" "$TMP/appcast.xml" "$TAG" "$DIST/$ARCHIVE" >&2
mv "$TMP/appcast.xml" "$DIST/appcast.xml"
echo "$DIST/appcast.xml"
