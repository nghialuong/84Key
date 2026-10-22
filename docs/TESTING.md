# Testing 84Key

84Key is tested at three levels, from fast/pure to full end-to-end, with the
Linux host covered by its own suites (section 4).

```sh
bash core/tests/run_tests.sh     # all the C++ suites below, Linux host included; exit 0 = all pass
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

### Round-trip mode (paste correct Vietnamese)

Easiest of all: a line **with no `=>`/TAB delimiter** is treated as already-correct
text. The harness reverse-encodes it to Telex keystrokes, types them, and verifies
the result equals your line — so you can paste a whole article and have it
re-typed and checked, no keystrokes to write. (English-detection is on and
traditional orthography `òa`/`úy` is used for these lines, matching normal prose;
add `@modern=on` if your text uses the reform `oà`/`uý` spelling.) `core/tests/
cases/roundtrip_sample.txt` shows this.

### Gating vs. report-only

Article fixtures are **report-only**: they print `file:line "keys" -> "got"
(expect "want")` and per-file counts, but do **not** fail the run — so you can
drop in real articles where a few lines legitimately differ (proper nouns or
technical/foreign words outside the bundled ~10k English list, source typos,
spelling conventions). The strict gate that fails CI is the built-in C++ cases
(engine harness + the simulation's own A–G / regression cases).

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

### System search fields (async, backspace-swallowing)

Some system fields apply inline-autocomplete and **drop injected backspaces**, so
a transform like `chúng` would come out `chuúng` (or `đủ` → `dđủ` in a URL bar)
unless we rewrite text differently. Two manual harnesses cover these:

```sh
bash tools/e2e_spotlight.sh            # Spotlight (Cmd+Space): chungs -> chúng
bash tools/e2e_url_bar.sh              # Chromium omnibox:       ddur   -> đủ
```

The Spotlight field is owned by `com.apple.Spotlight` on older macOS and by
`com.apple.campo` on macOS 26/27 (Tahoe); `InputController.mm` detects either by
bundle id **and** by AX behavior (an Apple search field exposing value + selected
range), then replaces text atomically via the Accessibility API — falling back to
a Shift+Left select-and-overwrite when the atomic path can't run. Same terminal
Accessibility + Automation requirement as `e2e_type.sh`.

### Per-keystroke diagnostics

Run the app binary with `KEY84_TRACE=1` to log what the engine decided for each
key (code, backspaces, new-char count, options) — useful for diagnosing
live-only issues:

```sh
KEY84_TRACE=1 build/dd/Build/Products/Release/84Key.app/Contents/MacOS/84Key
```

## 4. Linux

### Host tests — `platform/linux/tests/host_test.cpp`

Pure C++ like the suites above, run by `core/tests/run_tests.sh` (through
`platform/linux/tests/run_tests.sh`) and by `ctest` in the CMake build. The
script first rebuilds the engine harness and the typing simulation with
`-DLINUX`, so the engine's own suites also hold under the Linux key table.

`host_test.cpp` drives `Composer` — the Linux typing pipeline — and models what
an IBus client does with its output (commit, preedit, keys handed back), then
holds it to the macOS pipeline:

- **every Telex word in `viet_telex.dat`**, plain and capitalised, English
  detection off and on (~118,000 sequences), must show the same text on both
  hosts;
- **a seeded random fuzz** — 3,000 sequences in each of a dozen modes (Telex,
  VNI, Simple Telex; detection, spelling, quick Telex, free marking, ...) mixing
  letters, digits, punctuation, spaces and Backspace — must too. The only runs
  set aside are those where the engine asks to rewrite more than the word holds
  (an engine overreach; see `Composer::engineAgrees()`), where the macOS host
  deletes a character it does not own and so is no reference — they are counted
  and reported;
- **the legacy code tables** are checked against `ConvertTool`: typing in TCVN3,
  VNI Windows, Unicode Compound or CP1258, Backspace included, must give the
  conversion of what Unicode typing gives;
- plus the preedit protocol (what is committed when, what reaches the app), the
  Linux-only behaviour (Enter, shortcuts, clicks, keypad, password fields), the
  VI/EN hotkey, and the explicit cases of `core/tests/cases/*.txt`
  (`backspace_restore.txt` gates).

When a differential check fails, look at one script key by key on both hosts, or
at what the Linux host shows for it:

```sh
cd platform/linux/tests
/tmp/key84_linux_host_test --trace "ijfu{BS}w" 0 1    # keys, input type, detection
/tmp/key84_linux_host_test --type "tieesng vieejt"
```

### End-to-end — `platform/linux/tests/e2e.py`

Real keystrokes (XTEST, via `xdotool`) into GTK 3 and GTK 4 text fields, through
the GTK IBus module, a real `ibus-daemon` and the engine binary — which the
daemon finds through a component file, runs with `--xml` and starts with
`--ibus`, exactly as when installed. It checks what the host tests cannot: that
the preedit protocol behaves in a real toolkit (a click mid-word commits the word
once; Enter, Tab and shortcuts land after the word), 500 keys per second, a
password field, live settings changes, the VI/EN hotkey, the input-source menu,
and the trace procedure in [`LINUX.md`](LINUX.md).

```sh
python3 platform/linux/tests/e2e.py --engine build/linux/ibus-engine-84key
```

Everything runs privately — its own D-Bus session, X server (Xvfb), IBus daemon
and config directory — so it never types into your desktop or touches your
settings. Needs `xvfb`, `xdotool`, `ibus`, `ibus-gtk3`, `ibus-gtk4` and
`python3-gi` with the GTK typelibs. CI runs it on every push; `--keep` keeps the
logs, and `KEY84_TRACE=1` in the environment traces the engine into them.
