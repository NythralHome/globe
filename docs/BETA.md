# Globe Beta

Globe is currently distributed as a beta macOS app.

## Install

1. Download `Globe-0.1.0-beta.6.pkg`.
2. Open the installer package.
3. Complete the installer.
4. Globe opens automatically from Applications.
5. Complete the welcome setup.

## Required macOS Setup

Globe needs two manual macOS steps:

1. System Settings > Privacy & Security > Accessibility
   - Add `Globe.app` from Applications.
   - Enable Globe.
2. System Settings > Keyboard
   - Set `Press Globe key to` to `Do Nothing`.

These steps are required because Globe does not use private Apple APIs.

If Globe warns that it is running from a temporary protected location, quit it,
drag `Globe.app` to Applications from the disk image, and launch the copy in
Applications. This keeps macOS Accessibility permission attached to the installed
app.

## Privacy

Globe does not record, store, or transmit typed text. It only listens for Globe/Fn key state changes in order to switch input sources.

## Diagnostics

Diagnostic logs are written to:

```text
~/Library/Logs/Globe/Globe.log
```

The log records setup state, permission state, Globe/Fn key state changes, and input source switching results. It does not log typed text.
