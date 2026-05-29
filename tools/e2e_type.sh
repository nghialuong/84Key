#!/bin/bash
#
# e2e_type.sh — MANUAL end-to-end check of the live 84Key pipeline.
#
# Types Telex keys into TextEdit using synthetic key events and prints the
# resulting text, so you can confirm what the real app actually produces
# (this exercises the CGEvent tap + field, which the C++ simulation cannot).
#
# Requirements:
#   * 84Key is running and has Accessibility permission (menu bar shows "VI").
#   * Your terminal app is granted Accessibility AND Automation permission
#     (System Settings > Privacy & Security > Accessibility / Automation),
#     so it may control System Events and TextEdit.
#   * Disable other Vietnamese input methods (OpenKey/EVKey/built-in).
#
# Usage:
#   bash tools/e2e_type.sh                 # types a default set of cases
#   bash tools/e2e_type.sh "dd ddi tieesng vieejt nguwowif"
#
# Notes:
#   * It clicks the TextEdit text area first — this both focuses it (so the keys
#     land) and sends a mouse event that resets the engine's word session, so
#     each run starts clean.
#   * For a per-keystroke engine trace, run the app binary with KEY84_TRACE=1:
#       KEY84_TRACE=1 build/dd/Build/Products/Release/84Key.app/Contents/MacOS/84Key
set -e

KEYS="${1:-dd ddi tieesng vieejt truwowngf nguwowif ddoongf quawngr}"

osascript <<OSA
tell application "TextEdit"
    activate
    if (count of documents) = 0 then make new document
    set text of front document to ""
end tell
delay 0.6
tell application "System Events" to tell process "TextEdit"
    set frontmost to true
    set p to position of window 1
    set s to size of window 1
    click at {(item 1 of p) + (item 1 of s) / 2, (item 2 of p) + (item 2 of s) / 2}
end tell
delay 0.3
tell application "System Events" to keystroke "$KEYS"
delay 0.7
return (text of front document of application "TextEdit")
OSA
