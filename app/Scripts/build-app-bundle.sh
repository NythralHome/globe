#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${GLOBE_VERSION:-0.1.0-beta.12}"
BUILD_NUMBER="${GLOBE_BUILD:-1}"
BUNDLE_DIR="$APP_DIR/.build/bundles/Globe.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGN_IDENTITY="${GLOBE_CODESIGN_IDENTITY:--}"

cd "$APP_DIR"
swift build -c release
"$SCRIPT_DIR/render-assets.swift"

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$APP_DIR/.build/release/Globe" "$MACOS_DIR/Globe"
cp "$APP_DIR/.build/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Globe</string>
    <key>CFBundleExecutable</key>
    <string>Globe</string>
    <key>CFBundleIdentifier</key>
    <string>dev.nythral.globe</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Globe</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Globe needs Accessibility permission to observe the Globe/Fn key and switch input sources. It does not record typed text.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --timestamp --options runtime --sign "$SIGN_IDENTITY" --identifier dev.nythral.globe "$BUNDLE_DIR" >/dev/null

echo "$BUNDLE_DIR"
