#!/usr/bin/env bash
# Remove Camera-Man app and all its data from this Mac.

set -e
BUNDLE_ID="com.cameraman.app"
APP_NAMES=("Camera-Man" "CameraMan")

echo "Stopping Camera-Man if running..."
for name in "${APP_NAMES[@]}"; do
  pkill -x "$name" 2>/dev/null || true
done
# Also by bundle id (e.g. when run from Xcode)
killall "Camera-Man" 2>/dev/null || true
killall "CameraMan" 2>/dev/null || true
sleep 1

echo "Removing application..."
for name in "${APP_NAMES[@]}"; do
  if [[ -d "/Applications/$name.app" ]]; then
    rm -rf "/Applications/$name.app"
    echo "  Removed /Applications/$name.app"
  fi
done

echo "Removing DerivedData..."
DERIVED=~/Library/Developer/Xcode/DerivedData
if [[ -d "$DERIVED" ]]; then
  while IFS= read -r -d '' dir; do
    rm -rf "$dir"
    echo "  Removed $(basename "$dir")"
  done < <(find "$DERIVED" -maxdepth 1 -type d -name "CameraMan-*" -print0 2>/dev/null)
  # Also remove any standalone CameraMan.app build product
  find "$DERIVED" -name "CameraMan.app" -type d -print0 2>/dev/null | while IFS= read -r -d '' app; do
    rm -rf "$app"
    echo "  Removed $app"
  done
fi

echo "Removing support files..."
[[ -d "$HOME/Library/Application Support/$BUNDLE_ID" ]] && rm -rf "$HOME/Library/Application Support/$BUNDLE_ID" && echo "  Removed Application Support/$BUNDLE_ID"
[[ -f "$HOME/Library/Preferences/$BUNDLE_ID.plist" ]] && rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist" && echo "  Removed Preferences/$BUNDLE_ID.plist"
[[ -d "$HOME/Library/Caches/$BUNDLE_ID" ]] && rm -rf "$HOME/Library/Caches/$BUNDLE_ID" && echo "  Removed Caches/$BUNDLE_ID"
[[ -d "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" ]] && rm -rf "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" && echo "  Removed Saved Application State"

echo "Camera-Man has been removed from this Mac."
