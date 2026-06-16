# Globe Beta Guide

Globe beta builds are distributed as signed, notarized macOS PKG installers through GitHub Releases and [globe.nythral.com](https://globe.nythral.com).

## Install

1. Download the latest `Globe-*.pkg`.
2. Open the installer package.
3. Complete installation.
4. Globe opens automatically from `/Applications`.
5. Complete the welcome setup.

## Required macOS Setup

Globe needs two manual macOS steps:

1. System Settings > Privacy & Security > Accessibility
   - Add `Globe.app` from `/Applications`.
   - Enable Globe.
2. System Settings > Keyboard
   - Set `Press Globe key to` to `Do Nothing`.

These steps are required because Globe does not use private Apple APIs and macOS does not allow apps to silently grant Accessibility permission.

## Confirm It Works

Open Globe > Settings > Permissions and use `Test Globe key`.

- If the status updates when you press Globe/Fn, Globe can observe the key.
- If it does not update, check Accessibility permission and confirm the app is installed in `/Applications`.

## Updates

Use `Check for Updates` from the menu bar or Settings > About. Globe checks GitHub Releases on demand. If a newer version exists, it downloads the signed PKG installer and opens it.

After the installer finishes, Globe restarts from `/Applications`.

## Privacy

Globe does not record, store, or transmit typed text. It only listens for Globe/Fn key state changes in order to switch input sources.

## Diagnostics

Use `Export Diagnostics` from the menu bar or Settings > About before filing a bug. Attach the exported text file to the GitHub issue if it does not contain anything you consider sensitive.

The report contains version, macOS, Accessibility status, input source names/IDs, key mapping, and recent Globe log lines. It does not contain typed text.

Local logs are written to:

```text
~/Library/Logs/Globe/Globe.log
```
