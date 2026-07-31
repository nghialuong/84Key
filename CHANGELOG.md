# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.6] - 2026-07-31

### Fixed

- **Slow English typing with Telex enabled**: compound words assembled from known
  English words, such as `dashboard`, `airdrop`, and `markdown`, are now restored
  correctly at the word boundary instead of losing letters or gaining Vietnamese
  tone marks. Valid Vietnamese Telex spellings remain protected across alternate
  tone and modifier-key orders.

## [0.1.5] - 2026-06-21

### Fixed

- **English typing — accent now clears immediately**: typing a word like `iss`
  showed the accented `ís` until you pressed space, because the doubled tone key
  (the escape that forces the literal English letters) only dropped the mark at the
  word break. The mark is now dropped the moment the word is detected as
  non-Vietnamese (`iss` → `is`, `ass` → `as`), so the stray accent never lingers
  mid-word. Full English words (`issue`, `assign`, `miss`) still type out whole,
  and the correction stays compatible with the browser/Google Docs empty-character
  fix.

## [0.1.4] - 2026-06-16

### Fixed

- **Google Docs (and browser fields) typing**: in browsers, a backspace fired
  back-to-back with the replacement was dropped by the async web layer — the
  insert landed before the deletion — so the doubled-tone restore "garr" → "gar"
  came out "gảar". Browser corrections now emit an empty character (U+202F) to
  reset the autocomplete/composition state, then paced backspaces before the
  insert. One mechanism now fixes both the address bar ("đủ" no longer "dđủ") and
  in-page editors like Google Docs.

## [0.1.3] - 2026-06-14

### Fixed

- **macOS 27 (Tahoe) Spotlight typing**: the Spotlight search field is now owned
  by the `com.apple.campo` process instead of `com.apple.Spotlight`, so the
  Accessibility atomic-replace path no longer matched and injected backspaces were
  dropped (e.g. "chúng" came out "chuúng"). Spotlight-like fields are now detected
  by bundle id **and** by AX behavior (an Apple search field exposing value +
  selected range), and fall back to a Shift+Left select-and-overwrite when the
  atomic replace can't run (N≠M, VNI, or AX failure).

## [0.1.0] - Unreleased

First macOS release.

### Added

- Vietnamese typing engine derived from OpenKey (GPLv3), with **Telex**, **VNI**,
  and **Simple Telex** input methods and the Unicode code table (TCVN3,
  VNI-Windows, Unicode Compound, and CP1258 also supported).
- **Automatic English detection**: while typing in Telex, English words are left
  undiacriticized without switching modes, favoring Vietnamese on ambiguous input.
- **Spotlight diacritic fix**: correct diacritic placement in Spotlight (and
  similar fields) even when typing quickly, via the Accessibility API, with a
  fallback to the normal path.
- Menu-bar SwiftUI app with a VI/EN indicator and quick toggle.
- Settings for input method, code table, feature toggles, run-on-startup, and a
  language-switch hotkey, persisted with registered defaults.
- First-run Accessibility onboarding and a warning about conflicts with other
  Vietnamese input methods.
- Vietnamese-by-Telex syllable dictionary generated from linguistic rules (no
  external word list); English word list from the public-domain
  google-10000-english set.
- **Privacy**: 100% local processing, no telemetry, no network calls for typing.
- C++ engine test harness, a keystroke-level simulation of the macOS output
  pipeline with drop-in `cases/*.txt` article fixtures, a live end-to-end script,
  and continuous integration.

[Unreleased]: https://github.com/nghialuong/84Key/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nghialuong/84Key/releases/tag/v0.1.0
