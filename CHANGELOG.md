# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- (Add new changes here before releasing)

## [1.1.0] - 2026-09-22

### Added

- New settings window in the style of System Settings: sidebar with search (⌘F), colored pages, card rows
- Visual shape picker with live previews
- Organic shape, rebuilt: five smooth presets (Pebble, Cloud, Bean, Drop, Wave), Shuffle, and optional Breathing motion
- Soft edge for every shape: the camera fades out toward the outline instead of a hard cut
- Open at login
- Global shortcuts from any app: ⌃⌥⌘C shows / hides the camera, ⌃⌥⌘S switches size
- Show / Hide Camera in the menu bar; the camera turns off (light off) while hidden, and ⌘W hides instead of closing
- The camera follows you to every desktop and over full-screen apps
- Settings point to the macOS video effects (Portrait, Studio Light, Background) in the menu bar
- Hide Dock icon option (menu bar only)
- App Sandbox; submitted to the Mac App Store as "CameraMan: Floating Webcam"
- Brazilian Portuguese (pt-BR); Settings → General → Language picks the language just for CameraMan
- App icon
- Signed with Developer ID and notarized by Apple: opens without Gatekeeper warnings

### Changed

- Bundle identifier is now `dev.oprimo.CameraMan` (settings from 1.0 start fresh)
- Restore defaults asks for confirmation from the menu bar too
- Sharper image: the camera now runs at its best quality instead of 480×360
- About 90% less CPU: color correction runs on the GPU instead of filtering every frame on the CPU
- The camera stops while the screen sleeps or is locked

### Removed

- The old random / hand-drawn custom shapes (they had visible corners); replaced by the new organic shape

### Fixed

- Border, gradient and shadow colors were never saved and reset on every launch

## [1.0.0] - 2025-02-09

### Added

- Camera preview with selectable video devices
- Custom shapes: Circle, Rectangle, Rounded Rectangle
- Position and zoom controls (arrow keys, +/-, R to reset)
- Flip horizontal, cycle shape, switch camera, toggle window size
- Border settings (toggle, width, color)
- Settings panel and status bar menu
- Persistence of settings via UserDefaults
- DMG build script and distribution instructions

[Unreleased]: https://github.com/oprimodev/camera-man-macos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/oprimodev/camera-man-macos/releases/tag/v1.0.0
