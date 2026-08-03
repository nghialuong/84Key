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

OUT="${TMPDIR:-/tmp}/key84_engine_test"
c++ -std=c++14 -O2 -o "$OUT" engine_test.cpp "${ENGINE_SRC[@]}"
"$OUT"

# Keystroke-level simulation of the macOS host's typing pipeline (catches
# host-decode bugs the engine harness cannot).
SIM="${TMPDIR:-/tmp}/key84_typing_sim"
c++ -std=c++14 -O2 -o "$SIM" typing_sim_test.cpp "${ENGINE_SRC[@]}"
"$SIM"
