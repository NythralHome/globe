#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0-beta.14}"
BUILD_NUMBER="${GLOBE_BUILD:-1}"
DISPLAY_NAME="${GLOBE_DISPLAY_NAME:-Globe}"
DISTRIBUTION="${GLOBE_DISTRIBUTION:-developer-id}"
BUNDLE_ID="${GLOBE_BUNDLE_ID:-dev.nythral.globe}"
BUNDLE_DIR="$APP_DIR/.build/bundles/Globe.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGN_IDENTITY="${GLOBE_CODESIGN_IDENTITY:--}"
PROVISIONING_PROFILE="${GLOBE_PROVISIONING_PROFILE:-}"
ENTITLEMENTS=()
SWIFT_FLAGS=()

if [[ "$DISTRIBUTION" == "app-store" ]]; then
    BUNDLE_ID="${GLOBE_BUNDLE_ID:-com.nythral.globe}"
    ENTITLEMENTS=(--entitlements "$APP_DIR/Entitlements/AppStore.entitlements")
    SWIFT_FLAGS=(-Xswiftc -DGLOBE_APP_STORE)
fi

CODESIGN_FLAGS=(--force --deep --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID")

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    CODESIGN_FLAGS+=(--timestamp)
fi

if [[ "$DISTRIBUTION" != "app-store" ]]; then
    CODESIGN_FLAGS+=(--options runtime)
fi

cd "$APP_DIR"
SWIFT_BUILD_COMMAND=(swift build -c release)
if [[ ${#SWIFT_FLAGS[@]} -gt 0 ]]; then
    SWIFT_BUILD_COMMAND+=("${SWIFT_FLAGS[@]}")
fi
"${SWIFT_BUILD_COMMAND[@]}"
"$SCRIPT_DIR/render-assets.swift"

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$APP_DIR/.build/release/Globe" "$MACOS_DIR/Globe"
cp "$APP_DIR/.build/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

if [[ -n "$PROVISIONING_PROFILE" ]]; then
    cp "$PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>Globe</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Globe needs Accessibility permission to observe the Globe/Fn key and switch input sources. It does not record typed text.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
PLIST

CODESIGN_COMMAND=(codesign "${CODESIGN_FLAGS[@]}")
if [[ ${#ENTITLEMENTS[@]} -gt 0 ]]; then
    CODESIGN_COMMAND+=("${ENTITLEMENTS[@]}")
fi
CODESIGN_COMMAND+=("$BUNDLE_DIR")
"${CODESIGN_COMMAND[@]}" >/dev/null

echo "$BUNDLE_DIR"
