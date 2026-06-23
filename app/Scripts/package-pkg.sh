#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0-beta.18}"
BUILD_DIR="$APP_DIR/.build"
BUNDLE_DIR="$BUILD_DIR/bundles/Globe.app"
DIST_DIR="$BUILD_DIR/dist"
COMPONENT_PKG="$BUILD_DIR/pkg/Globe-component-$VERSION.pkg"
PKG_PATH="$DIST_DIR/Globe-$VERSION.pkg"
SCRIPTS_DIR="$BUILD_DIR/pkg/scripts"
INSTALLER_IDENTITY="${GLOBE_INSTALLER_SIGN_IDENTITY:-}"

"$SCRIPT_DIR/build-app-bundle.sh" >/dev/null

rm -rf "$BUILD_DIR/pkg" "$PKG_PATH"
mkdir -p "$SCRIPTS_DIR" "$DIST_DIR"

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

pkgbuild \
  --component "$BUNDLE_DIR" \
  --install-location /Applications \
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

productbuild "${productbuild_args[@]}" "$PKG_PATH" >/dev/null

if [[ "${GLOBE_NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${GLOBE_NOTARY_PROFILE:-}" ]]; then
    echo "GLOBE_NOTARY_PROFILE is required when GLOBE_NOTARIZE=1" >&2
    exit 1
  fi
  xcrun notarytool submit "$PKG_PATH" --keychain-profile "$GLOBE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG_PATH"
fi

echo "$PKG_PATH"
