#!/bin/bash
#
# package.sh — build 84Key.app and a .dmg, and (optionally) notarize the .dmg so
# it opens cleanly on other Macs.
#
# Signing:
#   - Auto-detects a stable signing identity (Developer ID preferred, else Apple
#     Development). Override with CODESIGN_IDENTITY. A stable identity keeps the
#     macOS Accessibility/TCC grant valid across rebuilds.
#   - Falls back to ad-hoc if no identity is found (local use only).
#
# Notarization (to share with others):
#   1. One-time, create a notarytool keychain profile (you enter your Apple ID and
#      an app-specific password from appleid.apple.com):
#        xcrun notarytool store-credentials "84key-notary" \
#            --apple-id "you@example.com" --team-id "TAFDRXJZSR"
#   2. Build + notarize + staple:
#        KEY84_NOTARY_PROFILE=84key-notary bash tools/package.sh
#   The resulting build/84Key.dmg opens normally on any Mac (no Gatekeeper warning).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/platform/macos"
BUILD="$ROOT/build"
CONFIG="${CONFIG:-Release}"
APP_NAME="84Key"
NOTARY_PROFILE="${KEY84_NOTARY_PROFILE:-}"   # notarytool keychain profile; set to notarize

echo "==> Generating Xcode project (XcodeGen)"
( cd "$MACOS" && xcodegen generate >/dev/null )

if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | awk -F'"' '/Developer ID Application/{print $2; exit}')"
  [ -z "$CODESIGN_IDENTITY" ] && CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | awk -F'"' '/Apple Development/{print $2; exit}')"
fi

# Notarization requires a secure (online) timestamp; skip it otherwise for speed.
TS="--timestamp=none"
[ -n "$NOTARY_PROFILE" ] && TS="--timestamp"

echo "==> Building $CONFIG"
rm -rf "$BUILD"
mkdir -p "$BUILD"
xcodebuild -project "$MACOS/$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
  -configuration "$CONFIG" -derivedDataPath "$BUILD/dd" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

APP="$BUILD/dd/Build/Products/$CONFIG/$APP_NAME.app"
[ -d "$APP" ] || { echo "ERROR: build did not produce $APP" >&2; exit 1; }

if [ -n "$CODESIGN_IDENTITY" ]; then
  echo "==> Re-signing app with: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime $TS -s "$CODESIGN_IDENTITY" "$APP"
else
  echo "    (ad-hoc signed — no Developer ID/Apple Development identity found)"
fi

echo "==> Staging app and building DMG"
DIST="$BUILD/dist"
mkdir -p "$DIST"
cp -R "$APP" "$DIST/"
ln -sf /Applications "$DIST/Applications"

DMG="$BUILD/$APP_NAME.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST" -ov -format UDZO "$DMG" >/dev/null

if [ -n "$CODESIGN_IDENTITY" ]; then
  codesign --force $TS -s "$CODESIGN_IDENTITY" "$DMG"
fi

echo ""
echo "==> Built"
echo "    App: $APP"
echo "    DMG: $DMG"

if [ -n "$NOTARY_PROFILE" ]; then
  echo ""
  echo "==> Notarizing (profile: $NOTARY_PROFILE) — this can take a few minutes"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "==> Notarized DMG ready to share: $DMG"
else
  cat <<'NOTE'

NOTE: Not notarized — Gatekeeper will warn on other Macs (open via right-click >
Open, or System Settings > Privacy & Security > Open Anyway).
To produce a share-ready notarized DMG, create a notarytool keychain profile once
(see the header of this script) and re-run with KEY84_NOTARY_PROFILE set.
NOTE
fi
