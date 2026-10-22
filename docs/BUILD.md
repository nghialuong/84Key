# Building 84Key

## Prerequisites

- macOS app: macOS with **Xcode** (command-line tools included), and
  **XcodeGen**: `brew install xcodegen` — generates `84Key.xcodeproj` from
  `platform/macos/project.yml`.
- Linux engine: see [Linux](#linux) below.
- Python 3 (only to regenerate the dictionaries).

## Engine tests

The engine is plain C++14 and builds/runs anywhere:

```sh
bash core/tests/run_tests.sh
```

This compiles `core/engine/*.cpp` with the harness and asserts the Vietnamese
typing, English-detection and option cases. It also runs the keystroke
simulation of the macOS output pipeline. It exits non-zero on any failure and is
the gate used in CI. For the full testing story — including drop-in article
fixtures (`core/tests/cases/*.txt`) and the live end-to-end check — see
[`TESTING.md`](TESTING.md).

## macOS app

```sh
cd platform/macos
xcodegen generate
xcodebuild -scheme 84Key -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The committed `84Key.xcodeproj` can be opened in Xcode directly; regenerate it
whenever you change `project.yml`.

To run the app, build it in Xcode and launch, or open the built `.app`. On first
launch 84Key asks for **Accessibility** permission (System Settings → Privacy &
Security → Accessibility). Disable other Vietnamese input methods (OpenKey, EVKey,
the built-in macOS Vietnamese source) to avoid conflicts.

### Testing a dev build next to an installed release

The Debug configuration builds as a **separate app** — bundle id
`com.nghialuong.key84.debug`, named **"84Key Dev"** — so it gets its own
Accessibility entry and its own settings, without disturbing an installed
release. Only one Vietnamese IME can run at a time, so **quit the release before
launching the Dev build** (and vice-versa); two taps transforming the same keys
produce garbage.

For the Accessibility grant to persist across rebuilds, sign the Dev build with a
real (non-ad-hoc) Apple Development certificate — TCC then keys on the team +
bundle id instead of a per-build hash. Substitute your own team id (the cert's OU,
shown by `security find-identity -v -p codesigning`):

```sh
cd platform/macos
xcodegen generate
xcodebuild -scheme 84Key -configuration Debug \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Development: <Your Name> (XXXXXXXXXX)" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  DEVELOPMENT_TEAM=<TEAMID> \
  build
```

Then grant "84Key Dev" Accessibility once. An unsigned build
(`CODE_SIGNING_ALLOWED=NO`) still runs, but re-prompts after every rebuild.

## Linux

The Linux version is an IBus engine (`platform/linux`, built with CMake) plus a
small settings window (Python, GTK 4, libadwaita). On Ubuntu/Debian:

```sh
sudo apt install build-essential cmake pkg-config libibus-1.0-dev \
                 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
cmake -S platform/linux -B build/linux -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build/linux
ctest --test-dir build/linux --output-on-failure
```

Then either install it (`sudo cmake --install build/linux`, then `ibus
restart`) or build a package (`cd build/linux && cpack` gives
`ibus-84key_<version>_amd64.deb`). The engine is compiled with `-DLINUX`, i.e.
the X11 key table in `core/engine/platforms/linux.h`.

### Running a development build without installing

An engine started without `--ibus` registers itself with the running IBus
daemon, so nothing needs to be installed to try a change:

```sh
KEY84_DATA_DIR=$PWD/core/data KEY84_TRACE=1 build/linux/ibus-engine-84key &
ibus engine 84key        # select it (GNOME switches back on the next source change)
```

`KEY84_TRACE=1` logs every key and what the engine did with it. The settings
window runs straight from the tree:

```sh
python3 platform/linux/setup/ibus-setup-84key.py
```

See [`LINUX.md`](LINUX.md) for the user-facing side and
[`TESTING.md`](TESTING.md#4-linux) for the Linux tests.

## Dictionaries

`core/data/english_words.dat` and `core/data/viet_telex.dat` are committed.
Regenerate with:

```sh
python3 tools/gen_dict.py                      # Vietnamese from rules; keep English
python3 tools/gen_dict.py --english /path/to/google-10000-english.txt
```

## Continuous integration

`.github/workflows/ci.yml` runs on push/PR: the C++ engine test harness (Ubuntu;
it includes the Linux host tests), the Linux IBus engine (build, host tests, the
end-to-end test under Xvfb, and the `.deb` as a build artifact), and the macOS
app build (regenerated via XcodeGen, `CODE_SIGNING_ALLOWED=NO`).

`.github/workflows/release.yml` runs on a version tag (`v*`): it builds, signs,
notarizes, and publishes a `.dmg` as a GitHub Release, then attaches the Linux
`.deb` to it. See [`RELEASE.md`](RELEASE.md).

## Packaging / distribution

`tools/package.sh` produces a runnable `.app` and a `.dmg`. Code signing and
notarization require an Apple Developer account; without one, a locally-signed
build runs after approving it in System Settings → Privacy & Security. For the
automated, signed-and-notarized release flow, see [`RELEASE.md`](RELEASE.md).

On Linux, `cpack` in the CMake build directory produces the `.deb` (its
dependencies are worked out by `dpkg-shlibdeps`, so it targets the release it
was built on — CI builds on Ubuntu 24.04).
