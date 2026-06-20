#!/usr/bin/env bash
# Builds Perch.app from the SPM executable: compiles release, assembles the
# bundle, generates the icon, writes Info.plist, and ad-hoc code-signs.
#
# Usage: scripts/build_app.sh [version] [build]
#   version  CFBundleShortVersionString (default: 0.0.0-dev)
#   build    CFBundleVersion            (default: derived from git or 1)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.0.0-dev}"
BUILD="${2:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
# The SPM product / executable name — always "Perch".
APP_NAME="Perch"
# Bundle identity. Defaults reproduce the release build byte-for-byte; override
# for a side-by-side local build (distinct preferences/permission entry):
#   BUNDLE_ID=dev.perch.Perch.dev DISPLAY_NAME="Perch Dev" scripts/build_app.sh 0.0.0-dev
BUNDLE_ID="${BUNDLE_ID:-dev.perch.Perch}"
DISPLAY_NAME="${DISPLAY_NAME:-Perch}"
BUNDLE_FILENAME="${BUNDLE_FILENAME:-$DISPLAY_NAME}"

# Use the full Xcode toolchain when only Command Line Tools are selected. Any
# already-selected Xcode (e.g. a versioned `Xcode_16.2.app` in CI) is respected.
if ! xcode-select -p 2>/dev/null | grep -q "Xcode" && [ -d "/Applications/Xcode.app" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_FILENAME.app"

echo "==> Building $DISPLAY_NAME $VERSION (build $BUILD, id $BUNDLE_ID)"
swift build -c release --product "$APP_NAME"

echo "==> Assembling bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist (substitute version/build/identity placeholders).
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" \
    -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" -e "s/__DISPLAY_NAME__/$DISPLAY_NAME/g" \
    "$ROOT_DIR/Packaging/Info.plist.template" > "$APP_BUNDLE/Contents/Info.plist"

# PkgInfo (classic, harmless, expected by some tooling).
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Generating icon"
ICON_TMP="$(mktemp -d)"
swift "$ROOT_DIR/Packaging/generate_icon.swift" "$ICON_TMP/icon_1024.png"

ICONSET="$ICON_TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512; do
    sips -z "$size" "$size" "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICON_TMP"

echo "==> Ad-hoc code signing"
# No Developer ID available → ad-hoc sign so the app runs locally and Gatekeeper
# attaches a stable identity.
codesign --force --deep --sign - --options runtime "$APP_BUNDLE" 2>/dev/null \
    || codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --verbose=2 "$APP_BUNDLE"

echo "==> Built $APP_BUNDLE"
