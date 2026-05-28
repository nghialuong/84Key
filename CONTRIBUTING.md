# Contributing to 84Key

Thanks for your interest in improving 84Key, a free and open-source Vietnamese
input method for macOS. Contributions of all kinds are welcome: bug reports,
fixes, features, documentation, and translations.

## License of contributions

84Key is licensed under the **GNU General Public License v3.0 (GPLv3)**. By
submitting a contribution, you agree that it will be licensed under GPLv3. This
is required: 84Key derives its typing engine from
[OpenKey](https://github.com/tuyenvm/OpenKey), which is GPLv3, so the whole
project must remain GPLv3. Do not contribute code or data under an incompatible
license.

## Repository layout

84Key is split into two main parts:

- **`core/`** — the C++ typing engine, shared across platforms. This is GPLv3
  and is largely derived from OpenKey. Changes here affect every platform.
- **`platform/macos/`** — the SwiftUI menu-bar application (the macOS front
  end).

Keep platform-agnostic typing logic in `core/`, and keep macOS-specific code
(menu bar, settings UI, Accessibility integration) in `platform/macos/`.

## Before you submit

1. **Run the engine tests.** Any change that touches `core/` must pass the C++
   test suite:

   ```sh
   bash core/tests/run_tests.sh
   ```

   Do not submit a change with failing tests, and never skip or fake tests.

2. **Build the macOS app** if your change touches `platform/macos/`, to make
   sure it still compiles (Xcode / `xcodebuild`).

## Commit style

We use [Conventional Commits](https://www.conventionalcommits.org/). Use one
logical change per commit and a clear type prefix, optionally with a scope:

- `feat:` / `feat(core):` — a new feature
- `fix:` / `fix(macos):` — a bug fix
- `docs:` — documentation only
- `test:` — adding or fixing tests
- `refactor:` — code change that neither fixes a bug nor adds a feature
- `ci:`, `build:`, `chore:` — tooling, build, and maintenance

Example: `fix(core): correct tone placement for "qu" and "gi" clusters`.

## Code style

- For **original 84Key code**, follow the conventions already used in the
  surrounding files (Swift API design guidelines for SwiftUI, idiomatic modern
  C++ for new engine code).
- **Do not reformat reused engine files.** The files derived from OpenKey
  should keep their original formatting and structure so that upstream changes
  remain easy to track and diffs stay minimal. Make only the changes needed.

## Filing issues

Open an issue on GitHub. For bug reports, please include:

- macOS version and Mac model.
- The input method (Telex / VNI / Simple Telex) and code table in use.
- Exact keystrokes typed and the expected vs. actual output.
- Whether any other Vietnamese IME (OpenKey, EVKey, etc.) was running.

## Pull requests

1. Fork the repository and create a topic branch off `main`.
2. Make your change with focused, conventional commits.
3. Run the engine tests (and build the app if relevant).
4. Open a pull request describing the change and the motivation behind it.
5. Reference any related issues.

For security issues, please do **not** open a public issue. See
[SECURITY.md](SECURITY.md).
