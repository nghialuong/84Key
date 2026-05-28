#!/bin/bash
# Build and run the 84Key engine + English-detection test harness.
# Exits non-zero if any case fails.
set -e
cd "$(dirname "$0")"

OUT="${TMPDIR:-/tmp}/key84_engine_test"
c++ -std=c++14 -O2 -o "$OUT" \
    engine_test.cpp \
    ../engine/Engine.cpp \
    ../engine/Vietnamese.cpp \
    ../engine/Macro.cpp \
    ../engine/SmartSwitchKey.cpp \
    ../engine/ConvertTool.cpp \
    ../engine/EnglishDetect.cpp

"$OUT"
