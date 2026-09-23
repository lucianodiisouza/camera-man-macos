#!/usr/bin/env bash
#
# Build CameraMan in Release, sign it with Developer ID, notarize it and wrap it in a notarized DMG.
# Usage: ./create-dmg.sh
#   The version comes from MARKETING_VERSION in the Xcode project.
#
# Env (or .env.local next to this script, which is git-ignored):
#   CAMERAMAN_SIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"
#   CAMERAMAN_NOTARY_PROFILE  keychain profile from `xcrun notarytool store-credentials`
#
# Without CAMERAMAN_SIGN_IDENTITY the app is ad-hoc signed and Gatekeeper will block it on other Macs.
# Without CAMERAMAN_NOTARY_PROFILE it is signed but not notarized, and Gatekeeper still warns.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -f .env.local ]]; then
  # What the caller exported still wins over the file.
  ENV_BEFORE="$(export -p)"
  set -a
  # shellcheck disable=SC1091
  . ./.env.local
  set +a
  eval "$ENV_BEFORE" 2>/dev/null || true
fi

IDENTITY="${CAMERAMAN_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${CAMERAMAN_NOTARY_PROFILE:-}"

APP_NAME="CameraMan"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
ENTITLEMENTS="CameraMan/CameraMan.entitlements"
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
# Built ad-hoc, then signed below with the Developer ID, so Xcode's automatic signing never picks a development cert.
echo "→ Building ${APP_NAME} (Release)..."
xcodebuild -scheme CameraMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -quiet clean build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: ${APP_PATH} not found after build."
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_NAME="${APP_NAME}-${VERSION}"
echo "→ ${APP_NAME} ${VERSION}"

# ── 4. Sign + notarize the app ───────────────────────────────────────────────
if [[ -n "$IDENTITY" ]]; then
  echo "→ Signing with: $IDENTITY"
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" \
    "$APP_PATH"
  codesign --verify --strict --verbose=2 "$APP_PATH"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
    echo "→ Notarizing the app (usually a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$ZIP_PATH"
    xcrun stapler staple "$APP_PATH"
  else
    echo "  (CAMERAMAN_NOTARY_PROFILE not set — skipping notarization)"
  fi
else
  echo "  (CAMERAMAN_SIGN_IDENTITY not set — the app stays ad-hoc signed)"
fi

# ── 5. Create DMG ────────────────────────────────────────────────────────────
echo "→ Creating ${DMG_NAME}.dmg..."
rm -f "${DMG_NAME}.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_PATH" "$STAGING/${APP_NAME}.app"

DMG_SIGN_ARGS=()
[[ -n "$IDENTITY" ]] && DMG_SIGN_ARGS+=(--codesign "$IDENTITY")

create-dmg \
  --volname "$APP_NAME" \
  --background "$BG_IMAGE" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 80 \
  --icon "${APP_NAME}.app" 160 185 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 480 185 \
  ${DMG_SIGN_ARGS[@]+"${DMG_SIGN_ARGS[@]}"} \
  "${DMG_NAME}.dmg" \
  "$STAGING/"

if [[ -n "$IDENTITY" && -n "$NOTARY_PROFILE" ]]; then
  echo "→ Notarizing the DMG..."
  xcrun notarytool submit "${DMG_NAME}.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "${DMG_NAME}.dmg"

  # ── 6. Verify ──────────────────────────────────────────────────────────────
  echo "→ Verifying..."
  xcrun stapler validate "$APP_PATH"
  xcrun stapler validate "${DMG_NAME}.dmg"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "${DMG_NAME}.dmg"
fi

echo ""
echo "Done. DMG ready: ${DMG_NAME}.dmg"
