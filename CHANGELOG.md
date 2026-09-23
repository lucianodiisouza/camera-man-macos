# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- (Add new changes here before releasing)

## [1.1.0] - 2026-09-22

### Added

- New settings window in the style of System Settings: sidebar with search (⌘F), colored pages, card rows
- Visual shape picker with live previews
- Open at login
- App icon
- Signed with Developer ID and notarized by Apple: opens without Gatekeeper warnings

### Changed

- Bundle identifier is now `dev.oprimo.CameraMan` (settings from 1.0 start fresh)
- Restore defaults asks for confirmation from the menu bar too

### Removed

- Organic / hand-drawn custom shapes

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
