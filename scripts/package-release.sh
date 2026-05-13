#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/app/idi.app"
RELEASE_DIR="$ROOT_DIR/.build/release"
STAGING_DIR="$RELEASE_DIR/dmg-root"
ZIP_PATH="$RELEASE_DIR/idi.zip"
DMG_PATH="$RELEASE_DIR/idi.dmg"

"$ROOT_DIR/scripts/build-app.sh"
mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH"
rm -rf "$STAGING_DIR"

if command -v codesign >/dev/null; then
  codesign --verify --deep --strict "$APP_DIR"
fi

/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if command -v hdiutil >/dev/null; then
  mkdir -p "$STAGING_DIR"
  /usr/bin/ditto "$APP_DIR" "$STAGING_DIR/idi.app"
  hdiutil create -volname "idi" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
  if command -v codesign >/dev/null; then
    codesign --verify --deep --strict "$STAGING_DIR/idi.app"
  fi
  rm -rf "$STAGING_DIR"
  printf 'Packaged %s and %s\n' "$ZIP_PATH" "$DMG_PATH"
else
  printf 'Packaged %s; hdiutil unavailable, skipped DMG\n' "$ZIP_PATH"
fi

printf 'Release artifacts are ad-hoc signed and not notarized.\n'
