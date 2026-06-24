#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=version.sh
source "$SCRIPT_DIR/version.sh"
VERSION="${GLOBE_VERSION:-$GLOBE_DEFAULT_APPSTORE_VERSION}"
BUILD_NUMBER="${GLOBE_BUILD:-$GLOBE_DEFAULT_APPSTORE_BUILD}"
DIST_DIR="$APP_DIR/.build/app-store"
PKG_PATH="$DIST_DIR/Globe-$VERSION-$BUILD_NUMBER-mas.pkg"
STAGING_DIR="${TMPDIR:-/tmp}/globe-mas-package"
STAGED_APP="$STAGING_DIR/Globe.app"
PROVISIONING_PROFILE="${GLOBE_PROVISIONING_PROFILE:-$APP_DIR/../signing-private/Globe-Mac-App-Store-2026.mobileprovision}"

profile_value() {
    local profile_plist="$1"
    local plist_path="$2"
    /usr/libexec/PlistBuddy -c "Print $plist_path" "$profile_plist" 2>/dev/null || true
}

find_identity() {
    local prefix="$1"
    local team_id="$2"
    security find-identity -v | awk -v prefix="$prefix" -v team_id="$team_id" '
        index($0, "\"" prefix) && index($0, "(" team_id ")") {
            identity = $0
            sub(/^[^"]*"/, "", identity)
            sub(/"[^"]*$/, "", identity)
            print identity
            exit
        }
    '
}

if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
    echo "Missing provisioning profile: $PROVISIONING_PROFILE" >&2
    exit 1
fi

PROFILE_PLIST="$(mktemp)"
security cms -D -i "$PROVISIONING_PROFILE" > "$PROFILE_PLIST"
TEAM_ID="$(profile_value "$PROFILE_PLIST" ":TeamIdentifier:0")"
rm -f "$PROFILE_PLIST"

if [[ -z "$TEAM_ID" ]]; then
    echo "Could not read TeamIdentifier from provisioning profile." >&2
    exit 1
fi

APP_SIGN_IDENTITY="${GLOBE_CODESIGN_IDENTITY:-$(find_identity "Apple Distribution:" "$TEAM_ID")}"
INSTALLER_SIGN_IDENTITY="${GLOBE_INSTALLER_SIGN_IDENTITY:-$(find_identity "3rd Party Mac Developer Installer:" "$TEAM_ID")}"

if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    echo "Missing Apple Distribution signing identity for team $TEAM_ID." >&2
    exit 1
fi

if [[ -z "$INSTALLER_SIGN_IDENTITY" ]]; then
    echo "Missing 3rd Party Mac Developer Installer signing identity for team $TEAM_ID." >&2
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
