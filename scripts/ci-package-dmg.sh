#!/bin/bash
set -euo pipefail

VERSION="${1:-unknown}"
APP_NAME="FriSpeak"
BUILD_DIR="build"
EXPORT_DIR="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "=== Packaging $APP_NAME $VERSION ==="

rm -f "$DMG_PATH"

if command -v create-dmg &>/dev/null; then
  echo "Using create-dmg for branded DMG..."

  ICON_SRC="$EXPORT_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"

  DMG_ARGS=(
    --volname "$APP_NAME $VERSION"
    --window-pos 200 120
    --window-size 600 400
    --icon-size 100
    --icon "$APP_NAME.app" 175 120
    --hide-extension "$APP_NAME.app"
    --app-drop-link 425 120
  )

  if [ -f "$ICON_SRC" ]; then
    DMG_ARGS+=(--volicon "$ICON_SRC")
    echo "  Using app icon for volume icon"
  fi

  create-dmg "${DMG_ARGS[@]}" "$DMG_PATH" "$EXPORT_DIR/"

  echo "Branded DMG created."
else
  echo "create-dmg not found, falling back to basic hdiutil..."

  STAGING="$BUILD_DIR/dmg_staging"
  rm -rf "$STAGING"
  mkdir -p "$STAGING"
  cp -R "$EXPORT_DIR/$APP_NAME.app" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"

  SIZE=$(du -sk "$STAGING" | cut -f1)
  TMP_DMG="${DMG_PATH%.dmg}_tmp.dmg"

  hdiutil create -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    -size $((SIZE + 20480))k \
    "$TMP_DMG"

  hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov -o "$DMG_PATH"

  rm -f "$TMP_DMG"
  rm -rf "$STAGING"
  echo "Basic DMG created."
fi

ls -lh "$DMG_PATH"
