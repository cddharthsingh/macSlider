#!/usr/bin/env bash
# Builds macSlider.app from the SwiftPM executable. No Xcode project needed.
#   scripts/build-app.sh            -> release build in ./build/macSlider.app
#   SIGN_IDENTITY="Developer ID Application: ..." scripts/build-app.sh  -> signed
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
CONFIG="${CONFIG:-release}"
APP="build/macSlider.app"

swift build -c "$CONFIG" --product macSlider
BIN="$(swift build -c "$CONFIG" --show-bin-path)/macSlider"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/macSlider"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Ad-hoc signatures are keyed on the binary hash, so each rebuild needs Accessibility re-granted (`make run` resets it).
codesign --force --deep --options runtime \
  --entitlements Resources/macSlider.entitlements \
  --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP ($VERSION build $BUILD)"
