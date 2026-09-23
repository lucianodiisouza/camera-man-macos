#!/usr/bin/env bash
#
# Archive CameraMan for the Mac App Store.
# Usage:
#   ./appstore.sh            archive and export a signed .pkg into build/appstore (nothing leaves this Mac)
#   ./appstore.sh --upload   archive and upload the build to App Store Connect
#
# Signing is automatic through the Apple account signed in to Xcode (Settings → Accounts). The first run creates the
# Apple Distribution and Mac Installer Distribution certificates and the App Store profile if they are missing.
# The app record must already exist in App Store Connect before --upload.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DESTINATION="export"
[[ "${1:-}" == "--upload" ]] && DESTINATION="upload"

OUT="build/appstore"
ARCHIVE="$OUT/CameraMan.xcarchive"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "→ Archiving CameraMan (Release, universal)..."
xcodebuild -scheme CameraMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet archive

# Same options file, with the destination this run asked for.
OPTIONS="$OUT/ExportOptions.plist"
cp appstore/ExportOptions.plist "$OPTIONS"
/usr/libexec/PlistBuddy -c "Set :destination $DESTINATION" "$OPTIONS"

echo "→ Exporting ($DESTINATION)..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OPTIONS" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE/Info.plist")"
if [[ "$DESTINATION" == "upload" ]]; then
  echo "Done. CameraMan $VERSION ($BUILD) uploaded; it shows up in App Store Connect → TestFlight after processing."
else
  echo "Done. CameraMan $VERSION ($BUILD): $OUT/CameraMan.pkg"
fi
