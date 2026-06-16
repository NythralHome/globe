# Globe FAQ

## Why does Globe need Accessibility permission?

macOS requires Accessibility permission for apps that observe global keyboard control events. Globe needs this to detect Globe/Fn key state changes while you are typing in other apps.

Globe does not record typed text.

## Why do I need to set `Press Globe key to` to `Do Nothing`?

macOS can handle Globe/Fn before Globe gets a chance to switch directly. Setting the default macOS Globe action to `Do Nothing` prevents the system from cycling input sources first.

## Does Globe auto-update?

Not silently. Globe checks GitHub Releases only when you ask it to. If a newer version exists, it downloads the signed PKG installer and opens it.

## Where is Globe installed?

The PKG installer installs Globe to:

```text
/Applications/Globe.app
```

## Where is Globe after launch?

Globe is a menu bar app. Look for the globe icon in the macOS menu bar.

## What should I attach to a bug report?

Use Globe > `Export Diagnostics` and attach the generated text file if possible. The report includes app state and logs, but no typed text.

## Can Globe be released on the Mac App Store?

Possibly, but it requires a separate review of sandboxing and Accessibility behavior. The current beta is distributed as a signed and notarized Developer ID installer.
