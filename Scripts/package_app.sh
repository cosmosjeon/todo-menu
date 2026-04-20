#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME="TodoMenu"
EXECUTABLE="TodoMenuApp"
BUNDLE_ID="com.cosmos.todomenu"
VERSION="1.0.0"
MIN_MACOS="14.0"
CONF="${1:-release}"
ARCH=$(uname -m)

echo "==> Building $EXECUTABLE ($CONF, $ARCH)..."
swift build -c "$CONF" --arch "$ARCH"

BIN=".build/${ARCH}-apple-macosx/${CONF}/${EXECUTABLE}"
if [[ ! -f "$BIN" ]]; then
  echo "ERROR: Binary not found at $BIN" >&2
  exit 1
fi

APP="$ROOT/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Creating Info.plist..."
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Copying binary..."
cp "$BIN" "$APP/Contents/MacOS/${EXECUTABLE}"
chmod +x "$APP/Contents/MacOS/${EXECUTABLE}"

xattr -cr "$APP" 2>/dev/null || true
find "$APP" -name '._*' -delete 2>/dev/null || true

echo "==> Ad-hoc signing..."
codesign --force --sign "-" "$APP"

echo ""
echo "Done! ${APP_NAME}.app created at:"
echo "  $APP"
echo ""
echo "To install:"
echo "  cp -R ${APP_NAME}.app ~/Applications/"
echo "  open ~/Applications/${APP_NAME}.app"
echo ""
echo "To add to login items:"
echo "  System Settings > General > Login Items > add ${APP_NAME}"
