#!/bin/bash
# Build and run the Linux host tests. Needs only a C++17 compiler: no IBus, no
# display. Exits non-zero if any case fails.
#
#   1. core/tests' engine harness and typing simulation, built with -DLINUX —
#      the Linux engine uses the X11 key table (core/engine/platforms/linux.h),
#      so the engine's own suites must hold under it too;
#   2. host_test.cpp — the Linux typing pipeline (Composer) against the macOS
#      one, the preedit protocol, the VI/EN hotkey.
#
# The end-to-end test through a real IBus daemon and GTK is tests/e2e.py.
set -eo pipefail
cd "$(dirname "$0")"

CORE=../../../core
ENGINE_SRC="$CORE/engine/Engine.cpp $CORE/engine/Vietnamese.cpp $CORE/engine/Macro.cpp \
            $CORE/engine/SmartSwitchKey.cpp $CORE/engine/ConvertTool.cpp $CORE/engine/EnglishDetect.cpp"
OUT="${TMPDIR:-/tmp}"

echo "== core engine suites, Linux key table =="
c++ -std=c++14 -O2 -DLINUX -o "$OUT/key84_engine_test_linux" $CORE/tests/engine_test.cpp $ENGINE_SRC
c++ -std=c++14 -O2 -DLINUX -o "$OUT/key84_typing_sim_linux" $CORE/tests/typing_sim_test.cpp $ENGINE_SRC
# Both read their data and fixtures relative to core/tests.
(cd $CORE/tests && "$OUT/key84_engine_test_linux" | tail -1 && "$OUT/key84_typing_sim_linux" | tail -1)

echo "== Linux host =="
c++ -std=c++17 -O2 -DLINUX -Wall -Wextra -Wno-deprecated-declarations -I$CORE/engine \
    -o "$OUT/key84_linux_host_test" host_test.cpp \
    ../src/Composer.cpp ../src/SwitchKey.cpp ../src/EngineGlobals.cpp $ENGINE_SRC
"$OUT/key84_linux_host_test" $CORE/data $CORE/tests/cases
