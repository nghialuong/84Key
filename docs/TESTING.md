# Testing 84Key

84Key is tested at three levels, from fast/pure to full end-to-end.

```sh
bash core/tests/run_tests.sh     # runs the two C++ suites below; exit 0 = all pass
```

## 1. Engine harness — `core/tests/engine_test.cpp`

Drives the real C++ engine (`vKeyHandleEvent`) and reconstructs the visible text
with a reference decoder, asserting exact output. Covers TEST_CASES groups
A (Telex), B (VNI), C/D/E/F (English detection) and G (engine options). This
validates the **engine** in isolation — it does not exercise the macOS app.

## 2. Typing simulation — `core/tests/typing_sim_test.cpp`

Reproduces the **macOS host's exact output pipeline** (the Unicode-code-table
decode in `platform/macos/Input/InputController.mm`): `vDoNothing` types the
literal key; `vWillProcess`/`vRestore` apply the optional empty char + N
backspaces + decoded characters. It types **continuously** like a real person,
so it catches host-side and word-boundary bugs the engine harness cannot (this
is how the `dd`→`đ` English-detection regression was found and fixed). No AppKit,
CGEvent, or Accessibility permission is needed, so it runs anywhere, including CI.

### Article fixtures — `core/tests/cases/*.txt`

Drop your own test files in `core/tests/cases/`. They are auto-discovered and run
by the simulation. One case per line:

```
<telex keys> => <expected output>     # or separate with a TAB
```

- Lines starting with `#` are comments; blank lines are ignored.
- Trailing whitespace is ignored. A whole sentence on one line is fine (spaces
  are typed as word breaks).
- Directives change the mode for the lines that follow (each file starts as
  Telex, English-detection OFF, modern orthography ON, spell-check ON):
  `@input=telex|vni|simple1|simple2`, `@detect=on|off`, `@modern=on|off`,
  `@spell=on|off`, `@reset`.

See `core/tests/cases/sample.txt` for a worked example. Failures print
`file:line  "keys" -> "got"  (expect "want")` and fail the run.

## 3. Live end-to-end (macOS, manual) — `tools/e2e_type.sh`

Exercises the real CGEvent tap + a real text field, which the simulation cannot:

```sh
bash tools/e2e_type.sh "dd ddi tieesng vieejt"
```

It types into TextEdit via synthetic events and prints the resulting text.
Requirements:
- 84Key is running with **Accessibility** permission (menu bar shows “VI”).
- The controlling terminal has Accessibility + Automation permission.
- Other Vietnamese input methods are disabled.

Tip: build the app with a stable signing identity (`tools/package.sh` re-signs
with your Developer ID / Apple Development automatically) so the Accessibility
grant **persists across rebuilds** instead of being lost each time.

### Per-keystroke diagnostics

Run the app binary with `KEY84_TRACE=1` to log what the engine decided for each
key (code, backspaces, new-char count, options) — useful for diagnosing
live-only issues:

```sh
KEY84_TRACE=1 build/dd/Build/Products/Release/84Key.app/Contents/MacOS/84Key
```
