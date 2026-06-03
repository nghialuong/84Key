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
# Notarization (to share with others) — two ways to supply credentials:
#   A) Local: a notarytool keychain profile (you enter your Apple ID and an
#      app-specific password from appleid.apple.com), one-time:
#        xcrun notarytool store-credentials "84key-notary" \
#            --apple-id "you@example.com" --team-id "<YOUR_TEAM_ID>"
#      then: KEY84_NOTARY_PROFILE=84key-notary bash tools/package.sh
#   B) CI / unattended: an App Store Connect API key (.p8). Set:
#        KEY84_ASC_KEY_PATH=/path/to/AuthKey_XXXX.p8
#        KEY84_ASC_KEY_ID=<Key ID>
#        KEY84_ASC_ISSUER_ID=<Issuer ID>
#   The resulting build/84Key.dmg opens normally on any Mac (no Gatekeeper warning).
#
# Other env overrides:
#   CODESIGN_IDENTITY  — signing identity (else auto-detected from the keychain).
#   KEY84_VERSION      — override MARKETING_VERSION (e.g. from a release tag).
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

# Decide how to authenticate with notarytool. A keychain profile (local) takes
# precedence; otherwise fall back to an App Store Connect API key (CI-friendly).
NOTARY_ARGS=()
if [ -n "$NOTARY_PROFILE" ]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${KEY84_ASC_KEY_PATH:-}" ]; then
  NOTARY_ARGS=(--key "$KEY84_ASC_KEY_PATH" \
               --key-id "${KEY84_ASC_KEY_ID:?KEY84_ASC_KEY_ID is required with KEY84_ASC_KEY_PATH}" \
               --issuer "${KEY84_ASC_ISSUER_ID:?KEY84_ASC_ISSUER_ID is required with KEY84_ASC_KEY_PATH}")
fi

# Notarization requires a secure (online) timestamp; skip it otherwise for speed.
TS="--timestamp=none"
[ ${#NOTARY_ARGS[@]} -gt 0 ] && TS="--timestamp"

echo "==> Building $CONFIG"
rm -rf "$BUILD"
mkdir -p "$BUILD"
VERSION_OVERRIDE=()
[ -n "${KEY84_VERSION:-}" ] && VERSION_OVERRIDE=(MARKETING_VERSION="$KEY84_VERSION")
xcodebuild -project "$MACOS/$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
  -configuration "$CONFIG" -derivedDataPath "$BUILD/dd" \
  CODE_SIGNING_ALLOWED=NO "${VERSION_OVERRIDE[@]}" \
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

if [ ${#NOTARY_ARGS[@]} -gt 0 ]; then
  echo ""
  echo "==> Notarizing — this can take a few minutes"
  # notarytool can intermittently stall connecting/uploading to Apple's notary
  # service and then hang on `--wait` indefinitely (in CI that burns the whole
  # 6-hour job limit). Bound each attempt with --timeout so a stuck submission
  # fails fast, and retry once since the stall is transient. Override the cap
  # with KEY84_NOTARY_TIMEOUT (e.g. "30m").
  NOTARY_TIMEOUT="${KEY84_NOTARY_TIMEOUT:-20m}"
  attempt=1
  until xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" \
        --wait --timeout "$NOTARY_TIMEOUT"; do
    if [ "$attempt" -ge 2 ]; then
      echo "ERROR: notarization failed/stalled after $attempt attempts" >&2
      exit 1
    fi
    echo "==> Notarization attempt $attempt stalled or failed; retrying…" >&2
    attempt=$((attempt + 1))
  done
  echo "==> Stapling"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "==> Notarized DMG ready to share: $DMG"
else
  cat <<'NOTE'

NOTE: Not notarized — Gatekeeper will warn on other Macs (open via right-click >
Open, or System Settings > Privacy & Security > Open Anyway).
To produce a share-ready notarized DMG, supply notarization credentials (see the
header of this script): a keychain profile (KEY84_NOTARY_PROFILE) or an App Store
Connect API key (KEY84_ASC_KEY_PATH / KEY84_ASC_KEY_ID / KEY84_ASC_ISSUER_ID).
NOTE
fi
