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

extract_profile_value() {
    local profile_plist="$1"
    local plist_path="$2"
    /usr/libexec/PlistBuddy -c "Print $plist_path" "$profile_plist" 2>/dev/null || true
}

write_app_store_entitlements() {
    local output_path="$1"
    local team_id="${GLOBE_TEAM_ID:-}"
    local app_identifier="${GLOBE_APPLICATION_IDENTIFIER:-}"
    local keychain_group="${GLOBE_KEYCHAIN_GROUP:-}"

    if [[ -n "$PROVISIONING_PROFILE" && -f "$PROVISIONING_PROFILE" ]]; then
        local profile_plist
        profile_plist="$(mktemp)"
        security cms -D -i "$PROVISIONING_PROFILE" > "$profile_plist"
        team_id="${team_id:-$(extract_profile_value "$profile_plist" ":TeamIdentifier:0")}"
        app_identifier="${app_identifier:-$(extract_profile_value "$profile_plist" ":Entitlements:com.apple.application-identifier")}"
        keychain_group="${keychain_group:-$(extract_profile_value "$profile_plist" ":Entitlements:keychain-access-groups:0")}"
        rm -f "$profile_plist"
    fi

    mkdir -p "$(dirname "$output_path")"
    {
        cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
PLIST
        if [[ -n "$app_identifier" ]]; then
            cat <<PLIST
    <key>com.apple.application-identifier</key>
    <string>$app_identifier</string>
PLIST
        fi
        if [[ -n "$team_id" ]]; then
            cat <<PLIST
    <key>com.apple.developer.team-identifier</key>
    <string>$team_id</string>
PLIST
        fi
        cat <<PLIST
    <key>com.apple.security.app-sandbox</key>
    <true/>
PLIST
        if [[ -n "$keychain_group" ]]; then
            cat <<PLIST
    <key>keychain-access-groups</key>
    <array>
        <string>$keychain_group</string>
    </array>
PLIST
        fi
        cat <<PLIST
</dict>
</plist>
PLIST
    } > "$output_path"
}

if [[ "$DISTRIBUTION" == "app-store" ]]; then
    BUNDLE_ID="${GLOBE_BUNDLE_ID:-com.nythral.globe}"
    GENERATED_ENTITLEMENTS="$APP_DIR/.build/generated/AppStore.entitlements"
    write_app_store_entitlements "$GENERATED_ENTITLEMENTS"
    ENTITLEMENTS=(--entitlements "$GENERATED_ENTITLEMENTS")
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

ACCESSIBILITY_USAGE_PLIST=""
if [[ "$DISTRIBUTION" != "app-store" ]]; then
    ACCESSIBILITY_USAGE_PLIST='
    <key>NSAccessibilityUsageDescription</key>
    <string>Globe needs Input Monitoring permission to observe the Globe/Fn key and switch input sources. It does not record typed text.</string>'
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
$ACCESSIBILITY_USAGE_PLIST
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
