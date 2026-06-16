#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0-beta.4}"
BUILD_DIR="$APP_DIR/.build"
BUNDLE_DIR="$BUILD_DIR/bundles/Globe.app"
DIST_DIR="$BUILD_DIR/dist"
COMPONENT_PKG="$BUILD_DIR/pkg/Globe-component-$VERSION.pkg"
PKG_PATH="$DIST_DIR/Globe-$VERSION.pkg"
INSTALLER_IDENTITY="${GLOBE_INSTALLER_SIGN_IDENTITY:-}"

"$SCRIPT_DIR/build-app-bundle.sh" >/dev/null

rm -rf "$BUILD_DIR/pkg" "$PKG_PATH"
mkdir -p "$BUILD_DIR/pkg" "$DIST_DIR"

pkgbuild \
  --component "$BUNDLE_DIR" \
  --install-location /Applications \
  --identifier dev.nythral.globe \
  --version "$VERSION" \
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
