# CMake toolchain file: compile OCCT for wasm32-unknown-wasip1 against the SWIFT SDK's sysroot.
#
# Why this file exists instead of wasi-sdk's own wasi-sdk-p1.cmake, which Scripts/build-occt-wasm.sh
# used to fall through to: the two sysroots in play are not interchangeable, and OCCT has to be
# compiled against the same one the Swift side links. Measured, 2026-09-23, both with the pinned
# installs:
#
#   |                        | Swift SDK WASI.sdk | wasi-sdk 34.0 wasm32-wasip1 |
#   |------------------------|--------------------|-----------------------------|
#   | _LIBCPP_HAS_THREADS    | 0                  | 1, in both eh and noeh      |
#   | libc++ _LIBCPP_VERSION | 210106 (LLVM 21)   | LLVM 23.1.0                 |
#   | __cxa_throw in libc++abi.a | absent         | present, in the eh flavour  |
#
# The Swift side links WASI.sdk's libc++ and libc++abi and cannot be told otherwise, so building
# OCCT against wasi-sdk's sysroot would put two libc++ builds, two major versions apart and
# disagreeing about whether std::mutex exists, under one set of mangled names in one module. The
# bridge's flat C ABI keeps C++ types out of Swift's way; it does nothing about which libc++
# definition the linker picks for a symbol both archives define.
#
# So: the Swift SDK's WASI.sdk is the sysroot, the threading shim covers _LIBCPP_HAS_THREADS 0, and
# wasi-sdk contributes exactly one thing, the exception-enabled libc++abi and libunwind from its
# lib/wasm32-wasip1/eh directory, which WASI.sdk has no equivalent of. That is the combination
# PR #2180 built, linked and ran end to end.
#
# The compiler is the swift.org toolchain's clang, not wasi-sdk's and not Xcode's:
#   * Xcode's cannot link for wasm at all (no wasm-ld, no swift-autolink-extract);
#   * wasi-sdk's is LLVM 23 and would compile OCCT against LLVM 21 headers it did not ship.
#
# Inputs, all set by Scripts/build-occt-wasm.sh from Scripts/wasm-toolchain-versions.txt; each is
# required, and a missing one is a hard error rather than a silent host-toolchain fallback:
#   SWIFT_TOOLCHAIN_BIN  the swift.org toolchain's usr/bin
#   SWIFT_WASI_SYSROOT   the Swift wasm SDK's wasm32-unknown-wasip1/WASI.sdk
#   WASI_SDK_EH_LIBDIR   wasi-sdk's share/wasi-sysroot/lib/wasm32-wasip1/eh
#   WASI_SWIFT_BUILTINS_DIR  the Swift wasm SDK's clang builtins dir (wasip1)

# The environment is read as well as the cache, because CMake re-includes a toolchain file inside
# every try_compile sub-project and a -D cache entry does not reach one. Measured: with -D alone,
# CMakeDetermineCompilerABI's try_compile fails on this very FATAL_ERROR, after the parent project
# has already configured fine. Scripts/build-occt-wasm.sh exports all four.
foreach(var SWIFT_TOOLCHAIN_BIN SWIFT_WASI_SYSROOT WASI_SDK_EH_LIBDIR WASI_SWIFT_BUILTINS_DIR)
  if(NOT ${var} AND DEFINED ENV{${var}})
    set(${var} "$ENV{${var}}")
  endif()
endforeach()
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
     SWIFT_TOOLCHAIN_BIN SWIFT_WASI_SYSROOT WASI_SDK_EH_LIBDIR WASI_SWIFT_BUILTINS_DIR)

foreach(var SWIFT_TOOLCHAIN_BIN SWIFT_WASI_SYSROOT WASI_SDK_EH_LIBDIR)
  if(NOT ${var})
    message(FATAL_ERROR "wasi-swift-sdk.cmake: neither -D${var}=... nor ${var} in the environment. "
                        "Scripts/build-occt-wasm.sh sets all of them; configuring by hand means "
                        "setting them by hand.")
  endif()
endforeach()

set(CMAKE_SYSTEM_NAME WASI)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(CMAKE_EXECUTABLE_SUFFIX .wasm)

# wasm32-unknown-wasip1, spelled the way Scripts/wasm-toolchain-versions.txt pins it. wasi-sdk's
# own file says wasm32-wasip1; clang normalises the two to the same target, and the four-field
# spelling is the one the Swift SDK names, so it is the one used here.
set(WASI_SWIFT_TRIPLE wasm32-unknown-wasip1)

set(CMAKE_C_COMPILER   ${SWIFT_TOOLCHAIN_BIN}/clang)
set(CMAKE_CXX_COMPILER ${SWIFT_TOOLCHAIN_BIN}/clang++)
set(CMAKE_ASM_COMPILER ${SWIFT_TOOLCHAIN_BIN}/clang)
set(CMAKE_AR           ${SWIFT_TOOLCHAIN_BIN}/llvm-ar)
set(CMAKE_RANLIB       ${SWIFT_TOOLCHAIN_BIN}/llvm-ranlib)
set(CMAKE_NM           ${SWIFT_TOOLCHAIN_BIN}/llvm-nm)

set(CMAKE_C_COMPILER_TARGET   ${WASI_SWIFT_TRIPLE})
set(CMAKE_CXX_COMPILER_TARGET ${WASI_SWIFT_TRIPLE})
set(CMAKE_ASM_COMPILER_TARGET ${WASI_SWIFT_TRIPLE})

set(CMAKE_SYSROOT ${SWIFT_WASI_SYSROOT})

# This build produces static archives and links nothing, so CMake's compiler check must not try to
# link an executable. Doing so here would drag in the sysroot's own no-exceptions libc++abi and
# report a broken compiler for a step the build never takes. Linking is #2174's, and the two
# variables below are what it will need.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

link_directories(${WASI_SDK_EH_LIBDIR})
if(WASI_SWIFT_BUILTINS_DIR)
  link_directories(${WASI_SWIFT_BUILTINS_DIR})
endif()

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
