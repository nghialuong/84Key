# 84Key on Linux

84Key runs on Linux as an **IBus input method engine**: the input framework
Ubuntu, Fedora, Debian and most GNOME desktops already use. It works in X11 and
Wayland sessions alike, in every application IBus reaches (GTK 3/4, Qt,
LibreOffice, browsers, terminals), and shares the typing engine, the dictionaries
and the English detection with the macOS app.

> Tested: Ubuntu 24.04, IBus 1.5.29, GTK 3 and GTK 4 applications (X11). Other
> IBus setups (KDE Plasma with IBus, Wayland sessions, Fedora) use the same IBus
> protocol and are expected to work; reports welcome.

## Install

### Ubuntu 24.04 or newer, Debian 13

1. Download `ibus-84key_<version>_amd64.deb` from the
   [Releases page](https://github.com/nghialuong/84Key/releases), then:

   ```sh
   sudo apt install ./ibus-84key_*_amd64.deb
   ibus restart
   ```

2. Add 84Key as an input source: open **84Key** from the app grid and click
   **Thêm 84Key** — or Settings → Keyboard → Input Sources → **+** →
   Vietnamese → **84Key**.
3. **Remove other Vietnamese input sources** (Unikey, Bamboo, ...). The settings
   window offers to do it. Two Vietnamese engines on the same keys produce
   doubled or wrong letters.

### Other distributions

Build from source — see [BUILD.md](BUILD.md#linux). You need a C++17 compiler,
CMake and the IBus development files (`libibus-1.0-dev` / `ibus-devel`); the
settings window needs Python 3 with PyGObject, GTK 4 and libadwaita.

## Using it

- **Select 84Key** in the top bar (or with Super + Space, GNOME's input source
  switcher). The indicator shows **VI** or **EN**.
- **VI ⇄ EN inside 84Key**: **Ctrl + Shift** (pressed and released on its own,
  so shortcuts like Ctrl + Shift + T are unaffected). Change it in the settings
  window, or click the indicator and pick *Chế độ gõ*.
- **The indicator menu** has the input method (Telex, VNI, Simple Telex), the
  code table, the common switches and *Cài đặt 84Key…* for everything else.
- **Settings** live in `~/.config/84key/settings.ini` and apply immediately,
  whether changed from the menu, the settings window or by editing the file. A
  file with a syntax error is ignored — and never overwritten — until it is
  fixed.

## How typing works (and why letters are never doubled)

The macOS app lets each key reach the application and then corrects the text
with synthetic backspaces and retyped letters. In asynchronous editors that burst
can arrive out of order, which is where doubled letters come from.

On Linux 84Key never edits text an application already holds:

- the word you are typing is shown as **composing text** (underlined) and every
  correction — a tone moving, ươ forming, an English word restored — happens
  inside it;
- at the end of the word (space, punctuation, Enter, an arrow key, a shortcut)
  the finished word is committed **in one piece**, together with the
  punctuation;
- keys 84Key has nothing to do with — shortcuts, navigation, anything typed while
  no word is open — reach the application untouched;
- clicking elsewhere mid-word, or switching windows, commits the word as shown,
  exactly once;
- password fields get the raw keys, nothing composed.

### Differences from macOS

- **Backspacing into a finished word** deletes characters but does not reopen the
  word for more tone keys: `tieng ⌫ s` gives `tiengs`, where macOS gives `tiếng`.
  Reopening would mean rewriting text the application owns. Backspace *inside*
  the word you are typing works as on macOS.
- **A digit typed right after a space** starts no word, the same as a digit at
  the start of a line (`abc 4Us` → `abc 4Ú`; macOS gives `4Us` after a space).
- The Spotlight and browser-autocomplete fixes do not exist: they work around the
  backspace bursts that this design does not produce.
- **Per-app VI/EN memory** (*Phím chuyển thông minh*) is implemented: IBus names
  the focused application. (Under Wayland the shell may report one name for every
  application; the setting then behaves like a single global VI/EN.)
- Macros are not available yet (as on macOS, there is no macro editor).

## Troubleshooting

**84Key is not in the input source list.** Run `ibus restart` (or log out and
back in) after installing; IBus reads its engine list at start-up. Check with
`ibus list-engine | grep 84key`.

**Typing still produces plain letters.** Make sure 84Key is the selected input
source and shows **VI**, not **EN** (Ctrl + Shift switches). `ibus engine`
should print `84key`.

**Qt or Electron applications ignore 84Key.** Qt needs `QT_IM_MODULE=ibus`
(Ubuntu sets it). Chromium-based applications under Wayland need their Wayland
IME switch, e.g. `--enable-wayland-ime`; under X11 they use IBus directly.

**Barcode scanners or auto-type tools jumble characters in GTK 3 apps.** At
hundreds of keys per second GTK 3's asynchronous IBus client can reorder keys
an engine hands back — with any engine. Start the application with
`IBUS_ENABLE_SYNC_MODE=1` (or set it in `~/.config/environment.d/`).

**Reporting a bug.** Include a trace of what 84Key decided for each key. Stop
the engine IBus started and start it yourself with tracing on; IBus picks it up:

```sh
pkill -f ibus-engine-84key; KEY84_TRACE=1 /usr/libexec/ibus-engine-84key --ibus
```

Every key, focus change and reset is then logged to that terminal (it includes
what you type — trim it before posting). Press Ctrl + C when done; IBus starts a
normal engine again the next time it needs one.

## Uninstall

```sh
sudo apt remove ibus-84key
```

Your settings stay in `~/.config/84key/`; delete that directory to remove them.

## Files

| Path | What |
|---|---|
| `/usr/libexec/ibus-engine-84key` | the engine (started by IBus) |
| `/usr/libexec/ibus-setup-84key` | the settings window |
| `/usr/share/ibus/component/84key.xml` | registers the engine with IBus |
| `/usr/share/84key/` | dictionaries and icon |
| `~/.config/84key/settings.ini` | your settings (same option names as the macOS app) |
| `~/.config/84key/apps.dat` | per-app VI/EN memory |
