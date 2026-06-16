#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0-beta}"
BUILD_DIR="$APP_DIR/.build"
BUNDLE_DIR="$BUILD_DIR/bundles/Globe.app"
DIST_DIR="$BUILD_DIR/dist"
STAGING_DIR="$BUILD_DIR/staging/Globe"
DMG_PATH="$DIST_DIR/Globe-$VERSION.dmg"

"$SCRIPT_DIR/build-app-bundle.sh" >/dev/null

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

cp -R "$BUNDLE_DIR" "$STAGING_DIR/Globe.app"
ln -s /Applications "$STAGING_DIR/Applications"

cp "$REPO_DIR/LICENSE" "$STAGING_DIR/LICENSE.txt"

cat > "$STAGING_DIR/README.txt" <<'README'
Globe Beta

Install:
1. Drag Globe.app to Applications.
2. Open Globe.app from Applications.
3. Complete the welcome setup.
4. In System Settings > Privacy & Security > Accessibility, add Globe from Applications and enable it.
5. In System Settings > Keyboard, set "Press Globe key to" to "Do Nothing".

Privacy:
Globe does not record, store, or transmit typed text. It only listens for the Globe/Fn key in order to switch input sources.
README

hdiutil create \
  -volname "Globe $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
