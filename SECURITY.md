# Security Policy

## Supported Versions

We release updates for the latest major version. Security fixes may be backported to previous versions when practical.

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security issue in CameraMan, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities.
2. **Email** the maintainers (e.g. via the email listed in your Git config for the repo, or open an issue asking for a private contact) with:
   - A clear description of the vulnerability
   - Steps to reproduce
   - Impact and possible mitigations (if you have ideas)
3. We will acknowledge your report and work on a fix. We may ask for more details.
4. After a fix is released, we can credit you in the release notes (unless you prefer to stay anonymous).

We appreciate the effort of security researchers and will do our best to respond in a timely manner.

## Scope

CameraMan is a local macOS app that uses the camera and stores settings in UserDefaults. In scope: issues that could lead to unauthorized camera access, data exposure, or code execution. Out of scope: issues that require physical access, already compromised machine, or issues in macOS/Xcode themselves (report those to Apple).
