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
DMG_TMP="dmg-temp"

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

echo "→ Preparing DMG contents..."
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"
cp -R "$APP_PATH" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

echo "→ Creating ${DMG_NAME}.dmg..."
rm -f "${DMG_NAME}.dmg"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "${DMG_NAME}.dmg"

echo "→ Cleaning up..."
rm -rf "$DMG_TMP"

echo ""
echo "Done. DMG ready: ${DMG_NAME}.dmg"
echo "You can upload this file for users to install (drag to Applications)."
