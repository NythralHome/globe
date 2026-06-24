#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=version.sh
source "$SCRIPT_DIR/version.sh"
VERSION="${GLOBE_VERSION:-$GLOBE_DEFAULT_VERSION}"
BUILD_DIR="$APP_DIR/.build"
BUNDLE_DIR="$BUILD_DIR/bundles/Globe.app"
DIST_DIR="$BUILD_DIR/dist"
COMPONENT_PKG="$BUILD_DIR/pkg/Globe-component-$VERSION.pkg"
PKG_PATH="$DIST_DIR/Globe-$VERSION.pkg"
SCRIPTS_DIR="$BUILD_DIR/pkg/scripts"
STAGING_ROOT="$BUILD_DIR/pkg/root"
STAGED_APP="$STAGING_ROOT/Applications/Globe.app"
COMPONENT_PLIST="$BUILD_DIR/pkg/components.plist"
INSTALLER_IDENTITY="${GLOBE_INSTALLER_SIGN_IDENTITY:-}"

"$SCRIPT_DIR/build-app-bundle.sh" >/dev/null

rm -rf "$BUILD_DIR/pkg" "$PKG_PATH"
mkdir -p "$SCRIPTS_DIR" "$DIST_DIR" "$(dirname "$STAGED_APP")"

dot_clean "$BUNDLE_DIR" >/dev/null 2>&1 || true
xattr -cr "$BUNDLE_DIR" >/dev/null 2>&1 || true
find "$BUNDLE_DIR" -name '._*' -delete
ditto --norsrc --noextattr "$BUNDLE_DIR" "$STAGED_APP"
dot_clean "$STAGING_ROOT" >/dev/null 2>&1 || true
xattr -cr "$STAGING_ROOT" >/dev/null 2>&1 || true
find "$STAGING_ROOT" -name '._*' -delete
pkgbuild --analyze --root "$STAGING_ROOT" "$COMPONENT_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"

cat > "$SCRIPTS_DIR/postinstall" <<'SCRIPT'
#!/bin/sh
set -eu

APP_PATH="/Applications/Globe.app"
CONSOLE_USER="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null || true)"

if [ -d "$APP_PATH" ] && [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
  USER_ID="$(/usr/bin/id -u "$CONSOLE_USER" 2>/dev/null || true)"
  if [ -n "$USER_ID" ]; then
    /bin/launchctl asuser "$USER_ID" /usr/bin/osascript -e 'tell application id "dev.nythral.globe" to quit' >/dev/null 2>&1 || true
    /bin/sleep 1
    /usr/bin/pkill -x Globe >/dev/null 2>&1 || true
    /bin/sleep 1
    /bin/launchctl asuser "$USER_ID" /usr/bin/open "$APP_PATH" >/dev/null 2>&1 || true
  fi
fi

exit 0
SCRIPT
chmod 755 "$SCRIPTS_DIR/postinstall"

COPYFILE_DISABLE=1 pkgbuild \
  --root "$STAGING_ROOT" \
  --component-plist "$COMPONENT_PLIST" \
  --install-location / \
  --identifier dev.nythral.globe \
  --version "$VERSION" \
  --scripts "$SCRIPTS_DIR" \
  "$COMPONENT_PKG" >/dev/null

productbuild_args=(
  --package "$COMPONENT_PKG"
)

if [[ -n "$INSTALLER_IDENTITY" ]]; then
  productbuild_args+=(--sign "$INSTALLER_IDENTITY")
fi

COPYFILE_DISABLE=1 productbuild "${productbuild_args[@]}" "$PKG_PATH" >/dev/null

if [[ "${GLOBE_NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${GLOBE_NOTARY_PROFILE:-}" ]]; then
    echo "GLOBE_NOTARY_PROFILE is required when GLOBE_NOTARIZE=1" >&2
    exit 1
  fi
  xcrun notarytool submit "$PKG_PATH" --keychain-profile "$GLOBE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG_PATH"
fi

echo "$PKG_PATH"
