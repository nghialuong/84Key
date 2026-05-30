# 84Key — Product & Feature Overview

> A plain-language reference describing **what 84Key is** and **what it does**, for
> onboarding, support, marketing copy, or feeding to an assistant as context.
> For internals see [`ARCHITECTURE.md`](ARCHITECTURE.md); for how it's built and
> tested see [`BUILD.md`](BUILD.md) and [`TESTING.md`](TESTING.md).

## What it is

84Key is a free, open-source **Vietnamese input method (bộ gõ tiếng Việt) for
macOS**. It lets you type Vietnamese with diacritics using standard input
conventions (Telex, VNI, Simple Telex) in any application. The name comes from
Vietnam's `+84` international calling code.

It reuses the proven [OpenKey](https://github.com/tuyenvm/OpenKey) C++ typing
engine (GPLv3) and wraps it in a modern SwiftUI **menu-bar app**, adding two
flagship improvements on top: **automatic English-word detection** and a
**Spotlight diacritic-placement fix**.

- **Platform:** macOS only today. Windows and Linux are planned; the typing
  engine is already platform-independent C++ to make that possible.
- **License:** GPLv3 (inherited from OpenKey).
- **Bundle id:** `com.nghialuong.key84`.
- **Privacy:** 100% local. No telemetry, no network calls for typing, no
  accounts. Keystroke processing happens entirely on-device.

## How it works (one paragraph)

84Key installs a session-level `CGEvent` tap (requiring the macOS
**Accessibility** permission). For each keystroke it asks the C++ engine what to
do; the engine maintains the current word and decides whether to leave the key
alone or to rewrite the word (e.g. send synthetic backspaces, then the
re-composed characters with the correct diacritics). It deliberately avoids
acting in secure-input / password fields.

## Flagship features

1. **Accurate Vietnamese typing** — Telex, VNI, and Simple Telex, backed by the
   battle-tested OpenKey engine, with spell-checking of Vietnamese syllables.
2. **Automatic English detection** — while you type an English word in Telex,
   84Key recognizes it and skips diacritic transformation, so words like "feed",
   "tools", or "google" come out correctly **without switching modes**. It uses
   two dictionaries (a common-English list and a rule-generated
   Vietnamese-by-Telex syllable list) consulted off the hot path; ambiguous
   prefixes are resolved at the word break. *On by default.*
3. **Spotlight fix** — Spotlight's search field applies injected events
   asynchronously, which can drop a fast backspace (`chúng` → `chuúng`). For
   Spotlight only, 84Key rewrites the text atomically via the Accessibility API
   (and falls back to the normal path on any failure, so other apps are
   unaffected). *On by default.*
4. **Menu-bar app** — lightweight SwiftUI app living in the menu bar; the menu
   shows the current language (**VI/EN**) and lets you toggle it, open Settings,
   and quit. Includes a guided Accessibility onboarding flow.

## Settings reference

These are the user-facing options in **Settings**, grouped as they appear in the
app. Defaults reflect the registered defaults in `AppSettings.swift`.

### Input
- **Input method** — Telex (default), VNI, Simple Telex 1, Simple Telex 2.
- **Code table** — Unicode (default), TCVN3 (ABC), VNI Windows, Unicode
  Compound, Vietnamese CP1258.

### Smart features
- **Automatic English detection** *(default ON)* — skip diacritics while typing
  an English word in Telex, without switching modes.
- **Fix diacritics in Spotlight** *(default ON)* — the Spotlight fix above.
- **Smart switch key (remember language per app)** *(default ON)* — remembers
  VI/EN choice per application.

### Vietnamese typing
- **Spell check** *(default ON)* — validate Vietnamese syllables.
- **Modern orthography (oà, uý)** *(default ON)* — reform spelling vs.
  traditional `òa`/`úy`.
- **Free mark placement** — allow tone marks in flexible positions.
- **Quick Telex (cc→ch, gg→gi…)** — consonant shortcuts.
- **Restore word if spelling is wrong** — revert to raw keys on an invalid
  syllable.
- **Quick start consonant (f→ph, j→gi, w→qu)**.
- **Quick end consonant (g→ng, h→nh, k→ch)**.
- **Allow Z / F / W / J as letters**.
- **Capitalize first letter**.

### Compatibility
- **Use macros (text expansion)**.
- **Fix browser address-bar autocomplete** *(default OFF — avoids stray
  characters in normal fields)*.
- **Turn off Vietnamese in non-English keyboard layouts**.

### System
- **Launch 84Key at login** — via macOS `SMAppService`.
- **Switch language** — click the menu-bar **VI/EN** item.

## Permissions & setup

1. Launch 84Key; it appears in the menu bar.
2. Grant **Accessibility** permission when prompted (System Settings → Privacy &
   Security → Accessibility). The onboarding flow guides this. 84Key detects the
   grant by actually starting the event tap (more reliable than
   `AXIsProcessTrusted()` for ad-hoc/dev builds), and may quit-and-relaunch to
   pick up a fresh grant.
3. **Disable other Vietnamese IMEs** (OpenKey, EVKey, the built-in macOS
   Vietnamese source) — running more than one causes conflicting keystrokes.

## What 84Key does *not* do

- No telemetry, analytics, or network calls for typing.
- No accounts or cloud sync.
- Does not act in secure-input/password fields by design.
- Not yet notarized for distribution (planned; requires an Apple Developer
  account). Local/dev builds run after approval in System Settings.

## Credits

- **[OpenKey](https://github.com/tuyenvm/OpenKey)** by Mai Vũ Tuyên — the GPLv3
  Vietnamese typing engine powering 84Key.
- **[google-10000-english](https://github.com/first20hours/google-10000-english)**
  — the English word list used for automatic English detection.
