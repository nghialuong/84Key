#!/bin/bash
#
# e2e_spotlight.sh — MANUAL end-to-end check of 84Key in the macOS Spotlight
# search field (Cmd+Space).
#
# Types Telex keys into Spotlight using synthetic key events and reads the result
# back via the clipboard, so you can confirm the live app produces correct
# Vietnamese where injected backspaces used to be swallowed.
#
# Background: on macOS 27 (Tahoe) the Spotlight field is owned by the
# "com.apple.campo" process, not the classic "com.apple.Spotlight". 84Key now
# detects such system search fields (by bundle id and by AX behavior) and
# rewrites text atomically via the Accessibility API instead of sending
# backspaces, which the field drops — otherwise "chúng" came out as "chuúng".
#
# Why not Playwright/UI tests? 84Key works at the macOS CGEvent tap layer. Only
# real OS key events (System Events, as below) flow through the tap.
#
# Requirements:
#   * 84Key is running and has Accessibility permission (menu bar shows "VI"),
#     in Vietnamese / Telex / Unicode mode.
#   * Your terminal app is granted Accessibility AND Automation permission
#     (System Settings > Privacy & Security > Accessibility / Automation),
#     so it may control System Events.
#   * Disable other Vietnamese input methods (OpenKey/EVKey/built-in).
#
# Usage:
#   bash tools/e2e_spotlight.sh                       # chungs -> chúng
#   bash tools/e2e_spotlight.sh laf là
#   bash tools/e2e_spotlight.sh maay mây
set -e

KEYS="${1:-chungs}"
EXPECT="${2:-chúng}"

# Save the user's clipboard so we can restore it (we use Cmd+C to read back).
OLD_CLIP="$(pbpaste 2>/dev/null || true)"

osascript <<OSA >/dev/null
tell application "System Events"
    key code 49 using {command down}   -- Cmd+Space: open Spotlight
    delay 0.7
    keystroke "$KEYS"                   -- real CGEvents -> 84Key tap transforms
    delay 0.6
    keystroke "a" using {command down}  -- select all in the search field
    delay 0.1
    keystroke "c" using {command down}  -- copy the query text
    delay 0.2
    key code 53                         -- Escape: dismiss Spotlight (don't launch)
end tell
OSA

sleep 0.3
ACTUAL="$(pbpaste 2>/dev/null || true)"

# Restore the original clipboard.
printf '%s' "$OLD_CLIP" | pbcopy 2>/dev/null || true

echo "field:    Spotlight (Cmd+Space)"
echo "keys:     $KEYS"
echo "expected: $EXPECT"
echo "actual:   $ACTUAL"

if [ "$ACTUAL" = "$EXPECT" ]; then
    echo "PASS"
    exit 0
else
    echo "FAIL"
    exit 1
fi
