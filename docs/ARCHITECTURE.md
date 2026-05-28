# 84Key Architecture

84Key is split into a portable engine and a platform shell so the same Vietnamese
typing logic can be reused on macOS today and Windows/Linux later.

## Layout

```
core/
  engine/   C++ typing engine (from OpenKey, GPLv3) — platform-independent
  data/     english_words.dat, viet_telex.dat (generated)
  tests/    C++ test harness (engine + English detection)
platform/macos/
  App/      SwiftUI: Key84App, AppDelegate, SettingsView, AppSettings,
            OnboardingView, LoginItemManager
  Input/    Obj-C++: InputController (CGEvent tap, key send, Spotlight AX),
            EngineGlobals.cpp (engine option globals)
  Bridge/   Key84-Bridging-Header.h (exposes InputController to Swift)
  project.yml  XcodeGen spec -> 84Key.xcodeproj
tools/      gen_dict.py (dictionary generator)
```

## The engine (`core/engine`)

A pure C++14 library. The entry point is `vKeyHandleEvent(event, state, keycode,
capsStatus, otherControlKey)`. It maintains the current word buffer and writes its
decision into a `vKeyHookState`: a `code` (do-nothing / will-process / restore /
replace-macro), a `backspaceCount`, and `charData[]` (the replacement characters,
stored right-to-left). The host turns this into output. Options are `extern int v…`
globals the host defines (see `EngineGlobals.cpp`).

## macOS input core (`platform/macos/Input/InputController.mm`)

An Obj-C++ class that installs a session-level `CGEventTap`. On each key it calls
`vKeyHandleEvent`, then:

- **do-nothing** → lets the key through;
- **will-process / restore** → posts `backspaceCount` synthetic backspaces and the
  new characters (decoded from `charData`);
- **replace-macro** → expands a macro.

The interface (`InputController.h`) is pure Obj-C so Swift can use it through the
bridging header; the implementation is Obj-C++ and talks to the C++ engine.

## English auto-detection

Two dictionaries keyed by raw Telex keystrokes — a common-English list and a
Vietnamese-by-Telex syllable list — are consulted only at a transform keystroke
(off the hot path). If the typed keys form an English word that is not a valid
Vietnamese syllable, the diacritic is suppressed; ambiguous prefixes (e.g.
`google`) are restored at the word break. See `core/engine/EnglishDetect.*` and
`tools/gen_dict.py` (the Vietnamese list is generated from linguistic rules, not a
scraped word list).

## Spotlight fix

Spotlight's search field applies injected events asynchronously, so a fast
backspace can be lost (`chúng`→`chuúng`). For Spotlight only, `InputController`
replaces the text atomically through the Accessibility API (read value + caret,
verify the base letters match, set the new value), with a short stale-read retry,
and falls back to the normal CGEvent path on any failure — so every other app is
unaffected.

## Options & persistence

`AppSettings` is the single source of truth, backed by `NSUserDefaults` with
**registered defaults** (so default-ON options survive an absent key). Changes are
persisted and pushed into the engine globals via `InputController.applyEngineOptions:`.
