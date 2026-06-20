#!/usr/bin/env bash
# Packages dist/Perch.app into a distributable DMG with an /Applications
# shortcut for drag-to-install. Usage: scripts/make_dmg.sh [version]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.0.0-dev}"
APP_NAME="Perch"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found — run scripts/build_app.sh first" >&2
    exit 1
fi

echo "==> Staging DMG contents"
STAGE="$(mktemp -d)"
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGE"
echo "==> Created $DMG_PATH"
