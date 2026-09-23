# CameraMan

A small macOS camera overlay app with customizable shapes, draggable window, and status bar menu — similar to [Mini Video Me](https://github.com/maykbrito/mini-video-me), built with SwiftUI.

## Features

- **Camera preview** with selectable video devices
- **Shapes**: Circle, Organic (presets, shuffle, optional breathing), Square, Vertical 9:16, Horizontal 16:9; soft edge and corner radius
- **Position & zoom**: Offset (arrow keys) and scale (+/-), reset zoom (R)
- **Flip horizontal** (/), **cycle shape** (O), **switch camera** (Backspace), **toggle window size** (Space)
- **Border**: Toggle, width, and color in Settings
- **Settings window**: System Settings–style sidebar with search: Camera, Shape, Framing, Image, Border & Shadow, Window, General (open at login), Shortcuts, About
- **Made for recording**: global shortcuts (⌃⌥⌘C show/hide, ⌃⌥⌘S size) from any app, follows you across desktops and full-screen apps, camera off while hidden, GPU color correction
- **Languages**: English and Brazilian Portuguese
- **Status bar menu**: Icon in menu bar with Settings, Restore defaults, Window size, Screen edge, Camera list, Quit
- **Persistence**: UserDefaults for all settings

## Requirements

- macOS 14.0+
- Xcode 15+
- Camera (built-in or external)

## Build & Run

1. Open `CameraMan.xcodeproj` in Xcode.
2. Select the **CameraMan** scheme and **My Mac** as destination.
3. Build and run (⌘R).

Or from the command line:

```bash
cd camera-man
xcodebuild -scheme CameraMan -configuration Debug -destination 'platform=macOS' build
open build/Release/CameraMan.app
```

## Creating a DMG for distribution

**Prerequisites:** install [`create-dmg`](https://github.com/create-dmg/create-dmg) (first time only):

```bash
brew install create-dmg
```

To build a Release version and create a DMG that users can install (drag to Applications):

```bash
./create-dmg.sh
```

This produces `CameraMan-<version>.dmg` in the project root, with the version taken from `MARKETING_VERSION` in the Xcode project.

You can upload the DMG to GitHub Releases, your website, or any file host for others to download and install.

### Signing and notarization

`create-dmg.sh` signs the app with a Developer ID certificate (hardened runtime + camera entitlement), notarizes and staples both the app and the DMG, so it opens on any Mac without Gatekeeper warnings. It reads two settings from the environment or from a git-ignored `.env.local`:

```bash
CAMERAMAN_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
CAMERAMAN_NOTARY_PROFILE="your-notary-profile"   # from: xcrun notarytool store-credentials
```

Without them the DMG is still built, but ad-hoc signed, and macOS will block it on other Macs (right-click → Open to get past it).

## Mac App Store

```bash
./appstore.sh            # archive + export a signed .pkg to build/appstore
./appstore.sh --upload   # archive + upload to App Store Connect
```

Signing is automatic through the Apple account in Xcode → Settings → Accounts. Listing text, review notes and screenshot sizes are in [appstore/LISTING.md](appstore/LISTING.md); the privacy policy is [PRIVACY.md](PRIVACY.md).

## Usage

- **Settings**: Use **⌘,** or the menu bar icon. Use the status bar icon for quick access when the window is in the background.
- **Keyboard shortcuts** (with window focused): Arrows (position), +/− (zoom), R (reset zoom), / (flip), O (cycle shape), Backspace (next camera), Space (toggle window size).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community standards. Security issues: [SECURITY.md](SECURITY.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT
