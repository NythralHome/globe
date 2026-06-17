# Mac App Store Readiness

Globe is currently ready for Developer ID distribution outside the Mac App Store. The public beta PKG is signed with Developer ID Installer, notarized by Apple, stapled, and distributed through GitHub Releases.

The Mac App Store path needs a separate build and review track. Apple requires Mac App Store apps to be sandboxed, submitted as app bundles through App Store Connect/Xcode tooling, and updated by the App Store rather than by a third-party installer.

Current preparation status:

- Bundle ID `com.nythral.globe` exists in App Store Connect.
- App Store Connect app record exists as `Nythral Globe` with Apple ID `6781046732`.
- A Mac App Store provisioning profile exists for `com.nythral.globe`.
- Local Apple Distribution and Mac Installer Distribution signing identities are installed on the build Mac.
- `app/Scripts/package-app-store.sh` builds `app/.build/app-store/Globe-0.1.0-29-mas.pkg`.
- `Globe-0.1.0-14-mas.pkg` was validated and uploaded successfully through `altool`; delivery UUID `427c91d3-8150-410f-a994-bc92975231c8` returned `build-status: VALID`.

## Main Risk

Globe's core feature depends on observing the Globe/Fn key globally and requesting Input Monitoring permission. Before submitting to App Review, we need to prove that the same behavior works in a sandboxed App Store/TestFlight build.

Decision gate:

- If a sandboxed TestFlight build can observe Globe/Fn reliably, continue toward App Store submission.
- If sandboxing prevents reliable key observation, keep Developer ID distribution as the primary channel and do not submit the current architecture to the Mac App Store.

## Technical Checklist

- Create a dedicated App Store build configuration or Xcode archive path.
- Add App Sandbox entitlement with the smallest possible entitlement set.
- Remove the PKG/postinstall flow from the App Store build. App Store installs and updates must be handled by Apple.
- Disable direct GitHub installer downloads in the App Store build. The update UI can show release notes, but installation should route through the App Store.
- Test first-run onboarding, Input Monitoring permission request, launch at login, and Globe/Fn detection in a sandboxed local build.
- Submit an internal TestFlight build and retest on a clean Mac user account.
- Add a public privacy policy URL: `https://globe.nythral.com/privacy`.
- Use the App Store build flag: `GLOBE_DISTRIBUTION=app-store`.
- Add complete App Store metadata, screenshots, support URL, marketing URL, age rating, and review notes.
- Include App Review notes explaining why Input Monitoring permission is requested and that Globe does not record typed text.

## Metadata Checklist

- App Store listing name: `Nythral Globe` (`Globe` was unavailable in App Store Connect).
- Subtitle: direct Globe/Fn input source switching.
- Description: native macOS menu bar utility for people who type in multiple languages.
- Privacy: no typed text is recorded, stored, or transmitted.
- Privacy policy URL: `https://globe.nythral.com/privacy`
- Support URL: GitHub Issues or a Globe support page.
- Marketing URL: `https://globe.nythral.com`
- Screenshots: welcome setup, settings tabs, key actions, permissions, and menu bar behavior.
- Review notes: include setup steps for `Press Globe key to: Do Nothing` and Input Monitoring permission.

## Local App Store Build Probe

Build a sandboxed local bundle:

```sh
cd app
GLOBE_DISTRIBUTION=app-store GLOBE_VERSION=0.1.0 GLOBE_BUILD=29 Scripts/build-app-bundle.sh
```

The local probe uses ad-hoc signing unless `GLOBE_CODESIGN_IDENTITY` is set. It verifies that the app can be built with App Sandbox entitlements and the `GLOBE_APP_STORE` compile flag. A real App Store upload still needs Apple distribution signing through App Store Connect/Xcode tooling.

Build a Mac App Store upload package when Apple Distribution, Mac Installer Distribution, and a Mac App Store provisioning profile are installed locally:

```sh
cd app
Scripts/package-app-store.sh
```

The App Store package uses `CFBundleShortVersionString=0.1.0` and `CFBundleVersion=29`. Keep beta labels in App Store/TestFlight metadata, not in `CFBundleShortVersionString`. The generated `Info.plist` includes `ITSAppUsesNonExemptEncryption=false` so App Store Connect can detect export compliance automatically.

Expected package path:

```text
app/.build/app-store/Globe-0.1.0-29-mas.pkg
```

## Suggested Review Notes

Globe is a macOS menu bar utility that lets users map single, double, triple, and long Globe/Fn key presses to input source actions. It requests Input Monitoring permission only to observe Globe/Fn key state changes globally. Globe does not record typed text, keystroke contents, or user documents.

To test:

1. Install and launch Globe.
2. In System Settings > Keyboard, set `Press Globe key to` to `Do Nothing`.
3. In Globe setup, click `Request Input Monitoring`, then enable Globe in System Settings > Privacy & Security > Input Monitoring.
4. Open Globe Settings > Permissions and use `Test Globe key`.
5. Configure input sources in Settings > Key Actions and press Globe/Fn.

## Apple References

- [Mac App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Distributing apps for macOS](https://developer.apple.com/macos/distribution/)
- [Preparing for App Review](https://developer.apple.com/distribute/app-review/)
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
