#!/bin/bash
#
# e2e_gdocs.sh — MANUAL end-to-end check of 84Key inside Google Docs (Chrome).
#
# Types Telex keys into an already-open Google Doc using synthetic key events and
# reads the document text back via the clipboard (select-all + copy). This is the
# spot where Google Docs' async canvas + hidden-contenteditable editor used to
# drop injected backspaces, corrupting the doubled-tone restore "garr" -> "gar"
# into "gảar".
#
# Why not Playwright / DevTools? 84Key works at the macOS CGEvent tap layer.
# DevTools injects input straight into the renderer, bypassing the tap — 84Key
# never sees those keys. Only real OS key events (System Events, as below)
# exercise the tap.
#
# Requirements:
#   * 84Key is running with Accessibility permission (menu bar shows "VI"), in
#     Vietnamese / Telex / Unicode mode. Accessibility is needed both for the tap
#     AND for the new isWebContentEditorFocused() AX reads.
#   * Your terminal app is granted Accessibility AND Automation permission
#     (System Settings > Privacy & Security), so it may control System Events and
#     Chrome.
#   * Other Vietnamese input methods (OpenKey/EVKey/built-in) are disabled.
#   * A Google Doc is ALREADY OPEN, logged in, and the front Chrome tab, with the
#     caret in the document body. This script does NOT create or navigate to a
#     doc — it types into whatever is focused. USE A SCRATCH DOC: it types the
#     keys into the document and then does select-all + copy.
#
# Usage:
#   bash tools/e2e_gdocs.sh                 # garr -> gar
#   bash tools/e2e_gdocs.sh barr bar
#   bash tools/e2e_gdocs.sh Garr Gar
#
# Limitations (read this):
#   * Clipboard read-back proves the final document text, not the intermediate
#     keystroke sequence. For keystroke-level proof run the app with KEY84_TRACE=1
#     and watch Console.app.
#   * Google Docs is async; the delay after typing is longer than the omnibox
#     check and may need tuning per machine. If results look truncated, raise it.
#   * To reproduce the PRE-fix bug, run this against a build without the
#     web-editor fix — you should see "gảar" instead of "gar".
set -e

KEYS="${1:-garr}"
EXPECT="${2:-gar}"
APP="Google Chrome"

# Save the user's clipboard so we can restore it (we use Cmd+C to read back).
OLD_CLIP="$(pbpaste 2>/dev/null || true)"

osascript <<OSA >/dev/null
tell application "$APP" to activate
delay 0.8
tell application "System Events"
    keystroke "a" using command down   -- clear the doc body first so the
    delay 0.2                          -- read-back reflects only this run
    key code 51                        -- (Delete) — avoids stale text from a
    delay 0.3                          -- previous invocation
    keystroke "$KEYS"                  -- real CGEvents -> 84Key tap transforms
    delay 1.0                          -- Docs editor is async; give it time
    keystroke "a" using command down   -- select all in the document body
    delay 0.2
    keystroke "c" using command down   -- copy
    delay 0.3
end tell
OSA

sleep 0.4
ACTUAL="$(pbpaste 2>/dev/null || true)"

# Restore the original clipboard.
printf '%s' "$OLD_CLIP" | pbcopy 2>/dev/null || true

echo "app:      $APP (Google Docs)"
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
