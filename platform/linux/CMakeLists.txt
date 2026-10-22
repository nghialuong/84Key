# 84Key for Linux — an IBus input method engine around the shared C++ engine.
#
#   cmake -S platform/linux -B build/linux
#   cmake --build build/linux
#   ctest --test-dir build/linux --output-on-failure
#   sudo cmake --install build/linux          # or: cpack --config build/linux/CPackConfig.cmake
#
# See docs/BUILD.md (Linux) for the full story, including running a development
# build without installing anything.

cmake_minimum_required(VERSION 3.16)

# Keep the version in step with the macOS app (platform/macos/project.yml).
project(84key-linux VERSION 0.1.9 LANGUAGES CXX)

# ibus-daemon looks for engines in /usr/share/ibus/component only, so a
# /usr/local install would never be found. Install under /usr unless told
# otherwise.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX /usr CACHE PATH "Install prefix" FORCE)
endif()

include(GNUInstallDirs)

# Installed directories are 0755 whatever the builder's umask (dpkg expects it).
set(CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

set(KEY84_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(KEY84_CORE ${KEY84_ROOT}/core/engine)
set(KEY84_PKGDATADIR ${CMAKE_INSTALL_FULL_DATADIR}/84key)

option(KEY84_BUILD_ENGINE "Build the IBus engine (needs libibus-1.0-dev)" ON)
# Release builds pass the tag's version (see .github/workflows/release.yml).
set(KEY84_VERSION "${PROJECT_VERSION}" CACHE STRING "Version of the engine and the package")

# ---- The shared engine (core/engine, from OpenKey) --------------------------------
# Built with the Linux key table (core/engine/platforms/linux.h). The engine's own
# test suites run against that table too: see tests/run_tests.sh.
add_library(key84core STATIC
    ${KEY84_CORE}/Engine.cpp
    ${KEY84_CORE}/Vietnamese.cpp
    ${KEY84_CORE}/Macro.cpp
    ${KEY84_CORE}/SmartSwitchKey.cpp
    ${KEY84_CORE}/ConvertTool.cpp
    ${KEY84_CORE}/EnglishDetect.cpp)
target_compile_definitions(key84core PUBLIC LINUX)
target_include_directories(key84core PUBLIC ${KEY84_CORE})
# The engine keeps OpenKey's std::wstring_convert, deprecated since C++17.
target_compile_options(key84core PRIVATE -Wno-deprecated-declarations)

# ---- The Linux host, minus IBus (unit-tested) --------------------------------------
add_library(key84host STATIC
    src/Composer.cpp
    src/SwitchKey.cpp
    src/EngineGlobals.cpp)
target_include_directories(key84host PUBLIC src)
target_link_libraries(key84host PUBLIC key84core)
target_compile_options(key84host PRIVATE -Wall -Wextra)

# ---- The IBus engine ---------------------------------------------------------------
if(KEY84_BUILD_ENGINE)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(IBUS REQUIRED IMPORTED_TARGET ibus-1.0>=1.5.0)

    add_executable(ibus-engine-84key
        src/main.cpp
        src/Key84Engine.cpp
        src/Settings.cpp)
    target_link_libraries(ibus-engine-84key PRIVATE key84host PkgConfig::IBUS)
    target_compile_options(ibus-engine-84key PRIVATE -Wall -Wextra)
    target_compile_definitions(ibus-engine-84key PRIVATE
        KEY84_VERSION="${KEY84_VERSION}"
        KEY84_DATADIR="${KEY84_PKGDATADIR}"
        KEY84_SETUP_PATH="${CMAKE_INSTALL_FULL_LIBEXECDIR}/ibus-setup-84key")

    configure_file(data/84key.xml.in 84key.xml @ONLY)
    configure_file(setup/ibus-setup-84key.desktop.in ibus-setup-84key.desktop @ONLY)

    install(TARGETS ibus-engine-84key DESTINATION ${CMAKE_INSTALL_LIBEXECDIR})
    install(PROGRAMS setup/ibus-setup-84key.py
            DESTINATION ${CMAKE_INSTALL_LIBEXECDIR} RENAME ibus-setup-84key)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/84key.xml DESTINATION ${CMAKE_INSTALL_DATADIR}/ibus/component)
    install(FILES ${KEY84_ROOT}/core/data/english_words.dat ${KEY84_ROOT}/core/data/viet_telex.dat
            DESTINATION ${CMAKE_INSTALL_DATADIR}/84key)
    # The app icon is the macOS one, installed straight from its asset catalog.
    install(FILES ${KEY84_ROOT}/platform/macos/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png
            DESTINATION ${CMAKE_INSTALL_DATADIR}/84key/icons RENAME 84key.png)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ibus-setup-84key.desktop
            DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
endif()

# ---- Tests ---------------------------------------------------------------------------
enable_testing()
add_executable(host_test tests/host_test.cpp)
target_link_libraries(host_test PRIVATE key84host)
add_test(NAME host COMMAND host_test ${KEY84_ROOT}/core/data ${KEY84_ROOT}/core/tests/cases)

# ---- Debian package ------------------------------------------------------------------
set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME ibus-84key)
set(CPACK_PACKAGE_VERSION ${KEY84_VERSION})
set(CPACK_PACKAGE_VENDOR "84Key")
set(CPACK_PACKAGE_CONTACT "84Key <https://github.com/nghialuong/84Key/issues>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Vietnamese input method (Telex, VNI) with automatic English detection")
set(CPACK_PACKAGE_DESCRIPTION
    "84Key is a free Vietnamese input method for IBus: Telex, VNI and Simple Telex,\n\
spell checking, and automatic English detection so English words typed in\n\
Telex come out right without switching modes. Words are composed in the\n\
preedit and committed whole, so text is never rewritten with backspaces.")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/nghialuong/84Key")
set(CPACK_DEBIAN_PACKAGE_SECTION utils)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "ibus (>= 1.5.0), python3, python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1")
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_PACKAGING_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX})
include(CPack)
