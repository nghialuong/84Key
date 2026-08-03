# 84Key core engine + test harness.
#
# This exists so the engine and its test oracle build with MSVC on Windows.
# The POSIX path (`core/tests/run_tests.sh`) stays the canonical local/CI runner
# on macOS and Linux; this file is what the `windows-latest` CI job drives.
#
#   cmake -S core -B build/core
#   cmake --build build/core --config Release
#   ctest --test-dir build/core -C Release --output-on-failure
#
# Both builds compile the same sources with the same standard, so a green run
# here means the same thing a green run of run_tests.sh means.

cmake_minimum_required(VERSION 3.15)
project(key84_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Match run_tests.sh, which compiles every .cpp in core/engine. Globbing (rather
# than a hand-kept list) keeps this file and run_tests.sh from drifting apart
# when an engine source is added; CONFIGURE_DEPENDS re-globs on rebuild.
file(GLOB KEY84_ENGINE_SOURCES CONFIGURE_DEPENDS
     "${CMAKE_CURRENT_SOURCE_DIR}/engine/*.cpp")

if(NOT KEY84_ENGINE_SOURCES)
    message(FATAL_ERROR "No engine sources found in core/engine — wrong source dir?")
endif()

add_library(key84_engine STATIC ${KEY84_ENGINE_SOURCES})
target_include_directories(key84_engine PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/engine")

if(MSVC)
    # /utf-8 is load-bearing, not cosmetic. The engine and both test harnesses
    # carry UTF-8 Vietnamese literals (expected values like "chính", "choải")
    # and none of the files has a BOM. Without /utf-8, MSVC decodes them as the
    # machine's ANSI codepage and the literals silently become mojibake — the
    # oracle would still run, just against corrupted expectations. Removing this
    # flag does not fail loudly; it makes the test suite lie.
    target_compile_options(key84_engine PUBLIC /utf-8 /W3 /EHsc)
    # fopen() in the test harnesses; the engine is otherwise clean.
    target_compile_definitions(key84_engine PUBLIC _CRT_SECURE_NO_WARNINGS)
else()
    target_compile_options(key84_engine PRIVATE -Wall)
endif()

enable_testing()

# The harnesses open their dictionaries and fixtures via paths relative to
# core/tests ("../data/viet_telex.dat", "cases/*.txt"), so every test must run
# with that as its working directory regardless of where the build tree lives.
set(KEY84_TESTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/tests")

foreach(harness engine_test typing_sim_test)
    add_executable(${harness} "${KEY84_TESTS_DIR}/${harness}.cpp")
    target_link_libraries(${harness} PRIVATE key84_engine)
    add_test(NAME ${harness} COMMAND ${harness})
    set_tests_properties(${harness} PROPERTIES WORKING_DIRECTORY "${KEY84_TESTS_DIR}")
endforeach()
