#!/bin/bash
#
# send_invariants_test.sh — guards the send layer of InputController.mm.
#
# The fast-typing tone drop ("sướng" coming out "sương") was not an algorithm
# bug: the engine emitted the right transform and the burst carrying it was lost
# on the way to the app, because synthetic events were posted in ways that let a
# busy app collapse them. The fix is a set of invariants about how an event
# leaves this process, and invariants are exactly what silently rot — a new
# sender added later would compile, run, and only misbehave under load, in one
# app, at speed. Nothing in the C++ harness can see CGEvent, so they are checked
# here, against the source.
#
# Exits non-zero if any invariant is broken.

set -u
cd "$(dirname "$0")/../Input"
SRC=InputController.mm
pass=0
fail=0

ok()   { echo "  [PASS] $1"; pass=$((pass + 1)); }
bad()  { echo "  [FAIL] $1"; fail=$((fail + 1)); }

# Body of a function, by name: from its opening line to the closing brace in
# column 1. Good enough for this file, which is plain top-level C functions.
body() {
    awk -v fn="$1" '
        $0 ~ "^(static )?[A-Za-z_].*[ *]" fn "\\(" { inside = 1 }
        inside { print }
        inside && /^}/ { exit }
    ' "$SRC"
}

echo "== macOS send-layer invariants ($SRC) =="

# 1. One way out. Every synthetic event must be stamped and marked
#    non-coalescing, which only holds if nothing posts around PostSynthetic.
n=$(grep -c 'CGEventTapPostEvent' "$SRC")
if [ "$n" -eq 1 ] && body PostSynthetic | grep -q 'CGEventTapPostEvent'; then
    ok "CGEventTapPostEvent is called once, from PostSynthetic"
else
    bad "CGEventTapPostEvent called $n time(s); it must be called only by PostSynthetic —
         a sender that posts directly skips the timestamp and the NonCoalesced flag,
         and its burst becomes collapsible again"
fi

# 2. What that one way out has to do. A burst of events sharing one creation
#    timestamp reads as key repeat, and repeat may be dropped.
if body PostSynthetic | grep -q 'CGEventSetTimestamp'; then
    ok "PostSynthetic stamps every event"
else
    bad "PostSynthetic no longer calls CGEventSetTimestamp — events posted in one
         burst would again share a creation time and read as key repeat"
fi
if body PostSynthetic | grep -q 'kCGEventFlagMaskNonCoalesced'; then
    ok "PostSynthetic marks every event non-coalescing"
else
    bad "PostSynthetic no longer sets kCGEventFlagMaskNonCoalesced — the window
         server may merge a delete into the insert that follows it"
fi

# 3. Backspaces are built, not reposted. A cached pair handed to the app N times
#    is one event object with one identity, N times over.
n=$(grep -c 'CGEventCreateKeyboardEvent(gEventSource, KEY_DELETE' "$SRC")
if [ "$n" -eq 2 ] && [ "$(body PostBackspace | grep -c 'CGEventCreateKeyboardEvent(gEventSource, KEY_DELETE')" -eq 2 ]; then
    ok "backspace events are created per delete, inside PostBackspace"
else
    bad "backspace events are created $n time(s) outside PostBackspace — caching a
         pair and reposting it is what made a run of deletes look like key repeat"
fi
if grep -qE '(gBackSpaceDown|gBackSpaceUp)' "$SRC"; then
    bad "the cached gBackSpaceDown / gBackSpaceUp globals are back"
else
    ok "no cached backspace event globals"
fi

# 4. A tap the system disables loses keystrokes the engine never sees, so the
#    engine's buffer stops describing the screen. Re-enabling alone is not enough.
if body Key84Callback | awk '/kCGEventTapDisabledByTimeout/ { seen = 1 }
                             seen && /RequestNewSession/ { found = 1 }
                             seen && /CGEventTapEnable/ { exit found ? 0 : 1 }' ; then
    ok "a system-disabled tap starts a new word before it is re-enabled"
else
    bad "the tap-disabled branch re-enables the tap without RequestNewSession() —
         the next word break would rewrite the word from a stale engine buffer"
fi

# 5. Nothing may block the tap callback on an unbounded count. Each AX read is
#    allowed 50ms, so a retry budget expressed in attempts is a budget in seconds,
#    and overrunning it is what gets the tap disabled in the first place.
if body replaceFocusedTextViaAX | grep -q 'deadline'; then
    ok "the Accessibility retry is bounded by a deadline"
else
    bad "replaceFocusedTextViaAX no longer bounds its retry by wall-clock time"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
