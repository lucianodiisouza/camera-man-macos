#!/usr/bin/env bash
#
# Build CameraMan in Release and create a DMG for distribution.
# Usage: ./create-dmg.sh [version]
#   version defaults to 1.0.0 (set in Xcode project).
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="${1:-1.0.0}"
APP_NAME="CameraMan"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
BG_IMAGE="dmg-background.png"

# ── 1. Check for create-dmg ──────────────────────────────────────────────────
if ! command -v create-dmg &>/dev/null; then
  echo "Error: 'create-dmg' not found. Install it with:"
  echo "  brew install create-dmg"
  exit 1
fi

# ── 2. Generate background image ────────────────────────────────────────────
echo "→ Generating DMG background..."
python3 dmg-bg.py

# ── 3. Build app ─────────────────────────────────────────────────────────────
echo "→ Building ${APP_NAME} (Release)..."
xcodebuild -scheme CameraMan \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  clean build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: ${APP_PATH} not found after build."
  exit 1
fi

# ── 4. Create DMG ────────────────────────────────────────────────────────────
echo "→ Creating ${DMG_NAME}.dmg..."
rm -f "${DMG_NAME}.dmg"

create-dmg \
  --volname "$APP_NAME" \
  --background "$BG_IMAGE" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 80 \
  --icon "${APP_NAME}.app" 160 185 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 480 185 \
  "${DMG_NAME}.dmg" \
  "${BUILD_DIR}/Build/Products/Release/"

echo ""
echo "Done. DMG ready: ${DMG_NAME}.dmg"
