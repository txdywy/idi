#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/app/idi.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/idi.iconset"
ICON_PATH="$RESOURCES_DIR/idi.icns"

swift build --package-path "$ROOT_DIR" -c release

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"
cp "$ROOT_DIR/.build/release/idi" "$MACOS_DIR/idi"

if command -v sips >/dev/null && command -v iconutil >/dev/null; then
  SVG_ICON="$ROOT_DIR/.build/idi-icon.svg"
  cat > "$SVG_ICON" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="228" fill="#080a0f"/>
  <circle cx="512" cy="512" r="376" fill="#111827" stroke="#8ee6ff" stroke-width="18"/>
  <path d="M286 696V346h92v350h-92Zm180 0V224h92v472h-92Zm180 0V446h92v250h-92Z" fill="#8ee6ff"/>
  <path d="M250 760h524" stroke="#fda085" stroke-width="52" stroke-linecap="round"/>
</svg>
SVG
  for size in 16 32 64 128 256 512; do
    sips -s format png -z "$size" "$size" "$SVG_ICON" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -s format png -z "$double" "$double" "$SVG_ICON" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>idi</string>
  <key>CFBundleIdentifier</key>
  <string>dev.idi.monitor</string>
  <key>CFBundleName</key>
  <string>idi</string>
  <key>CFBundleDisplayName</key>
  <string>idi</string>
  <key>CFBundleIconFile</key>
  <string>idi</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

printf 'Built %s\n' "$APP_DIR"
