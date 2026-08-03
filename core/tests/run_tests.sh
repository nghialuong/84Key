#!/bin/bash
# Build and run the 84Key engine + English-detection test harness.
# Exits non-zero if any case fails.
set -e
cd "$(dirname "$0")"

# Every .cpp in core/engine, discovered rather than listed. core/CMakeLists.txt
# (the MSVC/Windows path) globs the same directory, so a newly added engine
# source lands in both builds instead of only the one whose list got updated.
ENGINE_SRC=(../engine/*.cpp)
if [ ! -e "${ENGINE_SRC[0]}" ]; then
    echo "ERROR: no engine sources found in ../engine" >&2
    exit 1
fi

# A per-run directory, not a fixed path: two concurrent runs (a local shell and
# a CI step, or two terminals) sharing one would delete each other's objects
# mid-build and fail for reasons that look nothing like the cause.
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/key84_tests_build.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT

# The engine compiles to objects once, at C++14, and both harnesses link against
# them. Compiling the engine into each harness instead would be fine until
# typing_sim_test moved to C++17 (below): a single command cannot hold two
# standards, so the engine would have been dragged along and Engine.cpp's
# std::wstring_convert/<codecvt> pair would emit deprecation warnings on every
# run. core/CMakeLists.txt splits the two the same way, for the same reason.
ENGINE_OBJ=()
for src in "${ENGINE_SRC[@]}"; do
    obj="$BUILD/$(basename "${src%.cpp}").o"
    c++ -std=c++14 -O2 -c -o "$obj" "$src"
    ENGINE_OBJ+=("$obj")
done

OUT="$BUILD/engine_test"
c++ -std=c++14 -O2 -o "$OUT" engine_test.cpp "${ENGINE_OBJ[@]}"
"$OUT"

# Keystroke-level simulation of the macOS host's typing pipeline (catches
# host-decode bugs the engine harness cannot). C++17 because it enumerates
# cases/*.txt with std::filesystem — MSVC ships no <dirent.h>, and W0 of the
# Windows port needs this harness to build there.
SIM="$BUILD/typing_sim_test"
c++ -std=c++17 -O2 -o "$SIM" typing_sim_test.cpp "${ENGINE_OBJ[@]}"
"$SIM"
