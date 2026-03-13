# Contributing to Camera-Man

Thank you for considering contributing to Camera-Man. Below are some guidelines to make the process smooth.

## How to Contribute

- **Bug reports and feature requests:** Open a [GitHub Issue](https://github.com/oprimodev/camera-man-macos/issues). Use the issue templates if available, and include steps to reproduce for bugs.
- **Code changes:** Open a Pull Request from a fork. Keep PRs focused (one feature or fix per PR) and reference any related issues.

## Development Setup

1. Clone the repo and open `CameraMan.xcodeproj` in Xcode.
2. Requirements: macOS 14.0+, Xcode 15+.
3. Select the **CameraMan** scheme and **My Mac**, then build and run (⌘R).

Command-line build:

```bash
xcodebuild -scheme CameraMan -configuration Debug -destination 'platform=macOS' build
```

## Code and Style

- The project is in **Swift** with **SwiftUI**. Follow existing patterns in the codebase.
- Prefer SwiftUI and native APIs. Keep the UI consistent with the current design.
- No formal style guide is enforced; consistency with the rest of the file and project matters most.

## Pull Request Process

1. Create a branch from `main` (or the default branch).
2. Make your changes and ensure the app builds and runs.
3. Update documentation (e.g. README) if you change behavior or add features.
4. Open a PR with a clear title and description. Link related issues.
5. Maintainers will review and may request changes. Once approved, your PR can be merged.

## Reporting Bugs

Include:

- macOS version and (if relevant) Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or logs if helpful

## Feature Ideas

Open an issue with the “enhancement” or “feature” label. Describe the use case and, if you can, a rough approach. Discussion there helps before you invest in a large PR.

## License

By contributing, you agree that your contributions will be licensed under the same [MIT License](LICENSE) that covers this project.
