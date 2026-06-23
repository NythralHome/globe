# Mac App Store Build

Globe has two distribution flavors from the same `main` branch.

- **Nythral Globe for the Mac App Store** uses a registered global shortcut, `Control-Option-Z`, through Carbon `RegisterEventHotKey`. It does not request Accessibility or Input Monitoring access.
- **Globe Pro** is the signed and notarized Developer ID installer from `globe.nythral.com`. It keeps direct Globe/Fn switching through Input Monitoring.

## Current Status

- Bundle ID: `com.nythral.globe`
- App Store Connect Apple ID: `6781046732`
- App Store package script: `app/Scripts/package-app-store.sh`
- Current package path: `app/.build/app-store/Globe-0.1.0-38-mas.pkg`
- App Store build flag: `GLOBE_DISTRIBUTION=app-store`

## App Store Behavior

The App Store build is sandboxed and avoids Accessibility-only APIs for non-accessibility purposes.

- Default global trigger: `Control-Option-Z`
- Users can change the main action shortcut in Settings.
- Single, double, and triple presses of the main shortcut map to configured input sources.
- Users can also assign direct shortcuts to individual input sources, such as `Control-1` for one language and `Control-2` for another.
- Launch at Login is never enabled automatically; it is controlled only by an explicit user toggle.
- Updates are handled by the Mac App Store.
- The app does not record typed text, inspect character key presses, or transmit keyboard data.

## Pro Behavior

The Pro build is distributed outside the Mac App Store as a signed and notarized installer.

- Global trigger: direct Globe/Fn key.
- Single, double, triple, and long Globe/Fn actions are supported.
- Input Monitoring is requested only for direct Globe/Fn key state detection.
- Updates can be downloaded from GitHub Releases or the product website.

## Build

Build a sandboxed App Store bundle:

```sh
cd app
GLOBE_DISTRIBUTION=app-store GLOBE_VERSION=0.1.0 GLOBE_BUILD=38 Scripts/build-app-bundle.sh
```

Build the App Store upload package:

```sh
cd app
Scripts/package-app-store.sh
```

The App Store package uses `CFBundleShortVersionString=0.1.0` and `CFBundleVersion=38`. Keep beta labels in App Store/TestFlight metadata, not in `CFBundleShortVersionString`.

## Suggested Review Notes

Nythral Globe is a native macOS menu bar utility for predictable input source switching.

This build does not request Accessibility or Input Monitoring access. It uses the system global hotkey API (`RegisterEventHotKey`) to register user-configurable global shortcuts. The default action shortcut is `Control-Option-Z`; users can map single, double, and triple presses of that shortcut to specific macOS input sources, and can also assign direct shortcuts to individual input sources.

Launch at Login is not enabled automatically. It is available only as an explicit user-controlled toggle in settings.

To test:

1. Install and launch Nythral Globe.
2. Open Settings > Key Actions and assign input sources to single, double, and triple shortcut actions.
3. Press `Control-Option-Z` from another app to switch to the configured input source.
4. Optionally assign direct shortcuts to input sources, for example `Control-1` and `Control-2`, then test them from another app.

## Apple References

- [Mac App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Distributing apps for macOS](https://developer.apple.com/macos/distribution/)
- [Preparing for App Review](https://developer.apple.com/distribute/app-review/)
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
