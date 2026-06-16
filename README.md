# Globe

A predictable macOS Globe/Fn key input source switcher.

Globe is a small native macOS menu bar utility that makes language switching direct and intentional:

- Press Globe/Fn once to switch to language #1.
- Press Globe/Fn twice to switch to language #2.
- Press Globe/Fn three times to switch to language #3.
- Press and hold Globe/Fn to open Globe settings.

## Status

Globe is in early development. The current repository contains the initial Swift package structure, core press interpretation logic, and native macOS integration scaffolding.

## Repository Layout

- `app/` - macOS app source code and tests.
- `.github/` - issue and pull request templates.

## Installation

Globe is currently available as a beta build. See [docs/BETA.md](docs/BETA.md) for beta installation and setup.

During development, build and run the app from the Swift package in `app/`.

```sh
cd app
swift test
swift run Globe
```

## Accessibility Permission

Globe needs macOS Accessibility permission to observe global keyboard control events. The app only handles the Globe/Fn behavior needed for input source switching.

To enable permission manually:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable Globe.

Globe should also guide users to this screen from the app when permission is missing.

## Default macOS Globe Behavior

For the most predictable behavior, disable the default macOS Globe/Fn language switching action in System Settings. Globe does not use private Apple APIs to change this setting automatically.

## Privacy

Globe does not record, store, or transmit typed text. It only listens for the Globe/Fn key in order to switch input sources.

## Development

Requirements:

- macOS
- Xcode command line tools
- Swift 6 or newer

Run tests:

```sh
cd app
swift test
```

Build a local `.app` bundle:

```sh
app/Scripts/build-app-bundle.sh
open app/.build/bundles/Globe.app
```

The generated bundle is local build output and is not committed.

Build a beta `.dmg`:

```sh
app/Scripts/package-beta.sh
open app/.build/dist/Globe-0.1.0-beta.5.dmg
```

Build a beta `.pkg` installer:

```sh
app/Scripts/package-pkg.sh
open app/.build/dist/Globe-0.1.0-beta.5.pkg
```

To sign the `.pkg`, install a `Developer ID Installer` certificate and pass
`GLOBE_INSTALLER_SIGN_IDENTITY`.

For manual Accessibility testing, copy the generated bundle into `/Applications`, add that copy in System Settings, and relaunch it:

```sh
cp -R app/.build/bundles/Globe.app /Applications/Globe.app
open /Applications/Globe.app
```

macOS may not grant a stable Accessibility identity to an ad-hoc app launched directly from `.build`.

## Roadmap

- Global Globe/Fn event tap
- Direct input source assignment
- Menu bar controls
- Settings window
- Launch at login
- Optional switching HUD
- Signed release builds

## Screenshots

Screenshots will be added after the first usable UI milestone.

## License

MIT
