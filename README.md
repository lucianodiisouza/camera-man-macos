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

## Usage

- **Settings**: Click the gear icon on the preview or use **⌘,**. Use the status bar icon for quick access when the window is in the background.
- **Keyboard shortcuts** (with window focused): Arrows (position), +/− (zoom da câmera), R (reset zoom), / (flip), O (cycle shape), Backspace (next camera), Space (toggle window size).

## License

MIT
