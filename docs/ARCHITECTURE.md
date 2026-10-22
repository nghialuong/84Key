# 84Key Architecture

84Key is split into a portable engine and a platform shell so the same Vietnamese
typing logic runs on macOS and Linux today, and Windows later.

## Layout

```
core/
  engine/   C++ typing engine (from OpenKey, GPLv3) — platform-independent
  data/     english_words.dat, viet_telex.dat (generated)
  tests/    C++ test harness (engine + English detection)
platform/macos/
  App/      SwiftUI: Key84App (menu-bar entry), AppDelegate, AppController
            (owns the input controller + permission/login lifecycle),
            SettingsView, AppSettings, OnboardingView, LoginItemManager
  Input/    Obj-C++: InputController (CGEvent tap, key send, Spotlight AX),
            EngineGlobals.cpp (engine option globals)
  Bridge/   Key84-Bridging-Header.h (exposes InputController to Swift)
  project.yml  XcodeGen spec -> 84Key.xcodeproj
platform/linux/
  src/      C++: Composer (the typing pipeline, no IBus), Key84Engine (the
            IBusEngine), SwitchKey (VI/EN hotkey), Settings (settings.ini),
            EngineGlobals.cpp, main.cpp (ibus-engine-84key)
  setup/    ibus-setup-84key (Python, GTK 4 + libadwaita settings window)
  data/     84key.xml.in (IBus component)
  tests/    host_test.cpp (pipeline vs macOS, hotkey), e2e.py (Xvfb + IBus + GTK)
  CMakeLists.txt  build, tests, .deb (CPack)
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

## Linux input core (`platform/linux`)

On Linux 84Key is an **IBus engine** (`ibus-engine-84key`), so it works wherever
IBus does — X11 and Wayland, GTK, Qt, browsers, terminals — with no special
permission. The engine is compiled with `-DLINUX` (the X11 key table in
`core/engine/platforms/linux.h`); keys reach it as keysyms, which `Composer` maps
to engine keys by the character typed, so any keyboard layout works.

### Composer: the word lives in the preedit

The macOS host lets each key through and corrects the app's text with synthetic
backspaces and retyped characters. IBus offers something better, and
`Composer` (pure C++, no IBus) is built on it:

- the word being typed is the IBus **preedit**: `Composer` keeps it as one unit
  per engine character (so a two-part character in VNI Windows or Unicode
  Compound is deleted whole) and applies every `vKeyHookState` — backspaces and
  new characters — to that buffer instead of to the app;
- a key that ends the word (space, punctuation, Enter, an arrow, a shortcut —
  the engine's own break rule) commits the word, corrected by the engine's
  break-time rules, **in one commit** together with the break character;
- keys the word does not need (shortcuts, navigation, anything with no word open)
  are returned to IBus unhandled and reach the app as real key events;
- the preedit is shown in `IBUS_ENGINE_PREEDIT_COMMIT` mode, so when the user
  clicks or focus moves mid-word IBus commits it; the engine only forgets the
  word on `reset`/`focus_out` and never commits it a second time;
- a Backspace with no word open resets the engine (dropping its word history),
  so the engine never reopens a word the app already holds; and a rewrite that
  would reach past the word (an engine overreach, see `engineAgrees()`) is
  refused instead of deleting the app's text.

`platform/linux/tests/host_test.cpp` holds this pipeline to the macOS one: every
Telex dictionary word and a seeded random-typing fuzz must show the same text on
both hosts (see [`TESTING.md`](TESTING.md#4-linux)).

### The IBus engine

`Key84Engine` is the `IBusEngine` subclass. The engine core keeps its word in
global state, so one `Composer` serves the process; the focused engine object
drives it and every focus change starts a new word. It also owns:

- **VI/EN** — `SwitchKey` matches the hotkey (default Ctrl + Shift, modifier-only
  combos fire on release with nothing pressed in between). The language is the
  `InputMode` property, whose symbol GNOME Shell shows in the top bar
  (**VI**/**EN**); with *Phím chuyển thông minh* it is remembered per
  application, using the client name IBus passes to `focus_in_id`.
- **The input-source menu** — IBus properties for the input method, code table
  and switches, plus *Cài đặt 84Key…*.
- **Password fields** — `IBUS_INPUT_PURPOSE_PASSWORD`/`PIN` put `Composer` in
  bypass: keys pass through untouched.
- **Settings** — `Settings` reads `~/.config/84key/settings.ini`, whose keys are
  the engine option names the macOS app stores in `UserDefaults`; missing keys
  keep their defaults (`EngineGlobals.cpp`), like the macOS registered defaults.
  A file monitor applies changes from the menu, the settings window or an editor
  immediately.

`main.cpp` runs the engine for ibus-daemon (`--ibus`), prints its description
(`--xml`, which the component file `84key.xml` uses, so the description exists
once), or — with neither — registers it with the running daemon for development.
