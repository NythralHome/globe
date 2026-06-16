#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0-beta.6}"
BUILD_DIR="$APP_DIR/.build"
BUNDLE_DIR="$BUILD_DIR/bundles/Globe.app"
DIST_DIR="$BUILD_DIR/dist"
STAGING_DIR="$BUILD_DIR/staging/Globe"
DMG_PATH="$DIST_DIR/Globe-$VERSION.dmg"
RW_DMG_PATH="$DIST_DIR/Globe-$VERSION-rw.dmg"
MOUNT_DIR="$BUILD_DIR/mount/Globe-$VERSION"
VOLUME_NAME="Globe $VERSION"

"$SCRIPT_DIR/build-app-bundle.sh" >/dev/null

rm -rf "$STAGING_DIR" "$DMG_PATH" "$RW_DMG_PATH" "$MOUNT_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

cp -R "$BUNDLE_DIR" "$STAGING_DIR/Globe.app"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
cp "$APP_DIR/.build/assets/DMGBackground.png" "$STAGING_DIR/.background/DMGBackground.png"

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
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH" >/dev/null

mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -noverify -noautoopen >/dev/null

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_DIR" as alias
  tell folder dmgFolder
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 880, 560}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set background picture of viewOptions to file ".background:DMGBackground.png"
    set position of item "Globe.app" of container window to {180, 240}
    set position of item "Applications" of container window to {580, 240}
    set position of item "README.txt" of container window to {180, 365}
    set position of item "LICENSE.txt" of container window to {580, 365}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG_PATH"

if [[ "${GLOBE_CODESIGN_IDENTITY:--}" != "-" ]]; then
  codesign --force --timestamp --sign "$GLOBE_CODESIGN_IDENTITY" "$DMG_PATH" >/dev/null
fi

if [[ "${GLOBE_NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${GLOBE_NOTARY_PROFILE:-}" ]]; then
    echo "GLOBE_NOTARY_PROFILE is required when GLOBE_NOTARIZE=1" >&2
    exit 1
  fi
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$GLOBE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi

echo "$DMG_PATH"
