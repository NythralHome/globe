#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0}"
BUILD_NUMBER="${GLOBE_BUILD:-28}"
DIST_DIR="$APP_DIR/.build/app-store"
PKG_PATH="$DIST_DIR/Globe-$VERSION-$BUILD_NUMBER-mas.pkg"
STAGING_DIR="${TMPDIR:-/tmp}/globe-mas-package"
STAGED_APP="$STAGING_DIR/Globe.app"
APP_SIGN_IDENTITY="${GLOBE_CODESIGN_IDENTITY:-Apple Distribution: Sergey Plagov (V989445HKJ)}"
INSTALLER_SIGN_IDENTITY="${GLOBE_INSTALLER_SIGN_IDENTITY:-3rd Party Mac Developer Installer: Sergey Plagov (V989445HKJ)}"
PROVISIONING_PROFILE="${GLOBE_PROVISIONING_PROFILE:-$APP_DIR/../signing-private/Globe-Mac-App-Store-2026.mobileprovision}"

if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
    echo "Missing provisioning profile: $PROVISIONING_PROFILE" >&2
    exit 1
fi

mkdir -p "$DIST_DIR"

APP_BUNDLE="$(
    GLOBE_DISTRIBUTION=app-store \
    GLOBE_VERSION="$VERSION" \
    GLOBE_BUILD="$BUILD_NUMBER" \
    GLOBE_CODESIGN_IDENTITY="$APP_SIGN_IDENTITY" \
    GLOBE_PROVISIONING_PROFILE="$PROVISIONING_PROFILE" \
    "$SCRIPT_DIR/build-app-bundle.sh" | tail -n 1
)"

rm -f "$PKG_PATH"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
ditto --norsrc --noextattr "$APP_BUNDLE" "$STAGED_APP"
APP_BUNDLE="$STAGED_APP"

dot_clean "$APP_BUNDLE" >/dev/null 2>&1 || true
xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true

COPYFILE_DISABLE=1 productbuild \
    --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_SIGN_IDENTITY" \
    "$PKG_PATH" >/dev/null

pkgutil --check-signature "$PKG_PATH" >/dev/null

echo "$PKG_PATH"
