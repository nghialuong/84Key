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
# Compare the printed output to the expected Vietnamese. For a per-keystroke
# engine trace, instead run the app binary directly with KEY84_TRACE=1:
#   KEY84_TRACE=1 build/dd/Build/Products/Release/84Key.app/Contents/MacOS/84Key
# then type and read the trace in Console.app (or stderr).
set -e

KEYS="${1:-dd ddi tieesng vieejt truwowngf nguwowif ddoongf quawngr}"

osascript <<OSA
tell application "TextEdit"
    activate
    if (count of documents) = 0 then make new document
    set text of document 1 to ""
end tell
delay 0.6
tell application "System Events" to keystroke "$KEYS"
delay 0.6
set result to text of document 1 of application "TextEdit"
return result
OSA
