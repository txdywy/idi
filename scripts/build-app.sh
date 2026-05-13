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
  <defs>
    <linearGradient id="bg" x1="160" y1="104" x2="864" y2="920" gradientUnits="userSpaceOnUse">
      <stop stop-color="#101824"/>
      <stop offset="0.54" stop-color="#05070C"/>
      <stop offset="1" stop-color="#111015"/>
    </linearGradient>
    <linearGradient id="ring" x1="238" y1="212" x2="790" y2="822" gradientUnits="userSpaceOnUse">
      <stop stop-color="#8EE6FF"/>
      <stop offset="0.52" stop-color="#D8F7FF"/>
      <stop offset="1" stop-color="#F6B875"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="236" fill="url(#bg)"/>
  <path d="M512 132 830 316v392L512 892 194 708V316L512 132Z" fill="#0B111A" stroke="url(#ring)" stroke-width="28"/>
  <path d="M512 214 758 356v312L512 810 266 668V356L512 214Z" fill="#111A25" stroke="#253344" stroke-width="10"/>
  <path d="M344 648V424h80v224h-80Zm120 0V318h96v330h-96Zm136 0V480h80v168h-80Z" fill="#1C4654" opacity="0.72"/>
  <path d="M352 640V432h64v208h-64Zm128 0V326h64v314h-64Zm128 0V488h64v152h-64Z" fill="#8EE6FF"/>
  <path d="M326 704h372" stroke="#F6B875" stroke-width="34" stroke-linecap="round"/>
  <circle cx="512" cy="512" r="286" fill="none" stroke="#8EE6FF" stroke-opacity="0.16" stroke-width="8"/>
  <path d="M302 354 512 234l210 120" fill="none" stroke="#FFFFFF" stroke-opacity="0.16" stroke-width="7" stroke-linecap="round"/>
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
