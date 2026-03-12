# Camera-Man

A small macOS camera overlay app with customizable shapes, draggable window, and status bar menu — similar to [Mini Video Me](https://github.com/maykbrito/mini-video-me), built with SwiftUI.

## Features

- **Camera preview** with selectable video devices
- **Custom shapes**: Circle, Rectangle, Rounded Rectangle (clip applied to preview)
- **Position & zoom**: Offset (arrow keys) and scale (+/-), reset zoom (R)
- **Flip horizontal** (/), **cycle shape** (O), **switch camera** (Backspace), **toggle window size** (Space)
- **Border**: Toggle, width, and color in Settings
- **Settings panel**: Camera, shape, position, zoom, flip, border, window size, screen edge
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

To build a Release version and create a DMG that users can install (drag to Applications):

```bash
./create-dmg.sh
```

This produces `CameraMan-1.0.0.dmg` in the project root. To use a custom version label:

```bash
./create-dmg.sh 1.2.0   # creates CameraMan-1.2.0.dmg
```

You can upload the DMG to GitHub Releases, your website, or any file host for others to download and install.

### Unsigned / un-notarized apps

The DMG is built without Apple code signing or notarization, so macOS Gatekeeper may block it the first time users try to open CameraMan. They may see a message like *“CameraMan can’t be opened because it is from an unidentified developer”* or *“the developer cannot be verified”*.

**How to open the app anyway:**

1. **Right-click (or Control+click) on CameraMan** in Applications (or in the DMG) → **Open** → confirm with **Open** in the dialog. This only needs to be done once; afterward the app will open normally.
2. Alternatively, if a single-click already showed the security dialog: go to **System Settings → Privacy & Security** and scroll to the **Security** section. If macOS shows a line like *“CameraMan was blocked from use because it is not from an identified developer”*, click **Open Anyway** and confirm.

This is expected for apps that are not signed with an Apple Developer account. To distribute without this prompt you would need to [sign and notarize](https://developer.apple.com/documentation/security/notarizing_mac_software_before_distribution) the app (Apple Developer Program required).

## Usage

- **Settings**: Click the gear icon on the preview or use **⌘,**. Use the status bar icon for quick access when the window is in the background.
- **Keyboard shortcuts** (with window focused): Arrows (position), +/− (zoom da câmera), R (reset zoom), / (flip), O (cycle shape), Backspace (next camera), Space (toggle window size).

## License

MIT
