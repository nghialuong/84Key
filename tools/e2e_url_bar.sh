#!/bin/bash
#
# e2e_url_bar.sh — MANUAL end-to-end check of 84Key in a Chromium address bar.
#
# Types Telex keys into a Chromium browser's omnibox using synthetic key events
# and reads the result back via the clipboard, so you can confirm the live app
# produces correct Vietnamese in the URL bar (the spot where inline-autocomplete
# used to corrupt transforms, e.g. "đủ" -> "dđủ").
#
# Why not Playwright? 84Key works at the macOS CGEvent tap layer. Playwright
# injects input through the Chrome DevTools Protocol straight into the renderer,
# bypassing the tap — 84Key never sees those keys. Only real OS key events
# (System Events, as below) exercise the tap.
#
# Requirements:
#   * 84Key is running and has Accessibility permission (menu bar shows "VI"),
#     in Vietnamese / Telex mode.
#   * Your terminal app is granted Accessibility AND Automation permission
#     (System Settings > Privacy & Security > Accessibility / Automation),
#     so it may control System Events and the browser.
#   * Disable other Vietnamese input methods (OpenKey/EVKey/built-in).
#
# Usage:
#   bash tools/e2e_url_bar.sh                                  # Chrome, ddur -> đủ
#   bash tools/e2e_url_bar.sh "Brave Browser" tieesng tiếng
#   bash tools/e2e_url_bar.sh "Microsoft Edge" nguwowif người
#
# Limitation (read this): this proves the fix yields correct text in the omnibox.
# Reproducing the *pre-fix* corruption requires real autocomplete history so the
# browser actually offers a selected inline suggestion; a clean profile may not,
# in which case even the unfixed build can look correct. For a faithful repro,
# run it against a key sequence whose prefix is in your history.
set -e

APP="${1:-Google Chrome}"
KEYS="${2:-ddur}"
EXPECT="${3:-đủ}"

# Save the user's clipboard so we can restore it (we use Cmd+C to read back).
OLD_CLIP="$(pbpaste 2>/dev/null || true)"

osascript <<OSA >/dev/null
tell application "$APP" to activate
delay 0.6
tell application "System Events"
    keystroke "l" using command down   -- focus + select omnibox
    delay 0.2
    key code 51                        -- Delete: empty the omnibox
    delay 0.2
    keystroke "$KEYS"                  -- real CGEvents -> 84Key tap transforms
    delay 0.6
    keystroke "a" using command down   -- select all
    delay 0.1
    keystroke "c" using command down   -- copy omnibox text
    delay 0.2
    key code 53                        -- Escape: discard, do NOT navigate
end tell
OSA

delay_read() { sleep 0.3; }
delay_read
ACTUAL="$(pbpaste 2>/dev/null || true)"

# Restore the original clipboard.
printf '%s' "$OLD_CLIP" | pbcopy 2>/dev/null || true

echo "app:      $APP"
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
