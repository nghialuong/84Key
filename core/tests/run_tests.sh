#!/bin/bash
# Build and run the 84Key engine + English-detection test harness.
# Exits non-zero if any case fails.
set -e
cd "$(dirname "$0")"

ENGINE_SRC="../engine/Engine.cpp ../engine/Vietnamese.cpp ../engine/Macro.cpp \
            ../engine/SmartSwitchKey.cpp ../engine/ConvertTool.cpp ../engine/EnglishDetect.cpp"

OUT="${TMPDIR:-/tmp}/key84_engine_test"
c++ -std=c++14 -O2 -o "$OUT" engine_test.cpp $ENGINE_SRC
"$OUT"

# Keystroke-level simulation of the macOS host's typing pipeline (catches
# host-decode bugs the engine harness cannot).
SIM="${TMPDIR:-/tmp}/key84_typing_sim"
c++ -std=c++14 -O2 -o "$SIM" typing_sim_test.cpp $ENGINE_SRC
"$SIM"
