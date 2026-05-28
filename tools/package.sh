#!/bin/bash
#
# package.sh — build a runnable 84Key.app and a .dmg for local distribution.
#
# Signing:
#   - By default the app is ad-hoc signed (CODE_SIGNING_ALLOWED=NO). It runs
#     locally after you approve it in System Settings > Privacy & Security.
#   - For a Developer ID signed build, set CODESIGN_IDENTITY to your identity,
#     e.g.  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#
# Notarization requires an Apple Developer account and is NOT done here — see the
# note printed at the end.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/platform/macos"
BUILD="$ROOT/build"
CONFIG="${CONFIG:-Release}"
APP_NAME="84Key"

echo "==> Generating Xcode project (XcodeGen)"
( cd "$MACOS" && xcodegen generate >/dev/null )

echo "==> Building $CONFIG"
rm -rf "$BUILD"
mkdir -p "$BUILD"

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "    signing with: $CODESIGN_IDENTITY"
  xcodebuild -project "$MACOS/$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration "$CONFIG" -derivedDataPath "$BUILD/dd" \
    CODE_SIGN_IDENTITY="$CODESIGN_IDENTITY" \
    build >/dev/null
else
  echo "    ad-hoc signing (no CODESIGN_IDENTITY set)"
  xcodebuild -project "$MACOS/$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration "$CONFIG" -derivedDataPath "$BUILD/dd" \
    CODE_SIGNING_ALLOWED=NO \
    build >/dev/null
fi

APP="$BUILD/dd/Build/Products/$CONFIG/$APP_NAME.app"
if [ ! -d "$APP" ]; then
  echo "ERROR: build did not produce $APP" >&2
  exit 1
fi

echo "==> Staging app and building DMG"
DIST="$BUILD/dist"
mkdir -p "$DIST"
cp -R "$APP" "$DIST/"
ln -sf /Applications "$DIST/Applications"

DMG="$BUILD/$APP_NAME.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST" -ov -format UDZO "$DMG" >/dev/null

echo ""
echo "==> Done"
echo "    App: $APP"
echo "    DMG: $DMG"
echo ""
if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  cat <<'NOTE'
NOTE: This is an ad-hoc signed (unnotarized) build. macOS Gatekeeper will warn on
first launch — approve it in System Settings > Privacy & Security ("Open Anyway").
84Key also needs Accessibility permission (it will prompt on first run).

For a distributable, notarized build you need an Apple Developer account:
  1. Build with CODESIGN_IDENTITY set to your "Developer ID Application" identity.
  2. Notarize the .dmg:  xcrun notarytool submit build/84Key.dmg \
       --apple-id <id> --team-id <TEAMID> --password <app-specific-pw> --wait
  3. Staple:            xcrun stapler staple build/84Key.dmg
ACTION REQUIRED: set up the Apple Developer account before public distribution.
NOTE
fi
